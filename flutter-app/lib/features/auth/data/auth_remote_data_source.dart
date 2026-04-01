import '../../../core/network/api_client.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';
import '../domain/password_reset_challenge.dart';
import '../domain/verification_challenge.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/public/identity/sign-in',
      body: {'email': email, 'password': password},
    );

    return _parseAuthSession(response);
  }

  Future<AuthSession> signInWithGoogle(String idToken) async {
    final response = await _apiClient.post(
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
    final response = await _apiClient.post(
      '/api/v1/public/identity/sign-up',
      body: {'email': email, 'password': password, 'display_name': displayName},
    );

    return VerificationChallenge.fromJson(response);
  }

  Future<VerificationChallenge> resendVerification(String email) async {
    final response = await _apiClient.post(
      '/api/v1/public/identity/resend-verification',
      body: {'email': email},
    );

    return VerificationChallenge.fromJson(response);
  }

  Future<PasswordResetChallenge> forgotPassword(String email) async {
    final response = await _apiClient.post(
      '/api/v1/public/identity/forgot-password',
      body: {'email': email},
    );

    return PasswordResetChallenge.fromJson(response);
  }

  Future<String> verifyResetOTP({
    required String email,
    required String otp,
  }) async {
    final response = await _apiClient.post(
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
    final response = await _apiClient.post(
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

    return AuthUser.fromJson(
      response['user'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<AuthUser> me() async {
    final response = await _apiClient.get(
      '/api/v1/identity/me',
      requiresAuth: true,
    );

    return AuthUser.fromJson(
      response['user'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _apiClient.post(
      '/api/v1/public/identity/refresh',
      body: {'refresh_token': refreshToken},
    );

    return _parseAuthSession(response);
  }

  Future<void> signOut(String refreshToken) async {
    await _apiClient.postWithoutResponseBody(
      '/api/v1/public/identity/sign-out',
      body: {'refresh_token': refreshToken},
    );
  }

  AuthSession _parseAuthSession(Map<String, dynamic> response) {
    final user = response['user'] as Map<String, dynamic>? ?? const {};
    final tokens = response['tokens'] as Map<String, dynamic>? ?? const {};

    return AuthSession.fromJson({
      'user': user,
      'access_token': tokens['access_token'],
      'refresh_token': tokens['refresh_token'],
      'access_token_expires_at': tokens['access_token_expires_at'],
      'refresh_token_expires_at': tokens['refresh_token_expires_at'],
      'token_type': tokens['token_type'],
    });
  }
}
