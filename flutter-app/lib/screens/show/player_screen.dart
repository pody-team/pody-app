import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/features/content/presentation/content_scope.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/show/player_favorites_store.dart';
import 'package:pody/screens/show/player_queue_bottom_sheet.dart';
import 'package:pody/screens/show/player_transcript_sync.dart';
import 'package:pody/state/player_state.dart';
import 'package:pody/utils/player_utils.dart';
import 'package:pody/widgets/episode_companion_section.dart';
import 'package:share_plus/share_plus.dart';

const Color _playerSurface = Color(0xFFFFFEFC);
const Color _playerSurfaceStrong = Color(0xFFF4E7D2);
const Color _playerPrimary = Color(0xFFBF5700);
const Color _playerSecondary = Color(0xFFE1AD01);
const Color _playerNeutral = Color(0xFF3E2723);
const Color _playerMuted = Color(0xFF7E665F);
const Color _playerBorder = Color(0xFFE7D6C3);

class PlayerScreen extends StatefulWidget {
  final Show? show;
  final Episode? episode;
  final VoidCallback? onOpenShow;

  const PlayerScreen({super.key, this.show, this.episode, this.onOpenShow})
    : assert(show != null),
      assert(episode != null);

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  final PlayerState _playerState = PlayerState.instance;
  bool _didLoadFavorites = false;
  bool _isLiked = false;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _transcriptScrollController = ScrollController();
  final List<GlobalKey> _bubbleKeys = [];
  double _dragStart = 0;
  int _lastActiveIndex = -1;
  bool _isTranscriptAutoFollowEnabled = true;
  bool _showReturnToCurrentTranscriptButton = false;
  bool _isTranscriptAutoScrolling = false;
  String? _favoriteEpisodeId;
  String? _transcriptEpisodeId;

