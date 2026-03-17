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

  @override
  void close({bool force = false}) {}

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
