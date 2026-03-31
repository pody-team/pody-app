import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/utils/player_utils.dart';

const Color _searchCanvas = Color(0xFFFFFBF6);
const Color _searchSurface = Color(0xFFFFFEFC);
const Color _searchSurfaceStrong = Color(0xFFF2E6D9);
const Color _searchPrimary = Color(0xFFBF5700);
const Color _searchNeutral = Color(0xFF3E2723);
const Color _searchMuted = Color(0xFF7E665F);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  int _selectedTab = 0;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _recentSearches = [
    'Technology',
    'True Crime',
    'Design Systems',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shows = MockData.shows
        .where(
          (show) =>
              _searchController.text.trim().isEmpty ||
              show.title.toLowerCase().contains(
                _searchController.text.trim().toLowerCase(),
              ) ||
              show.category.toLowerCase().contains(
                _searchController.text.trim().toLowerCase(),
              ),
        )
        .toList();
    final episodes = shows.expand((show) => show.episodes).toList();

    return Scaffold(
      backgroundColor: _searchCanvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Text(
              'Tìm kiếm',
              style: GoogleFonts.newsreader(
                color: _searchNeutral,
                fontSize: 34,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Khám phá show, tập và host theo cùng hệ danh mục của Pody.',
              style: GoogleFonts.workSans(
                color: _searchMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: _searchSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _searchNeutral.withValues(alpha: 0.08),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.workSans(
                  color: _searchNeutral,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _searchSurface,
                  hintText: 'Tìm show, tập hoặc host...',
                  hintStyle: GoogleFonts.workSans(color: _searchMuted),
                  prefixIcon: const Icon(Icons.search, color: _searchPrimary),
                  suffixIcon: _searchController.text.isEmpty
                      ? const Icon(Icons.mic_none_rounded, color: _searchMuted)
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close, color: _searchMuted),
                        ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Segment(
                    label: 'Show',
                    selected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Segment(
                    label: 'Tập',
                    selected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_searchController.text.isEmpty) ...[
              Text(
                'Tìm gần đây',
                style: GoogleFonts.newsreader(
                  color: _searchNeutral,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentSearches
                    .map(
                      (term) => ActionChip(
                        label: Text(term),
                        onPressed: () {
                          _searchController.text = term;
                          setState(() {});
                        },
                        backgroundColor: _searchSurfaceStrong,
                        labelStyle: GoogleFonts.workSans(
                          color: _searchNeutral,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],
            ...(_selectedTab == 0
                ? shows.map((show) => _ShowResultCard(show: show))
                : episodes.map(
                    (episode) => _EpisodeResultCard(episode: episode),
                  )),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _searchPrimary : _searchSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? _searchPrimary
                : _searchNeutral.withValues(alpha: 0.08),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.workSans(
            color: selected ? Colors.white : _searchNeutral,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ShowResultCard extends StatelessWidget {
  const _ShowResultCard({required this.show});

  final dynamic show;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => openShowDetail(context, show),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _searchSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _searchNeutral.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  show.imageUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.title,
                      style: GoogleFonts.workSans(
                        color: _searchNeutral,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Host: ${show.hostsLabel}',
                      style: GoogleFonts.workSans(
                        color: _searchMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _searchSurfaceStrong,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        show.category,
                        style: GoogleFonts.workSans(
                          color: _searchPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeResultCard extends StatelessWidget {
  const _EpisodeResultCard({required this.episode});

  final dynamic episode;

  @override
  Widget build(BuildContext context) {
    final show = MockData.shows.firstWhere(
      (candidate) => candidate.id == episode.showId,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => openPlayerScreen(context, show: show, episode: episode),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _searchSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _searchNeutral.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  episode.images.isNotEmpty
                      ? episode.images.first
                      : show.imageUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.workSans(
                        color: _searchNeutral,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      show.title,
                      style: GoogleFonts.workSans(
                        color: _searchMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill_rounded, color: _searchPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
