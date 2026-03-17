class ContentAiHost {
  const ContentAiHost({
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

  factory ContentAiHost.fromJson(Map<String, dynamic> json) {
    return ContentAiHost(
      id: _readString(json['id']),
      displayName: _readString(json['display_name']),
      avatarUrl: _readString(json['avatar_url']),
      role: _readString(json['role'], fallback: 'host'),
      voiceProfileId: _readNullableString(json['voice_profile_id']),
      bio: _readNullableString(json['bio']),
    );
  }
}

class ContentCreateAiHostInput {
  const ContentCreateAiHostInput({
    required this.displayName,
    this.avatarUrl,
    this.voiceProfileId,
    this.bio,
  });

  final String displayName;
  final String? avatarUrl;
  final String? voiceProfileId;
  final String? bio;

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      if (avatarUrl != null && avatarUrl!.isNotEmpty) 'avatar_url': avatarUrl,
      if (voiceProfileId != null && voiceProfileId!.isNotEmpty)
        'voice_profile_id': voiceProfileId,
      if (bio != null && bio!.isNotEmpty) 'bio': bio,
    };
  }
}

class ContentCreateShowInput {
  const ContentCreateShowInput({
    required this.title,
    required this.primaryCategory,
    required this.aiHost,
    this.description,
    this.coverImageUrl,
    this.languageCode,
    this.contentType,
  });

  final String title;
  final String primaryCategory;
  final ContentCreateAiHostInput aiHost;
  final String? description;
  final String? coverImageUrl;
  final String? languageCode;
  final String? contentType;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'primary_category': primaryCategory,
      'ai_host': aiHost.toJson(),
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
    required this.aiHost,
    required this.subscriberCount,
    required this.totalEpisodeCount,
    required this.publishedAt,
  });

  final String id;
  final String slug;
  final String title;
  final String coverImageUrl;
  final String primaryCategory;
  final ContentAiHost aiHost;
  final int subscriberCount;
  final int totalEpisodeCount;
  final DateTime publishedAt;

  String get formattedSubscriberCount => _formatCount(subscriberCount);

  factory ContentShowSummary.fromJson(Map<String, dynamic> json) {
    return ContentShowSummary(
      id: _readString(json['id']),
      slug: _readString(json['slug']),
      title: _readString(json['title']),
      coverImageUrl: _readString(json['cover_image_url']),
      primaryCategory: _readString(json['primary_category']),
      aiHost: ContentAiHost.fromJson(
        (json['ai_host'] as Map<String, dynamic>?) ?? const {},
      ),
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
    required this.aiHost,
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
  final ContentAiHost aiHost;
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
  String get formattedSubscriberCount => _formatCount(subscriberCount);
  String get formattedListenCount => _formatCount(totalListenCount);

  ContentShowSummary toSummary() {
    return ContentShowSummary(
      id: id,
      slug: slug,
      title: title,
      coverImageUrl: coverImageUrl,
      primaryCategory: primaryCategory,
      aiHost: aiHost,
      subscriberCount: subscriberCount,
      totalEpisodeCount: totalEpisodeCount,
      publishedAt: publishedAt,
    );
  }

  factory ContentShowDetail.fromJson(Map<String, dynamic> json) {
    return ContentShowDetail(
      id: _readString(json['id']),
      slug: _readString(json['slug']),
      title: _readString(json['title']),
      description: _readString(json['description']),
      coverImageUrl: _readString(json['cover_image_url']),
      categories: _readStringList(json['categories']),
      tags: _readStringList(json['tags']),
      aiHost: ContentAiHost.fromJson(
        (json['ai_host'] as Map<String, dynamic>?) ?? const {},
      ),
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
    );
  }
}

class ContentShowBundle {
  const ContentShowBundle({required this.show, required this.episodes});

  final ContentShowDetail show;
  final List<ContentEpisodeSummary> episodes;
}

String _readString(Object? value, {String fallback = ''}) {
  if (value is String) {
    return value;
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
