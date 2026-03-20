import 'package:pody/core/network/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:pody/models/news/news_article.dart';

class ArticleApiService {
  final ApiClient _apiClient;

  ArticleApiService(this._apiClient);

  Future<List<NewsArticle>> fetchArticles({
    String? category,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final params = <String, String>{};
      if (category != null && category.isNotEmpty) {
        params['category'] = category;
      }
      if (query != null && query.isNotEmpty) {
        params['q'] = query;
      }
      params['limit'] = '$limit';
      params['offset'] = '$offset';

      var path = '/api/v1/article';
      if (params.isNotEmpty) {
        final queryString = params.entries
            .map(
              (entry) =>
                  '${entry.key}=${Uri.encodeQueryComponent(entry.value)}',
            )
            .join('&');
        path = '$path?$queryString';
      }

      final response = await _apiClient.get(path, requiresAuth: true);
      final articleList = response['articles'];
      if (articleList is! List) {
        return const <NewsArticle>[];
      }

      return articleList
          .whereType<Map<String, dynamic>>()
          .map(NewsArticle.fromJson)
          .toList();
    } catch (e) {
      debugPrint('Error fetching articles: $e');
      return const <NewsArticle>[];
    }
  }

  Future<NewsArticle?> fetchArticleDetail(int id) async {
    try {
      final response = await _apiClient.get(
        '/api/v1/article/$id',
        requiresAuth: true,
      );
      return NewsArticle.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching article detail: $e');
      return null;
    }
  }

  Future<bool> sendInteraction(int articleId, int userId, String type) async {
    try {
      await _apiClient.post(
        '/api/v1/article/$articleId/interaction',
        body: {'user_id': userId, 'type': type},
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      debugPrint('Error sending interaction: $e');
      return false;
    }
  }

  Future<void> sendMetric(int articleId, int userId, int secondsRead) async {
    try {
      await _apiClient.post(
        '/api/v1/article/$articleId/metric',
        body: {'user_id': userId, 'reading_time_seconds': secondsRead},
        requiresAuth: true,
      );
    } catch (e) {
      debugPrint('Error sending metric: $e');
    }
  }
}
