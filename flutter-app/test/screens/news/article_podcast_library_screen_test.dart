import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pody/core/network/api_client.dart';
import 'package:pody/data/article_scope.dart';
import 'package:pody/data/article_service.dart';
import 'package:pody/models/news/article_podcast_job.dart';
import 'package:pody/screens/news/article_podcast_library_screen.dart';

void main() {
  testWidgets('shows only completed article podcast jobs', (
    WidgetTester tester,
  ) async {
    final service = _FakeArticleApiService(
      ApiClient(baseUrl: 'http://localhost:8080'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ArticleScope(
          service: service,
          child: const ArticlePodcastLibraryScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Podcast bao chi: AI'), findsOneWidget);
    expect(find.text('Podcast bao chi: Cloud'), findsOneWidget);
    expect(find.text('Podcast bao chi: Dang xu ly'), findsNothing);
    expect(find.text('Podcast bao chi: That bai'), findsNothing);
  });
}

class _FakeArticleApiService extends ArticleApiService {
  _FakeArticleApiService(super.apiClient);

  @override
  Future<List<ArticlePodcastJobSummary>> fetchPodcastJobs() async {
    return <ArticlePodcastJobSummary>[
      ArticlePodcastJobSummary(
        jobId: 'job-1',
        status: 'completed',
        title: 'Podcast bao chi: AI',
        audioUrl: 'https://example.com/audio-1.wav',
        createdAt: DateTime(2026, 4, 2, 9),
        updatedAt: DateTime(2026, 4, 2, 9, 5),
      ),
      ArticlePodcastJobSummary(
        jobId: 'job-2',
        status: 'queued',
        title: 'Podcast bao chi: Dang xu ly',
        createdAt: DateTime(2026, 4, 2, 9, 10),
        updatedAt: DateTime(2026, 4, 2, 9, 12),
      ),
      ArticlePodcastJobSummary(
        jobId: 'job-3',
        status: 'failed',
        title: 'Podcast bao chi: That bai',
        createdAt: DateTime(2026, 4, 2, 9, 20),
        updatedAt: DateTime(2026, 4, 2, 9, 21),
      ),
      ArticlePodcastJobSummary(
        jobId: 'job-4',
        status: 'completed',
        title: 'Podcast bao chi: Cloud',
        audioUrl: 'https://example.com/audio-4.wav',
        createdAt: DateTime(2026, 4, 2, 9, 30),
        updatedAt: DateTime(2026, 4, 2, 9, 35),
      ),
    ];
  }
}
