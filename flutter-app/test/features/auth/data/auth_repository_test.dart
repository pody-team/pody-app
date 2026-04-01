import 'package:flutter_test/flutter_test.dart';
import 'package:pody/core/network/api_client.dart';
import 'package:pody/features/auth/data/auth_local_data_source.dart';
import 'package:pody/features/auth/data/auth_remote_data_source.dart';
import 'package:pody/features/auth/data/auth_repository.dart';
import 'package:pody/features/auth/data/google_auth_data_source.dart';
import 'package:pody/features/auth/domain/auth_session.dart';
import 'package:pody/features/auth/domain/auth_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AuthRepository Google sign-in', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'signInWithGoogle exchanges Google token and persists session',
      () async {
        final remoteDataSource = _FakeAuthRemoteDataSource(_session);
        final googleAuthDataSource = _FakeGoogleAuthDataSource(
          idToken: 'google-id-token',
        );
        final localDataSource = AuthLocalDataSource();
        final repository = AuthRepository(
          remoteDataSource: remoteDataSource,
          localDataSource: localDataSource,
          googleAuthDataSource: googleAuthDataSource,
        );

        final session = await repository.signInWithGoogle();

        expect(session.user.email, 'google@pody.vn');
        expect(remoteDataSource.lastGoogleIDToken, 'google-id-token');

        final storedSession = await localDataSource.readSession();
        expect(storedSession?.accessToken, 'access-token');
        expect(storedSession?.refreshToken, 'refresh-token');
      },
    );

    test('signOut clears local session and Google session', () async {
      final remoteDataSource = _FakeAuthRemoteDataSource(_session);
      final googleAuthDataSource = _FakeGoogleAuthDataSource(
        idToken: 'google-id-token',
      );
      final localDataSource = AuthLocalDataSource();
      final repository = AuthRepository(
        remoteDataSource: remoteDataSource,
        localDataSource: localDataSource,
        googleAuthDataSource: googleAuthDataSource,
      );

      await localDataSource.saveSession(_session);
      await repository.signOut(_session);

      expect(await localDataSource.readSession(), isNull);
      expect(googleAuthDataSource.signOutCalled, isTrue);
      expect(remoteDataSource.lastSignedOutRefreshToken, 'refresh-token');
    });
  });
}

class _FakeAuthRemoteDataSource extends AuthRemoteDataSource {
  _FakeAuthRemoteDataSource(this.session)
    : super(ApiClient(baseUrl: 'http://localhost:8080'));

  final AuthSession session;
  String? lastGoogleIDToken;
  String? lastSignedOutRefreshToken;

  @override
  Future<AuthSession> signInWithGoogle(String idToken) async {
    lastGoogleIDToken = idToken;
    return session;
  }

  @override
  Future<void> signOut(String refreshToken) async {
    lastSignedOutRefreshToken = refreshToken;
  }
}

class _FakeGoogleAuthDataSource implements GoogleAuthDataSource {
  _FakeGoogleAuthDataSource({required this.idToken});

  final String idToken;
  bool signOutCalled = false;

  @override
  Future<String> signIn() async => idToken;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

final _session = AuthSession(
  user: AuthUser(
    id: 'google-user-1',
    email: 'google@pody.vn',
    displayName: 'Google User',
    status: 'active',
    avatarUrl: 'https://example.com/avatar.png',
  ),
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  accessTokenExpiresAt: DateTime.utc(2026, 4, 1, 12),
  refreshTokenExpiresAt: DateTime.utc(2026, 4, 8, 12),
  tokenType: 'Bearer',
);
