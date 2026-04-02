import '../domain/content_models.dart';
import 'content_remote_data_source.dart';

class ContentRepository {
  ContentRepository(this._remoteDataSource);

  final ContentRemoteDataSource _remoteDataSource;

  Future<ContentHomeFeed> getHomeFeed() {
    return _remoteDataSource.getHomeFeed();
  }

  Future<ContentShowBundle> getShowBundle(String showId) async {
    final results = await Future.wait<dynamic>([
      _remoteDataSource.getShowDetail(showId),
      _remoteDataSource.listShowEpisodes(showId),
    ]);

    return ContentShowBundle(
      show: results[0] as ContentShowDetail,
      episodes: results[1] as List<ContentEpisodeSummary>,
    );
  }

  Future<ContentShowBundle> getCreatorShowBundle(String showId) async {
    final results = await Future.wait<dynamic>([
      _remoteDataSource.getCreatorShowDetail(showId),
      _remoteDataSource.listCreatorShowEpisodes(showId),
    ]);

    return ContentShowBundle(
      show: results[0] as ContentShowDetail,
      episodes: results[1] as List<ContentEpisodeSummary>,
    );
  }

  Future<ContentEpisodeDetail> getEpisodeDetail(String episodeId) {
    return _remoteDataSource.getEpisodeDetail(episodeId);
  }

  Future<ContentEpisodeDetail> getCreatorEpisodeDetail(String episodeId) {
    return _remoteDataSource.getCreatorEpisodeDetail(episodeId);
  }

  Future<List<ContentBookmarkedEpisode>> listBookmarkedEpisodes() {
    return _remoteDataSource.listBookmarkedEpisodes();
  }

  Future<ContentEpisodeBookmarkStatus> getEpisodeBookmarkStatus(
    String episodeId,
  ) {
    return _remoteDataSource.getEpisodeBookmarkStatus(episodeId);
  }

  Future<ContentEpisodeBookmarkStatus> saveEpisodeBookmark(String episodeId) {
    return _remoteDataSource.saveEpisodeBookmark(episodeId);
  }

  Future<ContentEpisodeBookmarkStatus> deleteEpisodeBookmark(String episodeId) {
    return _remoteDataSource.deleteEpisodeBookmark(episodeId);
  }

  Future<List<ContentShowSummary>> listMyShows() {
    return _remoteDataSource.listMyShows();
  }

  Future<ContentShowDetail> createShow(ContentCreateShowInput input) {
    return _remoteDataSource.createShow(input);
  }

  Future<List<String>> listCreateShowCategories() async {
    final feed = await _remoteDataSource.getHomeFeed();
    return feed.categories.where((item) => item.trim().isNotEmpty).toList();
  }
}
