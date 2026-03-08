class UserProfile {
  final String id;
  final String name;
  final String avatarUrl;
  final String bio;
  final int listeningHours;
  final int showCount;
  final int followingCount;
  final int followerCount;
  final bool isFollowing;

  const UserProfile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.bio = '',
    this.listeningHours = 0,
    this.showCount = 0,
    this.followingCount = 0,
    this.followerCount = 0,
    this.isFollowing = false,
  });
}