  Episode get episode => widget.episode!;
  Show get show => widget.show!;

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _playerState.addListener(_handlePlayerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadFavorites) {
      _didLoadFavorites = true;
      unawaited(_syncFavoriteState(widget.episode!.id));
    }
  }

  @override
  void dispose() {
    _playerState.removeListener(_handlePlayerChanged);
    _scrollController.dispose();
    _transcriptScrollController.dispose();
    super.dispose();
  }

  void _handlePlayerChanged() {
    final activeEpisodeId = (_playerState.episode ?? episode).id;
    if (_favoriteEpisodeId != activeEpisodeId) {
      unawaited(_syncFavoriteState(activeEpisodeId));
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _syncFavoriteState(String episodeId) async {
    _favoriteEpisodeId = episodeId;
    final authController = AuthScope.of(context);
    bool isLiked;
    if (authController.isAuthenticated) {
      try {
        final repository = ContentScope.of(context);
        final status = await repository.getEpisodeBookmarkStatus(episodeId);
        isLiked = status.isBookmarked;
        await PlayerFavoritesStore.instance.set(episodeId, isLiked);
      } catch (_) {
        isLiked = await PlayerFavoritesStore.instance.isFavorited(episodeId);
      }
    } else {
      isLiked = await PlayerFavoritesStore.instance.isFavorited(episodeId);
    }
    if (!mounted || _favoriteEpisodeId != episodeId) {
      return;
    }
    setState(() => _isLiked = isLiked);
  }

  Future<void> _toggleFavorite(Episode activeEpisode) async {
    final authController = AuthScope.of(context);
    bool isLiked;
    if (authController.isAuthenticated) {
      try {
        final repository = ContentScope.of(context);
        final status = _isLiked
            ? await repository.deleteEpisodeBookmark(activeEpisode.id)
            : await repository.saveEpisodeBookmark(activeEpisode.id);
        isLiked = status.isBookmarked;
        await PlayerFavoritesStore.instance.set(activeEpisode.id, isLiked);
      } on ApiException {
        isLiked = await PlayerFavoritesStore.instance.toggle(activeEpisode.id);
      } catch (_) {
        isLiked = await PlayerFavoritesStore.instance.toggle(activeEpisode.id);
      }
    } else {
      isLiked = await PlayerFavoritesStore.instance.toggle(activeEpisode.id);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isLiked = isLiked;
      _favoriteEpisodeId = activeEpisode.id;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isLiked ? 'Đã lưu tập vào yêu thích.' : 'Đã bỏ khỏi yêu thích.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareEpisode(Show activeShow, Episode activeEpisode) async {
    final buffer = StringBuffer()
      ..writeln('🎧 ${activeEpisode.title}')
      ..writeln('🎙️ ${activeShow.title}')
      ..writeln();

    final description = activeEpisode.description.trim();
    if (description.isNotEmpty) {
      final compactDescription = description.replaceAll(RegExp(r'\s+'), ' ');
      if (compactDescription.length > 180) {
        buffer.writeln('${compactDescription.substring(0, 180)}...');
      } else {
        buffer.writeln(compactDescription);
      }
      buffer.writeln();
    }

    buffer.writeln('Nghe trên Pody.');
    await SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: activeEpisode.title),
    );
  }

  Future<void> _showQueue() async {
    final queue = _playerState.queue;
    final currentIndex = _playerState.currentQueueIndex;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.7,
          child: PlayerQueueBottomSheet(
            episodes: queue,
            currentIndex: currentIndex,
            onSelectEpisode: (index) async {
              await _playerState.playQueueEpisodeAt(index);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        );
      },
    );
  }

  void _resetTranscriptTracking(String episodeId) {
    if (_transcriptEpisodeId == episodeId) {
      return;
    }

    _transcriptEpisodeId = episodeId;
    _lastActiveIndex = -1;
    _isTranscriptAutoFollowEnabled = true;
    _showReturnToCurrentTranscriptButton = false;
  }

  double? _resolveTranscriptTargetOffset(int bubbleIndex) {
    if (!_transcriptScrollController.hasClients ||
        bubbleIndex < 0 ||
        bubbleIndex >= _bubbleKeys.length) {
      return null;
    }

    final context = _bubbleKeys[bubbleIndex].currentContext;
    final renderBox = context?.findRenderObject() as RenderBox?;
    final scrollAncestor = _transcriptScrollController
        .position
        .context
        .storageContext
        .findRenderObject();
    if (renderBox == null || scrollAncestor == null) {
      return null;
    }

    final scrollPosition = _transcriptScrollController.position;
    final offset = renderBox
        .localToGlobal(Offset.zero, ancestor: scrollAncestor)
        .dy;

    return (_transcriptScrollController.offset +
            offset -
            scrollPosition.viewportDimension * 0.3)
        .clamp(0.0, scrollPosition.maxScrollExtent);
  }

  Future<void> _scrollTranscriptToBubble(
    int bubbleIndex, {
    bool animated = true,
  }) async {
    final targetOffset = _resolveTranscriptTargetOffset(bubbleIndex);
    if (targetOffset == null) {
      return;
    }

    _isTranscriptAutoScrolling = true;
    try {
      if (animated) {
        await _transcriptScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        _transcriptScrollController.jumpTo(targetOffset);
      }
    } finally {
      _isTranscriptAutoScrolling = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isTranscriptAutoFollowEnabled = true;
      _showReturnToCurrentTranscriptButton = false;
    });
  }

  void _syncTranscriptReturnButton(
    int activeBubbleIndex, {
    bool enableAutoFollowWhenNear = false,
  }) {
    if (!_transcriptScrollController.hasClients) {
      return;
    }

    final targetOffset = _resolveTranscriptTargetOffset(activeBubbleIndex);
    if (targetOffset == null) {
      return;
    }

    final shouldShow = shouldShowReturnToCurrentTranscriptButton(
      currentOffset: _transcriptScrollController.offset,
      targetOffset: targetOffset,
    );
    final shouldEnableAutoFollow =
        enableAutoFollowWhenNear &&
        !shouldShow &&
        !_isTranscriptAutoFollowEnabled;

    if (!mounted ||
        (_showReturnToCurrentTranscriptButton == shouldShow &&
            !shouldEnableAutoFollow)) {
      return;
    }

    setState(() {
      _showReturnToCurrentTranscriptButton = shouldShow;
      if (shouldEnableAutoFollow) {
        _isTranscriptAutoFollowEnabled = true;
      }
    });
  }

  bool _handleTranscriptScrollNotification(
    ScrollNotification notification,
    int activeBubbleIndex,
  ) {
    if (_isTranscriptAutoScrolling) {
      return false;
    }

    final isUserDriven =
        (notification is ScrollStartNotification &&
            notification.dragDetails != null) ||
        (notification is ScrollUpdateNotification &&
            notification.dragDetails != null) ||
        (notification is OverscrollNotification &&
            notification.dragDetails != null);

    if (isUserDriven && _isTranscriptAutoFollowEnabled && mounted) {
      setState(() {
        _isTranscriptAutoFollowEnabled = false;
      });
    }

    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification ||
        notification is ScrollEndNotification ||
        notification is UserScrollNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncTranscriptReturnButton(
          activeBubbleIndex,
          enableAutoFollowWhenNear:
              notification is ScrollEndNotification ||
              notification is UserScrollNotification,
        );
      });
    }

    return false;
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: enabled ? _playerSurface : _playerSurfaceStrong,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _playerBorder),
          ),
          child: Icon(
            icon,
            color: enabled
                ? _playerNeutral
                : _playerMuted.withValues(alpha: 0.45),
            size: 28,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeEpisode = _playerState.episode ?? episode;
    final activeShow = _playerState.show ?? show;
    final position = _playerState.position;
    final duration = _playerState.duration.inSeconds > 0
        ? _playerState.duration
        : activeEpisode.duration;
    final progress = _playerState.progress;
    final isPlaying = _playerState.isPlaying;
    final playbackSpeed = _playerState.playbackSpeed;
    final hasAudio = activeEpisode.audioUrl?.trim().isNotEmpty ?? false;
    final currentTime = _formatTime(position.inSeconds);
    final totalTime = _formatTime(duration.inSeconds);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFBF6), Color(0xFFF7ECDD)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is OverscrollNotification &&
                  notification.overscroll < 0) {
                _dragStart += notification.overscroll.abs();
                if (_dragStart > 80) {
                  _dragStart = 0;
                  Navigator.pop(context);
                }
              }
              if (notification is ScrollEndNotification) {
                _dragStart = 0;
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(
                    height: availableHeight,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 10,
                            left: 18,
                            right: 18,
                            bottom: 10,
                          ),
                          child: Row(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _playerSurface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: _playerBorder),
                                    ),
                                    child: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: _playerNeutral,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Đang phát',
                                      style: GoogleFonts.workSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                        color: _playerMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      activeShow.title,
                                      style: GoogleFonts.newsreader(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: _playerNeutral,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _playerSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _playerBorder),
                                ),
                                child: Text(
                                  '${activeShow.episodes.length} tập',
                                  style: GoogleFonts.workSans(
                                    color: _playerMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 4,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _playerSurface,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: _playerBorder),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 22,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  12,
                                ),
                                child: activeEpisode.bubbles.isNotEmpty
                                    ? _buildTranscript()
                                    : SingleChildScrollView(
                                        physics: const ClampingScrollPhysics(),
                                        child: Text(
                                          activeEpisode.description,
                                          style: GoogleFonts.workSans(
                                            fontSize: 14,
                                            color: _playerNeutral,
                                            height: 1.65,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _playerSecondary.withValues(
                                    alpha: 0.18,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  activeShow.category,
                                  style: GoogleFonts.workSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _playerPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  activeShow.primaryHost.name,
                                  style: GoogleFonts.workSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _playerMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: _MarqueeText(
                                  text: activeEpisode.title,
                                  style: GoogleFonts.newsreader(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    color: _playerNeutral,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                            decoration: BoxDecoration(
                              color: _playerSurface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: _playerBorder),
                            ),
                            child: Column(
                              children: [
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 14,
                                    ),
                                    activeTrackColor: _playerPrimary,
                                    inactiveTrackColor: _playerPrimary
                                        .withValues(alpha: 0.12),
                                    thumbColor: _playerPrimary,
                                    overlayColor: _playerPrimary.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                  child: Slider(
                                    value: progress,
                                    onChanged: hasAudio
                                        ? (v) {
                                            _playerState.seekToFraction(v);
                                          }
                                        : null,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        currentTime,
                                        style: GoogleFonts.workSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _playerMuted,
                                        ),
                                      ),
                                      Text(
                                        totalTime,
                                        style: GoogleFonts.workSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _playerMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildControlButton(
                                    icon: Icons.skip_previous_rounded,
                                    enabled:
                                        hasAudio && _playerState.hasPrevious,
                                    onTap: _playerState.skipToPrevious,
                                  ),
                                  const SizedBox(width: 14),
                                  _buildControlButton(
                                    icon: Icons.replay_10,
                                    enabled: hasAudio,
                                    onTap: () {
                                      _playerState.seekRelative(
                                        const Duration(seconds: -15),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 16),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: hasAudio
                                          ? () {
                                              _playerState.togglePlayPause();
                                            }
                                          : null,
                                      child: Container(
                                        width: 74,
                                        height: 74,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              _playerPrimary,
                                              _playerSecondary,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x22BF5700),
                                              blurRadius: 24,
                                              offset: Offset(0, 12),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  _buildControlButton(
                                    icon: Icons.forward_10,
                                    enabled: hasAudio,
                                    onTap: () {
                                      _playerState.seekRelative(
                                        const Duration(seconds: 15),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 14),
                                  _buildControlButton(
                                    icon: Icons.skip_next_rounded,
                                    enabled: hasAudio && _playerState.hasNext,
                                    onTap: _playerState.skipToNext,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: hasAudio
                                      ? () {
                                          _playerState.cyclePlaybackSpeed();
                                        }
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _playerSurfaceStrong,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: _playerBorder),
                                    ),
                                    child: Text(
                                      '${playbackSpeed}x',
                                      style: GoogleFonts.workSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _playerNeutral,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: _playerSurface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: _playerBorder),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    final openShow = widget.onOpenShow;
                                    if (openShow != null) {
                                      openShow();
                                      return;
                                    }
                                    openShowDetail(context, activeShow);
                                  },
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: _playerSecondary.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.mic_none_rounded,
                                          size: 15,
                                          color: _playerPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        activeShow.primaryHost.name,
                                        style: GoogleFonts.workSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _playerNeutral,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () =>
                                          _toggleFavorite(activeEpisode),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: Icon(
                                          _isLiked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          key: ValueKey(_isLiked),
                                          color: _isLiked
                                              ? _playerPrimary
                                              : _playerMuted,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 22),
                                    GestureDetector(
                                      onTap: () => _shareEpisode(
                                        activeShow,
                                        activeEpisode,
                                      ),
                                      child: Icon(
                                        Icons.share_outlined,
                                        color: _playerMuted,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 22),
                                    GestureDetector(
                                      onTap: _showQueue,
                                      child: Icon(
                                        Icons.queue_music_rounded,
                                        color: _playerMuted,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!hasAudio) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _playerSurfaceStrong,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                'Tập này chưa có audio playback trong app.',
                                style: GoogleFonts.workSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _playerMuted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  EpisodeCompanionSection(
                    show: activeShow,
                    episode: activeEpisode,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mô tả',
                          style: GoogleFonts.newsreader(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: _playerNeutral,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _playerSurface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: _playerBorder),
                          ),
                          child: Text(
                            activeEpisode.description,
                            style: GoogleFonts.workSans(
                              fontSize: 14,
                              color: _playerNeutral,
                              height: 1.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap:
                          widget.onOpenShow ??
                          () => openShowDetail(context, activeShow),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _playerSurface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _playerBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _playerSecondary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.podcasts_rounded,
                                color: _playerPrimary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activeShow.title,
                                    style: GoogleFonts.workSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _playerNeutral,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${activeShow.episodes.length} tập • ${activeShow.category}',
                                    style: GoogleFonts.workSans(
                                      fontSize: 12,
                                      color: _playerMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: _playerMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Full transcript view — shows all lines, highlights active line & words.
  Widget _buildTranscript() {
    final activeEpisode = _playerState.episode ?? episode;
    final bubbles = activeEpisode.bubbles;
    final progress = _playerState.progress;
    final currentSeconds = _playerState.position.inMilliseconds / 1000.0;

    _resetTranscriptTracking(activeEpisode.id);

    // Ensure keys list is big enough
    while (_bubbleKeys.length < bubbles.length) {
      _bubbleKeys.add(GlobalKey());
    }

    final activeBubbleIndex = resolveActiveTranscriptBubbleIndex(
      bubbles: bubbles,
      currentSeconds: currentSeconds,
      fallbackProgress: progress,
    );

    // Auto-scroll to active bubble whenever it changes
    if (activeBubbleIndex != _lastActiveIndex) {
      _lastActiveIndex = activeBubbleIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isTranscriptAutoFollowEnabled) {
          _scrollTranscriptToBubble(activeBubbleIndex);
          return;
        }

        _syncTranscriptReturnButton(activeBubbleIndex);
      });
    }

    // Progress within the active bubble (0.0 → 1.0)
    final bubbleProgress = resolveTranscriptBubbleProgress(
      bubbles: bubbles,
      activeBubbleIndex: activeBubbleIndex,
      currentSeconds: currentSeconds,
      fallbackProgress: progress,
    );

    // Check if there are multiple speakers (conversation style vs storytelling)
    final hasMultipleSpeakers =
        bubbles.map((b) => b.speakerId).toSet().length > 1;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) => _handleTranscriptScrollNotification(
            notification,
            activeBubbleIndex,
          ),
          child: ListView.builder(
            controller: _transcriptScrollController,
            physics: const ClampingScrollPhysics(),
            itemCount: bubbles.length,
            itemBuilder: (context, i) {
              final bubble = bubbles[i];
              final isActive = i == activeBubbleIndex;
              final isPast = i < activeBubbleIndex;
              final showSpeaker =
                  hasMultipleSpeakers &&
                  (i == 0 || bubbles[i - 1].speakerId != bubble.speakerId);

              return Container(
                key: _bubbleKeys[i],
                margin: EdgeInsets.only(
                  bottom: i == bubbles.length - 1 ? 84 : 18,
                ),
                padding: isActive
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                    : const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? _playerSurfaceStrong : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSpeaker)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: GoogleFonts.workSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isActive ? _playerPrimary : _playerMuted,
                            letterSpacing: 0.5,
                          ),
                          child: Text(bubble.speaker.toUpperCase()),
                        ),
                      ),
                    isActive
                        ? _buildHighlightedText(
                            bubble: bubble,
                            progress: bubbleProgress,
                            currentSeconds: currentSeconds,
                          )
                        : AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: GoogleFonts.workSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: isPast
                                  ? _playerMuted
                                  : _playerNeutral.withValues(alpha: 0.55),
                              height: 1.6,
                            ),
                            child: Text(bubble.text),
                          ),
                  ],
                ),
              );
            },
          ),
        ),
        Positioned(
          right: 0,
          bottom: 12,
          child: IgnorePointer(
            ignoring: !_showReturnToCurrentTranscriptButton,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              offset: _showReturnToCurrentTranscriptButton
                  ? Offset.zero
                  : const Offset(0, 1.2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _showReturnToCurrentTranscriptButton ? 1 : 0,
                child: FilledButton.icon(
                  onPressed: () => _scrollTranscriptToBubble(activeBubbleIndex),
                  style: FilledButton.styleFrom(
                    backgroundColor: _playerPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(
                    'Về hiện tại',
                    style: GoogleFonts.workSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Renders text highlighting only the current word with rounded background.
  Widget _buildHighlightedText({
    required ChatBubble bubble,
    required double progress,
    required double currentSeconds,
  }) {
    final words = bubble.text
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentWordIndex = resolveTranscriptWordIndex(
      bubble: bubble,
      currentSeconds: currentSeconds,
      fallbackProgress: progress,
    );

    return Text.rich(
      TextSpan(
        children: words.asMap().entries.map((entry) {
          final idx = entry.key;
          final word = entry.value;
          final isCurrent = idx == currentWordIndex;
          final suffix = idx == words.length - 1 ? '' : ' ';

          if (isCurrent) {
            return WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: _playerPrimary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$word$suffix',
                  style: GoogleFonts.workSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _playerNeutral,
                    height: 1.6,
                  ),
                ),
              ),
            );
          }

          return TextSpan(
            text: '$word$suffix',
            style: GoogleFonts.workSans(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: _playerNeutral,
              height: 1.6,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Spotify-style marquee text that scrolls horizontally when overflowing.
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _animController;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        setState(() => _needsScroll = true);
        _startScrolling();
      }
    });
  }

  void _startScrolling() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          _scrollController.jumpTo(0);
          _animController.reset();
          Future.delayed(const Duration(seconds: 1), () {
            if (!mounted) return;
            _animController.forward();
          });
        });
      }
    });

    _animController.addListener(() {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(maxScroll * _animController.value);
      }
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: (widget.style.fontSize ?? 18) * (widget.style.height ?? 1.2) + 2,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return LinearGradient(
            colors: [
              if (_needsScroll) Colors.transparent else Colors.white,
              Colors.white,
              Colors.white,
              if (_needsScroll) Colors.transparent else Colors.white,
            ],
            stops: const [0.0, 0.05, 0.95, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}
