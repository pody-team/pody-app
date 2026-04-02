import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pody/core/network/api_client.dart';
import 'package:pody/features/ai/data/ai_remote_data_source.dart';
import 'package:pody/features/ai/domain/ai_models.dart';
import 'package:pody/features/auth/data/auth_local_data_source.dart';
import 'package:pody/features/auth/data/auth_remote_data_source.dart';
import 'package:pody/features/auth/data/auth_repository.dart';
import 'package:pody/features/auth/data/google_auth_data_source.dart';
import 'package:pody/features/auth/domain/auth_session.dart';
import 'package:pody/features/auth/domain/auth_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Auth refresh flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'request protected tu refresh bang public auth client khi access token het han',
      () async {
        final protectedApiClient = ApiClient(baseUrl: 'https://example.com');
        final publicAuthApiClient = ApiClient(baseUrl: 'https://example.com');
        final protectedAdapter = _FakeAdapter((request) async {
          expect(request.headers['Authorization'], 'Bearer fresh-access-token');
          return _jsonResponse(200, {
            'user': {
              'id': 'user-1',
              'email': 'user@pody.vn',
              'display_name': 'Pody User',
              'status': 'active',
            },
          });
        });
        final publicAdapter = _FakeAdapter((request) async {
          expect(request.path, '/api/v1/public/identity/refresh');
          expect(
            request.data,
            isA<Map<String, dynamic>>().having(
              (body) => body['refresh_token'],
              'refresh_token',
              'refresh-token',
            ),
          );
          return _jsonResponse(200, _refreshPayload());
        });
        protectedApiClient.dio.httpClientAdapter = protectedAdapter;
        publicAuthApiClient.dio.httpClientAdapter = publicAdapter;

        final localDataSource = AuthLocalDataSource();
        await localDataSource.saveSession(_expiredSession());

        final authRepository = AuthRepository(
          remoteDataSource: AuthRemoteDataSource(
            protectedApiClient,
            publicApiClient: publicAuthApiClient,
          ),
          localDataSource: localDataSource,
          googleAuthDataSource: _FakeGoogleAuthDataSource(),
        );
        protectedApiClient.attachAuthenticator(
          getValidAccessToken: authRepository.getValidAccessToken,
          refreshAccessToken: authRepository.refreshAccessTokenForApiClient,
          clearSession: authRepository.clearSessionForApiClient,
        );

        final response = await protectedApiClient
            .get('/api/v1/identity/me', requiresAuth: true)
            .timeout(const Duration(seconds: 1));

        expect(
          (response['user'] as Map<String, dynamic>)['email'],
          'user@pody.vn',
        );
        expect(publicAdapter.requestCount, 1);
        expect(protectedAdapter.requestCount, 1);
        expect(
          (await localDataSource.readSession())?.accessToken,
          'fresh-access-token',
        );
      },
    );

    test(
      'SSE AI mo duoc stream sau khi refresh access token bang public auth client',
      () async {
        final protectedApiClient = ApiClient(baseUrl: 'https://example.com');
        final publicAuthApiClient = ApiClient(baseUrl: 'https://example.com');
        final protectedAdapter = _FakeAdapter((request) async {
          expect(request.headers['Authorization'], 'Bearer fresh-access-token');
          expect(request.responseType, ResponseType.stream);
          return ResponseBody.fromBytes(
            utf8.encode(
              'event: status\ndata: {"message":"Dang tim thong tin","phase":"search"}\n\n'
              'event: done\ndata: {"thread_id":"thread-1"}\n\n',
            ),
            200,
            headers: {
              Headers.contentTypeHeader: ['text/event-stream'],
            },
          );
        });
        final publicAdapter = _FakeAdapter((request) async {
          expect(request.path, '/api/v1/public/identity/refresh');
          return _jsonResponse(200, _refreshPayload());
        });
        protectedApiClient.dio.httpClientAdapter = protectedAdapter;
        publicAuthApiClient.dio.httpClientAdapter = publicAdapter;

        final localDataSource = AuthLocalDataSource();
        await localDataSource.saveSession(_expiredSession());

        final authRepository = AuthRepository(
          remoteDataSource: AuthRemoteDataSource(
            protectedApiClient,
            publicApiClient: publicAuthApiClient,
          ),
          localDataSource: localDataSource,
          googleAuthDataSource: _FakeGoogleAuthDataSource(),
        );
        protectedApiClient.attachAuthenticator(
          getValidAccessToken: authRepository.getValidAccessToken,
          refreshAccessToken: authRepository.refreshAccessTokenForApiClient,
          clearSession: authRepository.clearSessionForApiClient,
        );

        final remote = AIRemoteDataSource(protectedApiClient);

        final events = await remote
            .streamCreateThread(prompt: 'Tao show moi')
            .take(2)
            .toList()
            .timeout(const Duration(seconds: 1));

        expect(events[0].type, AIChatStreamEventType.status);
        expect(events[0].phase, 'search');
        expect(events[1].type, AIChatStreamEventType.done);
        expect(events[1].threadId, 'thread-1');
        expect(publicAdapter.requestCount, 1);
        expect(protectedAdapter.requestCount, 1);
      },
    );
  });
}

Map<String, dynamic> _refreshPayload() {
  final now = DateTime.now().toUtc();
  return {
    'user': {
      'id': 'user-1',
      'email': 'user@pody.vn',
      'display_name': 'Pody User',
      'status': 'active',
    },
    'tokens': {
      'access_token': 'fresh-access-token',
      'refresh_token': 'fresh-refresh-token',
      'access_token_expires_at': now
          .add(const Duration(hours: 1))
          .toIso8601String(),
      'refresh_token_expires_at': now
          .add(const Duration(days: 30))
          .toIso8601String(),
      'token_type': 'Bearer',
    },
  };
}

AuthSession _expiredSession() {
  final now = DateTime.now().toUtc();
  return AuthSession(
    user: const AuthUser(
      id: 'user-1',
      email: 'user@pody.vn',
      displayName: 'Pody User',
      status: 'active',
    ),
    accessToken: 'expired-access-token',
    refreshToken: 'refresh-token',
    accessTokenExpiresAt: now.subtract(const Duration(minutes: 5)),
    refreshTokenExpiresAt: now.add(const Duration(days: 30)),
    tokenType: 'Bearer',
  );
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

class _FakeGoogleAuthDataSource implements GoogleAuthDataSource {
  @override
  Future<String> signIn() async => 'google-id-token';

  @override
  Future<void> signOut() async {}
}
