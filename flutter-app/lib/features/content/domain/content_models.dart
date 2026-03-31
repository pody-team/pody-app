class ContentHost {
  const ContentHost({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.role,
    this.voiceProfileId,
    this.bio,
  });

  final String id;
  final String displayName;
  final String avatarUrl;
  final String role;
  final String? voiceProfileId;
  final String? bio;

  factory ContentHost.fromJson(Map<String, dynamic> json) {
    return ContentHost(
      id: _readString(json['id']),
      displayName: _readString(json['display_name']),
      avatarUrl: _readString(json['avatar_url']),
      role: _readString(json['role'], fallback: 'host'),
      voiceProfileId: _readNullableString(json['voice_profile_id']),
      bio: _readNullableString(json['bio']),
    );
  }
}

class ContentCreateHostInput {
  const ContentCreateHostInput({
    required this.displayName,
    this.role,
    this.avatarUrl,
    this.voiceProfileId,
    this.bio,
  });

  final String displayName;
  final String? role;
  final String? avatarUrl;
  final String? voiceProfileId;
  final String? bio;

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      if (role != null && role!.isNotEmpty) 'role': role,
      if (avatarUrl != null && avatarUrl!.isNotEmpty) 'avatar_url': avatarUrl,
      if (voiceProfileId != null && voiceProfileId!.isNotEmpty)
        'voice_profile_id': voiceProfileId,
      if (bio != null && bio!.isNotEmpty) 'bio': bio,
    };
  }
}

class ContentCreateShowSeed {
  const ContentCreateShowSeed({
    required this.title,
    required this.primaryCategory,
    required this.hosts,
    this.description,
    this.coverImageUrl,
    this.contentType = 'podcast',
  });

  final String title;
  final String primaryCategory;
  final List<ContentCreateHostInput> hosts;
  final String? description;
  final String? coverImageUrl;
  final String contentType;
}

class ContentCreateShowInput {
  const ContentCreateShowInput({
    required this.title,
    required this.primaryCategory,
    required this.hosts,
    this.description,
    this.coverImageUrl,
    this.languageCode,
    this.contentType,
  });

  final String title;
  final String primaryCategory;
  final List<ContentCreateHostInput> hosts;
  final String? description;
  final String? coverImageUrl;
  final String? languageCode;
  final String? contentType;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'primary_category': primaryCategory,
      'hosts': hosts.map((host) => host.toJson()).toList(),
      if (description != null && description!.isNotEmpty)
        'description': description,
      if (coverImageUrl != null && coverImageUrl!.isNotEmpty)
        'cover_image_url': coverImageUrl,
      if (languageCode != null && languageCode!.isNotEmpty)
        'language_code': languageCode,
      if (contentType != null && contentType!.isNotEmpty)
        'content_type': contentType,
    };
  }
}

class ContentOwnerSummary {
  const ContentOwnerSummary({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String avatarUrl;

  factory ContentOwnerSummary.fromJson(Map<String, dynamic> json) {
    return ContentOwnerSummary(
      id: _readString(json['id']),
      displayName: _readString(json['display_name']),
      avatarUrl: _readString(json['avatar_url']),
    );
  }
}

class ContentPreviewEpisode {
  const ContentPreviewEpisode({
    required this.id,
    required this.showId,
    required this.title,
    required this.durationSeconds,
    required this.publishedAt,
  });

  final String id;
  final String showId;
  final String title;
  final int durationSeconds;
  final DateTime publishedAt;

  String get formattedDuration => _formatDuration(durationSeconds);

  factory ContentPreviewEpisode.fromJson(Map<String, dynamic> json) {
    return ContentPreviewEpisode(
      id: _readString(json['id']),
      showId: _readString(json['show_id']),
      title: _readString(json['title']),
      durationSeconds: _readInt(json['duration_seconds']),
      publishedAt: _readDateTime(json['published_at']),
    );
  }
}

class ContentShowSummary {
  const ContentShowSummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.coverImageUrl,
    required this.primaryCategory,
    required this.hosts,
    required this.contentType,
    required this.subscriberCount,
    required this.totalEpisodeCount,
    required this.publishedAt,
  });

