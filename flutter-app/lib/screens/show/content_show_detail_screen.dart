import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/features/content/presentation/content_legacy_mapper.dart';
import 'package:pody/features/content/presentation/content_scope.dart';
import 'package:pody/utils/player_utils.dart';

const _detailCanvas = Color(0xFFF7F0E8);
const _detailPrimary = Color(0xFFBF5700);
const _detailSecondary = Color(0xFFE1AD01);
const _detailTertiary = Color(0xFF566931);
const _detailNeutral = Color(0xFF3E2723);
const _detailSurface = Color(0xFFFFFBF6);
const _detailSurfaceStrong = Color(0xFFF1E2D3);

enum ContentShowDetailSource { listener, creator }

class ContentShowDetailScreen extends StatefulWidget {
  const ContentShowDetailScreen({
    required this.showId,
    this.initialSummary,
    this.source = ContentShowDetailSource.listener,
    super.key,
  });

  final String showId;
  final ContentShowSummary? initialSummary;
  final ContentShowDetailSource source;

  @override
  State<ContentShowDetailScreen> createState() =>
      _ContentShowDetailScreenState();
}

class _ContentShowDetailScreenState extends State<ContentShowDetailScreen> {
  ContentShowBundle? _bundle;
  bool _isLoading = false;
  String? _errorMessage;
  String? _playingEpisodeId;
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) {
      return;
    }
    _didLoad = true;
    _loadShow();
  }

  Future<void> _loadShow() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = ContentScope.of(context);
      final bundle = widget.source == ContentShowDetailSource.creator
          ? await repository.getCreatorShowBundle(widget.showId)
          : await repository.getShowBundle(widget.showId);
      if (!mounted) {
        return;
      }
      setState(() {
        _bundle = bundle;
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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openEpisode(ContentEpisodeSummary episode) async {
    final bundle = _bundle;
    if (bundle == null) {
      return;
    }

    setState(() => _playingEpisodeId = episode.id);
    try {
      final repository = ContentScope.of(context);
      final detail = widget.source == ContentShowDetailSource.creator
          ? await repository.getCreatorEpisodeDetail(episode.id)
          : await repository.getEpisodeDetail(episode.id);
      final remainingDetails = await Future.wait([
        for (final summary in bundle.episodes)
          if (summary.id != episode.id)
            widget.source == ContentShowDetailSource.creator
                ? repository.getCreatorEpisodeDetail(summary.id)
                : repository.getEpisodeDetail(summary.id),
      ]);
      if (!mounted) {
        return;
      }

      final detailById = <String, ContentEpisodeDetail>{
        detail.id: detail,
        for (final item in remainingDetails) item.id: item,
      };
      final legacyShow = mapContentShowToLegacyWithEpisodeDetails(
        bundle.show,
        bundle.episodes,
        detailById,
      );
      final legacyEpisode = mapContentEpisodeDetailToLegacy(
        detail,
        hosts: bundle.show.hosts,
      );

      openPlayerScreen(
        context,
        show: legacyShow,
        episode: legacyEpisode,
        onOpenShow: () {
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ContentShowDetailScreen(
                showId: bundle.show.id,
                initialSummary: bundle.show.toSummary(),
                source: widget.source,
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    } finally {
      if (mounted) {
        setState(() => _playingEpisodeId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.initialSummary;
    final bundle = _bundle;
    final show = bundle?.show;

    return Scaffold(
      backgroundColor: _detailCanvas,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_detailSurface, _detailCanvas],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: _detailCanvas,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _IconCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                leadingWidth: 56,
                title: Text(
                  show?.title ?? summary?.title ?? 'Chi tiết show',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.workSans(
                    color: _detailNeutral,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_isLoading && bundle == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else if (_errorMessage != null && bundle == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(
                    message: _errorMessage!,
                    onRetry: _loadShow,
                  ),
                )
              else
                SliverList.list(
                  children: [
                    _buildHero(show, summary, bundle),
                    _buildDescription(show),
                    _buildEpisodes(bundle),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(
    ContentShowDetail? show,
    ContentShowSummary? summary,
    ContentShowBundle? bundle,
  ) {
    final title = show?.title ?? summary?.title ?? 'Đang tải';
    final coverImageUrl = show?.coverImageUrl ?? summary?.coverImageUrl ?? '';
    final hosts = show?.hosts ?? summary?.hosts ?? const [];
    final hostLabel = hosts.map((host) => host.displayName).join(', ');
    final categories = <String>{
      if ((summary?.primaryCategory ?? '').isNotEmpty) summary!.primaryCategory,
      ...?show?.categories.where((item) => item.isNotEmpty),
    }.toList(growable: false);
    final latestEpisodes =
        bundle == null ? <ContentEpisodeSummary>[] : [...bundle.episodes]
          ..sort((left, right) {
            final byNumber = right.episodeNumber.compareTo(left.episodeNumber);
            if (byNumber != 0) {
              return byNumber;
            }
            return right.publishedAt.compareTo(left.publishedAt);
          });
    final latest = latestEpisodes.isEmpty ? null : latestEpisodes.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Container(
        decoration: BoxDecoration(
          color: _detailSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _detailPrimary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: _detailNeutral.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 280,
              child: _DetailImage(
                imageUrl: coverImageUrl,
                fallbackColor: _detailSurfaceStrong,
                iconColor: _detailPrimary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...categories.map(
                        (category) => _buildChip(
                          category,
                          backgroundColor: _detailPrimary.withValues(
                            alpha: 0.08,
                          ),
                          foregroundColor: _detailPrimary,
                        ),
                      ),
                      if (show != null)
                        _buildChip(
                          show.contentType,
                          backgroundColor: _detailTertiary.withValues(
                            alpha: 0.12,
                          ),
                          foregroundColor: _detailTertiary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: GoogleFonts.newsreader(
                      color: _detailNeutral,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 0.95,
                    ),
                  ),
                  if (hostLabel.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (hosts.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: _detailSurfaceStrong,
                              backgroundImage: hosts.first.avatarUrl.isEmpty
                                  ? null
                                  : NetworkImage(hosts.first.avatarUrl),
                              child: hosts.first.avatarUrl.isEmpty
                                  ? Text(
                                      _initialFor(hosts.first.displayName),
                                      style: GoogleFonts.workSans(
                                        color: _detailNeutral,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            'Dẫn bởi $hostLabel',
                            style: GoogleFonts.workSans(
                              color: _detailNeutral.withValues(alpha: 0.72),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (show != null) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildStatChip(
                          '${show.formattedListenCount} lượt nghe',
                        ),
                        _buildStatChip(
                          '${show.formattedSubscriberCount} theo dõi',
                        ),
                        _buildStatChip('${show.totalEpisodeCount} tập'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _detailCanvas,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: _detailSurfaceStrong,
                            backgroundImage: show.owner.avatarUrl.isEmpty
                                ? null
                                : NetworkImage(show.owner.avatarUrl),
                            child: show.owner.avatarUrl.isEmpty
                                ? Text(
                                    _initialFor(show.owner.displayName),
                                    style: GoogleFonts.workSans(
                                      color: _detailNeutral,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  show.owner.displayName,
                                  style: GoogleFonts.workSans(
                                    color: _detailNeutral,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${show.totalEpisodeCount} tập • ${show.languageCode.toUpperCase()} • ${show.contentType}',
                                  style: GoogleFonts.workSans(
                                    color: _detailNeutral.withValues(
                                      alpha: 0.6,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (latest != null) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => _openEpisode(latest),
                      style: FilledButton.styleFrom(
                        backgroundColor: _detailPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        'Nghe tập mới nhất',
                        style: GoogleFonts.workSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription(ContentShowDetail? show) {
    if (show == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _detailNeutral.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Về show',
              style: GoogleFonts.workSans(
                color: _detailPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              show.description,
              style: GoogleFonts.workSans(
                color: _detailNeutral.withValues(alpha: 0.78),
                fontSize: 14,
                height: 1.65,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (show.tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: show.tags
                    .map(
                      (tag) => _buildChip(
                        tag,
                        backgroundColor: _detailSecondary.withValues(
                          alpha: 0.18,
                        ),
                        foregroundColor: _detailNeutral,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodes(ContentShowBundle? bundle) {
    if (bundle == null) {
      return const SizedBox.shrink();
    }

    final episodes = [...bundle.episodes]
      ..sort((left, right) {
        final byNumber = left.episodeNumber.compareTo(right.episodeNumber);
        if (byNumber != 0) {
          return byNumber;
        }
        return left.publishedAt.compareTo(right.publishedAt);
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THƯ VIỆN TẬP',
            style: GoogleFonts.workSans(
              color: _detailPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tất cả tập',
            style: GoogleFonts.newsreader(
              color: _detailNeutral,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (episodes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _detailNeutral.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                'Show này đã có host và metadata đầy đủ, nhưng chưa có tập nào được phát hành.',
                style: GoogleFonts.workSans(
                  color: _detailNeutral.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            )
          else
            ...episodes.map((episode) {
              final isPlaying = _playingEpisodeId == episode.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: isPlaying ? null : () => _openEpisode(episode),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _detailNeutral.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: 84,
                              height: 84,
                              child: _DetailImage(
                                imageUrl: episode.coverImageUrl.isNotEmpty
                                    ? episode.coverImageUrl
                                    : bundle.show.coverImageUrl,
                                fallbackColor: _detailSurfaceStrong,
                                iconColor: _detailPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildChip(
                                  'Tập ${episode.episodeNumber}',
                                  backgroundColor: _detailSecondary.withValues(
                                    alpha: 0.2,
                                  ),
                                  foregroundColor: _detailNeutral,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  episode.title,
                                  style: GoogleFonts.newsreader(
                                    color: _detailNeutral,
                                    fontSize: 23,
                                    height: 0.98,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  episode.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.workSans(
                                    color: _detailNeutral.withValues(
                                      alpha: 0.72,
                                    ),
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${episode.formattedDuration} • ${episode.publishedAt.day}/${episode.publishedAt.month}/${episode.publishedAt.year}',
                                  style: GoogleFonts.workSans(
                                    color: _detailNeutral.withValues(
                                      alpha: 0.52,
                                    ),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? _detailSurfaceStrong
                                  : _detailPrimary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isPlaying
                                  ? Icons.hourglass_bottom_rounded
                                  : Icons.play_arrow_rounded,
                              color: isPlaying ? _detailNeutral : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildChip(
    String value, {
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: GoogleFonts.workSans(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _detailPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        value,
        style: GoogleFonts.workSans(
          color: _detailNeutral,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _humanizeError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Không thể tải dữ liệu show lúc này.';
  }

  String _initialFor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'P';
    }
    return trimmed.characters.first.toUpperCase();
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: _detailNeutral.withValues(alpha: 0.08)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: _detailNeutral, size: 18),
      ),
    );
  }
}

class _DetailImage extends StatelessWidget {
  const _DetailImage({
    required this.imageUrl,
    required this.fallbackColor,
    required this.iconColor,
  });

  final String imageUrl;
  final Color fallbackColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return DecoratedBox(
          decoration: BoxDecoration(color: fallbackColor),
          child: Center(
            child: Icon(
              Icons.podcasts_rounded,
              color: iconColor.withValues(alpha: 0.6),
              size: 32,
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _detailSecondary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.wifi_tethering_error_rounded,
                color: _detailPrimary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Không tải được show',
              style: GoogleFonts.newsreader(
                color: _detailNeutral,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.workSans(
                color: _detailNeutral.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _detailPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Thử lại',
                style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
