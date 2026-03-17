import 'package:flutter/material.dart';
import 'package:pody/state/player_state.dart';
import 'package:pody/utils/player_utils.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final _playerState = PlayerState.instance;

  @override
  void initState() {
    super.initState();
    _playerState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _playerState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _openFullPlayer(BuildContext context) {
    final show = _playerState.show;
    final episode = _playerState.episode;
    if (show != null && episode != null) {
      openPlayerScreen(context, show: show, episode: episode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final episode = _playerState.episode;
    final show = _playerState.show;
    final progressValue = _playerState.progress;

    if (episode == null || show == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _openFullPlayer(context),
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          _openFullPlayer(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                episode.images.isNotEmpty
                    ? episode.images.first
                    : show.imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            // Title & Progress
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${show.title} • Ep. ${show.totalEpisodeCount}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // mini progress bar
                  LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    color: Colors.white,
                    minHeight: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Controls
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.favorite_border,
                color: Colors.white,
                size: 24,
              ),
            ),
            IconButton(
              onPressed: () {
                _playerState.togglePlayPause();
              },
              icon: Icon(
                _playerState.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill,
                color: Colors.white,
                size: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