  final String id;
  final String slug;
  final String title;
  final String coverImageUrl;
  final String primaryCategory;
  final List<ContentHost> hosts;
  final String contentType;
  final int subscriberCount;
  final int totalEpisodeCount;
  final DateTime publishedAt;

  ContentHost? get primaryHost => hosts.isEmpty ? null : hosts.first;
  String get hostNames => hosts.map((host) => host.displayName).join(', ');

  String get formattedSubscriberCount => _formatCount(subscriberCount);

  factory ContentShowSummary.fromJson(Map<String, dynamic> json) {
    final rawHosts = json['hosts'] as List<dynamic>? ?? const [];
    return ContentShowSummary(
      id: _readString(json['id']),
      slug: _readString(json['slug']),
      title: _readString(json['title']),
      coverImageUrl: _readString(json['cover_image_url']),
      primaryCategory: _readString(json['primary_category']),
      hosts: rawHosts
          .whereType<Map<String, dynamic>>()
          .map(ContentHost.fromJson)
          .toList(),
      contentType: _readString(json['content_type'], fallback: 'podcast'),
      subscriberCount: _readInt(json['subscriber_count']),
      totalEpisodeCount: _readInt(json['total_episode_count']),
      publishedAt: _readDateTime(json['published_at']),
    );
  }
}

class ContentHomeShowCard {
  const ContentHomeShowCard({
    required this.show,
    required this.previewEpisodes,
  });

  final ContentShowSummary show;
  final List<ContentPreviewEpisode> previewEpisodes;

  factory ContentHomeShowCard.fromJson(Map<String, dynamic> json) {
    final rawPreviewEpisodes =
        json['preview_episodes'] as List<dynamic>? ?? const [];
    return ContentHomeShowCard(
      show: ContentShowSummary.fromJson(
        (json['show'] as Map<String, dynamic>?) ?? const {},
      ),
      previewEpisodes: rawPreviewEpisodes
          .whereType<Map<String, dynamic>>()
          .map(ContentPreviewEpisode.fromJson)
          .toList(),
    );
  }
}

class ContentHomeFeed {
  const ContentHomeFeed({required this.categories, required this.shows});

  final List<String> categories;
  final List<ContentHomeShowCard> shows;

  factory ContentHomeFeed.fromJson(Map<String, dynamic> json) {
    final rawShows = json['shows'] as List<dynamic>? ?? const [];
    final rawCategories = json['categories'] as List<dynamic>? ?? const [];
    return ContentHomeFeed(
      categories: rawCategories.map((item) => _readString(item)).toList(),
      shows: rawShows
          .whereType<Map<String, dynamic>>()
          .map(ContentHomeShowCard.fromJson)
          .toList(),
    );
  }
}

