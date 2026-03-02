import 'package:flutter/material.dart';
import 'package:pody/theme/app_colors.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/podcast/player_screen.dart';
import 'package:pody/screens/podcast/podcast_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = ['All', 'Podcasts', 'Episodes', 'Downloads'];

  @override
  Widget build(BuildContext context) {
    // Pull data from MockData
    final allPodcasts = MockData.podcasts;
    final savedEpisodes = MockData.savedEpisodes;
    final progress = MockData.currentUserProgress;

    // "Recently Played" = episodes with listening progress
    final recentlyPlayed = progress.map((p) {
      final ep = MockData.getEpisodeById(p.episodeId);
      final pod = MockData.getPodcastById(p.podcastId);
      return {'episode': ep, 'podcast': pod, 'progress': p};
    }).where((m) => m['episode'] != null && m['podcast'] != null).toList();

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 100),
      children: [
        // Filter Chips
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _filters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isSelected = _selectedFilter == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : kBgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(color: Colors.white12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _filters[index],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 28),

        // Recently Played
        _buildSectionTitle('Recently Played'),
        const SizedBox(height: 12),
        SizedBox(
          height: 165,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: recentlyPlayed.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final ep = recentlyPlayed[index]['episode'] as Episode;
              final pod = recentlyPlayed[index]['podcast'] as Podcast;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerScreen(podcast: pod, episode: ep),
                    ),
                  );
                },
                child: SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          ep.images.isNotEmpty ? ep.images.first : pod.imageUrl,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ep.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 28),

        // Your Podcasts
        _buildSectionTitle('Your Podcasts'),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: allPodcasts.map((podcast) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PodcastDetailScreen(podcast: podcast),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kBgCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          podcast.imageUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              podcast.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${podcast.episodes.length} episodes available',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Saved Episodes
        _buildSectionTitle('Saved Episodes'),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: savedEpisodes.asMap().entries.map((entry) {
              final index = entry.key;
              final ep = entry.value;
              final pod = MockData.getPodcastById(ep.podcastId);
              final isLast = index == savedEpisodes.length - 1;
              return GestureDetector(
                onTap: () {
                  if (pod != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(podcast: pod, episode: ep),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : const Border(
                            bottom: BorderSide(color: Colors.white10),
                          ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ep.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${pod?.title ?? ''} • ${ep.formattedDuration}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.download_done,
                        color: Colors.white38,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white54,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
