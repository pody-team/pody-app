import 'package:flutter/material.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/utils/player_utils.dart';
import 'package:pody/widgets/episode_companion_section.dart';

class PlayerScreen extends StatefulWidget {
  final Show? show;
  final Episode? episode;

  const PlayerScreen({super.key, this.show, this.episode});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  bool _isPlaying = true;
  double _progress = 0.33;
  double _playbackSpeed = 1.0;
  bool _isLiked = false;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _transcriptScrollController = ScrollController();
  final List<GlobalKey> _bubbleKeys = [];
  double _dragStart = 0;
  int _lastActiveIndex = -1;

  Episode get episode => widget.episode ?? show.episodes.first;
  Show get show => widget.show ?? MockData.shows.first;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;

        return Container(
          color: const Color(0xFF0F0F14),
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
                            top: 12,
                            left: 20,
                            right: 20,
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  show.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 44),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            child: episode.bubbles.isNotEmpty
                                ? _buildTranscript()
                                : SingleChildScrollView(
                                    physics: const ClampingScrollPhysics(),
                                    child: Text(
                                      episode.description,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withValues(
                                          alpha: 0.72,
                                        ),
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Row(
                            children: [
                              Expanded(
                                child: _MarqueeText(
                                  text: episode.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14,
                                  ),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white.withValues(
                                    alpha: 0.15,
                                  ),
                                  thumbColor: Colors.white,
                                  overlayColor: Colors.white.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                                child: Slider(
                                  value: _progress,
                                  onChanged: (v) =>
                                      setState(() => _progress = v),
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
                                      _currentTime,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _totalTime,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              GestureDetector(
                                onTap: _cycleSpeed,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_playbackSpeed}x',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _progress =
                                        (_progress -
                                                15 / episode.duration.inSeconds)
                                            .clamp(0.0, 1.0);
                                  });
                                },
                                child: Icon(
                                  Icons.replay_10,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 36,
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _isPlaying = !_isPlaying),
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
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _progress =
                                        (_progress +
                                                15 / episode.duration.inSeconds)
                                            .clamp(0.0, 1.0);
                                  });
                                },
                                child: Icon(
                                  Icons.forward_10,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 36,
                                ),
                              ),
                              Icon(
                                Icons.timer_outlined,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  final user = MockData.getUserById(
                                    show.primaryHost.id,
                                  );
                                  if (user != null) {
                                    openUserDetail(context, user);
                                  }
                                },
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.mic_none_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      show.primaryHost.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _isLiked = !_isLiked),
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: Icon(
                                        _isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        key: ValueKey(_isLiked),
                                        color: _isLiked
                                            ? const Color(0xFFFE2C55)
                                            : Colors.white
                                                .withValues(alpha: 0.5),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Icon(
                                    Icons.share_outlined,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 24),
                                  Icon(
                                    Icons.queue_music_rounded,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    size: 24,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 28),
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  EpisodeCompanionSection(show: show, episode: episode),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: GestureDetector(
                      onTap: () => openShowDetail(context, show),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.podcasts_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    show.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${show.episodes.length} tập • ${show.category}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
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
    final bubbles = episode.bubbles;

    // Ensure keys list is big enough
    while (_bubbleKeys.length < bubbles.length) {
      _bubbleKeys.add(GlobalKey());
    }

    final activeBubbleIndex = (_progress * bubbles.length).floor().clamp(
      0,
      bubbles.length - 1,
    );

    // Auto-scroll to active bubble whenever it changes
    if (activeBubbleIndex != _lastActiveIndex) {
      _lastActiveIndex = activeBubbleIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_transcriptScrollController.hasClients) return;
        final key = _bubbleKeys[activeBubbleIndex];
        final ctx = key.currentContext;
        if (ctx != null) {
          final renderBox = ctx.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final scrollable = _transcriptScrollController.position;
            final offset = renderBox
                .localToGlobal(
                  Offset.zero,
                  ancestor:
                      _transcriptScrollController.position.context.storageContext
                          .findRenderObject(),
                )
                .dy;
            final target = (_transcriptScrollController.offset +
                    offset -
                    scrollable.viewportDimension * 0.3)
                .clamp(
                  0.0,
                  _transcriptScrollController.position.maxScrollExtent,
                );
            _transcriptScrollController.animateTo(
              target,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }
        }
      });
    }

    // Progress within the active bubble (0.0 → 1.0)
    final bubbleProgress = (_progress * bubbles.length) - activeBubbleIndex;

    // Check if there are multiple speakers (conversation style vs storytelling)
    final hasMultipleSpeakers = bubbles.map((b) => b.speakerId).toSet().length > 1;

    return ListView.builder(
      controller: _transcriptScrollController,
      physics: const ClampingScrollPhysics(),
      itemCount: bubbles.length,
      itemBuilder: (context, i) {
        final bubble = bubbles[i];
        final isActive = i == activeBubbleIndex;
        final isPast = i < activeBubbleIndex;
        final showSpeaker = hasMultipleSpeakers &&
            (i == 0 || bubbles[i - 1].speakerId != bubble.speakerId);

        return Container(
          key: _bubbleKeys[i],
          margin: const EdgeInsets.only(bottom: 18),
          padding: isActive
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSpeaker)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? Color(bubble.colorValue)
                          : Colors.white.withValues(alpha: 0.3),
                      letterSpacing: 0.5,
                    ),
                    child: Text(bubble.speaker.toUpperCase()),
                  ),
                ),
              isActive
                  ? _buildHighlightedText(
                      text: bubble.text,
                      progress: bubbleProgress,
                    )
                  : AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isPast
                            ? Colors.white.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.22),
                        height: 1.6,
                      ),
                      child: Text(bubble.text),
                    ),
            ],
          ),
        );
      },
    );
  }

  /// Renders text highlighting only the current word with rounded background.
  Widget _buildHighlightedText({
    required String text,
    required double progress,
  }) {
    final words = text.split(' ');
    final currentWordIndex =
        (progress * words.length).floor().clamp(0, words.length - 1);

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFAB40).withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$word$suffix',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.95),
                    height: 1.6,
                  ),
                ),
              ),
            );
          }

          return TextSpan(
            text: '$word$suffix',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.9),
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
