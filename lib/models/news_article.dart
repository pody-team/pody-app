class NewsArticle {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String publisher;
  final String time;
  bool isAdded;

  NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.publisher,
    required this.time,
    this.isAdded = false,
  });
}
