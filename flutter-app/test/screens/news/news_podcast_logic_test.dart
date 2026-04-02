import 'package:flutter_test/flutter_test.dart';
import 'package:pody/core/network/api_client.dart';
import 'package:pody/data/article_service.dart';
import 'package:pody/screens/news/news_podcast_selection.dart';

void main() {
  test('createPodcastJob accepts empty article ids and sends them unchanged', () async {
    final apiClient = _RecordingApiClient();
    final service = ArticleApiService(apiClient);

    final response = await service.createPodcastJob(articleIds: const <int>[]);

    expect(apiClient.lastPath, '/api/v1/article/podcast-jobs');
    expect(apiClient.lastRequiresAuth, isTrue);
    expect(apiClient.lastBody?['article_ids'], isEmpty);
    expect(response.jobId, 'job-1');
  });

  test('updatePodcastSelection keeps only the newest twenty article ids', () {
    var selectedIds = <int>[];

    for (var articleId = 1; articleId <= 21; articleId++) {
      selectedIds = updatePodcastSelection(
        selectedIdsInOrder: selectedIds,
        articleId: articleId,
        isCurrentlySelected: false,
      ).selectedIdsInOrder;
    }

    expect(selectedIds, List<int>.generate(20, (index) => index + 2));
  });

  test('updatePodcastSelection removes an article when toggled off', () {
    final update = updatePodcastSelection(
      selectedIdsInOrder: const <int>[5, 6, 7],
      articleId: 6,
      isCurrentlySelected: true,
    );

    expect(update.selectedIdsInOrder, const <int>[5, 7]);
    expect(update.removedIds, isEmpty);
  });
}

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(baseUrl: 'http://localhost:8080');

  String? lastPath;
  Map<String, dynamic>? lastBody;
  bool lastRequiresAuth = false;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
    bool requiresAuth = false,
  }) async {
    lastPath = path;
    lastBody = body;
    lastRequiresAuth = requiresAuth;
    return <String, dynamic>{
      'job_id': 'job-1',
      'status': 'queued',
      'created_at': '2026-04-02T10:00:00Z',
    };
  }
}
