import 'package:flutter/material.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/utils/player_utils.dart';

class FollowingListScreen extends StatelessWidget {
  const FollowingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final users = MockData.otherUsers;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E13),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        ),
        title: const Text(
          'Đang theo dõi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        itemCount: users.length,
        separatorBuilder: (_, __) => Divider(
          color: Colors.white.withValues(alpha: 0.06),
          height: 1,
        ),
        itemBuilder: (context, index) {
          final user = users[index];
          return _UserTile(user: user);
        },
      ),
    );
  }
}

class _UserTile extends StatefulWidget {
  final UserProfile user;
  const _UserTile({required this.user});

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  bool _isFollowing = true; // They're in "following" list, so initially true

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return GestureDetector(
      onTap: () => openUserDetail(context, user),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.network(
                user.avatarUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            // Name + Bio
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.bio,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Follow/Unfollow button
            GestureDetector(
              onTap: () => setState(() => _isFollowing = !_isFollowing),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: _isFollowing
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: _isFollowing
                      ? Border.all(color: Colors.white24)
                      : null,
                ),
                child: Text(
                  _isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isFollowing ? Colors.white60 : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
