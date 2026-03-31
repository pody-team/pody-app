import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/utils/player_utils.dart';

const Color _userCanvas = Color(0xFFFFFBF6);
const Color _userSurface = Color(0xFFFFFEFC);
const Color _userSurfaceStrong = Color(0xFFF2E6D9);
const Color _userPrimary = Color(0xFFBF5700);
const Color _userNeutral = Color(0xFF3E2723);
const Color _userMuted = Color(0xFF7E665F);

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.user});

  final UserProfile user;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.user.isFollowing;
  }

  UserProfile get user => widget.user;

  List<Show> get _userPodcasts {
    return MockData.shows
        .where((p) => p.hosts.any((h) => h.id == user.id))
        .toList();
  }

  List<Map<String, dynamic>> get _userEpisodes {
    final result = <Map<String, dynamic>>[];
    for (final show in _userPodcasts) {
      for (final episode in show.episodes) {
        result.add({'podcast': show, 'episode': episode});
      }
    }
    return result;
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final shows = _userPodcasts;
    final episodes = _userEpisodes;

    return Scaffold(
      backgroundColor: _userCanvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: _userCanvas,
            surfaceTintColor: _userCanvas,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, color: _userNeutral),
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.more_horiz, color: _userNeutral),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _userSurface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _userNeutral.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(48),
                      child: Image.network(
                        user.avatarUrl,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name,
                      style: GoogleFonts.newsreader(
                        color: _userNeutral,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.name.toLowerCase().replaceAll(' ', '')}',
                      style: GoogleFonts.workSans(
                        color: _userMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user.bio,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.workSans(
                        color: _userMuted,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            value: _formatCount(user.followerCount),
                            label: 'Người theo dõi',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            value: _formatCount(user.followingCount),
                            label: 'Đang theo dõi',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            value: '${user.showCount}',
                            label: 'Show',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() => _isFollowing = !_isFollowing);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _isFollowing
                                  ? _userSurfaceStrong
                                  : _userPrimary,
                              foregroundColor: _isFollowing
                                  ? _userNeutral
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: GoogleFonts.workSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            child: Text(
                              _isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _userNeutral,
                            side: BorderSide(
                              color: _userNeutral.withValues(alpha: 0.12),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          child: const Text('Nhắn tin'),
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
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(
                'Show nổi bật',
                style: GoogleFonts.newsreader(
                  color: _userNeutral,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 208,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: shows.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final show = shows[index];
                  return GestureDetector(
                    onTap: () => openShowDetail(context, show),
                    child: Container(
                      width: 154,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _userSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _userNeutral.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              show.imageUrl,
                              width: 126,
                              height: 126,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            show.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.workSans(
                              color: _userNeutral,
                              fontSize: 14,
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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
              child: Text(
                'Tập gần đây',
                style: GoogleFonts.newsreader(
                  color: _userNeutral,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = episodes[index];
                final show = item['podcast'] as Show;
                final episode = item['episode'] as Episode;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () =>
                        openPlayerScreen(context, show: show, episode: episode),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _userSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _userNeutral.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              episode.images.isNotEmpty
                                  ? episode.images.first
                                  : show.imageUrl,
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
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
                                    color: _userNeutral,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  show.title,
                                  style: GoogleFonts.workSans(
                                    color: _userMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            color: _userPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }, childCount: episodes.length),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _userSurfaceStrong,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.workSans(
              color: _userNeutral,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.workSans(
              color: _userMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
