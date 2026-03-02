import 'package:flutter/material.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/podcast/player_screen.dart';
import 'package:pody/screens/podcast/podcast_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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

  void _handleNotificationTap(BuildContext context, AppNotification notification) {
    switch (notification.targetType) {
      case NotificationTargetType.episode:
        // Find the episode and its parent podcast
        final episode = MockData.getEpisodeById(notification.targetId ?? '');
        final podcast = MockData.getPodcastById(episode?.podcastId ?? '');
        if (episode != null && podcast != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(
                podcast: podcast,
                episode: episode,
              ),
            ),
          );
        }
        break;
      case NotificationTargetType.podcast:
        final podcast = MockData.getPodcastById(notification.targetId ?? '');
        if (podcast != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PodcastDetailScreen(podcast: podcast),
            ),
          );
        }
        break;
      case NotificationTargetType.profile:
      case NotificationTargetType.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = MockData.notifications;
    final unread = notifications.where((n) => n.isUnread).toList();
    final read = notifications.where((n) => !n.isUnread).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E13),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // New section
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

            // New notifications
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _NotificationTile(
                  notification: unread[index],
                  icon: _iconForType(unread[index].type),
                  onTap: () => _handleNotificationTap(context, unread[index]),
                ),
                childCount: unread.length,
              ),
            ),

            // Earlier section
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

            // Earlier notifications
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _NotificationTile(
                  notification: read[index],
                  icon: _iconForType(read[index].type),
                  onTap: () => _handleNotificationTap(context, read[index]),
                ),
                childCount: read.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final IconData icon;
  final VoidCallback? onTap;

  const _NotificationTile({required this.notification, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isNew = notification.isUnread;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNew ? Colors.white.withValues(alpha: 0.04) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: isNew
            ? Border.all(color: Colors.white.withValues(alpha: 0.06))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with icon badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  notification.actorAvatarUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
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

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: notification.actorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(text: ' ${notification.action}'),
                      if (notification.targetTitle.isNotEmpty)
                        TextSpan(
                          text: ' ${notification.targetTitle}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
                if (notification.preview != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    notification.preview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white38,
                      fontStyle: FontStyle.italic,
                      height: 1.3,
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

          // New dot indicator
          if (isNew) ...[
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    ));
  }
}
