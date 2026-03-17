class AIVoiceProfile {
  const AIVoiceProfile({
    required this.id,
    required this.name,
    required this.provider,
    required this.providerVoiceId,
    required this.languageCode,
    required this.gender,
  });

  final String id;
  final String name;
  final String provider;
  final String providerVoiceId;
  final String languageCode;
  final String gender;

  factory AIVoiceProfile.fromJson(Map<String, dynamic> json) {
    return AIVoiceProfile(
      id: _readString(json['id']),
      name: _readString(json['name']),
      provider: _readString(json['provider']),
      providerVoiceId: _readString(json['provider_voice_id']),
      languageCode: _readString(json['language_code']),
      gender: _readString(json['gender']),
    );
  }
}

class AIHostDraft {
  const AIHostDraft({
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.voiceProfileId,
    this.bio,
    this.personaSummary,
  });

  final String displayName;
  final String role;
  final String? avatarUrl;
  final String? voiceProfileId;
  final String? bio;
  final String? personaSummary;

  factory AIHostDraft.fromJson(Map<String, dynamic> json) {
    return AIHostDraft(
      displayName: _readString(json['display_name']),
      role: _readString(json['role'], fallback: 'host'),
      avatarUrl: _readNullableString(json['avatar_url']),
      voiceProfileId: _readNullableString(json['voice_profile_id']),
      bio: _readNullableString(json['bio']),
      personaSummary: _readNullableString(json['persona_summary']),
    );
  }
}

class AIEpisodeDraft {
  const AIEpisodeDraft({
    required this.episodeNumber,
    required this.title,
    required this.description,
    required this.estimatedDurationSeconds,
    required this.status,
    this.id,
    this.notes,
    this.coverImageUrl,
  });

  final String? id;
  final int episodeNumber;
  final String title;
  final String description;
  final int estimatedDurationSeconds;
  final String status;
  final String? notes;
  final String? coverImageUrl;

  String get formattedDuration => _formatDuration(estimatedDurationSeconds);

  factory AIEpisodeDraft.fromJson(Map<String, dynamic> json) {
    return AIEpisodeDraft(
      id: _readNullableString(json['id']),
      episodeNumber: _readInt(json['episode_number']),
      title: _readString(json['title']),
      description: _readString(json['description']),
      estimatedDurationSeconds: _readInt(
        json['estimated_duration_seconds'],
        fallback: 900,
      ),
      status: _readString(json['status'], fallback: 'draft'),
      notes: _readNullableString(json['notes']),
      coverImageUrl: _readNullableString(json['cover_image_url']),
    );
  }
}

class AIShowDraft {
  const AIShowDraft({
    required this.slug,
    required this.title,
    required this.description,
    required this.primaryCategory,
    required this.hosts,
    required this.categories,
    required this.tags,
    required this.languageCode,
    required this.contentType,
    this.id,
    this.coverImageUrl,
  });

  final String? id;
  final String slug;
  final String title;
  final String description;
  final String primaryCategory;
  final List<AIHostDraft> hosts;
  final List<String> categories;
  final List<String> tags;
  final String languageCode;
  final String contentType;
  final String? coverImageUrl;

  AIHostDraft? get primaryHost => hosts.isEmpty ? null : hosts.first;
  String get hostNames => hosts.map((host) => host.displayName).join(', ');

  factory AIShowDraft.fromJson(Map<String, dynamic> json) {
    final rawHosts = json['hosts'] as List<dynamic>? ?? const [];
    return AIShowDraft(
      id: _readNullableString(json['id']),
      slug: _readString(json['slug']),
      title: _readString(json['title']),
      description: _readString(json['description']),
      primaryCategory: _readString(json['primary_category']),
      hosts: rawHosts
          .whereType<Map<String, dynamic>>()
          .map(AIHostDraft.fromJson)
          .toList(),
      categories: _readStringList(json['categories']),
      tags: _readStringList(json['tags']),
      languageCode: _readString(json['language_code'], fallback: 'vi'),
      contentType: _readString(json['content_type'], fallback: 'podcast'),
      coverImageUrl: _readNullableString(json['cover_image_url']),
    );
  }
}

