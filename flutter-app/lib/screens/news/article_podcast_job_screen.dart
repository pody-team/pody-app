import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/data/article_scope.dart';
import 'package:pody/models/models.dart';
import 'package:pody/utils/player_utils.dart';

const Color _podcastCanvas = Color(0xFFFFFBF6);
const Color _podcastSurface = Color(0xFFFFFEFC);
const Color _podcastPrimary = Color(0xFFBF5700);
const Color _podcastNeutral = Color(0xFF3E2723);
const Color _podcastMuted = Color(0xFF7E665F);
const Color _podcastStrong = Color(0xFFF2E6D9);

class ArticlePodcastJobScreen extends StatefulWidget {
  const ArticlePodcastJobScreen({
    required this.jobId,
    required this.initialArticles,
    super.key,
  });

  final String jobId;
  final List<NewsArticle> initialArticles;

  @override
  State<ArticlePodcastJobScreen> createState() => _ArticlePodcastJobScreenState();
}

class _ArticlePodcastJobScreenState extends State<ArticlePodcastJobScreen> {
  Timer? _pollingTimer;
  bool _isLoading = true;
  String? _errorMessage;
  ArticlePodcastJobDetail? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_detail?.isTerminal == true) {
        _pollingTimer?.cancel();
        return;
      }
      _loadDetail(showLoader: false);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDetail({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final detail = await ArticleScope.of(context).fetchPodcastJobDetail(
        widget.jobId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _isLoading = false;
        _errorMessage = null;
      });
      if (detail.isTerminal) {
        _pollingTimer?.cancel();
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Khong tai duoc trang thai podcast luc nay.';
      });
    }
  }

  void _openGeneratedAudio() {
    final detail = _detail;
    if (detail == null || !detail.isCompleted || (detail.audioUrl?.isEmpty ?? true)) {
      return;
    }
    final playable = _buildPlayableContent(detail);
    openPlayerScreen(
      context,
      show: playable.$1,
      episode: playable.$2,
    );
  }

  (Show, Episode) _buildPlayableContent(ArticlePodcastJobDetail detail) {
    final host = Host(
      id: 'article-podcast-host',
      name: 'Pody News AI',
      avatarUrl: 'https://picsum.photos/seed/article-podcast-host/200/200',
      voiceId: 'kore',
    );
    final episode = Episode(
      id: detail.jobId,
      showId: 'article-podcast-show-${detail.jobId}',
      episodeNumber: 1,
      title: detail.podcastTitle?.trim().isNotEmpty == true
          ? detail.podcastTitle!.trim()
          : 'Podcast bai bao',
      description:
          detail.podcastDescription?.trim().isNotEmpty == true
          ? detail.podcastDescription!.trim()
          : 'Ban audio tong hop tu cac bai bao da chon.',
      duration: Duration(seconds: detail.durationSeconds ?? 60),
      images: const ['https://picsum.photos/seed/article-podcast-cover/800/800'],
      audioUrl: detail.audioUrl,
      bubbles: [
        if ((detail.scriptText ?? '').trim().isNotEmpty)
          ChatBubble(
            speakerId: host.id,
            speaker: host.name,
            text: detail.scriptText!.trim(),
            isRight: false,
          ),
      ],
    );
    final show = Show(
      id: 'article-podcast-show-${detail.jobId}',
      title: 'Article Podcast',
      hosts: [host],
      category: 'News',
      imageUrl: 'https://picsum.photos/seed/article-podcast-cover/800/800',
      episodes: [episode],
      subscriberCount: '0',
      totalEpisodeCount: 1,
      authorId: 'article-service',
    );
    return (show, episode);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final selectedArticles = detail?.selectedArticles.isNotEmpty == true
        ? detail!.selectedArticles
        : widget.initialArticles
              .map(
                (article) => ArticlePodcastSelectedArticle(
                  articleId: article.id,
                  title: article.title,
                  summary: article.description,
                ),
              )
              .toList();

    return Scaffold(
      backgroundColor: _podcastCanvas,
      appBar: AppBar(
        backgroundColor: _podcastCanvas,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Podcast bai bao',
          style: GoogleFonts.newsreader(
            color: _podcastNeutral,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        color: _podcastPrimary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _buildHero(detail),
            const SizedBox(height: 18),
            _buildSection(
              title: 'Bai da chon',
              child: Column(
                children: [
                  for (final article in selectedArticles)
                    _buildArticleTile(article),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildSection(
              title: 'Noi dung tong hop',
              child: _isLoading && detail == null
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : _errorMessage != null
                  ? Text(
                      _errorMessage!,
                      style: GoogleFonts.workSans(color: Colors.redAccent),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((detail?.researchSummary ?? '').trim().isNotEmpty) ...[
                          _buildLabel('Research summary'),
                          Text(
                            detail!.researchSummary!,
                            style: GoogleFonts.workSans(
                              color: _podcastMuted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if ((detail?.podcastDescription ?? '').trim().isNotEmpty) ...[
                          _buildLabel('Mo ta'),
                          Text(
                            detail!.podcastDescription!,
                            style: GoogleFonts.workSans(
                              color: _podcastMuted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if ((detail?.outline ?? const <String>[]).isNotEmpty) ...[
                          _buildLabel('Outline'),
                          for (final item in detail!.outline)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '• $item',
                                style: GoogleFonts.workSans(
                                  color: _podcastNeutral,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                        if ((detail?.scriptText ?? '').trim().isNotEmpty) ...[
                          _buildLabel('Script'),
                          Text(
                            detail!.scriptText!,
                            style: GoogleFonts.workSans(
                              color: _podcastNeutral,
                              height: 1.55,
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

  Widget _buildHero(ArticlePodcastJobDetail? detail) {
    final status = detail?.status ?? 'queued';
    final statusLabel = _statusLabel(status);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4E6), Color(0xFFF4E7D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _podcastPrimary.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _podcastSurface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.workSans(
                color: _podcastPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            detail?.podcastTitle?.trim().isNotEmpty == true
                ? detail!.podcastTitle!
                : 'Dang tao podcast bai bao',
            style: GoogleFonts.newsreader(
              color: _podcastNeutral,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            detail?.isCompleted == true
                ? 'Podcast da san sang. Ban co the mo player de nghe ngay trong app.'
                : detail?.error?.trim().isNotEmpty == true
                ? detail!.error!
                : 'He thong dang tong hop noi dung, viet script va sinh audio tu cac bai ban da chon.',
            style: GoogleFonts.workSans(
              color: _podcastMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: detail?.isCompleted == true ? _openGeneratedAudio : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _podcastPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: GoogleFonts.workSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  child: Text(
                    detail?.isCompleted == true ? 'Mo player' : 'Dang xu ly...',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: _loadDetail,
                style: IconButton.styleFrom(
                  backgroundColor: _podcastSurface,
                  foregroundColor: _podcastPrimary,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _podcastSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _podcastNeutral.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.newsreader(
              color: _podcastNeutral,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildArticleTile(ArticlePodcastSelectedArticle article) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _podcastStrong,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.title,
            style: GoogleFonts.workSans(
              color: _podcastNeutral,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if ((article.summary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              article.summary!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.workSans(
                color: _podcastMuted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.workSans(
          color: _podcastPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'researching':
        return 'Dang research';
      case 'drafting':
        return 'Dang viet noi dung';
      case 'validating':
        return 'Dang kiem tra script';
      case 'synthesizing':
        return 'Dang sinh audio';
      case 'uploading':
        return 'Dang upload';
      case 'completed':
        return 'Da hoan tat';
      case 'failed':
        return 'That bai';
      default:
        return 'Dang xep hang';
    }
  }
}
