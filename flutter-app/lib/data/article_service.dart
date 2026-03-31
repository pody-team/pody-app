import 'package:pody/core/network/api_client.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:pody/models/news/news_article.dart';
import 'package:pody/models/news/news_category.dart';
import 'package:pody/models/social/comment.dart';

class ArticleApiService {
  final ApiClient _apiClient;
  static const _publicBasePath = '/api/v1/public/article';
  static const _protectedBasePath = '/api/v1/article';

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

      var path = _publicBasePath;
      if (params.isNotEmpty) {
        final queryString = params.entries
            .map(
              (entry) =>
                  '${entry.key}=${Uri.encodeQueryComponent(entry.value)}',
            )
            .join('&');
        path = '$path?$queryString';
      }

      final response = await _apiClient.get(path);
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
      rethrow;
    }
  }

  Future<List<NewsCategory>> fetchCategories() async {
    try {
      final response = await _apiClient.get('$_publicBasePath/categories');
      final categoryList = response['categories'];
      if (categoryList is! List) {
        return const <NewsCategory>[];
      }

      return categoryList
          .whereType<Map<String, dynamic>>()
          .map(NewsCategory.fromJson)
          .where((category) => category.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      rethrow;
    }
  }

  Future<NewsArticle?> fetchArticleDetail(int id) async {
    try {
      final publicResponse = await _apiClient.get('$_publicBasePath/$id');
      final publicArticle = NewsArticle.fromJson(publicResponse);
      try {
        final protectedResponse = await _apiClient.get(
          '$_protectedBasePath/$id',
          requiresAuth: true,
        );
        return NewsArticle.fromJson(protectedResponse);
      } on ApiException {
        return publicArticle;
      }
    } catch (e) {
      debugPrint('Error fetching article detail from public route: $e');
    }

    try {
      final response = await _apiClient.get(
        '$_protectedBasePath/$id',
        requiresAuth: true,
      );
      return NewsArticle.fromJson(response);
    } on ApiException catch (error) {
      debugPrint('Error fetching article detail: $error');
      return null;
    } catch (e) {
      debugPrint('Error fetching article detail: $e');
      return null;
    }
  }

  Future<NewsArticle?> sendInteraction(int articleId, String type) async {
    try {
      await _apiClient.post(
        '$_protectedBasePath/$articleId/reactions',
        body: {'type': type},
        requiresAuth: true,
      );
      return fetchArticleDetail(articleId);
    } catch (e) {
      debugPrint('Error sending interaction: $e');
      return null;
    }
  }

  Future<void> sendMetric(int articleId, int secondsRead) async {
    try {
      await _apiClient.post(
        '$_protectedBasePath/$articleId/metric',
        body: {'reading_time_seconds': secondsRead},
        requiresAuth: true,
      );
    } catch (e) {
      debugPrint('Error sending metric: $e');
    }
  }

  Future<List<Comment>> fetchComments(
    int articleId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.get(
        '$_publicBasePath/$articleId/comments?limit=$limit&offset=$offset',
      );
      final items = response['comments'];
      if (items is! List) {
        return const <Comment>[];
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map(Comment.fromArticleJson)
          .toList();
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      return const <Comment>[];
    }
  }

  Future<Comment?> createComment(
    int articleId, {
    required String content,
    String? userName,
  }) async {
    try {
      final response = await _apiClient.post(
        '$_protectedBasePath/$articleId/comments',
        body: {
          'content': content,
          if (userName != null && userName.isNotEmpty) 'user_name': userName,
        },
        requiresAuth: true,
      );
      final comment = response['comment'];
      if (comment is! Map<String, dynamic>) {
        return null;
      }
      return Comment.fromArticleJson(comment);
    } catch (e) {
      debugPrint('Error creating comment: $e');
      return null;
    }
  }
}
