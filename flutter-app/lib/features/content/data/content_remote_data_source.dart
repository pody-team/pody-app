import 'package:pody/core/network/api_client.dart';

import '../domain/content_models.dart';

class ContentRemoteDataSource {
  ContentRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<ContentHomeFeed> getHomeFeed() async {
    final response = await _apiClient.get('/api/v1/public/content/home');
    return ContentHomeFeed.fromJson(response);
  }

  Future<ContentShowDetail> getShowDetail(String showId) async {
    final response = await _apiClient.get(
      '/api/v1/public/content/shows/$showId',
    );
    return ContentShowDetail.fromJson(
      (response['show'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<List<ContentEpisodeSummary>> listShowEpisodes(String showId) async {
    final response = await _apiClient.get(
      '/api/v1/public/content/shows/$showId/episodes',
    );
    final rawEpisodes = response['episodes'] as List<dynamic>? ?? const [];
    return rawEpisodes
        .whereType<Map<String, dynamic>>()
        .map(ContentEpisodeSummary.fromJson)
        .toList();
  }

  Future<ContentEpisodeDetail> getEpisodeDetail(String episodeId) async {
    final response = await _apiClient.get(
      '/api/v1/public/content/episodes/$episodeId',
    );
    return ContentEpisodeDetail.fromJson(
      (response['episode'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<ContentShowDetail> getCreatorShowDetail(String showId) async {
    final response = await _apiClient.get(
      '/api/v1/content/me/shows/$showId',
      requiresAuth: true,
    );
    return ContentShowDetail.fromJson(
      (response['show'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<List<ContentEpisodeSummary>> listCreatorShowEpisodes(
    String showId,
  ) async {
    final response = await _apiClient.get(
      '/api/v1/content/me/shows/$showId/episodes',
      requiresAuth: true,
    );
    final rawEpisodes = response['episodes'] as List<dynamic>? ?? const [];
    return rawEpisodes
        .whereType<Map<String, dynamic>>()
        .map(ContentEpisodeSummary.fromJson)
        .toList();
  }

  Future<ContentEpisodeDetail> getCreatorEpisodeDetail(String episodeId) async {
    final response = await _apiClient.get(
      '/api/v1/content/me/episodes/$episodeId',
      requiresAuth: true,
    );
    return ContentEpisodeDetail.fromJson(
      (response['episode'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<ContentEpisodeBookmarkStatus> getEpisodeBookmarkStatus(
    String episodeId,
  ) async {
    final response = await _apiClient.get(
      '/api/v1/content/me/bookmarks/$episodeId',
      requiresAuth: true,
    );
    return ContentEpisodeBookmarkStatus.fromJson(response);
  }

  Future<List<ContentBookmarkedEpisode>> listBookmarkedEpisodes() async {
    final response = await _apiClient.get(
      '/api/v1/content/me/bookmarks',
      requiresAuth: true,
    );
    final rawBookmarks = response['bookmarks'] as List<dynamic>? ?? const [];
    return rawBookmarks
        .whereType<Map<String, dynamic>>()
        .map(ContentBookmarkedEpisode.fromJson)
        .toList();
  }

  Future<ContentEpisodeBookmarkStatus> saveEpisodeBookmark(
    String episodeId,
  ) async {
    final response = await _apiClient.put(
      '/api/v1/content/me/bookmarks/$episodeId',
      requiresAuth: true,
    );
    return ContentEpisodeBookmarkStatus.fromJson(response);
  }

  Future<ContentEpisodeBookmarkStatus> deleteEpisodeBookmark(
    String episodeId,
  ) async {
    final response = await _apiClient.delete(
      '/api/v1/content/me/bookmarks/$episodeId',
      requiresAuth: true,
    );
    return ContentEpisodeBookmarkStatus.fromJson(response);
  }

  Future<List<ContentShowSummary>> listMyShows() async {
    final response = await _apiClient.get(
      '/api/v1/content/me/shows',
      requiresAuth: true,
    );
    final rawShows = response['shows'] as List<dynamic>? ?? const [];
    return rawShows
        .whereType<Map<String, dynamic>>()
        .map(ContentShowSummary.fromJson)
        .toList();
  }

  Future<ContentShowDetail> createShow(ContentCreateShowInput input) async {
    final response = await _apiClient.post(
      '/api/v1/content/shows',
      body: input.toJson(),
      requiresAuth: true,
    );
    return ContentShowDetail.fromJson(
      (response['show'] as Map<String, dynamic>?) ?? const {},
    );
  }
}
