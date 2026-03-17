import 'package:flutter/material.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/features/notifications/data/notification_repository.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/auth/sign_in_screen.dart';
import 'package:pody/screens/auth/sign_up_screen.dart';
import 'package:pody/theme/app_colors.dart';
import 'package:pody/utils/player_utils.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({required this.repository, super.key});

  final NotificationRepository repository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = const [];
  bool _isLoading = false;
  bool _isMarkingAllRead = false;
  String? _errorMessage;
  String? _loadedForUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLoaded();
  }

  void _ensureLoaded() {
    final authController = AuthScope.of(context);
    final userID = authController.session?.user.id;
    if (!authController.isAuthenticated || userID == null || userID.isEmpty) {
      if (_loadedForUserId != null ||
          _notifications.isNotEmpty ||
          _errorMessage != null) {
        setState(() {
          _loadedForUserId = null;
          _notifications = const [];
          _errorMessage = null;
        });
      }
      return;
    }

    if (_loadedForUserId == userID || _isLoading) {
      return;
    }

    _loadNotifications(userID);
  }

  Future<void> _loadNotifications(String userID) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifications = await widget.repository.listNotifications();
      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = notifications;
        _loadedForUserId = userID;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _humanizeError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsReadAndOpen(AppNotification notification) async {
    if (notification.isUnread) {
      setState(() {
        _notifications = _notifications
            .map(
              (item) => item.id == notification.id ? item.markAsRead() : item,
            )
            .toList(growable: false);
      });

      try {
        await widget.repository.markAsRead(notification.id);
      } catch (_) {
        // Keep UX optimistic for now; the inbox will resync on refresh.
      }
    }

    if (!mounted) {
      return;
    }

    _handleNotificationTap(context, notification);
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkingAllRead || _notifications.every((item) => !item.isUnread)) {
      return;
    }

    setState(() => _isMarkingAllRead = true);
    try {
      await widget.repository.markAllAsRead();
      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = _notifications
            .map((item) => item.isUnread ? item.markAsRead() : item)
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    } finally {
      if (mounted) {
        setState(() => _isMarkingAllRead = false);
      }
    }
  }

  String _humanizeError(Object error) {
    if (error is ApiException) {
      if (error.isUnauthorized) {
        return 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại để xem thông báo.';
      }
      return error.message;
    }
    return 'Không thể tải thông báo lúc này. Hãy thử lại sau.';
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return Icons.favorite;
      case NotificationType.comment:
        return Icons.chat_bubble;
      case NotificationType.follow:
        return Icons.person_add;
      case NotificationType.milestone:
        return Icons.emoji_events;
      case NotificationType.newEpisode:
        return Icons.headphones;
      case NotificationType.mention:
        return Icons.alternate_email;
    }
  }

  void _handleNotificationTap(
    BuildContext context,
    AppNotification notification,
  ) {
    switch (notification.targetType) {
      case NotificationTargetType.episode:
        final episode = MockData.getEpisodeById(notification.targetId ?? '');
        final show = MockData.getShowById(episode?.showId ?? '');
        if (episode != null && show != null) {
          openPlayerScreen(context, show: show, episode: episode);
        }
        break;
      case NotificationTargetType.show:
        final show = MockData.getShowById(notification.targetId ?? '');
        if (show != null) {
          openShowDetail(context, show);
        }
        break;
      case NotificationTargetType.profile:
        final user = MockData.getUserById(notification.targetId ?? '');
        if (user != null) {
          openUserDetail(context, user);
        }
        break;
      case NotificationTargetType.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.of(context);
    final unread = _notifications.where((item) => item.isUnread).toList();
    final read = _notifications.where((item) => !item.isUnread).toList();

    if (!authController.isAuthenticated) {
      return _GuestNotificationsView(
        onSignIn: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const SignInScreen()));
        },
        onSignUp: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const SignUpScreen()));
        },
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E13),
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.white,
          backgroundColor: kBgCard,
          onRefresh: () async {
            final userID = authController.session?.user.id;
            if (userID != null && userID.isNotEmpty) {
              await _loadNotifications(userID);
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: const Color(0xFF0F0E13),
                pinned: true,
                automaticallyImplyLeading: false,
                title: const Text(
                  'Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _isMarkingAllRead ? null : _markAllAsRead,
                    child: _isMarkingAllRead
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mark all read'),
                  ),
                ],
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NotificationsStateCard(
                    icon: Icons.wifi_off_rounded,
                    title: 'Chưa tải được thông báo',
                    message: _errorMessage!,
                    actionLabel: 'Thử lại',
                    onPressed: () {
                      final userID = authController.session?.user.id;
                      if (userID != null && userID.isNotEmpty) {
                        _loadNotifications(userID);
                      }
                    },
                  ),
                )
              else if (_notifications.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NotificationsStateCard(
                    icon: Icons.notifications_none_rounded,
                    title: 'Chưa có thông báo nào',
                    message:
                        'Khi có người tương tác với nội dung của bạn hoặc có cập nhật mới, Pody sẽ hiện ở đây.',
                  ),
                )
              else ...[
                if (unread.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white38,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final notification = unread[index];
                      return _NotificationTile(
                        notification: notification,
                        icon: _iconForType(notification.type),
                        onTap: () => _markAsReadAndOpen(notification),
                      );
                    }, childCount: unread.length),
                  ),
                ],
                if (read.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Text(
                        'EARLIER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white38,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final notification = read[index];
                      return _NotificationTile(
                        notification: notification,
                        icon: _iconForType(notification.type),
                        onTap: () => _markAsReadAndOpen(notification),
                      );
                    }, childCount: read.length),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestNotificationsView extends StatelessWidget {
  const _GuestNotificationsView({
    required this.onSignIn,
    required this.onSignUp,
  });

  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E13),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Đăng nhập để xem thông báo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Theo dõi lượt thích, bình luận và cập nhật mới dành riêng cho tài khoản của bạn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onSignIn,
                  child: const Text('Đăng nhập'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onSignUp,
                  child: const Text('Tạo tài khoản'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsStateCard extends StatelessWidget {
  const _NotificationsStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: 36),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, height: 1.5),
              ),
              if (actionLabel != null && onPressed != null) ...[
                const SizedBox(height: 18),
                FilledButton(onPressed: onPressed, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.icon,
    this.onTap,
  });

  final AppNotification notification;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isNew = notification.isUnread;
    final title = notification.title.isNotEmpty
        ? notification.title
        : '${notification.actorName} ${notification.action}';
    final subtitle = notification.body.isNotEmpty
        ? notification.body
        : notification.preview;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isNew
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isNew
              ? Border.all(color: Colors.white.withValues(alpha: 0.06))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _ActorAvatar(notification: notification),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0E13),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0F0E13),
                        width: 2,
                      ),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 10, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((subtitle ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white38,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (notification.targetTitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      notification.targetTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    notification.formattedTime,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActorAvatar extends StatelessWidget {
  const _ActorAvatar({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = notification.actorAvatarUrl.trim();
    if (avatarUrl.isEmpty || avatarUrl.contains('placehold.co')) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        child: Text(
          notification.actorName.isNotEmpty
              ? notification.actorName.characters.first.toUpperCase()
              : 'P',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.network(
        avatarUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            child: Text(
              notification.actorName.isNotEmpty
                  ? notification.actorName.characters.first.toUpperCase()
                  : 'P',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      ),
    );
  }
}
