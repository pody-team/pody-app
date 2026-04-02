import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pody/core/network/api_client.dart';
import 'package:pody/core/network/api_exception.dart';

void main() {
  group('ApiClient', () {
    test('tu dong gan access token cho request protected', () async {
      final apiClient = ApiClient(baseUrl: 'https://example.com');
      final adapter = _FakeAdapter((request) async {
        expect(request.headers['Authorization'], 'Bearer access-token-1');
        return _jsonResponse(200, {'status': 'ok'});
      });
      apiClient.dio.httpClientAdapter = adapter;
      apiClient.attachAuthenticator(
        getValidAccessToken: () async => 'access-token-1',
        refreshAccessToken: () async => 'access-token-2',
        clearSession: () async {},
      );

      final response = await apiClient.get(
        '/api/v1/identity/me',
        requiresAuth: true,
      );

      expect(response['status'], 'ok');
      expect(adapter.requestCount, 1);
    });

    test('tu dong refresh token va retry mot lan khi gap 401', () async {
      final apiClient = ApiClient(baseUrl: 'https://example.com');
      var refreshCount = 0;
      final adapter = _FakeAdapter((request) async {
        final authorization = request.headers['Authorization'];
        if (authorization == 'Bearer stale-token') {
          return _jsonResponse(401, {'error': 'invalid token'});
        }
        expect(authorization, 'Bearer fresh-token');
        return _jsonResponse(200, {'status': 'retried'});
      });
      apiClient.dio.httpClientAdapter = adapter;
      apiClient.attachAuthenticator(
        getValidAccessToken: () async => 'stale-token',
        refreshAccessToken: () async {
          refreshCount += 1;
          return 'fresh-token';
        },
        clearSession: () async {},
      );

      final response = await apiClient.get('/protected', requiresAuth: true);

      expect(response['status'], 'retried');
      expect(refreshCount, 1);
      expect(adapter.requestCount, 2);
    });

    test('clear session khi refresh fail', () async {
      final apiClient = ApiClient(baseUrl: 'https://example.com');
      var cleared = false;
      final adapter = _FakeAdapter((request) async {
        expect(request.headers['Authorization'], 'Bearer expired-token');
        return _jsonResponse(401, {'error': 'invalid token'});
      });
      apiClient.dio.httpClientAdapter = adapter;
      apiClient.attachAuthenticator(
        getValidAccessToken: () async => 'expired-token',
        refreshAccessToken: () async => null,
        clearSession: () async {
          cleared = true;
        },
      );

      try {
        await apiClient.get('/protected', requiresAuth: true);
        fail('Expected ApiException to be thrown.');
      } on ApiException {
        // Expected path.
      }

      expect(cleared, isTrue);
      expect(adapter.requestCount, 1);
    });

    test('reset transport va mo lai SSE stream sau khi roi mang', () async {
      late final _FakeAdapter initialAdapter;
      final recoveredAdapter = _FakeAdapter((request) async {
        expect(request.responseType, ResponseType.stream);
        expect(request.headers['Connection'], 'close');
        expect(request.persistentConnection, isFalse);
        return ResponseBody.fromString(
          'event: done\ndata: {"thread_id":"thread-1"}\n\n',
          200,
          headers: {
            Headers.contentTypeHeader: ['text/event-stream'],
          },
        );
      });
      var adapterFactoryCalls = 0;

      initialAdapter = _FakeAdapter((request) async {
        throw DioException.connectionError(
          requestOptions: request,
          reason: 'socket closed',
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'https://example.com',
        httpClientAdapterFactory: () {
          adapterFactoryCalls += 1;
          return adapterFactoryCalls == 1 ? initialAdapter : recoveredAdapter;
        },
      );

      final responseBody = await apiClient.openEventStream(
        '/api/v1/ai/chat-create/threads/stream',
        method: 'POST',
      );

      expect(responseBody.statusCode, 200);
      expect(adapterFactoryCalls, 2);
      expect(initialAdapter.closeCallCount, 1);
      expect(initialAdapter.lastForceClose, isTrue);
      expect(recoveredAdapter.requestCount, 1);
    });

    test('chu dong reset transport truoc request moi sau mot khoang idle dai', () async {
      var now = DateTime(2026, 4, 2, 8, 0, 0);
      late final _FakeAdapter initialAdapter;
      final refreshedAdapter = _FakeAdapter((request) async {
        return _jsonResponse(200, {'status': 'fresh-transport'});
      });
      var adapterFactoryCalls = 0;

      initialAdapter = _FakeAdapter((request) async {
        return _jsonResponse(200, {'status': 'initial-transport'});
      });

      final apiClient = ApiClient(
        baseUrl: 'https://example.com',
        httpClientAdapterFactory: () {
          adapterFactoryCalls += 1;
          return adapterFactoryCalls == 1 ? initialAdapter : refreshedAdapter;
        },
        transportIdleResetThreshold: const Duration(minutes: 1),
        nowProvider: () => now,
      );

      final firstResponse = await apiClient.get('/ping');
      expect(firstResponse['status'], 'initial-transport');

      now = now.add(const Duration(minutes: 2));

      final secondResponse = await apiClient.get('/ping');
      expect(secondResponse['status'], 'fresh-transport');
      expect(adapterFactoryCalls, 2);
      expect(initialAdapter.closeCallCount, 1);
      expect(initialAdapter.lastForceClose, isTrue);
      expect(refreshedAdapter.requestCount, 1);
    });
  });
}

ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromBytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions request) _handler;
  int requestCount = 0;
  int closeCallCount = 0;
  bool lastForceClose = false;

  @override
  void close({bool force = false}) {
    closeCallCount += 1;
    lastForceClose = force;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount += 1;
    return _handler(options);
  }
}