class AIProductionPlan {
  const AIProductionPlan({
    required this.id,
    required this.status,
    required this.seriesTitle,
    required this.seriesDescription,
    required this.targetLanguageCode,
    required this.showDraft,
    required this.episodes,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.threadId,
    this.toneStyle,
  });

  final String id;
  final String status;
  final String seriesTitle;
  final String seriesDescription;
  final String targetLanguageCode;
  final AIShowDraft showDraft;
  final List<AIEpisodeDraft> episodes;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? threadId;
  final String? toneStyle;

  factory AIProductionPlan.fromJson(Map<String, dynamic> json) {
    final rawEpisodes = json['episodes'] as List<dynamic>? ?? const [];
    return AIProductionPlan(
      id: _readString(json['id']),
      status: _readString(json['status']),
      seriesTitle: _readString(json['series_title']),
      seriesDescription: _readString(json['series_description']),
      targetLanguageCode: _readString(
        json['target_language_code'],
        fallback: 'vi',
      ),
      showDraft: AIShowDraft.fromJson(
        (json['show_draft'] as Map<String, dynamic>?) ?? const {},
      ),
      episodes: rawEpisodes
          .whereType<Map<String, dynamic>>()
          .map(AIEpisodeDraft.fromJson)
          .toList(),
      tags: _readStringList(json['tags']),
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
      threadId: _readNullableString(json['thread_id']),
      toneStyle: _readNullableString(json['tone_style']),
    );
  }
}

class AIChatMessage {
  const AIChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String text;
  final DateTime createdAt;

  bool get isUser => role.trim().toLowerCase() == 'user';

  factory AIChatMessage.fromJson(Map<String, dynamic> json) {
    return AIChatMessage(
      id: _readString(json['id']),
      role: _readString(json['role']),
      text: _readString(json['text_content']),
      createdAt: _readDateTime(json['created_at']),
    );
  }
}

class AIChatThread {
  const AIChatThread({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.currentPlan,
  });

  final String id;
  final String title;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AIChatMessage> messages;
  final AIProductionPlan? currentPlan;

  factory AIChatThread.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? const [];
    return AIChatThread(
      id: _readString(json['id']),
      title: _readString(json['title']),
      status: _readString(json['status']),
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
      messages: rawMessages
          .whereType<Map<String, dynamic>>()
          .map(AIChatMessage.fromJson)
          .toList(),
      currentPlan: json['current_plan'] is Map<String, dynamic>
          ? AIProductionPlan.fromJson(
              json['current_plan'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

enum AIChatStreamEventType { status, assistantDelta, thread, done, error }

class AIChatStreamEvent {
  const AIChatStreamEvent._({
    required this.type,
    this.message,
    this.deltaText,
    this.thread,
    this.threadId,
  });

  final AIChatStreamEventType type;
  final String? message;
  final String? deltaText;
  final AIChatThread? thread;
  final String? threadId;

  factory AIChatStreamEvent.status(String message) {
    return AIChatStreamEvent._(
      type: AIChatStreamEventType.status,
      message: message,
    );
  }

  factory AIChatStreamEvent.assistantDelta(String text) {
    return AIChatStreamEvent._(
      type: AIChatStreamEventType.assistantDelta,
      deltaText: text,
    );
  }

  factory AIChatStreamEvent.thread(AIChatThread thread) {
    return AIChatStreamEvent._(
      type: AIChatStreamEventType.thread,
      thread: thread,
    );
  }

  factory AIChatStreamEvent.done({String? threadId}) {
    return AIChatStreamEvent._(
      type: AIChatStreamEventType.done,
      threadId: threadId,
    );
  }

  factory AIChatStreamEvent.error(String message) {
    return AIChatStreamEvent._(
      type: AIChatStreamEventType.error,
      message: message,
    );
  }
}

String _readString(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }

  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _readNullableString(Object? value) {
  final text = _readString(value);
  return text.isEmpty ? null : text;
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return const [];
  }

  return value
      .map((item) => _readString(item))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

DateTime _readDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _formatDuration(int totalSeconds) {
  if (totalSeconds <= 0) {
    return '0m';
  }

  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}
