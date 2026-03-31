class NewsArticle {
  final int id;
  final String title;
  final String description;
  final String content;
  final String imageUrl;
  final String publisher;
  final String category;
  final List<String> categories;
  final String time;
  final int viewCount;
  final int commentsCount;
  final int likeCount;
  final int loveCount;
  final int dislikeCount;
  bool isAdded;
  bool isLiked;
  bool isLoved;
  bool isDisliked;

  NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    this.content = '',
    required this.imageUrl,
    required this.publisher,
    this.category = 'Tech',
    this.categories = const <String>[],
    required this.time,
    this.viewCount = 0,
    this.commentsCount = 0,
    this.likeCount = 0,
    this.loveCount = 0,
    this.dislikeCount = 0,
    this.isAdded = false,
    this.isLiked = false,
    this.isLoved = false,
    this.isDisliked = false,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    final categories = _readCategories(json);
    final author = (json['author'] as String?)?.trim();
    final reactions = _readReactions(json['reactions']);

    return NewsArticle(
      id: _readInt(json['id']),
      title: (json['title'] as String?)?.trim() ?? '',
      description: (json['summary'] as String?)?.trim() ?? '',
      content: (json['content'] as String?)?.trim() ?? '',
      imageUrl: _readImageUrl(json['thumbnail_url']),
      publisher: (author != null && author.isNotEmpty) ? author : 'Pody News',
      category: categories.isNotEmpty ? categories.first : 'The gioi',
      categories: categories,
      time: _readPublishedAt(json['published_at']) ?? 'Vua xong',
      viewCount: _readInt(json['view_count']),
      commentsCount: _readInt(json['comments_count']),
      likeCount: _readInt(reactions['like_count']),
      loveCount: _readInt(reactions['love_count']),
      dislikeCount: _readInt(reactions['dislike_count']),
      isAdded: json['is_added'] == true,
      isLiked: json['is_liked'] == true,
      isLoved: json['is_loved'] == true,
      isDisliked: json['is_disliked'] == true,
    );
  }

  NewsArticle copyWith({
    String? title,
    String? description,
    String? content,
    String? imageUrl,
    String? publisher,
    String? category,
    List<String>? categories,
    String? time,
    int? viewCount,
    int? commentsCount,
    int? likeCount,
    int? loveCount,
    int? dislikeCount,
    bool? isAdded,
    bool? isLiked,
    bool? isLoved,
    bool? isDisliked,
  }) {
    return NewsArticle(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      publisher: publisher ?? this.publisher,
      category: category ?? this.category,
      categories: categories ?? this.categories,
      time: time ?? this.time,
      viewCount: viewCount ?? this.viewCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likeCount: likeCount ?? this.likeCount,
      loveCount: loveCount ?? this.loveCount,
      dislikeCount: dislikeCount ?? this.dislikeCount,
      isAdded: isAdded ?? this.isAdded,
      isLiked: isLiked ?? this.isLiked,
      isLoved: isLoved ?? this.isLoved,
      isDisliked: isDisliked ?? this.isDisliked,
    );
  }

  static List<String> _readCategories(Map<String, dynamic> json) {
    final categories = json['categories'];
    if (categories is List) {
      return categories
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final category = (json['category'] as String?)?.trim();
    if (category != null && category.isNotEmpty) {
      return <String>[category];
    }

    return const <String>[];
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _readReactions(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    return const <String, dynamic>{};
  }

  static String _readImageUrl(dynamic value) {
    final imageUrl = value?.toString().trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return 'https://via.placeholder.com/300';
    }
    return imageUrl;
  }

  static String? _readPublishedAt(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final publishedAt = DateTime.tryParse(raw)?.toLocal();
    if (publishedAt == null) {
      return null;
    }

    final difference = DateTime.now().difference(publishedAt);
    if (difference.inMinutes < 1) {
      return 'Vua xong';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} phut truoc';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} gio truoc';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} ngay truoc';
    }

    final day = publishedAt.day.toString().padLeft(2, '0');
    final month = publishedAt.month.toString().padLeft(2, '0');
    return '$day/$month/${publishedAt.year}';
  }
}
