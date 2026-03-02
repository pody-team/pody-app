/// A single line of karaoke-style subtitle in an episode.
class ChatBubble {
  final String speakerId; // references Host.id
  final String speaker;   // display name (for quick access)
  final String text;
  final bool isRight;
  final int colorValue;

  const ChatBubble({
    required this.speakerId,
    required this.speaker,
    required this.text,
    required this.isRight,
    this.colorValue = 0xFFFFFFFF,
  });
}

class Episode {
  final String id;
  final String podcastId;
  final String title;
  final String description;
  final Duration duration;
  final List<String> images;
  final List<String> tags;
  final List<ChatBubble> bubbles;
  final int likes;
  final int comments;

  const Episode({
    required this.id,
    required this.podcastId,
    required this.title,
    required this.description,
    required this.duration,
    required this.images,
    this.tags = const [],
    this.bubbles = const [],
    this.likes = 0,
    this.comments = 0,
  });

  /// Format duration for display: "32 phút", "1h 05m"
  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '$m phút';
  }

  /// Format number for display: 12500 → '12.5k', 842 → '842'
  static String formatCount(int count) {
    if (count >= 1000000) {
      final v = count / 1000000;
      return v == v.truncateToDouble()
          ? '${v.toInt()}M'
          : '${v.toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      final v = count / 1000;
      return v == v.truncateToDouble()
          ? '${v.toInt()}k'
          : '${v.toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  String get formattedLikes => formatCount(likes);
  String get formattedComments => formatCount(comments);
}
