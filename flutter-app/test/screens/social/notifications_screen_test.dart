import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pody/core/network/api_client.dart';
import 'package:pody/features/auth/application/auth_controller.dart';
import 'package:pody/features/auth/data/auth_local_data_source.dart';
import 'package:pody/features/auth/data/auth_remote_data_source.dart';
import 'package:pody/features/auth/data/auth_repository.dart';
import 'package:pody/features/auth/data/google_auth_data_source.dart';
import 'package:pody/features/auth/domain/auth_session.dart';
import 'package:pody/features/auth/domain/auth_user.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/features/notifications/data/notification_remote_data_source.dart';
import 'package:pody/features/notifications/data/notification_repository.dart';
import 'package:pody/models/social/app_notification.dart';
import 'package:pody/screens/social/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('reloads notifications when the tab becomes visible again', (
    WidgetTester tester,
  ) async {
    final authController = await _buildAuthenticatedController();
    final visibility = ValueNotifier<bool>(true);
    final remote = _FakeNotificationRemoteDataSource(
      ApiClient(baseUrl: 'http://localhost:8080'),
    )..notifications = [_notification('notif-1', 'Thong bao cu')];

    await tester.pumpWidget(
      _buildScreen(
        authController: authController,
        repository: NotificationRepository(remote),
        visibility: visibility,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thong bao cu'), findsOneWidget);

    remote.notifications = [_notification('notif-2', 'Show da san sang')];
    visibility.value = false;
    await tester.pump();
    visibility.value = true;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Show da san sang'), findsOneWidget);
    expect(remote.listNotificationsCalls, 2);
  });

  testWidgets('polls for new notifications while the tab is visible', (
    WidgetTester tester,
  ) async {
    final authController = await _buildAuthenticatedController();
    final visibility = ValueNotifier<bool>(true);
    final remote = _FakeNotificationRemoteDataSource(
      ApiClient(baseUrl: 'http://localhost:8080'),
    )..notifications = [_notification('notif-1', 'Dang tao show')];

    await tester.pumpWidget(
      _buildScreen(
        authController: authController,
        repository: NotificationRepository(remote),
        visibility: visibility,
        refreshInterval: const Duration(seconds: 1),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dang tao show'), findsOneWidget);

    remote.notifications = [_notification('notif-2', 'Show da san sang')];
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Show da san sang'), findsOneWidget);
    expect(remote.listNotificationsCalls, 2);
  });
}

Widget _buildScreen({
  required AuthController authController,
  required NotificationRepository repository,
  required ValueNotifier<bool> visibility,
  Duration refreshInterval = const Duration(seconds: 15),
}) {
  return MaterialApp(
    home: AuthScope(
      controller: authController,
      child: NotificationsScreen(
        repository: repository,
        visibilityListenable: visibility,
        refreshInterval: refreshInterval,
      ),
    ),
  );
}

Future<AuthController> _buildAuthenticatedController() async {
  SharedPreferences.setMockInitialValues({});
  final controller = AuthController(
    AuthRepository(
      remoteDataSource: _FakeAuthRemoteDataSource(
        ApiClient(baseUrl: 'http://localhost:8080'),
      ),
      localDataSource: AuthLocalDataSource(),
      googleAuthDataSource: _FakeGoogleAuthDataSource(),
    ),
  );
  await controller.signIn(email: 'creator@pody.vn', password: 'password-123');
  return controller;
}

AppNotification _notification(String id, String title) {
  return AppNotification(
    id: id,
    type: NotificationType.milestone,
    actorId: '',
    actorName: 'Pody AI',
    actorAvatarUrl: '',
    action: title,
    targetType: NotificationTargetType.show,
    targetId: 'show-1',
    targetTitle: 'AI Founder Diary',
    title: title,
    body: '"AI Founder Diary" da duoc tao xong.',
    createdAt: DateTime(2026, 3, 30, 14),
  );
}

class _FakeNotificationRemoteDataSource extends NotificationRemoteDataSource {
  _FakeNotificationRemoteDataSource(super.apiClient);

  int listNotificationsCalls = 0;
  List<AppNotification> notifications = const [];

  @override
  Future<List<AppNotification>> listNotifications() async {
    listNotificationsCalls += 1;
    return notifications;
  }
}

class _FakeGoogleAuthDataSource implements GoogleAuthDataSource {
  @override
  Future<String> signIn() async => 'fake-id-token';

  @override
  Future<void> signOut() async {}
}

class _FakeAuthRemoteDataSource extends AuthRemoteDataSource {
  _FakeAuthRemoteDataSource(super.apiClient);

  static final AuthUser _user = AuthUser(
    id: 'user-1',
    email: 'creator@pody.vn',
    displayName: 'Creator',
    status: 'active',
  );

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final now = DateTime.now().toUtc();
    return AuthSession(
      user: _user,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      accessTokenExpiresAt: now.add(const Duration(hours: 1)),
      refreshTokenExpiresAt: now.add(const Duration(days: 30)),
      tokenType: 'Bearer',
    );
  }
}
