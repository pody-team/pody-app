class Host {
  final String id;
  final String name;
  final String avatarUrl;
  final String? voiceId;     // ID giọng nói AI (TTS)
  final String role;         // 'host', 'co-host', 'guest'

  const Host({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.voiceId,
    this.role = 'host',
  });
}

class Podcast {
  final String id;
  final String title;
  final List<Host> hosts;
  final String category;
  final String imageUrl;
  final List<Episode> episodes;
  final String subscriberCount;
  final int totalEpisodeCount;
  final bool isFollowing;

  const Podcast({
    required this.id,
    required this.title,
    required this.hosts,
    required this.category,
    required this.imageUrl,
    required this.episodes,
    required this.subscriberCount,
    required this.totalEpisodeCount,
    this.isFollowing = false,
  });

  /// Convenience: primary host (first in list)
  Host get primaryHost => hosts.first;

  /// Formatted hosts label: "Anh Ba & Linh"
  String get hostsLabel => hosts.map((h) => h.name).join(' & ');

  Podcast copyWith({bool? isFollowing}) {
    return Podcast(
      id: id,
      title: title,
      hosts: hosts,
      category: category,
      imageUrl: imageUrl,
      episodes: episodes,
      subscriberCount: subscriberCount,
      totalEpisodeCount: totalEpisodeCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

class Episode {
  final String id;
  final String podcastId;
  final String title;
  final String description;
  final String duration;
  final List<String> images;
  final List<String> tags;
  final List<ChatBubble> bubbles;
  final String likes;
  final String comments;

  const Episode({
    required this.id,
    required this.podcastId,
    required this.title,
    required this.description,
    required this.duration,
    required this.images,
    this.tags = const [],
    this.bubbles = const [],
    required this.likes,
    required this.comments,
  });
}

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
