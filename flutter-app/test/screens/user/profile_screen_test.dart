import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pody/core/network/api_client.dart';
import 'package:pody/features/auth/application/auth_controller.dart';
import 'package:pody/features/auth/data/auth_local_data_source.dart';
import 'package:pody/features/auth/data/auth_remote_data_source.dart';
import 'package:pody/features/auth/data/auth_repository.dart';
import 'package:pody/features/auth/data/google_auth_data_source.dart';
import 'package:pody/features/auth/domain/auth_session.dart';
import 'package:pody/features/auth/domain/auth_user.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/features/content/data/content_remote_data_source.dart';
import 'package:pody/features/content/data/content_repository.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/features/content/presentation/content_scope.dart';
import 'package:pody/screens/user/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders profile with real session and content data', (
    WidgetTester tester,
  ) async {
    final authController = await _buildAuthenticatedController();
    final repository = ContentRepository(
      _FakeContentRemoteDataSource(ApiClient(baseUrl: 'http://localhost:8080')),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ContentScope(
          repository: repository,
          child: AuthScope(
            controller: authController,
            child: const ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Creator Prime'), findsOneWidget);
    expect(find.text('@creator-prime'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('3.1k'), findsOneWidget);
    expect(find.text('Tập được lưu 1'), findsOneWidget);

    await tester.tap(find.text('Của tôi'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Future Makers'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Future Makers'), findsOneWidget);
    expect(find.text('Người theo dõi'), findsOneWidget);

    await tester.tap(find.text('Theo dõi'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có dữ liệu theo dõi'), findsOneWidget);
  });
}

Future<AuthController> _buildAuthenticatedController() async {
  SharedPreferences.setMockInitialValues({});
  final controller = AuthController(
    AuthRepository(
      remoteDataSource: _FakeAuthRemoteDataSource(
        ApiClient(baseUrl: 'http://localhost:8080'),
      ),
      localDataSource: AuthLocalDataSource(),
      googleAuthDataSource: _FakeGoogleAuthDataSource(),
    ),
  );
  await controller.signIn(email: 'creator@pody.vn', password: 'password-123');
  return controller;
}

class _FakeGoogleAuthDataSource implements GoogleAuthDataSource {
  @override
  Future<String> signIn() async => 'fake-id-token';

  @override
  Future<void> signOut() async {}
}

class _FakeAuthRemoteDataSource extends AuthRemoteDataSource {
  _FakeAuthRemoteDataSource(super.apiClient);

  static final AuthUser _user = AuthUser(
    id: 'user-1',
    email: 'creator@pody.vn',
    displayName: 'Creator Prime',
    username: 'creator-prime',
    bio: 'Đang xây creator studio bằng dữ liệu thật.',
    accountType: 'creator',
    status: 'active',
  );

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final now = DateTime.now().toUtc();
    return AuthSession(
      user: _user,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      accessTokenExpiresAt: now.add(const Duration(hours: 1)),
      refreshTokenExpiresAt: now.add(const Duration(days: 30)),
      tokenType: 'Bearer',
    );
  }
}

class _FakeContentRemoteDataSource extends ContentRemoteDataSource {
  _FakeContentRemoteDataSource(super.apiClient);

  @override
  Future<List<ContentBookmarkedEpisode>> listBookmarkedEpisodes() async {
    return [
      ContentBookmarkedEpisode(
        episode: ContentEpisodeSummary(
          id: 'episode-1',
          showId: 'show-1',
          title: 'Tập được lưu 1',
          description: 'Mô tả',
          coverImageUrl: 'https://example.com/episode-1.png',
          durationSeconds: 1200,
          publishedAt: DateTime(2026, 3, 30, 10),
          episodeNumber: 1,
        ),
        show: ContentShowSummary(
          id: 'show-1',
          slug: 'future-makers',
          title: 'Future Makers',
          coverImageUrl: 'https://example.com/show-1.png',
          primaryCategory: 'Công nghệ',
          hosts: const [],
          contentType: 'podcast',
          subscriberCount: 2100,
          totalEpisodeCount: 3,
          publishedAt: DateTime(2026, 3, 30, 9),
        ),
        bookmarkedAt: DateTime(2026, 3, 30, 11),
      ),
    ];
  }

  @override
  Future<List<ContentShowSummary>> listMyShows() async {
    return [
      ContentShowSummary(
        id: 'show-1',
        slug: 'future-makers',
        title: 'Future Makers',
        coverImageUrl: 'https://example.com/show-1.png',
        primaryCategory: 'Công nghệ',
        hosts: const [],
        contentType: 'podcast',
        subscriberCount: 2100,
        totalEpisodeCount: 3,
        publishedAt: DateTime(2026, 3, 30, 9),
      ),
      ContentShowSummary(
        id: 'show-2',
        slug: 'daily-builders',
        title: 'Daily Builders',
        coverImageUrl: 'https://example.com/show-2.png',
        primaryCategory: 'Business',
        hosts: const [],
        contentType: 'podcast',
        subscriberCount: 1000,
        totalEpisodeCount: 5,
        publishedAt: DateTime(2026, 3, 29, 9),
      ),
    ];
  }
}
