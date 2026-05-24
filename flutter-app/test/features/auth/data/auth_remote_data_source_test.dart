import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart'
    show Headers, HttpClientAdapter, RequestOptions, ResponseBody;
import 'package:flutter_test/flutter_test.dart';
import 'package:pody/core/config/app_environment.dart';
import 'package:pody/core/network/api_client.dart';
import 'package:pody/features/auth/data/auth_remote_data_source.dart';

void main() {
  test(
    'uploadAvatar rewrites internal MinIO URLs to the public /minio path',
    () async {
      final apiClient = ApiClient(baseUrl: AppEnvironment.apiBaseUrl);
      apiClient.dio.httpClientAdapter = _FakeAdapter((request) async {
        expect(request.path, '/api/v1/identity/me/avatar');
        return _jsonResponse(201, {
          'avatar_url':
              'http://localhost:9000/identity-avatars/avatars/user-1/avatar.png',
        });
      });

      final dataSource = AuthRemoteDataSource(apiClient);
      final avatarUrl = await dataSource.uploadAvatar(
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'avatar.png',
        contentType: 'image/png',
      );

      expect(
        avatarUrl,
        '${AppEnvironment.apiBaseUrl}/minio/identity-avatars/avatars/user-1/avatar.png',
      );
    },
  );

  test(
    'me rewrites same-host bucket URLs that are missing the /minio prefix',
    () async {
      final apiClient = ApiClient(baseUrl: AppEnvironment.apiBaseUrl);
      apiClient.dio.httpClientAdapter = _FakeAdapter((request) async {
        expect(request.path, '/api/v1/identity/me');
        return _jsonResponse(200, {
          'user': {
            'id': 'user-1',
            'email': 'creator@pody.vn',
            'display_name': 'Creator Prime',
            'status': 'active',
            'avatar_url':
                '${AppEnvironment.apiBaseUrl}/identity-avatars/avatars/user-1/avatar.png',
          },
        });
      });

      final dataSource = AuthRemoteDataSource(apiClient);
      final user = await dataSource.me();

      expect(
        user.avatarUrl,
        '${AppEnvironment.apiBaseUrl}/minio/identity-avatars/avatars/user-1/avatar.png',
      );
    },
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

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options);
  }
}
