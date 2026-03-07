class Comment {
  final String id;
  final String author;
  final String avatarUrl;
  final String text;
  final String time;
  int likes;
  final List<Comment> replies;
  final bool isStoryAvatar;
  final int viewMoreRepliesCount;

  Comment({
    required this.id,
    required this.author,
    required this.avatarUrl,
    required this.text,
    required this.time,
    this.likes = 0,
    this.replies = const [],
    this.isStoryAvatar = false,
    this.viewMoreRepliesCount = 0,
  });
}
