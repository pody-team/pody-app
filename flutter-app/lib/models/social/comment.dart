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

  factory Comment.fromArticleJson(Map<String, dynamic> json) {
    final rawUserName = (json['user_name'] as String?)?.trim();
    final author = (rawUserName != null && rawUserName.isNotEmpty)
        ? rawUserName
        : 'Nguoi dung';
    return Comment(
      id: json['id']?.toString() ?? '',
      author: author,
      avatarUrl: '',
      text: (json['content'] as String?)?.trim() ?? '',
      time: _readTime(json['created_at']),
    );
  }

  static String _readTime(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return 'Vua xong';
    }

    final createdAt = DateTime.tryParse(raw)?.toLocal();
    if (createdAt == null) {
      return 'Vua xong';
    }

    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) {
      return 'Vua xong';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} phut truoc';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} gio truoc';
    }
    return '${difference.inDays} ngay truoc';
  }
}
