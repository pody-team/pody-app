import '../../../core/network/api_exception.dart';
import '../domain/auth_session.dart';
import '../domain/password_reset_challenge.dart';
import '../domain/verification_challenge.dart';
import 'auth_local_data_source.dart';
import 'auth_remote_data_source.dart';
import 'google_auth_data_source.dart';

class AuthRepository {
  AuthRepository({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required GoogleAuthDataSource googleAuthDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource,
       _googleAuthDataSource = googleAuthDataSource;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final GoogleAuthDataSource _googleAuthDataSource;

  Future<AuthSession?> restoreSession() async {
    final usableSession = await _getUsableSession();
    if (usableSession == null) {
      return null;
    }

    try {
      final user = await _remoteDataSource.me();
      final refreshedSession = AuthSession(
        user: user,
        accessToken: usableSession.accessToken,
        refreshToken: usableSession.refreshToken,
        accessTokenExpiresAt: usableSession.accessTokenExpiresAt,
        refreshTokenExpiresAt: usableSession.refreshTokenExpiresAt,
        tokenType: usableSession.tokenType,
      );
      await _localDataSource.saveSession(refreshedSession);
      return refreshedSession;
    } on ApiException catch (error) {
      if (!error.isUnauthorized &&
          !_isExpired(usableSession.accessTokenExpiresAt)) {
        return usableSession;
      }
    }

    return _refreshSession(usableSession);
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final session = await _remoteDataSource.signIn(
      email: email,
      password: password,
    );
    await _localDataSource.saveSession(session);
    return session;
  }

  Future<AuthSession> signInWithGoogle() async {
    final idToken = await _googleAuthDataSource.signIn();
    final session = await _remoteDataSource.signInWithGoogle(idToken);
    await _localDataSource.saveSession(session);
    return session;
  }

  Future<VerificationChallenge> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _remoteDataSource.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  Future<VerificationChallenge> resendVerification(String email) {
    return _remoteDataSource.resendVerification(email);
  }

  Future<PasswordResetChallenge> forgotPassword(String email) {
    return _remoteDataSource.forgotPassword(email);
  }

  Future<String> verifyResetOTP({required String email, required String otp}) {
    return _remoteDataSource.verifyResetOTP(email: email, otp: otp);
  }

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _remoteDataSource.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
  }

  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = await _getUsableSession();
    if (session == null || session.accessToken.isEmpty) {
      throw ApiException(
        'Phien dang nhap da het han. Hay dang nhap lai de tiep tuc.',
        statusCode: 401,
      );
    }

    return _remoteDataSource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<String?> getValidAccessToken() async {
    final session = await _getUsableSession();
    return session?.accessToken;
  }

  Future<String?> refreshAccessTokenForApiClient() async {
    final storedSession = await _localDataSource.readSession();
    if (storedSession == null) {
      return null;
    }
    if (_isExpired(storedSession.refreshTokenExpiresAt)) {
      await _localDataSource.clearSession();
      return null;
    }

    final refreshedSession = await _refreshSession(storedSession);
    return refreshedSession?.accessToken;
  }

  Future<void> clearSessionForApiClient() {
    return _localDataSource.clearSession();
  }

  Future<void> signOut(AuthSession? session) async {
    if (session != null && session.refreshToken.isNotEmpty) {
      try {
        await _remoteDataSource.signOut(session.refreshToken);
      } on ApiException {
        // Local sign-out should still succeed even if the backend token is gone.
      }
    }

    try {
      await _googleAuthDataSource.signOut();
    } catch (_) {
      // Keep local sign-out resilient even if Google session cleanup fails.
    }

    await _localDataSource.clearSession();
  }

  Future<AuthSession?> _refreshSession(AuthSession storedSession) async {
    try {
      final refreshedSession = await _remoteDataSource.refresh(
        storedSession.refreshToken,
      );
      await _localDataSource.saveSession(refreshedSession);
      return refreshedSession;
    } on ApiException {
      await _localDataSource.clearSession();
      return null;
    }
  }

  Future<AuthSession?> _getUsableSession() async {
    final storedSession = await _localDataSource.readSession();
    if (storedSession == null) {
      return null;
    }

    if (_isExpired(storedSession.refreshTokenExpiresAt)) {
      await _localDataSource.clearSession();
      return null;
    }

    if (_isExpired(storedSession.accessTokenExpiresAt)) {
      return _refreshSession(storedSession);
    }

    return storedSession;
  }

  bool _isExpired(DateTime value) {
    return value.isBefore(
      DateTime.now().toUtc().add(const Duration(seconds: 30)),
    );
  }
}
