import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/features/content/presentation/content_legacy_mapper.dart';
import 'package:pody/features/content/presentation/content_scope.dart';
import 'package:pody/features/notifications/data/notification_repository.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/auth/sign_in_screen.dart';
import 'package:pody/screens/auth/sign_up_screen.dart';
import 'package:pody/screens/show/content_show_detail_screen.dart';
import 'package:pody/utils/player_utils.dart';

const _notifyCanvas = Color(0xFFF7F0E8);
const _notifyPrimary = Color(0xFFBF5700);
const _notifySecondary = Color(0xFFE1AD01);
const _notifyNeutral = Color(0xFF3E2723);
const _notifySurface = Color(0xFFFFFBF6);
const _notifySurfaceStrong = Color(0xFFF1E2D3);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    required this.repository,
    this.visible = true,
    this.visibilityListenable,
    this.refreshInterval = const Duration(seconds: 15),
    super.key,
  });

  final NotificationRepository repository;
  final bool visible;
  final ValueListenable<bool>? visibilityListenable;
  final Duration refreshInterval;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  List<AppNotification> _notifications = const [];
  bool _isLoading = false;
  bool _isMarkingAllRead = false;
  String? _errorMessage;
  String? _loadedForUserId;
  Timer? _refreshTimer;
  Duration? _refreshTimerInterval;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.visibilityListenable?.addListener(_handleVisibilityChanged);
  }

  @override
  void dispose() {
    widget.visibilityListenable?.removeListener(_handleVisibilityChanged);
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibilityListenable != widget.visibilityListenable) {
      oldWidget.visibilityListenable?.removeListener(_handleVisibilityChanged);
      widget.visibilityListenable?.addListener(_handleVisibilityChanged);
      _handleVisibilityChanged();
    }

    if (oldWidget.visible != widget.visible ||
        oldWidget.refreshInterval != widget.refreshInterval ||
        oldWidget.visibilityListenable != widget.visibilityListenable) {
      _syncRefreshTimer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLoaded();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isVisible) {
      _ensureLoaded(forceRefresh: true);
    }
  }

  bool get _isVisible => widget.visibilityListenable?.value ?? widget.visible;

  void _handleVisibilityChanged() {
    if (!mounted) {
      return;
    }

    _ensureLoaded(forceRefresh: _isVisible);
  }

  void _ensureLoaded({bool forceRefresh = false}) {
    final authController = AuthScope.of(context);
    final userId = authController.session?.user.id;
    _syncRefreshTimer();
    if (!authController.isAuthenticated || userId == null || userId.isEmpty) {
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

    if (!_isVisible) {
      return;
    }

    if (!forceRefresh && (_loadedForUserId == userId || _isLoading)) {
      return;
    }

    unawaited(_loadNotifications(userId));
  }

  void _syncRefreshTimer() {
    final authController = AuthScope.of(context);
    final userId = authController.session?.user.id;
    final shouldRefresh =
        _isVisible &&
        authController.isAuthenticated &&
        userId != null &&
        userId.isNotEmpty;

    if (!shouldRefresh) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _refreshTimerInterval = null;
      return;
    }

    final hasMatchingTimer =
        _refreshTimer != null &&
        _refreshTimer!.isActive &&
        _refreshTimerInterval == widget.refreshInterval;
    if (hasMatchingTimer) {
      return;
    }

    _refreshTimer?.cancel();
    if (widget.refreshInterval <= Duration.zero) {
      _refreshTimer = null;
      _refreshTimerInterval = null;
      return;
    }

    _refreshTimerInterval = widget.refreshInterval;
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) {
      if (!mounted || !_isVisible || _isLoading) {
        return;
      }

      final currentUserId = AuthScope.of(context).session?.user.id;
      if (currentUserId == null || currentUserId.isEmpty) {
        return;
      }

      unawaited(_loadNotifications(currentUserId));
    });
  }

  Future<void> _loadNotifications(String userId) async {
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
        _loadedForUserId = userId;
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

    await _handleNotificationTap(context, notification);
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
        return Icons.favorite_rounded;
      case NotificationType.comment:
        return Icons.chat_bubble_rounded;
      case NotificationType.follow:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.milestone:
        return Icons.auto_awesome_rounded;
      case NotificationType.newEpisode:
        return Icons.graphic_eq_rounded;
      case NotificationType.mention:
        return Icons.alternate_email_rounded;
    }
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    AppNotification notification,
  ) async {
    switch (notification.targetType) {
      case NotificationTargetType.episode:
        final episodeId = notification.targetId?.trim() ?? '';
        if (episodeId.isEmpty) {
          return;
        }
        try {
          final repository = ContentScope.of(context);
          final detail = await repository.getEpisodeDetail(episodeId);
          final bundle = await repository.getShowBundle(detail.showId);
          if (!context.mounted) {
            return;
          }
          openPlayerScreen(
            context,
            show: mapContentShowToLegacy(bundle.show, bundle.episodes),
            episode: mapContentEpisodeDetailToLegacy(
              detail,
              hosts: bundle.show.hosts,
            ),
            onOpenShow: () {
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ContentShowDetailScreen(
                    showId: bundle.show.id,
                    initialSummary: bundle.show.toSummary(),
                  ),
                ),
              );
            },
          );
        } catch (error) {
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
        }
        break;
      case NotificationTargetType.show:
        final showId = notification.targetId?.trim() ?? '';
        if (showId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ContentShowDetailScreen(showId: showId),
            ),
          );
        }
        break;
      case NotificationTargetType.profile:
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hồ sơ người dùng sẽ sớm được hỗ trợ bằng dữ liệu thật.',
            ),
          ),
        );
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
      backgroundColor: _notifyCanvas,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_notifySurface, _notifyCanvas],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: _notifyPrimary,
            backgroundColor: _notifySurface,
            onRefresh: () async {
              final userId = authController.session?.user.id;
              if (userId != null && userId.isNotEmpty) {
                await _loadNotifications(userId);
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                    child: _NotificationsHeader(
                      unreadCount: unread.length,
                      onMarkAllRead: _isMarkingAllRead ? null : _markAllAsRead,
                      isMarkingAllRead: _isMarkingAllRead,
                    ),
                  ),
                ),
                if (_isLoading && _notifications.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  )
                else if (_errorMessage != null && _notifications.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _NotificationsStateCard(
                      icon: Icons.wifi_tethering_error_rounded,
                      title: 'Không tải được thông báo',
                      message: _errorMessage!,
                      actionLabel: 'Thử lại',
                      onPressed: () {
                        final userId = authController.session?.user.id;
                        if (userId != null && userId.isNotEmpty) {
                          _loadNotifications(userId);
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
                          'Khi show, tập hoặc transcript hoàn tất, Pody sẽ hiện cập nhật ở đây.',
                    ),
                  )
                else ...[
                  if (unread.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(18, 22, 18, 10),
                        child: _SectionHeading(
                          eyebrow: 'Mới',
                          title: 'Cần bạn xem ngay',
                          description:
                              'Các cập nhật vừa đến và vẫn chưa được đánh dấu là đã đọc.',
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final notification = unread[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                          child: _NotificationTile(
                            notification: notification,
                            icon: _iconForType(notification.type),
                            onTap: () => _markAsReadAndOpen(notification),
                          ),
                        );
                      }, childCount: unread.length),
                    ),
                  ],
                  if (read.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
                        child: _SectionHeading(
                          eyebrow: 'Trước đó',
                          title: 'Đã xem gần đây',
                          description:
                              'Các thông báo cũ hơn vẫn còn lại để bạn mở lại khi cần.',
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final notification = read[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                          child: _NotificationTile(
                            notification: notification,
                            icon: _iconForType(notification.type),
                            onTap: () => _markAsReadAndOpen(notification),
                          ),
                        );
                      }, childCount: read.length),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.unreadCount,
    required this.onMarkAllRead,
    required this.isMarkingAllRead,
  });

  final int unreadCount;
  final VoidCallback? onMarkAllRead;
  final bool isMarkingAllRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THÔNG BÁO',
                      style: GoogleFonts.workSans(
                        color: _notifyPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      unreadCount > 0
                          ? '$unreadCount cập nhật mới'
                          : 'Hộp thư cập nhật',
                      style: GoogleFonts.newsreader(
                        color: _notifyNeutral,
                        fontSize: 30,
                        height: 0.98,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Theo dõi khi show, tập hoặc transcript vừa hoàn tất.',
                      style: GoogleFonts.workSans(
                        color: _notifyNeutral.withValues(alpha: 0.68),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _notifyPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextButton(
                  onPressed: onMarkAllRead,
                  style: TextButton.styleFrom(
                    foregroundColor: _notifyPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  child: isMarkingAllRead
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _notifyPrimary,
                          ),
                        )
                      : Text(
                          'Đọc hết',
                          style: GoogleFonts.workSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: GoogleFonts.workSans(
            color: _notifyPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: GoogleFonts.newsreader(
            color: _notifyNeutral,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 0.98,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: GoogleFonts.workSans(
            color: _notifyNeutral.withValues(alpha: 0.7),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
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
      backgroundColor: _notifyCanvas,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_notifySurface, _notifyCanvas],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _notifySurface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _notifyPrimary.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _notifyNeutral.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: _notifyPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        color: _notifyPrimary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Đăng nhập để xem thông báo',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.newsreader(
                        color: _notifyNeutral,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Theo dõi lúc show mới, tập mới và transcript vừa sẵn sàng cho riêng tài khoản của bạn.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.workSans(
                        color: _notifyNeutral.withValues(alpha: 0.7),
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: onSignIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: _notifyPrimary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Đăng nhập'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: onSignUp,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _notifyNeutral,
                        side: BorderSide(
                          color: _notifyNeutral.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Text('Tạo tài khoản'),
                    ),
                  ],
                ),
              ),
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
            color: _notifySurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _notifyPrimary.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _notifySecondary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: _notifyPrimary, size: 34),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  color: _notifyNeutral,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.workSans(
                  color: _notifyNeutral.withValues(alpha: 0.68),
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
              if (actionLabel != null && onPressed != null) ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: _notifyPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(actionLabel!),
                ),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isNew ? _notifySurface : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isNew
                  ? _notifyPrimary.withValues(alpha: 0.14)
                  : _notifyNeutral.withValues(alpha: 0.08),
            ),
            boxShadow: isNew
                ? [
                    BoxShadow(
                      color: _notifyPrimary.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _ActorAvatar(notification: notification),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _notifySurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: _notifySurface, width: 2),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _notifyPrimary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 12, color: _notifyPrimary),
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
                    Row(
                      children: [
                        if (isNew)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: const BoxDecoration(
                              color: _notifyPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.workSans(
                              fontSize: 14,
                              color: _notifyNeutral,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((subtitle ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.workSans(
                          fontSize: 13,
                          color: _notifyNeutral.withValues(alpha: 0.64),
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (notification.targetTitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _notifySecondary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          notification.targetTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.workSans(
                            fontSize: 11,
                            color: _notifyNeutral,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      notification.formattedTime,
                      style: GoogleFonts.workSans(
                        fontSize: 11,
                        color: _notifyNeutral.withValues(alpha: 0.46),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    final initials = notification.actorName.isNotEmpty
        ? notification.actorName.characters.first.toUpperCase()
        : 'P';
    if (avatarUrl.isEmpty || avatarUrl.contains('placehold.co')) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: _notifySurfaceStrong,
        child: Text(
          initials,
          style: GoogleFonts.workSans(
            color: _notifyNeutral,
            fontWeight: FontWeight.w700,
          ),
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
            backgroundColor: _notifySurfaceStrong,
            child: Text(
              initials,
              style: GoogleFonts.workSans(
                color: _notifyNeutral,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
    );
  }
}
