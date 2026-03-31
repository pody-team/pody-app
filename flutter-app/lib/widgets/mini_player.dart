import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/state/player_state.dart';
import 'package:pody/utils/player_utils.dart';

const _miniSurface = Color(0xFFFFFBF6);
const _miniSurfaceStrong = Color(0xFFF1E2D3);
const _miniPrimary = Color(0xFFBF5700);
const _miniNeutral = Color(0xFF3E2723);

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
    if (mounted) {
      setState(() {});
    }
  }

  void _openFullPlayer(BuildContext context) {
    final show = _playerState.show;
    final episode = _playerState.episode;
    if (show != null && episode != null) {
      openPlayerScreen(
        context,
        show: show,
        episode: episode,
        startPlayback: false,
      );
    }
  }

  String _subtitleForCurrentPlayback() {
    final show = _playerState.show;
    final episode = _playerState.episode;
    if (show == null || episode == null) {
      return '';
    }

    if (episode.episodeNumber > 0) {
      return '${show.title} • Tập ${episode.episodeNumber}';
    }

    return show.title;
  }

  @override
  Widget build(BuildContext context) {
    final episode = _playerState.episode;
    final show = _playerState.show;
    final progressValue = _playerState.progress.clamp(0.0, 1.0);

    if (episode == null || show == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _openFullPlayer(context),
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          _openFullPlayer(context);
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openFullPlayer(context),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _miniSurface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _miniPrimary.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: _miniNeutral.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _MiniArtwork(
                    imageUrl: episode.images.isNotEmpty
                        ? episode.images.first
                        : show.imageUrl,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.title,
                        style: GoogleFonts.workSans(
                          color: _miniNeutral,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitleForCurrentPlayback(),
                        style: GoogleFonts.workSans(
                          color: _miniNeutral.withValues(alpha: 0.58),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          backgroundColor: _miniPrimary.withValues(alpha: 0.08),
                          color: _miniPrimary,
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _MiniPlayerButton(
                  icon: Icons.skip_previous_rounded,
                  onPressed: _playerState.hasPrevious
                      ? () async {
                          await _playerState.skipToPrevious();
                        }
                      : null,
                ),
                _MiniPlayerButton(
                  icon: _playerState.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onPressed: () async {
                    await _playerState.togglePlayPause();
                  },
                  filled: true,
                ),
                _MiniPlayerButton(
                  icon: Icons.skip_next_rounded,
                  onPressed: _playerState.hasNext
                      ? () async {
                          await _playerState.skipToNext();
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      width: 52,
      height: 52,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 52,
          height: 52,
          color: _miniSurfaceStrong,
          alignment: Alignment.center,
          child: Icon(
            Icons.graphic_eq_rounded,
            color: _miniPrimary.withValues(alpha: 0.72),
            size: 24,
          ),
        );
      },
    );
  }
}

class _MiniPlayerButton extends StatelessWidget {
  const _MiniPlayerButton({
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final Future<void> Function()? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: filled
              ? _miniPrimary
              : _miniPrimary.withValues(alpha: enabled ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: IconButton(
          onPressed: onPressed,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          padding: EdgeInsets.zero,
          icon: Icon(
            icon,
            size: filled ? 22 : 20,
            color: filled
                ? Colors.white
                : enabled
                ? _miniNeutral
                : _miniNeutral.withValues(alpha: 0.28),
          ),
        ),
      ),
    );
  }
}
