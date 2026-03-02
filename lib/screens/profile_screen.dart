import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'podcast_detail_screen.dart';
import 'package:pody/theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Mock: Saved Episodes
  static const _savedEpisodes = [
    {
      'title': 'MVC thời hiện đại: Cũ nhưng không kỹ',
      'channel': 'Future Minds',
      'duration': '32 phút',
      'imageUrl':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuATYB8bGdInAe7ldY3ArRuwbXNgOSgCv93cf_umwxaersMiO-6idUlT4JXFpwUSTBWYaUxs3W4foHJSlIi116P_v-NXG1WPJ_bG3LJmYWFg4oQQe6aZkwYco6UVqt5O8iR2wfmhsQjOt59_QQnvE0ghwkHNXC0FjBst-UPCqL89lfv7T1IDKzYBZRgz7a0j3sSYJxx9nO8pU4XRcinnkKjwcYGD03mXKcfS3FbB6EBA_e0mvrG959LmvX520iuBE7NzNr-AbyPChHk',
    },
    {
      'title': '"The evidence was right there."',
      'channel': 'True Crime Daily',
      'duration': '45 phút',
      'imageUrl':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDRyNqWoebcCRyWA9Z01YumR31TnNjxnIwbUUAIbiubmjZz8n4AqMoO_sGjMeNG9Nb5gzGPgVIVWGpwrvBm6AKbhhLVVjvTi1jDJgwDe29EvYIS5fTqEDuGmIu8PVbWTTNfzZp6w09dErSJe5hnQS-DRuyYAfHBMd9Pk7pzFEQ-x0q_Zo_VBGtA1tYEnGVIAM1dDf56POWot-PMEFogFBBMzZrd10Iv26tCL3goroNsN7APhD9BZ1kHtKP7X0v1Am6ntCf_BwLHIY0',
    },
  ];

  // Mock: Following channels
  static const _following = [
    {
      'name': 'Future Minds',
      'category': 'Công nghệ',
      'imageUrl':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuATYB8bGdInAe7ldY3ArRuwbXNgOSgCv93cf_umwxaersMiO-6idUlT4JXFpwUSTBWYaUxs3W4foHJSlIi116P_v-NXG1WPJ_bG3LJmYWFg4oQQe6aZkwYco6UVqt5O8iR2wfmhsQjOt59_QQnvE0ghwkHNXC0FjBst-UPCqL89lfv7T1IDKzYBZRgz7a0j3sSYJxx9nO8pU4XRcinnkKjwcYGD03mXKcfS3FbB6EBA_e0mvrG959LmvX520iuBE7NzNr-AbyPChHk',
    },
    {
      'name': 'True Crime Daily',
      'category': 'Điều tra',
      'imageUrl':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDRyNqWoebcCRyWA9Z01YumR31TnNjxnIwbUUAIbiubmjZz8n4AqMoO_sGjMeNG9Nb5gzGPgVIVWGpwrvBm6AKbhhLVVjvTi1jDJgwDe29EvYIS5fTqEDuGmIu8PVbWTTNfzZp6w09dErSJe5hnQS-DRuyYAfHBMd9Pk7pzFEQ-x0q_Zo_VBGtA1tYEnGVIAM1dDf56POWot-PMEFogFBBMzZrd10Iv26tCL3goroNsN7APhD9BZ1kHtKP7X0v1Am6ntCf_BwLHIY0',
    },
    {
      'name': 'Mindful Hours',
      'category': 'Sức khỏe',
      'imageUrl':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBXxaIrUBG6uaxLRdgFLmXZRZOXa-4kEx5w4uuChjtHFq1nwsvjdfcRGefYdKgFNn4kVvW_v8kkD8uZ0SOAJ5JX8Uyp7KCEBpKWL-Ps-4lFOpviwCcZCXVxvYD35Ur2DJttpijqFr9_YK4E-bF4ApxeHY5ziXZZ0cR0BA3zR7CQq-V996pVWsqRrcxH44_lcySHGplz8KweWfgzOB0FHaB2CEFKh7YuFjAYHYVlQey6yQDhofs03-SnFBCpOCwH5APs1RA1y6vCmWsV',
    },
  ];

  // Mock: My Creations
  static const _creations = [
    {
      'title': 'Tech Trends 2024',
      'subtitle': '24 Episodes',
      'badge': 'Published',
      'isPublished': true,
      'imageUrl':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBXxaIrUBG6uaxLRdgFLmXZRZOXa-4kEx5w4uuChjtHFq1nwsvjdfcRGefYdKgFNn4kVvW_v8kkD8uZ0SOAJ5JX8Uyp7KCEBpKWL-Ps-4lFOpviwCcZCXVxvYD35Ur2DJttpijqFr9_YK4E-bF4ApxeHY5ziXZZ0cR0BA3zR7CQq-V996pVWsqRrcxH44_lcySHGplz8KweWfgzOB0FHaB2CEFKh7YuFjAYHYVlQey6yQDhofs03-SnFBCpOCwH5APs1RA1y6vCmWsV',
    },
    {
      'title': 'UI Design Systems',
      'subtitle': '8 Episodes',
      'badge': 'Draft',
      'isPublished': false,
      'imageUrl':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDB3RvJGL4ymSXKqgcf2lNqSv3cq179HXKWiZiCohETt28E1m9Z_7KC0cDZEUC5YV8wuMr8CPuagHWk9zKJLlXHPuyW0S96RCC2KUilP7rJn23yYsEjIX8YYefxyUh8M47ur7U6tZeXwMOWj9vWOyg46sZN5Xga8oRbi4IVwn1ba-B26NDOetx7_fnFLS9Om9LMhztFUCXD-72pMA6oZoityrwcYDRPabxnz_bQRT8ahfmK_V7SCwwaWgO9g_EKfyIVU4jzMkAtxFA_',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(child: _buildHeader(context)),
            ],
            body: Column(
              children: [
                // Inner TabBar
                Container(
                  color: Colors.black,
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorColor: kTikRed,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: kTikRed,
                    unselectedLabelColor: Colors.white38,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    tabs: const [
                      Tab(text: 'Đã lưu'),
                      Tab(text: 'Theo dõi'),
                      Tab(text: 'Của tôi'),
                    ],
                  ),
                ),
                const Expanded(
                  child: TabBarView(
                    children: [
                      _SavedTab(),
                      _FollowingTab(),
                      _MyCreationsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        children: [
          // Top bar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Avatar
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(38),
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuAWGX1z6hXmkcfBIlhDnk0zE9cv8lX5A5B_hsXdZwH57h3bdtokrT2CGW01UyaWneHx-8azq8ciqAjJQe3nJ7y5tREangqFs1BmRkWxfA98Mt0qCf5PuiB9U1DGLRFd9qOwV25TMb1uyyjoWi6gXf10TJRWnKursAmQTO0bgJ8Vqu9aPD_3OlBzSyKZSuntBKn6nEek-FUektilhtlyXBb3aUAj9Y3Zt1y_xgR7IvsTaWFf4UILkhoKo_6OpaEJJYqFpgedWemeUfoo',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Minh Nguyen',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 2),
          const Text('@minhdev',
              style: TextStyle(fontSize: 13, color: Colors.white38)),
          const SizedBox(height: 16),
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statChip('142h', 'Đã nghe'),
              _divider(),
              _statChip('12', 'Podcast'),
              _divider(),
              _statChip('186', 'Theo dõi'),
            ],
          ),
          const SizedBox(height: 16),
          // Edit Profile Button
          GestureDetector(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text('Chỉnh sửa hồ sơ',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  static Widget _statChip(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white38, letterSpacing: 1)),
      ],
    );
  }

  static Widget _divider() {
    return Container(
      width: 1, height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white12,
    );
  }
}

