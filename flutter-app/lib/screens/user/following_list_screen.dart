import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/utils/player_utils.dart';

const Color _followCanvas = Color(0xFFFFFBF6);
const Color _followSurface = Color(0xFFFFFEFC);
const Color _followSurfaceStrong = Color(0xFFF2E6D9);
const Color _followPrimary = Color(0xFFBF5700);
const Color _followNeutral = Color(0xFF3E2723);
const Color _followMuted = Color(0xFF7E665F);

class FollowingListScreen extends StatelessWidget {
  const FollowingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final users = MockData.otherUsers;

    return Scaffold(
      backgroundColor: _followCanvas,
      appBar: AppBar(
        backgroundColor: _followCanvas,
        surfaceTintColor: _followCanvas,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: _followNeutral),
        ),
        title: Text(
          'Đang theo dõi',
          style: GoogleFonts.newsreader(
            color: _followNeutral,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _followSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _followNeutral.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Creator bạn đang theo dõi',
                  style: GoogleFonts.newsreader(
                    color: _followNeutral,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${users.length} hồ sơ đang nằm trong danh sách theo dõi của bạn.',
                  style: GoogleFonts.workSans(
                    color: _followMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...users.map((user) => _UserTile(user: user)),
        ],
      ),
    );
  }
}

class _UserTile extends StatefulWidget {
  const _UserTile({required this.user});

  final UserProfile user;

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  bool _isFollowing = true;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => openUserDetail(context, user),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _followSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _followNeutral.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  user.avatarUrl,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: GoogleFonts.workSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _followNeutral,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.bio,
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        color: _followMuted,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _isFollowing = !_isFollowing),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _isFollowing ? _followSurfaceStrong : _followPrimary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                    style: GoogleFonts.workSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _isFollowing ? _followNeutral : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
