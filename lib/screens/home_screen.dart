import 'package:flutter/material.dart';
import 'package:pody/screens/player_screen.dart';
import 'package:pody/screens/search_screen.dart';
import 'package:pody/screens/podcast_detail_screen.dart';
import 'package:pody/theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<Map<String, dynamic>> _mockPodcasts = const [
    {
      'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuATYB8bGdInAe7ldY3ArRuwbXNgOSgCv93cf_umwxaersMiO-6idUlT4JXFpwUSTBWYaUxs3W4foHJSlIi116P_v-NXG1WPJ_bG3LJmYWFg4oQQe6aZkwYco6UVqt5O8iR2wfmhsQjOt59_QQnvE0ghwkHNXC0FjBst-UPCqL89lfv7T1IDKzYBZRgz7a0j3sSYJxx9nO8pU4XRcinnkKjwcYGD03mXKcfS3FbB6EBA_e0mvrG959LmvX520iuBE7NzNr-AbyPChHk',
      'title': 'Future Minds',
      'host': 'Tech & Innovation',
      'category': 'Công nghệ',
      'episodes': [
        'MVC thời hiện đại: Cũ nhưng không kỹ',
        'Nhìn nhanh về MVVM và MVP',
        'Clean Architecture thực chiến',
      ],
      'subscriberCount': '12.5k',
      'totalEpisodes': '42 tập',
    },
    {
      'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuDRyNqWoebcCRyWA9Z01YumR31TnNjxnIwbUUAIbiubmjZz8n4AqMoO_sGjMeNG9Nb5gzGPgVIVWGpwrvBm6AKbhhLVVjvTi1jDJgwDe29EvYIS5fTqEDuGmIu8PVbWTTNfzZp6w09dErSJe5hnQS-DRuyYAfHBMd9Pk7pzFEQ-x0q_Zo_VBGtA1tYEnGVIAM1dDf56POWot-PMEFogFBBMzZrd10Iv26tCL3goroNsN7APhD9BZ1kHtKP7X0v1Am6ntCf_BwLHIY0',
      'title': 'True Crime Daily',
      'host': 'Crime & Mystery',
      'category': 'Điều tra',
      'episodes': [
        '"The evidence was right there."',
        'Vụ án chưa có lời giải từ 1995.',
        'Kết quả phá án bất ngờ từ DNA.',
      ],
      'subscriberCount': '8.2k',
      'totalEpisodes': '31 tập',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 12, bottom: 100),
                children: [
                  // Filters + Search in one row
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(left: 16),
                              children: [
                                _buildFilterChip('Tất cả', isActive: true),
                                _buildFilterChip('Công nghệ'),
                                _buildFilterChip('Câu chuyện'),
                                _buildFilterChip('Ngắn < 15p'),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const SearchScreen()));
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.search, color: Colors.white, size: 17),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Podcast Cards
                  ..._mockPodcasts.map(
                    (data) => Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      child: _buildPodcastCard(context, data),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFilterChip(String label, {bool isActive = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? kTikRed : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.white60,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPodcastCard(BuildContext context, Map<String, dynamic> data) {
    final episodes = data['episodes'] as List;
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PodcastDetailScreen(data: data)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover Image with Gradient Overlay ──
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(data['imageUrl'], fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.2, 1.0],
                        colors: [Colors.transparent, Colors.black.withOpacity(0.95)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data['category'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    data['category'],
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white70,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                data['title'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                data['host'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: kTikRed,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'Theo dõi',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Episode List ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                children: [
                  ...List.generate(episodes.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.3),
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              episodes[index],
                              style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.play_circle_outline_rounded,
                              color: kTikTeal, size: 18),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                  Divider(color: Colors.white.withOpacity(0.06), height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.people_outline, color: Colors.white38, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        '${data['subscriberCount']} theo d\u00f5i',
                        style: const TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                      if (data['totalEpisodes'] != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.queue_music_rounded, color: Colors.white38, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          data['totalEpisodes'],
                          style: const TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        'Xem tất cả →',
                        style: const TextStyle(
                          fontSize: 12,
                          color: kTikTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
