import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/data/article_scope.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/news/article_podcast_playback.dart';
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
  State<ArticlePodcastJobScreen> createState() =>
      _ArticlePodcastJobScreenState();
}

class _ArticlePodcastJobScreenState extends State<ArticlePodcastJobScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollingTimer;
  bool _isLoading = true;
  String? _errorMessage;
  ArticlePodcastJobDetail? _detail;
  late final AnimationController _progressSpinController;

  @override
  void initState() {
    super.initState();
    _progressSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _progressSpinController.repeat();
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
    _progressSpinController.dispose();
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
      final detail = await ArticleScope.of(
        context,
      ).fetchPodcastJobDetail(widget.jobId);
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _isLoading = false;
        _errorMessage = null;
      });
      _syncAnimationForStatus(detail.status);
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
      _progressSpinController.stop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Khong tai duoc trang thai podcast luc nay.';
      });
      _progressSpinController.stop();
    }
  }

  void _openGeneratedAudio() {
    final detail = _detail;
    if (detail == null ||
        !detail.isCompleted ||
        (detail.audioUrl?.isEmpty ?? true)) {
      return;
    }
    final playable = buildArticlePodcastPlayable(detail);
    openPlayerScreen(context, show: playable.$1, episode: playable.$2);
  }

  void _syncAnimationForStatus(String? status) {
    final normalizedStatus = (status ?? '').trim().toLowerCase();
    final shouldSpin = normalizedStatus.isEmpty ||
        (normalizedStatus != 'completed' && normalizedStatus != 'failed');
    if (shouldSpin) {
      if (!_progressSpinController.isAnimating) {
        _progressSpinController.repeat();
      }
      return;
    }
    _progressSpinController.stop();
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
                        if ((detail?.researchSummary ?? '')
                            .trim()
                            .isNotEmpty) ...[
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
                        if ((detail?.podcastDescription ?? '')
                            .trim()
                            .isNotEmpty) ...[
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
                        if ((detail?.outline ?? const <String>[])
                            .isNotEmpty) ...[
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
    final progressValue = _statusProgressValue(status);
    final isTerminal = detail?.isTerminal == true;
    final hasFailed = status == 'failed';
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
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
              ),
              const SizedBox(width: 12),
              _buildStatusOrb(
                isTerminal: isTerminal,
                hasFailed: hasFailed,
              ),
            ],
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
          _buildProgressTimeline(status, progressValue),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: detail?.isCompleted == true
                      ? _openGeneratedAudio
                      : null,
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

  Widget _buildStatusOrb({
    required bool isTerminal,
    required bool hasFailed,
  }) {
    final orbColor = hasFailed
        ? Colors.redAccent
        : isTerminal
        ? Colors.green
        : _podcastPrimary;
    final icon = hasFailed
        ? Icons.close_rounded
        : isTerminal
        ? Icons.check_rounded
        : Icons.autorenew_rounded;

    final orb = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _podcastSurface,
        boxShadow: [
          BoxShadow(
            color: orbColor.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: orbColor.withValues(alpha: 0.22),
          ),
          color: orbColor.withValues(alpha: 0.10),
        ),
        child: Icon(icon, color: orbColor, size: 24),
      ),
    );

    if (isTerminal) {
      return orb;
    }

    return RotationTransition(
      turns: _progressSpinController,
      child: orb,
    );
  }

  Widget _buildProgressTimeline(String status, double progressValue) {
    final activeIndex = _statusStepIndex(status);
    final steps = const <String>[
      'Cho xu ly',
      'Research',
      'Draft',
      'Audio',
      'Hoan tat',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progressValue,
            minHeight: 10,
            backgroundColor: _podcastSurface,
            valueColor: const AlwaysStoppedAnimation<Color>(_podcastPrimary),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index <= activeIndex
                            ? _podcastPrimary
                            : _podcastPrimary.withValues(alpha: 0.18),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[index],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.workSans(
                        color: index <= activeIndex
                            ? _podcastNeutral
                            : _podcastMuted,
                        fontSize: 11,
                        fontWeight: index <= activeIndex
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < steps.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
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

  int _statusStepIndex(String status) {
    switch (status) {
      case 'researching':
        return 1;
      case 'drafting':
      case 'validating':
        return 2;
      case 'synthesizing':
      case 'uploading':
        return 3;
      case 'completed':
        return 4;
      case 'failed':
        return 3;
      default:
        return 0;
    }
  }

  double _statusProgressValue(String status) {
    switch (status) {
      case 'researching':
        return 0.24;
      case 'drafting':
        return 0.46;
      case 'validating':
        return 0.58;
      case 'synthesizing':
        return 0.76;
      case 'uploading':
        return 0.9;
      case 'completed':
        return 1;
      case 'failed':
        return 0.76;
      default:
        return 0.08;
    }
  }
}
