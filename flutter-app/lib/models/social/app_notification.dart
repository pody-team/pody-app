enum NotificationType { like, comment, follow, milestone, newEpisode, mention }

/// What the notification links to when tapped.
enum NotificationTargetType { episode, show, profile, none }

class AppNotification {
  final String id;
  final NotificationType type;

  // Who triggered the notification
  final String actorId;
  final String actorName;
  final String actorAvatarUrl;

  // Action description
  final String action; // 'liked your episode', 'commented on' ...

  // Target content (what was acted upon)
  final NotificationTargetType targetType;
  final String? targetId; // episode/podcast/profile id for navigation
  final String targetTitle; // display name: 'MVC thời hiện đại'

  // Optional preview text (for comments/replies)
  final String? preview;
  final String title;
  final String body;

  // Timestamps
  final DateTime createdAt;
  final DateTime? readAt; // null = unread

  AppNotification({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.actorAvatarUrl,
    required this.action,
    this.targetType = NotificationTargetType.none,
    this.targetId,
    this.targetTitle = '',
    this.preview,
    this.title = '',
    this.body = '',
    required this.createdAt,
    this.readAt,
  });

  bool get isUnread => readAt == null;

  /// Format relative time for display: "2 phút trước", "Hôm qua"
  String get formattedTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    }
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  AppNotification markAsRead() {
    return AppNotification(
      id: id,
      type: type,
      actorId: actorId,
      actorName: actorName,
      actorAvatarUrl: actorAvatarUrl,
      action: action,
      targetType: targetType,
      targetId: targetId,
      targetTitle: targetTitle,
      preview: preview,
      title: title,
      body: body,
      createdAt: createdAt,
      readAt: DateTime.now(),
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actorSnapshot =
        json['actor_snapshot'] as Map<String, dynamic>? ?? const {};
    final targetSnapshot =
        json['target_snapshot'] as Map<String, dynamic>? ?? const {};
    final title = json['title'] as String? ?? '';
    final body = json['body'] as String? ?? '';

    return AppNotification(
      id: json['id'] as String? ?? '',
      type: _parseType(json['type'] as String?),
      actorId: json['actor_user_id'] as String? ?? '',
      actorName:
          actorSnapshot['display_name'] as String? ??
          (title.isNotEmpty ? 'Pody' : 'Unknown'),
      actorAvatarUrl:
          actorSnapshot['avatar_url'] as String? ??
          'https://placehold.co/96x96/png',
      action: body.isNotEmpty ? body : title,
      targetType: _parseTargetType(json['target_type'] as String?),
      targetId: json['target_id'] as String?,
      targetTitle:
          targetSnapshot['title'] as String? ?? (title.isNotEmpty ? title : ''),
      preview: json['preview'] as String?,
      title: title,
      body: body,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      readAt: _parseDateTime(json['read_at']),
    );
  }

  static NotificationType _parseType(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'comment':
        return NotificationType.comment;
      case 'follow':
        return NotificationType.follow;
      case 'milestone':
        return NotificationType.milestone;
      case 'new_episode':
      case 'newepisode':
        return NotificationType.newEpisode;
      case 'mention':
        return NotificationType.mention;
      case 'like':
      default:
        return NotificationType.like;
    }
  }

  static NotificationTargetType _parseTargetType(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'episode':
        return NotificationTargetType.episode;
      case 'show':
        return NotificationTargetType.show;
      case 'profile':
        return NotificationTargetType.profile;
      default:
        return NotificationTargetType.none;
    }
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }
}
