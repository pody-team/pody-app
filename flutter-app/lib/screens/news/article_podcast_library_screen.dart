import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/data/article_scope.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/news/article_podcast_playback.dart';
import 'package:pody/screens/news/article_podcast_job_screen.dart';
import 'package:pody/utils/player_utils.dart';

const Color _libraryCanvas = Color(0xFFFFFBF6);
const Color _librarySurface = Color(0xFFFFFEFC);
const Color _libraryPrimary = Color(0xFFBF5700);
const Color _libraryNeutral = Color(0xFF3E2723);
const Color _libraryMuted = Color(0xFF7E665F);
const Color _libraryStrong = Color(0xFFF2E6D9);

class ArticlePodcastLibraryScreen extends StatefulWidget {
  const ArticlePodcastLibraryScreen({super.key});

  @override
  State<ArticlePodcastLibraryScreen> createState() =>
      _ArticlePodcastLibraryScreenState();
}

class _ArticlePodcastLibraryScreenState
    extends State<ArticlePodcastLibraryScreen> {
  List<ArticlePodcastJobSummary> _jobs = const <ArticlePodcastJobSummary>[];
  bool _isLoading = true;
  String? _errorMessage;
  String? _openingJobId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadJobs();
    });
  }

  Future<void> _loadJobs() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final jobs = await ArticleScope.of(context).fetchPodcastJobs();
      if (!mounted) {
        return;
      }
      setState(() {
        _jobs = jobs.where((job) => job.isCompleted).toList(growable: false);
        _isLoading = false;
      });
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
        _errorMessage = 'Khong tai duoc danh sach podcast bao luc nay.';
      });
    }
  }

  Future<void> _openJob(ArticlePodcastJobSummary job) async {
    if (_openingJobId != null) {
      return;
    }

    setState(() => _openingJobId = job.jobId);
    try {
      final detail = await ArticleScope.of(
        context,
      ).fetchPodcastJobDetail(job.jobId);
      if (!mounted) {
        return;
      }
      if (!detail.isCompleted || (detail.audioUrl?.isEmpty ?? true)) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ArticlePodcastJobScreen(
              jobId: job.jobId,
              initialArticles: const <NewsArticle>[],
            ),
          ),
        );
        return;
      }

      final playable = buildArticlePodcastPlayable(detail);
      openPlayerScreen(context, show: playable.$1, episode: playable.$2);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khong mo duoc podcast bao nay luc nay.')),
      );
    } finally {
      if (mounted) {
        setState(() => _openingJobId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _libraryCanvas,
      appBar: AppBar(
        backgroundColor: _libraryCanvas,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Podcast bao cua toi',
          style: GoogleFonts.newsreader(
            color: _libraryNeutral,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadJobs,
        color: _libraryPrimary,
        child: Builder(
          builder: (context) {
            if (_isLoading && _jobs.isEmpty) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            if (_errorMessage != null && _jobs.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                children: [
                  _LibraryStateCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'Chua tai duoc danh sach',
                    message: _errorMessage!,
                    actionLabel: 'Thu lai',
                    onPressed: _loadJobs,
                  ),
                ],
              );
            }

            if (_jobs.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                children: [
                  _LibraryStateCard(
                    icon: Icons.podcasts_outlined,
                    title: 'Chua co podcast bao nao',
                    message:
                        'Sau khi ban tao xong mot podcast tu bai bao, no se hien o day de mo lai bat cu luc nao.',
                    actionLabel: 'Lam moi',
                    onPressed: _loadJobs,
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF4E6), Color(0xFFF4E7D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _libraryPrimary.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _librarySurface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_jobs.length} podcast san sang',
                          style: GoogleFonts.workSans(
                            color: _libraryPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Nghe lai cac ban tin audio da tao',
                        style: GoogleFonts.newsreader(
                          color: _libraryNeutral,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          height: 1.04,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Day la danh sach cac podcast bai bao da hoan tat va co the mo lai ngay trong app.',
                        style: GoogleFonts.workSans(
                          color: _libraryMuted,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ..._jobs.map(
                  (job) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PodcastJobTile(
                      job: job,
                      isOpening: _openingJobId == job.jobId,
                      onTap: () => _openJob(job),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PodcastJobTile extends StatelessWidget {
  const _PodcastJobTile({
    required this.job,
    required this.isOpening,
    required this.onTap,
  });

  final ArticlePodcastJobSummary job;
  final bool isOpening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = job.title?.trim().isNotEmpty == true
        ? job.title!.trim()
        : 'Podcast bai bao';
    final updatedAt = job.updatedAt ?? job.createdAt;
    final subtitle = updatedAt == null
        ? 'Da san sang de phat'
        : 'Cap nhat luc ${_formatTimestamp(updatedAt)}';

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: isOpening ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _librarySurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _libraryNeutral.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _libraryStrong,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.graphic_eq_rounded,
                color: _libraryPrimary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.workSans(
                      color: _libraryNeutral,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.workSans(
                      color: _libraryMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            isOpening
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Icon(
                    Icons.play_circle_fill_rounded,
                    color: _libraryPrimary,
                    size: 32,
                  ),
          ],
        ),
      ),
    );
  }
}

class _LibraryStateCard extends StatelessWidget {
  const _LibraryStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _librarySurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _libraryNeutral.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _libraryStrong,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: _libraryPrimary, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              color: _libraryNeutral,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.workSans(
              color: _libraryMuted,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: _libraryPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              textStyle: GoogleFonts.workSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$hour:$minute $day/$month/${local.year}';
}