// ─── Tab 1: Đã Lưu ───────────────────────────────────────────────────────────
class _SavedTab extends StatelessWidget {
  const _SavedTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Continue Listening banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  const Text('Nghe tiếp',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white54,
                          letterSpacing: 0.5)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuATYB8bGdInAe7ldY3ArRuwbXNgOSgCv93cf_umwxaersMiO-6idUlT4JXFpwUSTBWYaUxs3W4foHJSlIi116P_v-NXG1WPJ_bG3LJmYWFg4oQQe6aZkwYco6UVqt5O8iR2wfmhsQjOt59_QQnvE0ghwkHNXC0FjBst-UPCqL89lfv7T1IDKzYBZRgz7a0j3sSYJxx9nO8pU4XRcinnkKjwcYGD03mXKcfS3FbB6EBA_e0mvrG959LmvX520iuBE7NzNr-AbyPChHk',
                      width: 52, height: 52, fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Clean Architecture thực chiến',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: 0.42,
                            backgroundColor: Colors.white12,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('13:24 còn lại',
                            style: TextStyle(fontSize: 11, color: Colors.white38)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.black, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Đã lưu',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white54)),
        const SizedBox(height: 10),
        ...ProfileScreen._savedEpisodes.map((ep) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EpisodeRow(ep: ep),
            )),
      ],
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  final Map<String, dynamic> ep;
  const _EpisodeRow({required this.ep});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(ep['imageUrl']!,
                width: 50, height: 50, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ep['title']!,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('${ep['channel']}  ·  ${ep['duration']}',
                    style: const TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
          Icon(Icons.play_circle_outline_rounded,
              color: Colors.white.withOpacity(0.5), size: 26),
        ],
      ),
    );
  }
}

