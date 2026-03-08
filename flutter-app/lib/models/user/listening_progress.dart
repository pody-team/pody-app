/// Tracks a user's listening state for a specific episode.
/// This is per-user data, separate from episode metadata.
class ListeningProgress {
  final String episodeId;
  final String showId;
  final double progress;        // 0.0 – 1.0
  final Duration position;      // exact seek position
  final Duration totalDuration;
  final DateTime lastPlayedAt;
  final bool isCompleted;

  const ListeningProgress({
    required this.episodeId,
    required this.showId,
    this.progress = 0.0,
    this.position = Duration.zero,
    this.totalDuration = Duration.zero,
    required this.lastPlayedAt,
    this.isCompleted = false,
  });

  ListeningProgress copyWith({
    double? progress,
    Duration? position,
    Duration? totalDuration,
    DateTime? lastPlayedAt,
    bool? isCompleted,
  }) {
    return ListeningProgress(
      episodeId: episodeId,
      showId: showId,
      progress: progress ?? this.progress,
      position: position ?? this.position,
      totalDuration: totalDuration ?? this.totalDuration,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  /// e.g. "13:24 còn lại"
  String get remainingLabel {
    final remaining = totalDuration - position;
    final m = remaining.inMinutes;
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s còn lại';
  }
}
