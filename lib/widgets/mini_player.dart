import 'package:flutter/material.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/screens/podcast/player_screen.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  bool _isPlaying = true;

  // Use the first episode with progress as "currently playing"
  final _progress = MockData.currentUserProgress.isNotEmpty
      ? MockData.currentUserProgress.first
      : null;

  void _openFullPlayer(BuildContext context) {
    final episode = _progress != null
        ? MockData.getEpisodeById(_progress!.episodeId)
        : MockData.allEpisodes.first;
    final podcast = _progress != null
        ? MockData.getPodcastById(_progress!.podcastId)
        : MockData.podcasts.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SizedBox.expand(
          child: PlayerScreen(
            podcast: podcast,
            episode: episode,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final episode = _progress != null
        ? MockData.getEpisodeById(_progress!.episodeId)
        : MockData.allEpisodes.first;
    final podcast = _progress != null
        ? MockData.getPodcastById(_progress!.podcastId)
        : MockData.podcasts.first;
    final progressValue = _progress?.progress ?? 0.0;

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
            )
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                episode?.images.isNotEmpty == true
                    ? episode!.images.first
                    : (podcast?.imageUrl ?? ''),
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
                    episode?.title ?? 'No episode',
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
                    '${podcast?.title ?? ''} • Ep. ${podcast?.totalEpisodeCount ?? ''}',
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
              icon: const Icon(Icons.favorite_border, color: Colors.white, size: 24),
            ),
            IconButton(
              onPressed: () {
                setState(() => _isPlaying = !_isPlaying);
              },
              icon: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
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