// ─── Tab 2: Đang Theo Dõi ────────────────────────────────────────────────────
class _FollowingTab extends StatelessWidget {
  const _FollowingTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // horizontal scroll row of channel avatars
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: ProfileScreen._following.length,
            itemBuilder: (ctx, i) {
              final ch = ProfileScreen._following[i];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.network(ch['imageUrl']!, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(ch['name']!,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        const Text('Cập nhật mới nhất',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white54)),
        const SizedBox(height: 10),
        // fake update items
        ...ProfileScreen._following.map((ch) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChannelUpdateRow(channel: ch),
            )),
      ],
    );
  }
}

class _ChannelUpdateRow extends StatelessWidget {
  final Map<String, dynamic> channel;
  const _ChannelUpdateRow({required this.channel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(channel['imageUrl']!,
                width: 48, height: 48, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(channel['name']!,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 2),
                Text('Tập mới vừa phát hành',
                    style: TextStyle(
                        fontSize: 11, color: Colors.white.withOpacity(0.4))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Xem',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 3: Của Tôi ──────────────────────────────────────────────────────────────
class _MyCreationsTab extends StatelessWidget {
  const _MyCreationsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Stats cards
        Row(
          children: [
            _miniStat('142h', 'Tổng giờ nghe', Icons.headphones_rounded),
            const SizedBox(width: 10),
            _miniStat('2.4k', 'Người theo dõi', Icons.people_outline),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Podcast của tôi',
            style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white54)),
        const SizedBox(height: 10),
        ...ProfileScreen._creations.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CreationCard(creation: c),
            )),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.history_rounded, color: Colors.white38, size: 13),
            const SizedBox(width: 6),
            const Text('Hoạt động gần đây',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white54)),
          ],
        ),
        const SizedBox(height: 10),
        _activityItem(Icons.favorite_rounded, 'Đã thích', 'The Joe Rogan Experience #2041', '2 giờ trước'),
        _activityItem(Icons.mode_comment_outlined, 'Đã bình luận', 'Lex Fridman Podcast #402', 'Hôm qua'),
      ],
    );
  }

  static Widget _miniStat(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white38, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(label,
                    style: const TextStyle(fontSize: 10, color: Colors.white38)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _activityItem(IconData icon, String action, String title, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white54, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                    children: [
                      TextSpan(text: '$action  '),
                      TextSpan(
                          text: title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(time,
                    style: const TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreationCard extends StatelessWidget {
  final Map<String, dynamic> creation;
  const _CreationCard({required this.creation});

  @override
  Widget build(BuildContext context) {
    final isPublished = creation['isPublished'] as bool;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(creation['imageUrl']!,
                width: 50, height: 50, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(creation['title']!,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(creation['subtitle']!,
                    style: const TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: isPublished
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              (creation['badge']! as String).toUpperCase(),
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isPublished ? Colors.white : Colors.white38,
                  letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
