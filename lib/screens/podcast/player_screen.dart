import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pody/theme/app_colors.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';

import 'package:pody/screens/social/comments_overlay.dart';
import 'podcast_detail_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  @override
  Widget build(BuildContext context) {
    final podcast = MockData.podcasts.first;
    final episode = podcast.episodes.first;
    return PodcastFeedItem(episode: episode, podcast: podcast);
  }
}

class PodcastFeedItem extends StatefulWidget {
  final Episode episode;
  final Podcast podcast;

  const PodcastFeedItem({super.key, required this.episode, required this.podcast});

  @override
  State<PodcastFeedItem> createState() => _PodcastFeedItemState();
}

class _PodcastFeedItemState extends State<PodcastFeedItem>
    with TickerProviderStateMixin {
  bool _isLiked = false;
  bool _isPlaying = true;
  bool _showPlayPauseIcon = false;
  double _progress = 0.33;
  bool _isDraggingProgress = false;

  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  // Player settings
  double _playbackSpeed = 1.0;
  bool _showSubtitles = true;
  bool _introMusic = true;
  bool _autoPlay = true;
  String _repeatMode = 'Off'; // Off, One, All

  // Animation controllers for each button
  late AnimationController _likeController;
  late AnimationController _commentController;
  late AnimationController _shareController;
  late AnimationController _playPauseController;

  late Animation<double> _likeScale;
  late Animation<double> _commentScale;
  late Animation<double> _shareScale;
  late Animation<double> _playPauseOpacity;
  late Animation<double> _playPauseScale;

  Episode get episode => widget.episode;
  Podcast get podcast => widget.podcast;

  @override
  void initState() {
    super.initState();
    _likeController = _createBounceController();
    _commentController = _createBounceController();
    _shareController = _createBounceController();

    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _playPauseOpacity =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.9), weight: 15),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 0.9), weight: 45),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 0.0), weight: 40),
        ]).animate(
          CurvedAnimation(parent: _playPauseController, curve: Curves.easeOut),
        );
    _playPauseScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.1), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 20),
        ]).animate(
          CurvedAnimation(parent: _playPauseController, curve: Curves.easeOut),
        );
    _playPauseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showPlayPauseIcon = false);
      }
    });

    _likeScale = _createBounceAnimation(_likeController);
    _commentScale = _createBounceAnimation(_commentController);
    _shareScale = _createBounceAnimation(_shareController);
  }

  AnimationController _createBounceController() {
    return AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  Animation<double> _createBounceAnimation(AnimationController controller) {
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.7), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }

  void _onPlayPauseTap() {
    setState(() {
      _isPlaying = !_isPlaying;
      _showPlayPauseIcon = true;
    });
    _playPauseController.forward(from: 0);
  }

  @override
  void dispose() {
    _likeController.dispose();
    _commentController.dispose();
    _shareController.dispose();
    _playPauseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onLikeTap() {
    setState(() => _isLiked = !_isLiked);
    _likeController.forward(from: 0);
  }

  void _onShareTap() {
    _shareController.forward(from: 0);
    showModalBottomSheet(
      context: context,
      backgroundColor: kBgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Share Episode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(Icons.link, 'Copy Link'),
                _buildShareOption(Icons.message, 'Message'),
                _buildShareOption(Icons.camera_alt, 'Story'),
                _buildShareOption(Icons.more_horiz, 'More'),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  void _onCommentTap() {
    _commentController.forward(from: 0);
    showCommentsOverlay(context);
  }

  void _showPlayerSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Player Settings',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Playback Speed
                  Row(
                    children: [
                      const Icon(Icons.speed, color: Colors.white54, size: 20),
                      const SizedBox(width: 12),
                      const Text(
                        'Playback Speed',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_playbackSpeed}x',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Speed selector
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                        final isActive = _playbackSpeed == speed;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() => _playbackSpeed = speed);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                speed == speed.toInt()
                                    ? '${speed.toInt()}x'
                                    : '${speed}x',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? Colors.black
                                      : Colors.white38,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                  const SizedBox(height: 12),

                  // Subtitles
                  _buildSettingToggle(
                    icon: Icons.subtitles_outlined,
                    title: 'Subtitles',
                    subtitle: 'Show captions on screen',
                    value: _showSubtitles,
                    onChanged: (val) {
                      setModalState(() => _showSubtitles = val);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 4),

                  // Intro Music
                  _buildSettingToggle(
                    icon: Icons.music_note,
                    title: 'Intro Music',
                    subtitle: 'Play intro before episode',
                    value: _introMusic,
                    onChanged: (val) {
                      setModalState(() => _introMusic = val);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 4),

                  // Auto-play
                  _buildSettingToggle(
                    icon: Icons.playlist_play,
                    title: 'Auto-play Next',
                    subtitle: 'Automatically play next episode',
                    value: _autoPlay,
                    onChanged: (val) {
                      setModalState(() => _autoPlay = val);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                  const SizedBox(height: 12),

                  // Repeat Mode
                  GestureDetector(
                    onTap: () {
                      setModalState(() {
                        if (_repeatMode == 'Off') {
                          _repeatMode = 'One';
                        } else if (_repeatMode == 'One') {
                          _repeatMode = 'All';
                        } else {
                          _repeatMode = 'Off';
                        }
                      });
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            _repeatMode == 'One'
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: _repeatMode == 'Off'
                                ? Colors.white38
                                : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Repeat',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _repeatMode != 'Off'
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _repeatMode,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _repeatMode != 'Off'
                                    ? Colors.black
                                    : Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sleep Timer
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSleepTimerPicker();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bedtime_outlined,
                            color: Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Sleep Timer',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white24,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.white24),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white38,
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  void _showSleepTimerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sleep Timer',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ...[
              'Off',
              '15 minutes',
              '30 minutes',
              '45 minutes',
              '1 hour',
              'End of episode',
            ].map(
              (option) => ListTile(
                title: Text(
                  option,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                trailing: option == 'Off'
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
                onTap: () => Navigator.pop(ctx),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onPlayPauseTap,
      child: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
              },
              itemCount: episode.images.length,
              itemBuilder: (context, index) {
                return Image.network(
                  episode.images[index],
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: 0.5),
                  colorBlendMode: BlendMode.darken,
                );
              },
            ),
          ),

          // Gradient at top and bottom
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black87,
                      Colors.black12,
                      Colors.transparent,
                      Colors.black54,
                      Colors.black,
                    ],
                    stops: [0.0, 0.2, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Floating Bubbles Area (Chat)
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            bottom: 160,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: episode.bubbles.map((bubble) {
                return Align(
                  alignment: bubble.isRight
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(bubble.isRight ? 20 : 4),
                        bottomRight: Radius.circular(bubble.isRight ? 4 : 20),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bubble.speaker.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(bubble.colorValue),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                bubble.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Top Bar (Search, Following/For You, Notifications)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCircleIconButton(
                    Icons.keyboard_arrow_down_rounded,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(), // Used to space out the top right buttons from top left
                ],
              ),
            ),
          ),

          // Right Action Bar
          Positioned(
            right: 12,
            bottom: 120,
            child: Column(
              children: [
                // Host Avatar
                SizedBox(
                  height: 60,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: Image.network(
                            podcast.primaryHost.avatarUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.black,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Like button
                _buildAnimatedAction(
                  animation: _likeScale,
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  label: episode.formattedLikes,
                  color: _isLiked ? Colors.redAccent : Colors.white,
                  onTap: _onLikeTap,
                ),
                // Comment button
                _buildAnimatedAction(
                  animation: _commentScale,
                  icon: Icons.chat_bubble_outline_rounded,
                  label: episode.formattedComments,
                  color: Colors.white,
                  onTap: _onCommentTap,
                ),
                // Share button
                _buildAnimatedAction(
                  animation: _shareScale,
                  icon: Icons.share,
                  label: 'Share',
                  color: Colors.white,
                  onTap: _onShareTap,
                ),
                // Settings mini button
                GestureDetector(
                  onTap: _showPlayerSettings,
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: Icon(
                      Icons.menu,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Info Area
          Positioned(
            left: 16,
            right: 72,
            bottom: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Pager indicator (TikTok style dots)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    episode.images.length,
                    (index) {
                      final isActive = index == _currentImageIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isActive ? 16 : 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white : Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Episode Info Chip
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PodcastDetailScreen(podcast: MockData.podcasts.first),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: const Icon(
                                Icons.graphic_eq,
                                size: 12,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${podcast.title} • Ep. ${podcast.totalEpisodeCount}'.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  episode.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  episode.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),

                // Tags
                if (episode.tags.isNotEmpty)
                  Row(
                    children: episode.tags.map((tag) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tag == '#AI' ? Colors.white : Colors.white70,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          // Progress Bar (interactive)
          Positioned(
            left: 0,
            right: 0,
            bottom: 74,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final width = MediaQuery.of(context).size.width;
                setState(() {
                  _progress = (details.localPosition.dx / width).clamp(
                    0.0,
                    1.0,
                  );
                  _isDraggingProgress = true;
                });
              },
              onTapUp: (_) => setState(() => _isDraggingProgress = false),
              onHorizontalDragStart: (_) {
                setState(() => _isDraggingProgress = true);
              },
              onHorizontalDragUpdate: (details) {
                final width = MediaQuery.of(context).size.width;
                setState(() {
                  _progress = (details.localPosition.dx / width).clamp(
                    0.0,
                    1.0,
                  );
                });
              },
              onHorizontalDragEnd: (_) {
                setState(() => _isDraggingProgress = false);
              },
              child: SizedBox(
                height: 20,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barHeight = _isDraggingProgress ? 6.0 : 2.0;
                    final totalWidth = constraints.maxWidth;
                    final activeWidth = totalWidth * _progress;
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Background track
                        Container(
                          height: barHeight,
                          width: totalWidth,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // Active track (left-aligned)
                        Container(
                          height: barHeight,
                          width: activeWidth,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // Thumb dot
                        if (_isDraggingProgress)
                          Positioned(
                            left: activeWidth - 5,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // Play/Pause overlay icon
          if (_showPlayPauseIcon)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _playPauseController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _playPauseOpacity.value,
                        child: Transform.scale(
                          scale: _playPauseScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton(
    IconData icon, {
    bool hasBadge = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          if (hasBadge)
            Positioned(
              right: 2,
              top: 2,
              child: const SizedBox(
                width: 8,
                height: 8,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedAction({
    required Animation<double> animation,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.scale(scale: animation.value, child: child);
          },
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
