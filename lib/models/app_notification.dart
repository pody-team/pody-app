enum NotificationType { like, comment, follow, milestone, newEpisode }

class AppNotification {
  final String id;
  final NotificationType type;
  final String user;
  final String action;
  final String target;
  final String? preview;
  final String time;
  final String avatarUrl;
  bool isNew;

  AppNotification({
    required this.id,
    required this.type,
    required this.user,
    required this.action,
    this.target = '',
    this.preview,
    required this.time,
    required this.avatarUrl,
    this.isNew = false,
  });
}
