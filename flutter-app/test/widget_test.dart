import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pody/core/network/api_client.dart';
import 'package:pody/data/article_service.dart';
import 'package:pody/features/ai/data/ai_remote_data_source.dart';
import 'package:pody/features/ai/data/ai_repository.dart';
import 'package:pody/features/auth/application/auth_controller.dart';
import 'package:pody/features/auth/data/auth_local_data_source.dart';
import 'package:pody/features/auth/data/auth_remote_data_source.dart';
import 'package:pody/features/auth/data/auth_repository.dart';
import 'package:pody/features/auth/data/google_auth_data_source.dart';
import 'package:pody/features/content/data/content_remote_data_source.dart';
import 'package:pody/features/content/data/content_repository.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/features/notifications/data/notification_remote_data_source.dart';
import 'package:pody/features/notifications/data/notification_repository.dart';
import 'package:pody/models/news/news_article.dart';

import 'package:pody/main.dart';
import 'package:pody/screens/auth/sign_in_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows home navigation on launch without forcing sign in', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final authController = AuthController(
      AuthRepository(
        remoteDataSource: AuthRemoteDataSource(
          ApiClient(baseUrl: 'http://localhost:8080'),
        ),
        localDataSource: AuthLocalDataSource(),
        googleAuthDataSource: _FakeGoogleAuthDataSource(),
      ),
    );
    await authController.initialize();

    await HttpOverrides.runZoned(() async {
      final apiClient = ApiClient(baseUrl: 'http://localhost:8080');
      await tester.pumpWidget(
        PodyApp(
          authController: authController,
          aiRepository: AIRepository(AIRemoteDataSource(apiClient)),
          contentRepository: ContentRepository(
            _FakeContentRemoteDataSource(apiClient),
          ),
          notificationRepository: NotificationRepository(
            NotificationRemoteDataSource(apiClient),
          ),
          articleApiService: _FakeArticleApiService(apiClient),
        ),
      );
      await tester.pump();

      expect(find.byType(MainNavigationScreen), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
    }, createHttpClient: (_) => _FakeHttpClient());
  });
}

class _FakeGoogleAuthDataSource implements GoogleAuthDataSource {
  @override
  Future<String> signIn() async => 'fake-id-token';

  @override
  Future<void> signOut() async {}
}

class _FakeContentRemoteDataSource extends ContentRemoteDataSource {
  _FakeContentRemoteDataSource(super.apiClient);

  @override
  Future<ContentHomeFeed> getHomeFeed() async {
    return ContentHomeFeed(
      categories: const ['Tất cả', 'Công nghệ'],
      shows: [
        ContentHomeShowCard(
          show: ContentShowSummary(
            id: 'show-1',
            slug: 'show-1',
            title: 'Future Minds',
            coverImageUrl: 'https://example.com/show-1.jpg',
            primaryCategory: 'Công nghệ',
            hosts: const [
              ContentHost(
                id: 'ai-1',
                displayName: 'Nova',
                avatarUrl: 'https://example.com/host-1.jpg',
                role: 'host',
              ),
            ],
            contentType: 'podcast',
            subscriberCount: 1200,
            totalEpisodeCount: 1,
            publishedAt: DateTime(2026, 3, 17),
          ),
          previewEpisodes: [
            ContentPreviewEpisode(
              id: 'episode-1',
              showId: 'show-1',
              title: 'MVC thời hiện đại',
              durationSeconds: 1800,
              publishedAt: DateTime(2026, 3, 17),
            ),
          ],
        ),
      ],
    );
  }
}

class _FakeArticleApiService extends ArticleApiService {
  _FakeArticleApiService(super.apiClient);

  @override
  Future<List<NewsArticle>> fetchArticles({
    String? category,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    return const <NewsArticle>[];
  }
}

class _FakeHttpClient implements HttpClient {
  bool _autoUncompress = true;

  @override
  bool get autoUncompress => _autoUncompress;

  @override
  set autoUncompress(bool value) {
    _autoUncompress = value;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _FakeHttpResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _transparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_transparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final Uint8List _transparentImage = Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
