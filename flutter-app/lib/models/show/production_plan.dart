import 'host.dart';

/// A draft episode inside a production plan (not yet produced).
class EpisodeDraft {
  final String id;
  final int number; // episode order: 1, 2, 3...
  final String title;
  final String description;
  final Duration estimatedDuration;
  final String notes; // production notes / instructions

  const EpisodeDraft({
    required this.id,
    required this.number,
    required this.title,
    this.description = '',
    this.estimatedDuration = const Duration(minutes: 15),
    this.notes = '',
  });

  EpisodeDraft copyWith({
    String? title,
    String? description,
    Duration? estimatedDuration,
    String? notes,
  }) {
    return EpisodeDraft(
      id: id,
      number: number,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      notes: notes ?? this.notes,
    );
  }
}

/// Status of a production plan.
enum PlanStatus { draft, reviewing, producing, completed, failed }

/// The AI-generated production plan for a podcast series.
class ProductionPlan {
  final String id;
  final String seriesTitle;
  final String seriesDescription;
  final List<Host> hosts;
  final List<String> tags; // e.g. ['Analytical', 'Professional']
  final String toneStyle; // e.g. 'Analytical, Professional'
  final List<EpisodeDraft> episodes;
  final PlanStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool autoGenerateImages;
  final bool autoGenerateIntroMusic;

  const ProductionPlan({
    required this.id,
    required this.seriesTitle,
    this.seriesDescription = '',
    this.hosts = const [],
    this.tags = const [],
    this.toneStyle = '',
    this.episodes = const [],
    this.status = PlanStatus.draft,
    required this.createdAt,
    required this.updatedAt,
    this.autoGenerateImages = false,
    this.autoGenerateIntroMusic = false,
  });

  /// Total estimated duration across all episodes.
  Duration get totalDuration =>
      episodes.fold(Duration.zero, (sum, ep) => sum + ep.estimatedDuration);

  /// Formatted total: "45 min" or "1h 20m"
  String get formattedTotalDuration {
    final h = totalDuration.inHours;
    final m = totalDuration.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '$m min';
  }

  /// Summary label: "3 Episodes • 45 min total"
  String get summaryLabel =>
      '${episodes.length} Episodes • $formattedTotalDuration total';

  ProductionPlan copyWith({
    String? seriesTitle,
    String? seriesDescription,
    List<Host>? hosts,
    List<String>? tags,
    String? toneStyle,
    List<EpisodeDraft>? episodes,
    PlanStatus? status,
    DateTime? updatedAt,
    bool? autoGenerateImages,
    bool? autoGenerateIntroMusic,
  }) {
    return ProductionPlan(
      id: id,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      seriesDescription: seriesDescription ?? this.seriesDescription,
      hosts: hosts ?? this.hosts,
      tags: tags ?? this.tags,
      toneStyle: toneStyle ?? this.toneStyle,
      episodes: episodes ?? this.episodes,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      autoGenerateImages: autoGenerateImages ?? this.autoGenerateImages,
      autoGenerateIntroMusic:
          autoGenerateIntroMusic ?? this.autoGenerateIntroMusic,
    );
  }
}
