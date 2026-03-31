class NewsCategory {
  const NewsCategory({
    required this.id,
    required this.slug,
    required this.name,
    required this.articleCount,
    this.description,
  });

  final String id;
  final String slug;
  final String name;
  final int articleCount;
  final String? description;

  factory NewsCategory.fromJson(Map<String, dynamic> json) {
    return NewsCategory(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      articleCount: _readInt(json['article_count']),
      description: json['description']?.toString().trim(),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
