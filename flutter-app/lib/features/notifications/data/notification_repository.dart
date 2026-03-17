import 'package:pody/models/social/app_notification.dart';

import 'notification_remote_data_source.dart';

class NotificationRepository {
  NotificationRepository(this._remoteDataSource);

  final NotificationRemoteDataSource _remoteDataSource;

  Future<List<AppNotification>> listNotifications() {
    return _remoteDataSource.listNotifications();
  }

  Future<int> unreadCount() {
    return _remoteDataSource.unreadCount();
  }

  Future<void> markAsRead(String notificationID) {
    return _remoteDataSource.markAsRead(notificationID);
  }

  Future<void> markAllAsRead() {
    return _remoteDataSource.markAllAsRead();
  }
}
