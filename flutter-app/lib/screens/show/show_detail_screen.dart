import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/utils/player_utils.dart';

const Color _legacyDetailCanvas = Color(0xFFFFFBF6);
const Color _legacyDetailSurface = Color(0xFFFFFEFC);
const Color _legacyDetailSurfaceStrong = Color(0xFFF2E6D9);
const Color _legacyDetailPrimary = Color(0xFFBF5700);
const Color _legacyDetailNeutral = Color(0xFF3E2723);
const Color _legacyDetailMuted = Color(0xFF7E665F);

class ShowDetailScreen extends StatelessWidget {
  const ShowDetailScreen({super.key, required this.show});

  final Show show;

  @override
  Widget build(BuildContext context) {
    final author = MockData.getUserById(show.authorId);

    return Scaffold(
      backgroundColor: _legacyDetailCanvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: _legacyDetailCanvas,
            surfaceTintColor: _legacyDetailCanvas,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: _legacyDetailNeutral,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _legacyDetailSurface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _legacyDetailNeutral.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.network(
                        show.imageUrl,
                        width: 198,
                        height: 198,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      show.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.newsreader(
                        color: _legacyDetailNeutral,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Host: ${show.hostsLabel}',
                      style: GoogleFonts.workSans(
                        color: _legacyDetailMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (author != null) ...[
                      const SizedBox(height: 14),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => openUserDetail(context, author),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _legacyDetailSurfaceStrong,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  author.avatarUrl,
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                author.name,
                                style: GoogleFonts.workSans(
                                  color: _legacyDetailNeutral,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _LegacyTag(show.category),
                        const _LegacyTag('Hàng tuần'),
                        _LegacyTag('${show.totalEpisodeCount} tập'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Khám phá những góc nhìn mới mẻ về công nghệ, tương lai và con người qua một format âm thanh dễ nghe và rõ ràng hơn.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.workSans(
                        color: _legacyDetailMuted,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: show.episodes.isEmpty
                                ? null
                                : () => openPlayerScreen(
                                    context,
                                    show: show,
                                    episode: show.episodes.first,
                                  ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Nghe ngay'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _legacyDetailPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              textStyle: GoogleFonts.workSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _legacyDetailNeutral,
                            side: BorderSide(
                              color: _legacyDetailNeutral.withValues(
                                alpha: 0.12,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          child: const Icon(Icons.favorite_border_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'Các tập',
                style: GoogleFonts.newsreader(
                  color: _legacyDetailNeutral,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final episode = show.episodes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () =>
                        openPlayerScreen(context, show: show, episode: episode),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _legacyDetailSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _legacyDetailNeutral.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _legacyDetailSurfaceStrong,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.workSans(
                                color: _legacyDetailPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  episode.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.workSans(
                                    color: _legacyDetailNeutral,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${episode.duration.inMinutes} phút',
                                  style: GoogleFonts.workSans(
                                    color: _legacyDetailMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            color: _legacyDetailPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }, childCount: show.episodes.length),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyTag extends StatelessWidget {
  const _LegacyTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _legacyDetailSurfaceStrong,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.workSans(
          color: _legacyDetailNeutral,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
