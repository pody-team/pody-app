import 'package:flutter/material.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/features/content/presentation/content_scope.dart';
import 'package:pody/models/models.dart';
import 'package:pody/utils/player_utils.dart';

class ContentShowDetailScreen extends StatefulWidget {
  const ContentShowDetailScreen({
    required this.showId,
    this.initialSummary,
    super.key,
  });

  final String showId;
  final ContentShowSummary? initialSummary;

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
      final bundle = await repository.getShowBundle(widget.showId);
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
      final detail = await repository.getEpisodeDetail(episode.id);
      if (!mounted) {
        return;
      }

      final legacyShow = _mapShowToLegacy(bundle.show, bundle.episodes);
      final legacyEpisode = _mapEpisodeToLegacy(detail);

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
      backgroundColor: const Color(0xFF0F0E13),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: const Color(0xFF0F0E13),
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                show?.title ?? summary?.title ?? 'Chi tiet show',
                style: const TextStyle(color: Colors.white),
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
                child: _ErrorState(message: _errorMessage!, onRetry: _loadShow),
              )
            else
              SliverList.list(
                children: [
                  _buildHero(show, summary),
                  _buildDescription(show),
                  _buildEpisodes(bundle),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(ContentShowDetail? show, ContentShowSummary? summary) {
    final title = show?.title ?? summary?.title ?? 'Dang tai';
    final coverImageUrl = show?.coverImageUrl ?? summary?.coverImageUrl ?? '';
    final aiHost = show?.aiHost ?? summary?.aiHost;
    final categoryChips =
        show?.categories ??
        <String>[if (summary != null) summary.primaryCategory];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        children: [
          Container(
            width: 192,
            height: 192,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(coverImageUrl, fit: BoxFit.cover),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          if (aiHost != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(aiHost.avatarUrl),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'AI host: ${aiHost.displayName}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          if (show != null) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ...categoryChips
                    .where((item) => item.isNotEmpty)
                    .map(_buildChip),
                _buildStatChip('${show.formattedListenCount} luot nghe'),
                _buildStatChip('${show.formattedSubscriberCount} theo doi'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: NetworkImage(show.owner.avatarUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          show.owner.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${show.totalEpisodeCount} tap • ${show.languageCode.toUpperCase()} • ${show.contentType}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescription(ContentShowDetail? show) {
    if (show == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ve show',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              show.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            if (show.tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: show.tags.map((tag) => _buildChip(tag)).toList(),
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

    final episodes = bundle.episodes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tat ca episodes',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          if (episodes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Text(
                'Show nay da co AI host va metadata day du, nhung chua co episode nao duoc phat hanh.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.66),
                  height: 1.6,
                ),
              ),
            )
          else
            ...episodes.map((episode) {
              final isPlaying = _playingEpisodeId == episode.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: isPlaying
                      ? null
                      : () {
                          _openEpisode(episode);
                        },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            episode.coverImageUrl.isNotEmpty
                                ? episode.coverImageUrl
                                : bundle.show.coverImageUrl,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tap ${episode.episodeNumber}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                episode.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                episode.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.58),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${episode.formattedDuration} • ${episode.publishedAt.day}/${episode.publishedAt.month}/${episode.publishedAt.year}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          isPlaying
                              ? Icons.hourglass_bottom_rounded
                              : Icons.play_circle_fill_rounded,
                          color: Colors.white.withValues(alpha: 0.86),
                          size: 30,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
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
    return 'Khong the tai du lieu show luc nay.';
  }

  Show _mapShowToLegacy(
    ContentShowDetail show,
    List<ContentEpisodeSummary> episodes,
  ) {
    return Show(
      id: show.id,
      title: show.title,
      hosts: [
        Host(
          id: show.aiHost.id,
          name: show.aiHost.displayName,
          avatarUrl: show.aiHost.avatarUrl,
          voiceId: show.aiHost.voiceProfileId,
          role: show.aiHost.role,
        ),
      ],
      category: show.primaryCategory,
      imageUrl: show.coverImageUrl,
      episodes: episodes.map(_mapEpisodeSummaryToLegacy).toList(),
      subscriberCount: show.formattedSubscriberCount,
      totalEpisodeCount: show.totalEpisodeCount,
      authorId: show.owner.id,
    );
  }

  Episode _mapEpisodeSummaryToLegacy(ContentEpisodeSummary episode) {
    return Episode(
      id: episode.id,
      showId: episode.showId,
      title: episode.title,
      description: episode.description,
      duration: Duration(seconds: episode.durationSeconds),
      images: [episode.coverImageUrl],
    );
  }

  Episode _mapEpisodeToLegacy(ContentEpisodeDetail episode) {
    return Episode(
      id: episode.id,
      showId: episode.showId,
      title: episode.title,
      description: episode.description,
      duration: Duration(seconds: episode.durationSeconds),
      images: [episode.coverImageUrl],
      tags: episode.tags,
      likes: episode.likeCount,
      comments: episode.commentCount,
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
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.podcasts_rounded,
              size: 46,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                onRetry();
              },
              child: const Text('Thu lai'),
            ),
          ],
        ),
      ),
    );
  }
}
