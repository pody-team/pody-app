import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'following_list_screen.dart';
import 'my_podcasts_screen.dart';
import 'listening_history_screen.dart';
import 'package:pody/theme/app_colors.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/utils/player_utils.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
    final user = MockData.currentUser;
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
                    color: Colors.white.withValues(alpha: 0.08),
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
              child: Image.network(user.avatarUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text('@${user.name.toLowerCase().replaceAll(' ', '')}',
              style: const TextStyle(fontSize: 13, color: Colors.white38)),
          const SizedBox(height: 16),
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ListeningHistoryScreen())),
                child: _statChip('${user.listeningHours}h', 'Đã nghe'),
              ),
              _divider(),
              GestureDetector(
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyPodcastsScreen())),
                child: _statChip('${user.podcastCount}', 'Podcast'),
              ),
              _divider(),
              GestureDetector(
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FollowingListScreen())),
                child: _statChip('${user.followingCount}', 'Theo dõi'),
              ),
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
    final savedEps = MockData.savedEpisodes;
    final progress = MockData.currentUserProgress;
    // Find first episode with progress for "Continue Listening"
    final continueEp = progress.isNotEmpty ? progress.first : null;
    final continueEpisode = continueEp != null ? MockData.getEpisodeById(continueEp.episodeId) : null;
    final continuePodcast = continueEp != null ? MockData.getPodcastById(continueEp.podcastId) : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Continue Listening banner
        if (continueEpisode != null && continueEp != null)
          GestureDetector(
            onTap: () {
              if (continuePodcast != null) {
                openPlayerScreen(context, podcast: continuePodcast, episode: continueEpisode);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history_rounded, color: Colors.white54, size: 14),
                      SizedBox(width: 6),
                      Text('Nghe tiếp',
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
                          continuePodcast?.imageUrl ?? continueEpisode.images.first,
                          width: 52, height: 52, fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(continueEpisode.title,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: continueEp.progress,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                minHeight: 3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(continueEp.remainingLabel,
                                style: const TextStyle(fontSize: 11, color: Colors.white38)),
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
          ),
        const SizedBox(height: 20),
        const Text('Đã lưu',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white54)),
        const SizedBox(height: 10),
        ...savedEps.map((ep) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EpisodeRow(episode: ep),
            )),
      ],
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  final Episode episode;
  const _EpisodeRow({required this.episode});

  @override
  Widget build(BuildContext context) {
    final podcast = MockData.getPodcastById(episode.podcastId);
    return GestureDetector(
      onTap: () {
        if (podcast != null) {
          openPlayerScreen(context, podcast: podcast, episode: episode);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                  episode.images.isNotEmpty ? episode.images.first : (podcast?.imageUrl ?? ''),
                  width: 50, height: 50, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(episode.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('${podcast?.title ?? ''}  ·  ${episode.formattedDuration}',
                      style: const TextStyle(fontSize: 11, color: Colors.white38)),
                ],
              ),
            ),
            Icon(Icons.play_circle_outline_rounded,
                color: Colors.white.withValues(alpha: 0.5), size: 26),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 2: Đang Theo Dõi ────────────────────────────────────────────────────
class _FollowingTab extends StatelessWidget {
  const _FollowingTab();

  @override
  Widget build(BuildContext context) {
    final following = MockData.followingChannels;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // horizontal scroll row of channel avatars
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: following.length,
            itemBuilder: (ctx, i) {
              final ch = following[i];
              return GestureDetector(
                onTap: () {
                  final podcast = MockData.podcasts.where(
                    (p) => p.title == ch['name']).firstOrNull;
                  if (podcast != null) {
                    openPodcastDetail(context, podcast);
                  }
                },
                child: Padding(
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
        ...following.map((ch) => Padding(
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
    return GestureDetector(
      onTap: () {
        final podcast = MockData.podcasts.where(
          (p) => p.title == channel['name']).firstOrNull;
        if (podcast != null) {
          openPodcastDetail(context, podcast);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                          fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Xem',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 3: Của Tôi ──────────────────────────────────────────────────────────────
class _MyCreationsTab extends StatelessWidget {
  const _MyCreationsTab();

  @override
  Widget build(BuildContext context) {
    final user = MockData.currentUser;
    final creations = MockData.myCreations;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Stats cards
        Row(
          children: [
            _miniStat('${user.listeningHours}h', 'Tổng giờ nghe', Icons.headphones_rounded),
            const SizedBox(width: 10),
            _miniStat('2.4k', 'Người theo dõi', Icons.people_outline),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Podcast của tôi',
            style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white54)),
        const SizedBox(height: 10),
        ...creations.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CreationCard(creation: c),
            )),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.history_rounded, color: Colors.white38, size: 13),
            SizedBox(width: 6),
            Text('Hoạt động gần đây',
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
              color: Colors.white.withValues(alpha: 0.07),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.06),
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
