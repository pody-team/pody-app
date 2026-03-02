import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/utils/player_utils.dart';

class PlayerScreen extends StatefulWidget {
  final Podcast? podcast;
  final Episode? episode;

  const PlayerScreen({super.key, this.podcast, this.episode});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  bool _isPlaying = true;
  double _progress = 0.33;
  bool _isDragging = false;
  double _playbackSpeed = 1.0;
  bool _isLiked = false;
  bool _showSubs = true;

  Episode get episode => widget.episode ?? podcast.episodes.first;
  Podcast get podcast => widget.podcast ?? MockData.podcasts.first;

  String get _currentTime {
    final total = episode.duration.inSeconds;
    final current = (total * _progress).toInt();
    return _formatTime(current);
  }

  String get _totalTime => _formatTime(episode.duration.inSeconds);

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _cycleSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final comments = MockData.comments;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;

        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.35, 1.0],
              colors: [
                const Color(0xFF3A2D5C),
                const Color(0xFF1A1428),
                const Color(0xFF0F0E13),
              ],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Player area fills the actual modal height
                SizedBox(
                  height: availableHeight,
                  child: Column(
                    children: [
            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.only(
                top: 12,
                left: 20,
                right: 20,
                bottom: 8,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'PHÁT TỪ PODCAST',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.5),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          podcast.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.more_vert, color: Colors.white, size: 24),
                ],
              ),
            ),

            // ── Cover Art ── (fills remaining space)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        episode.images.isNotEmpty
                            ? episode.images.first
                            : podcast.imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                    // Karaoke subtitle overlay
                    if (_showSubs && episode.bubbles.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                          child: _buildKaraokeBubble(),
                        ),
                      ),
                    // Cast icon
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.cast,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 18),
                      ),
                    ),
                    // Subtitle toggle
                    Positioned(
                      top: 12,
                      left: 12,
                      child: GestureDetector(
                        onTap: () => setState(() => _showSubs = !_showSubs),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _showSubs
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.subtitles,
                            color: _showSubs
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Episode Title + Add ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => openPodcastDetail(context, podcast),
                          child: Text(
                            podcast.title,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => setState(() => _isLiked = !_isLiked),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _isLiked
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                        key: ValueKey(_isLiked),
                        color: _isLiked
                            ? const Color(0xFF1DB954)
                            : Colors.white.withValues(alpha: 0.6),
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Progress Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: Slider(
                      value: _progress,
                      onChanged: (v) => setState(() => _progress = v),
                      onChangeStart: (_) =>
                          setState(() => _isDragging = true),
                      onChangeEnd: (_) =>
                          setState(() => _isDragging = false),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_currentTime,
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    Colors.white.withValues(alpha: 0.5))),
                        Text(_totalTime,
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    Colors.white.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Playback Controls ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Speed
                  GestureDetector(
                    onTap: _cycleSpeed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_playbackSpeed}x',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                  // Rewind 15s
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _progress = (_progress - 15 / episode.duration.inSeconds)
                            .clamp(0.0, 1.0);
                      });
                    },
                    child: Icon(Icons.replay_10,
                        color: Colors.white.withValues(alpha: 0.9), size: 36),
                  ),
                  // Play/Pause
                  GestureDetector(
                    onTap: () => setState(() => _isPlaying = !_isPlaying),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 38,
                      ),
                    ),
                  ),
                  // Forward 15s
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _progress = (_progress + 15 / episode.duration.inSeconds)
                            .clamp(0.0, 1.0);
                      });
                    },
                    child: Icon(Icons.forward_10,
                        color: Colors.white.withValues(alpha: 0.9), size: 36),
                  ),
                  // Timer
                  Icon(Icons.timer_outlined,
                      color: Colors.white.withValues(alpha: 0.5), size: 28),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Bottom Actions ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Host avatar
                  GestureDetector(
                    onTap: () {
                      final user =
                          MockData.getUserById(podcast.primaryHost.id);
                      if (user != null) openUserDetail(context, user);
                    },
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            podcast.primaryHost.avatarUrl,
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          podcast.primaryHost.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.share_outlined,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 22),
                      const SizedBox(width: 24),
                      Icon(Icons.queue_music_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 24),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Divider ──
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 28),
              color: Colors.white.withValues(alpha: 0.06),
            ),

            // ── Comments Section ──
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
              child: Row(
                children: [
                  const Text(
                    'Bình luận',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Hiện tất cả (${comments.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
                ],
              ),
            ), // closes SizedBox

            const SizedBox(height: 12),

            // Comment list
            ...comments.map((c) => _buildCommentTile(c)),

            const SizedBox(height: 12),

            // Comment input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        MockData.currentUser.avatarUrl,
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Viết bình luận...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.send_rounded,
                        color: Colors.white.withValues(alpha: 0.2), size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Divider ──
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 28),
              color: Colors.white.withValues(alpha: 0.06),
            ),

            // ── Episode Description ──
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mô tả',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    episode.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Podcast Info Card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: GestureDetector(
                onTap: () => openPodcastDetail(context, podcast),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(podcast.imageUrl,
                            width: 52, height: 52, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              podcast.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${podcast.episodes.length} tập • ${podcast.category}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Colors.white.withValues(alpha: 0.3)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildCommentTile(Comment comment) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: comment.isStoryAvatar
                  ? Border.all(color: const Color(0xFFE040FB), width: 2)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(comment.avatarUrl,
                  width: 36, height: 36, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.author,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.time,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.favorite_border,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(width: 4),
                    Text(
                      '${comment.likes}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Trả lời',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKaraokeBubble() {
    final bubbles = episode.bubbles;
    // Show all bubbles up to current point
    final activeBubbleIndex =
        (_progress * bubbles.length).floor().clamp(0, bubbles.length - 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(activeBubbleIndex + 1, (i) {
        final bubble = bubbles[i];
        final isActive = i == activeBubbleIndex;
        final opacity = isActive ? 1.0 : 0.5;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment:
                bubble.isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!bubble.isRight) ...[
                // Left speaker avatar
                Opacity(
                  opacity: opacity,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(
                      podcast.hosts.length > 1
                          ? podcast.hosts.last.avatarUrl
                          : podcast.primaryHost.avatarUrl,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Opacity(
                  opacity: opacity,
                  child: Column(
                    crossAxisAlignment: bubble.isRight
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (i == 0 || bubbles[i - 1].speakerId != bubble.speakerId)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            bubble.speaker,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: bubble.isRight
                              ? Colors.white.withValues(alpha: isActive ? 0.18 : 0.1)
                              : Colors.white.withValues(alpha: isActive ? 0.10 : 0.05),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft:
                                Radius.circular(bubble.isRight ? 14 : 4),
                            bottomRight:
                                Radius.circular(bubble.isRight ? 4 : 14),
                          ),
                          border: isActive
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: 0.15))
                              : null,
                        ),
                        child: Text(
                          bubble.text,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.w500 : FontWeight.w400,
                            color: Color(bubble.colorValue),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (bubble.isRight) ...[
                const SizedBox(width: 6),
                // Right speaker avatar
                Opacity(
                  opacity: opacity,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundImage:
                        NetworkImage(podcast.primaryHost.avatarUrl),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}