class ContentShowDetail {
  const ContentShowDetail({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.coverImageUrl,
    required this.categories,
    required this.tags,
    required this.hosts,
    required this.owner,
    required this.subscriberCount,
    required this.totalEpisodeCount,
    required this.totalListenCount,
    required this.languageCode,
    required this.contentType,
    required this.visibility,
    required this.monetizationType,
    required this.publishedAt,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String coverImageUrl;
  final List<String> categories;
  final List<String> tags;
  final List<ContentHost> hosts;
  final ContentOwnerSummary owner;
  final int subscriberCount;
  final int totalEpisodeCount;
  final int totalListenCount;
  final String languageCode;
  final String contentType;
  final String visibility;
  final String monetizationType;
  final DateTime publishedAt;

  String get primaryCategory => categories.isEmpty ? '' : categories.first;
  ContentHost? get primaryHost => hosts.isEmpty ? null : hosts.first;
  String get hostNames => hosts.map((host) => host.displayName).join(', ');
  String get formattedSubscriberCount => _formatCount(subscriberCount);
  String get formattedListenCount => _formatCount(totalListenCount);

  ContentShowSummary toSummary() {
    return ContentShowSummary(
      id: id,
      slug: slug,
      title: title,
      coverImageUrl: coverImageUrl,
      primaryCategory: primaryCategory,
      hosts: hosts,
      contentType: contentType,
      subscriberCount: subscriberCount,
      totalEpisodeCount: totalEpisodeCount,
      publishedAt: publishedAt,
    );
  }

  factory ContentShowDetail.fromJson(Map<String, dynamic> json) {
    final rawHosts = json['hosts'] as List<dynamic>? ?? const [];
    return ContentShowDetail(
      id: _readString(json['id']),
      slug: _readString(json['slug']),
      title: _readString(json['title']),
      description: _readString(json['description']),
      coverImageUrl: _readString(json['cover_image_url']),
      categories: _readStringList(json['categories']),
      tags: _readStringList(json['tags']),
      hosts: rawHosts
          .whereType<Map<String, dynamic>>()
          .map(ContentHost.fromJson)
          .toList(),
      owner: ContentOwnerSummary.fromJson(
        (json['owner'] as Map<String, dynamic>?) ?? const {},
      ),
      subscriberCount: _readInt(json['subscriber_count']),
      totalEpisodeCount: _readInt(json['total_episode_count']),
      totalListenCount: _readInt(json['total_listen_count']),
      languageCode: _readString(json['language_code']),
      contentType: _readString(json['content_type']),
      visibility: _readString(json['visibility']),
      monetizationType: _readString(json['monetization_type']),
      publishedAt: _readDateTime(json['published_at']),
    );
  }
}

class ContentEpisodeSummary {
  const ContentEpisodeSummary({
    required this.id,
    required this.showId,
    required this.title,
    required this.description,
    required this.coverImageUrl,
    required this.durationSeconds,
    required this.publishedAt,
    required this.episodeNumber,
  });

  final String id;
  final String showId;
  final String title;
  final String description;
  final String coverImageUrl;
  final int durationSeconds;
  final DateTime publishedAt;
  final int episodeNumber;

  String get formattedDuration => _formatDuration(durationSeconds);

  factory ContentEpisodeSummary.fromJson(Map<String, dynamic> json) {
    return ContentEpisodeSummary(
      id: _readString(json['id']),
      showId: _readString(json['show_id']),
      title: _readString(json['title']),
      description: _readString(json['description']),
      coverImageUrl: _readString(json['cover_image_url']),
      durationSeconds: _readInt(json['duration_seconds']),
      publishedAt: _readDateTime(json['published_at']),
      episodeNumber: _readInt(json['episode_number']),
    );
  }
}

class ContentTranscriptWord {
  const ContentTranscriptWord({
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
  });

  final double startSeconds;
  final double endSeconds;
  final String text;

  factory ContentTranscriptWord.fromJson(Map<String, dynamic> json) {
    return ContentTranscriptWord(
      startSeconds: _readDouble(json['start_seconds']),
      endSeconds: _readDouble(json['end_seconds']),
      text: _readString(json['text']),
    );
  }
}

class ContentTranscriptSegment {
  const ContentTranscriptSegment({
    required this.speaker,
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
    required this.words,
  });

  final String speaker;
  final double startSeconds;
  final double endSeconds;
  final String text;
  final List<ContentTranscriptWord> words;

  factory ContentTranscriptSegment.fromJson(Map<String, dynamic> json) {
    final rawWords = json['words'] as List<dynamic>? ?? const [];
    return ContentTranscriptSegment(
      speaker: _readString(json['speaker'], fallback: 'Speaker'),
      startSeconds: _readDouble(json['start_seconds']),
      endSeconds: _readDouble(json['end_seconds']),
      text: _readString(json['text']),
      words: rawWords
          .whereType<Map<String, dynamic>>()
          .map(ContentTranscriptWord.fromJson)
          .toList(),
    );
  }
}

class ContentEpisodeTranscript {
  const ContentEpisodeTranscript({
    required this.status,
    required this.language,
    required this.durationSeconds,
    required this.segments,
    this.alignmentMethod,
    this.assetUrl,
    this.text,
    this.error,
  });

  final String status;
  final String language;
  final double durationSeconds;
  final List<ContentTranscriptSegment> segments;
  final String? alignmentMethod;
  final String? assetUrl;
  final String? text;
  final String? error;

  factory ContentEpisodeTranscript.fromJson(Map<String, dynamic> json) {
    final rawSegments = json['segments'] as List<dynamic>? ?? const [];
    return ContentEpisodeTranscript(
      status: _readString(json['status'], fallback: 'pending'),
      language: _readString(json['language'], fallback: 'vi'),
      durationSeconds: _readDouble(json['duration_seconds']),
      segments: rawSegments
          .whereType<Map<String, dynamic>>()
          .map(ContentTranscriptSegment.fromJson)
          .toList(),
      alignmentMethod: _readNullableString(json['alignment_method']),
      assetUrl: _readNullableString(json['asset_url']),
      text: _readNullableString(json['text']),
      error: _readNullableString(json['error']),
    );
  }
}

class ContentEpisodeDetail {
  const ContentEpisodeDetail({
    required this.id,
    required this.showId,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.coverImageUrl,
    required this.durationSeconds,
    required this.publishedAt,
    required this.episodeNumber,
    required this.tags,
    required this.likeCount,
    required this.commentCount,
    this.transcript,
  });

  final String id;
  final String showId;
  final String title;
  final String description;
  final String audioUrl;
  final String coverImageUrl;
  final int durationSeconds;
  final DateTime publishedAt;
  final int episodeNumber;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final ContentEpisodeTranscript? transcript;

  String get formattedDuration => _formatDuration(durationSeconds);
  String get formattedLikeCount => _formatCount(likeCount);
  String get formattedCommentCount => _formatCount(commentCount);

  factory ContentEpisodeDetail.fromJson(Map<String, dynamic> json) {
    return ContentEpisodeDetail(
      id: _readString(json['id']),
      showId: _readString(json['show_id']),
      title: _readString(json['title']),
      description: _readString(json['description']),
      audioUrl: _readString(json['audio_url']),
      coverImageUrl: _readString(json['cover_image_url']),
      durationSeconds: _readInt(json['duration_seconds']),
      publishedAt: _readDateTime(json['published_at']),
      episodeNumber: _readInt(json['episode_number']),
      tags: _readStringList(json['tags']),
      likeCount: _readInt(json['like_count']),
      commentCount: _readInt(json['comment_count']),
      transcript: (json['transcript'] as Map<String, dynamic>?) != null
          ? ContentEpisodeTranscript.fromJson(
              json['transcript'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class ContentShowBundle {
  const ContentShowBundle({required this.show, required this.episodes});

  final ContentShowDetail show;
  final List<ContentEpisodeSummary> episodes;
}

class ContentEpisodeBookmarkStatus {
  const ContentEpisodeBookmarkStatus({
    required this.episodeId,
    required this.isBookmarked,
  });

  final String episodeId;
  final bool isBookmarked;

  factory ContentEpisodeBookmarkStatus.fromJson(Map<String, dynamic> json) {
    return ContentEpisodeBookmarkStatus(
      episodeId: _readString(json['episode_id']),
      isBookmarked: _readBool(json['is_bookmarked']),
    );
  }
}

class ContentBookmarkedEpisode {
  const ContentBookmarkedEpisode({
    required this.episode,
    required this.show,
    required this.bookmarkedAt,
  });

  final ContentEpisodeSummary episode;
  final ContentShowSummary show;
  final DateTime bookmarkedAt;

  factory ContentBookmarkedEpisode.fromJson(Map<String, dynamic> json) {
    return ContentBookmarkedEpisode(
      episode: ContentEpisodeSummary.fromJson(
        (json['episode'] as Map<String, dynamic>?) ?? const {},
      ),
      show: ContentShowSummary.fromJson(
        (json['show'] as Map<String, dynamic>?) ?? const {},
      ),
      bookmarkedAt: _readDateTime(json['bookmarked_at']),
    );
  }
}

String _readString(Object? value, {String fallback = ''}) {
  if (value is String) {
    return value;
  }
  return fallback;
}

bool _readBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  return fallback;
}

String? _readNullableString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

double _readDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return 0;
}

DateTime _readDateTime(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

List<String> _readStringList(Object? value) {
  final items = value as List<dynamic>? ?? const [];
  return items
      .map((item) => _readString(item))
      .where((item) => item.isNotEmpty)
      .toList();
}

String _formatCount(int value) {
  if (value >= 1000000) {
    final millions = value / 1000000;
    return millions == millions.truncateToDouble()
        ? '${millions.toInt()}M'
        : '${millions.toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    final thousands = value / 1000;
    return thousands == thousands.truncateToDouble()
        ? '${thousands.toInt()}k'
        : '${thousands.toStringAsFixed(1)}k';
  }
  return value.toString();
}

String _formatDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
  return '${duration.inMinutes} phut';
}
