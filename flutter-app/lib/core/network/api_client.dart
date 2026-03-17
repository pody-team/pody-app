import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_exception.dart';

typedef AccessTokenProvider = Future<String?> Function();
typedef AccessTokenRefresher = Future<String?> Function();
typedef SessionInvalidator = Future<void> Function();

class ApiClient {
  ApiClient({required this.baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final requiresAuth = options.extra[_requiresAuthKey] == true;
          final authorization = (options.headers['Authorization'] as String?)
              ?.trim();
          if (requiresAuth &&
              (authorization == null || authorization.isEmpty)) {
            final token = await _getValidAccessToken?.call();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final requiresAuth = request.extra[_requiresAuthKey] == true;
          final didRetry = request.extra[_retryKey] == true;
          final isUnauthorized = error.response?.statusCode == 401;

          if (requiresAuth &&
              isUnauthorized &&
              !didRetry &&
              _refreshAccessToken != null) {
            try {
              final refreshedToken = await _performSingleRefresh();
              if (refreshedToken != null && refreshedToken.isNotEmpty) {
                final response = await _retryRequest(request, refreshedToken);
                return handler.resolve(response);
              }
            } catch (_) {
              // Fall through and let the original error bubble up.
            }

            if (_clearSession != null) {
              await _clearSession!.call();
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  static const _requiresAuthKey = 'requiresAuth';
  static const _retryKey = 'retriedAfterRefresh';

  final String baseUrl;
  final Dio _dio;

  Dio get dio => _dio;

  AccessTokenProvider? _getValidAccessToken;
  AccessTokenRefresher? _refreshAccessToken;
  SessionInvalidator? _clearSession;
  Future<String?>? _ongoingRefresh;

  void attachAuthenticator({
    required AccessTokenProvider getValidAccessToken,
    required AccessTokenRefresher refreshAccessToken,
    required SessionInvalidator clearSession,
  }) {
    _getValidAccessToken = getValidAccessToken;
    _refreshAccessToken = refreshAccessToken;
    _clearSession = clearSession;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    String? bearerToken,
    bool requiresAuth = false,
  }) {
    return _send(
      'GET',
      path,
      bearerToken: bearerToken,
      requiresAuth: requiresAuth,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
    bool requiresAuth = false,
  }) {
    return _send(
      'POST',
      path,
      body: body,
      bearerToken: bearerToken,
      requiresAuth: requiresAuth,
    );
  }

  Future<void> postWithoutResponseBody(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
    bool requiresAuth = false,
  }) async {
    await _send(
      'POST',
      path,
      body: body,
      bearerToken: bearerToken,
      requiresAuth: requiresAuth,
      expectResponseBody: false,
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
    bool requiresAuth = false,
  }) {
    return _send(
      'PATCH',
      path,
      body: body,
      bearerToken: bearerToken,
      requiresAuth: requiresAuth,
    );
  }

  Future<void> patchWithoutResponseBody(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
    bool requiresAuth = false,
  }) async {
    await _send(
      'PATCH',
      path,
      body: body,
      bearerToken: bearerToken,
      requiresAuth: requiresAuth,
      expectResponseBody: false,
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
    bool requiresAuth = false,
    bool expectResponseBody = true,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(
          method: method,
          headers: {
            if (body != null) 'Content-Type': 'application/json',
            if (bearerToken != null && bearerToken.isNotEmpty)
              'Authorization': 'Bearer $bearerToken',
          },
          extra: {_requiresAuthKey: requiresAuth},
        ),
      );

      if (!expectResponseBody) {
        return const <String, dynamic>{};
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is String && data.trim().isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }

      throw ApiException('May chu tra ve du lieu khong hop le.');
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on FormatException {
      throw ApiException('May chu tra ve du lieu khong hop le.');
    }
  }

  Future<String?> _performSingleRefresh() {
    final existing = _ongoingRefresh;
    if (existing != null) {
      return existing;
    }

    final future = _refreshAccessToken!.call();
    _ongoingRefresh = future;

    return future.whenComplete(() {
      if (identical(_ongoingRefresh, future)) {
        _ongoingRefresh = null;
      }
    });
  }

  Future<Response<dynamic>> _retryRequest(
    RequestOptions request,
    String accessToken,
  ) {
    return _dio.request<dynamic>(
      request.path,
      data: request.data,
      queryParameters: request.queryParameters,
      cancelToken: request.cancelToken,
      options: Options(
        method: request.method,
        headers: {...request.headers, 'Authorization': 'Bearer $accessToken'},
        responseType: request.responseType,
        contentType: request.contentType,
        sendTimeout: request.sendTimeout,
        receiveTimeout: request.receiveTimeout,
        extra: {...request.extra, _requiresAuthKey: true, _retryKey: true},
      ),
    );
  }

  ApiException _mapDioException(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ApiException(
        'Khong the ket noi den may chu. Hay kiem tra lai backend va mang.',
      );
    }

    final response = error.response;
    if (response == null) {
      return ApiException('Yeu cau that bai.');
    }

    final message = _extractErrorMessage(response.data) ?? 'Yeu cau that bai.';
    return ApiException(message, statusCode: response.statusCode);
  }

  String? _extractErrorMessage(Object? responseBody) {
    if (responseBody is Map<String, dynamic>) {
      final message = responseBody['error'] ?? responseBody['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
      return null;
    }

    if (responseBody is String && responseBody.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) {
          final message = decoded['error'] ?? decoded['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message;
          }
        }
      } catch (_) {
        return responseBody;
      }
    }

    return null;
  }
}
