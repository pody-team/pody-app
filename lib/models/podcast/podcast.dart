import 'host.dart';
import 'episode.dart';

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
  final String authorId; // ID of the user who created this podcast

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
    required this.authorId,
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
      authorId: authorId,
    );
  }
}
