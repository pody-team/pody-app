import 'dart:typed_data';

import '../../../core/config/app_environment.dart';
import '../../../core/network/api_client.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';
import '../domain/password_reset_challenge.dart';
import '../domain/verification_challenge.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._apiClient, {ApiClient? publicApiClient})
    : _publicApiClient = publicApiClient ?? _apiClient;

  final ApiClient _apiClient;
  final ApiClient _publicApiClient;

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _publicApiClient.post(
      '/api/v1/public/identity/sign-in',
      body: {'email': email, 'password': password},
    );

    return _parseAuthSession(response);
  }

  Future<AuthSession> signInWithGoogle(String idToken) async {
    final response = await _publicApiClient.post(
      '/api/v1/public/identity/google',
      body: {'id_token': idToken},
    );

    return _parseAuthSession(response);
  }

  Future<VerificationChallenge> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _publicApiClient.post(
      '/api/v1/public/identity/sign-up',
      body: {'email': email, 'password': password, 'display_name': displayName},
    );

    return VerificationChallenge.fromJson(response);
  }

  Future<VerificationChallenge> resendVerification(String email) async {
    final response = await _publicApiClient.post(
      '/api/v1/public/identity/resend-verification',
      body: {'email': email},
    );

    return VerificationChallenge.fromJson(response);
  }

  Future<PasswordResetChallenge> forgotPassword(String email) async {
    final response = await _publicApiClient.post(
      '/api/v1/public/identity/forgot-password',
      body: {'email': email},
    );

    return PasswordResetChallenge.fromJson(response);
  }

  Future<String> verifyResetOTP({
    required String email,
    required String otp,
  }) async {
    final response = await _publicApiClient.post(
      '/api/v1/public/identity/verify-reset-otp',
      body: {'email': email, 'otp': otp},
    );

    return response['message'] as String? ?? 'password reset otp verified';
  }

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await _publicApiClient.post(
      '/api/v1/public/identity/reset-password',
      body: {'email': email, 'otp': otp, 'new_password': newPassword},
    );

    return response['message'] as String? ?? 'password reset successful';
  }

  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/identity/change-password',
      requiresAuth: true,
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );

    return response['message'] as String? ?? 'password changed successfully';
  }

  Future<AuthUser> updateProfile({
    required String displayName,
    required String username,
    required String bio,
    required String avatarUrl,
  }) async {
    final response = await _apiClient.patch(
      '/api/v1/identity/me',
      requiresAuth: true,
      body: {
        'display_name': displayName,
        'username': username,
        'bio': bio,
        'avatar_url': avatarUrl,
      },
    );

    return _parseAuthUser(
      response['user'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    final response = await _apiClient.postMultipart(
      '/api/v1/identity/me/avatar',
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      requiresAuth: true,
    );

    return _normalizeAvatarUrl(response['avatar_url'] as String? ?? '');
  }

  Future<AuthUser> me() async {
    final response = await _apiClient.get(
      '/api/v1/identity/me',
      requiresAuth: true,
    );

    return _parseAuthUser(
      response['user'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _publicApiClient.post(
      '/api/v1/public/identity/refresh',
      body: {'refresh_token': refreshToken},
    );

    return _parseAuthSession(response);
  }

  Future<void> signOut(String refreshToken) async {
    await _publicApiClient.postWithoutResponseBody(
      '/api/v1/public/identity/sign-out',
      body: {'refresh_token': refreshToken},
    );
  }

  AuthSession _parseAuthSession(Map<String, dynamic> response) {
    final user = response['user'] as Map<String, dynamic>? ?? const {};
    final tokens = response['tokens'] as Map<String, dynamic>? ?? const {};

    return AuthSession.fromJson({
      'user': _normalizedUserJson(user),
      'access_token': tokens['access_token'],
      'refresh_token': tokens['refresh_token'],
      'access_token_expires_at': tokens['access_token_expires_at'],
      'refresh_token_expires_at': tokens['refresh_token_expires_at'],
      'token_type': tokens['token_type'],
    });
  }

  AuthUser _parseAuthUser(Map<String, dynamic> user) {
    return AuthUser.fromJson(_normalizedUserJson(user));
  }

  Map<String, dynamic> _normalizedUserJson(Map<String, dynamic> user) {
    final normalized = Map<String, dynamic>.from(user);
    final avatarUrl = user['avatar_url'] as String?;
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      normalized['avatar_url'] = _normalizeAvatarUrl(avatarUrl);
    }
    return normalized;
  }

  String _normalizeAvatarUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return raw;
    }

    final apiBaseUri = Uri.tryParse(AppEnvironment.apiBaseUrl.trim());
    if (apiBaseUri == null ||
        !apiBaseUri.hasScheme ||
        apiBaseUri.host.isEmpty) {
      return raw;
    }

    final pathSegments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (pathSegments.isEmpty) {
      return raw;
    }

    if (uri.host == apiBaseUri.host && pathSegments.first == 'minio') {
      return raw;
    }

    final shouldRewriteInternalHost = _isInternalMinioHost(uri.host);
    final shouldRewriteMissingMinioPrefix =
        uri.host == apiBaseUri.host && pathSegments.first == 'identity-avatars';
    if (!shouldRewriteInternalHost && !shouldRewriteMissingMinioPrefix) {
      return raw;
    }

    final normalizedPathSegments = <String>[
      ...apiBaseUri.pathSegments.where((segment) => segment.isNotEmpty),
      'minio',
      ...pathSegments.where((segment) => segment != 'minio'),
    ];

    return apiBaseUri
        .replace(
          pathSegments: normalizedPathSegments,
          query: uri.hasQuery ? uri.query : null,
          fragment: uri.hasFragment ? uri.fragment : null,
        )
        .toString();
  }

  bool _isInternalMinioHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '0.0.0.0' ||
        normalized == 'minio' ||
        normalized == 'pody-minio';
  }
}
