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
  final String action;          // 'liked your episode', 'commented on' ...

  // Target content (what was acted upon)
  final NotificationTargetType targetType;
  final String? targetId;       // episode/podcast/profile id for navigation
  final String targetTitle;     // display name: 'MVC thời hiện đại'

  // Optional preview text (for comments/replies)
  final String? preview;

  // Timestamps
  final DateTime createdAt;
  final DateTime? readAt;       // null = unread

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
    required this.createdAt,
    this.readAt,
  });

  bool get isUnread => readAt == null;

  /// Format relative time for display: "2 phút trước", "Hôm qua"
  String get formattedTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
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
      createdAt: createdAt,
      readAt: DateTime.now(),
    );
  }
}
