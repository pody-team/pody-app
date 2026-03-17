import 'package:pody/core/network/api_client.dart';
import 'package:pody/models/social/app_notification.dart';

class NotificationRemoteDataSource {
  NotificationRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppNotification>> listNotifications() async {
    final response = await _apiClient.get(
      '/api/v1/notifications',
      requiresAuth: true,
    );

    final rawNotifications =
        response['notifications'] as List<dynamic>? ?? const [];
    return rawNotifications
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  Future<int> unreadCount() async {
    final response = await _apiClient.get(
      '/api/v1/notifications/unread-count',
      requiresAuth: true,
    );

    return response['unread_count'] as int? ?? 0;
  }

  Future<void> markAsRead(String notificationID) async {
    await _apiClient.patchWithoutResponseBody(
      '/api/v1/notifications/$notificationID/read',
      requiresAuth: true,
    );
  }

  Future<void> markAllAsRead() async {
    await _apiClient.patchWithoutResponseBody(
      '/api/v1/notifications/read-all',
      requiresAuth: true,
    );
  }
}
