class ArticlePodcastJobSummary {
  const ArticlePodcastJobSummary({
    required this.jobId,
    required this.status,
    this.title,
    this.audioUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String jobId;
  final String status;
  final String? title;
  final String? audioUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCompleted => status == 'completed';

  factory ArticlePodcastJobSummary.fromJson(Map<String, dynamic> json) {
    return ArticlePodcastJobSummary(
      jobId: (json['job_id'] as String?)?.trim() ?? '',
      status: (json['status'] as String?)?.trim() ?? 'queued',
      title: (json['title'] as String?)?.trim(),
      audioUrl: (json['audio_url'] as String?)?.trim(),
      createdAt: DateTime.tryParse(
        (json['created_at'] as String?)?.trim() ?? '',
      ),
      updatedAt: DateTime.tryParse(
        (json['updated_at'] as String?)?.trim() ?? '',
      ),
    );
  }
}

class ArticlePodcastJobDetail {
  const ArticlePodcastJobDetail({
    required this.jobId,
    required this.status,
    required this.selectedArticles,
    this.researchSummary,
    this.podcastTitle,
    this.podcastDescription,
    this.outline = const <String>[],
    this.scriptText,
    this.audioUrl,
    this.durationSeconds,
    this.error,
    this.createdAt,
    this.updatedAt,
  });

  final String jobId;
  final String status;
  final List<ArticlePodcastSelectedArticle> selectedArticles;
  final String? researchSummary;
  final String? podcastTitle;
  final String? podcastDescription;
  final List<String> outline;
  final String? scriptText;
  final String? audioUrl;
  final int? durationSeconds;
  final String? error;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isTerminal => status == 'completed' || status == 'failed';
  bool get isCompleted => status == 'completed';

  factory ArticlePodcastJobDetail.fromJson(Map<String, dynamic> json) {
    final selectedArticlesJson = json['selected_articles'];
    final outlineJson = json['outline'];
    return ArticlePodcastJobDetail(
      jobId: (json['job_id'] as String?)?.trim() ?? '',
      status: (json['status'] as String?)?.trim() ?? 'queued',
      selectedArticles: selectedArticlesJson is List
          ? selectedArticlesJson
                .whereType<Map<String, dynamic>>()
                .map(ArticlePodcastSelectedArticle.fromJson)
                .toList()
          : const <ArticlePodcastSelectedArticle>[],
      researchSummary: (json['research_summary'] as String?)?.trim(),
      podcastTitle: (json['podcast_title'] as String?)?.trim(),
      podcastDescription: (json['podcast_description'] as String?)?.trim(),
      outline: outlineJson is List
          ? outlineJson
                .map((item) => item?.toString().trim() ?? '')
                .where((item) => item.isNotEmpty)
                .toList()
          : const <String>[],
      scriptText: (json['script_text'] as String?)?.trim(),
      audioUrl: (json['audio_url'] as String?)?.trim(),
      durationSeconds: _readInt(json['duration_seconds']),
      error: (json['error'] as String?)?.trim(),
      createdAt: DateTime.tryParse(
        (json['created_at'] as String?)?.trim() ?? '',
      ),
      updatedAt: DateTime.tryParse(
        (json['updated_at'] as String?)?.trim() ?? '',
      ),
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed;
  }
}

class ArticlePodcastSelectedArticle {
  const ArticlePodcastSelectedArticle({
    required this.articleId,
    required this.title,
    this.summary,
  });

  final int articleId;
  final String title;
  final String? summary;

  factory ArticlePodcastSelectedArticle.fromJson(Map<String, dynamic> json) {
    return ArticlePodcastSelectedArticle(
      articleId: ArticlePodcastJobDetail._readInt(json['article_id']) ?? 0,
      title: (json['title'] as String?)?.trim() ?? '',
      summary: (json['summary'] as String?)?.trim(),
    );
  }
}
