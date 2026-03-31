import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/utils/player_utils.dart';

const Color _librarySurface = Color(0xFFFFFEFC);
const Color _librarySurfaceStrong = Color(0xFFF2E6D9);
const Color _libraryPrimary = Color(0xFFBF5700);
const Color _libraryNeutral = Color(0xFF3E2723);
const Color _libraryMuted = Color(0xFF7E665F);

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = ['Tất cả', 'Podcast', 'Tập', 'Tải về'];

  @override
  Widget build(BuildContext context) {
    final allPodcasts = MockData.shows;
    final progress = MockData.currentUserProgress;
    final recentlyPlayed = progress
        .map((p) {
          final ep = MockData.getEpisodeById(p.episodeId);
          final pod = MockData.getShowById(p.showId);
          return {'episode': ep, 'show': pod, 'progress': p};
        })
        .where((m) => m['episode'] != null && m['show'] != null)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _librarySurface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _libraryNeutral.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thư viện nghe',
                style: GoogleFonts.newsreader(
                  color: _libraryNeutral,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Xem lại những gì bạn đã nghe và quay lại các show yêu thích theo bố cục sáng đồng bộ.',
                style: GoogleFonts.workSans(
                  color: _libraryMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isSelected = _selectedFilter == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: isSelected ? _libraryPrimary : _librarySurface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected
                          ? _libraryPrimary
                          : _libraryNeutral.withValues(alpha: 0.08),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _filters[index],
                    style: GoogleFonts.workSans(
                      color: isSelected ? Colors.white : _libraryNeutral,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Nghe gần đây',
          style: GoogleFonts.newsreader(
            color: _libraryNeutral,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 186,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recentlyPlayed.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final ep = recentlyPlayed[index]['episode'] as Episode;
              final pod = recentlyPlayed[index]['show'] as Show;
              return GestureDetector(
                onTap: () => openPlayerScreen(context, show: pod, episode: ep),
                child: Container(
                  width: 136,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _librarySurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _libraryNeutral.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          ep.images.isNotEmpty ? ep.images.first : pod.imageUrl,
                          width: 112,
                          height: 112,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ep.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.workSans(
                          color: _libraryNeutral,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Podcast của bạn',
          style: GoogleFonts.newsreader(
            color: _libraryNeutral,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...allPodcasts.map((show) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => openShowDetail(context, show),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _librarySurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _libraryNeutral.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        show.imageUrl,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            show.title,
                            style: GoogleFonts.workSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _libraryNeutral,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${show.episodes.length} tập khả dụng',
                            style: GoogleFonts.workSans(
                              fontSize: 12,
                              color: _libraryMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: _librarySurfaceStrong,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: _libraryPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
