import 'package:flutter/material.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/podcast/player_screen.dart';
import 'package:pody/screens/podcast/podcast_detail_screen.dart';
import 'package:pody/screens/user/user_detail_screen.dart';
import 'package:pody/state/player_state.dart';

/// Opens the full-screen player as a modal bottom sheet (swipe-down to dismiss).
void openPlayerScreen(BuildContext context, {Podcast? podcast, Episode? episode}) {
  final p = podcast ?? MockData.podcasts.first;
  final e = episode ?? p.episodes.first;

  // Update global player state so mini player reflects the current episode
  PlayerState.instance.play(podcast: p, episode: e);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (context) {
      return SizedBox.expand(
        child: PlayerScreen(
          podcast: podcast,
          episode: episode,
        ),
      );
    },
  );
}

/// Opens PodcastDetailScreen (pushes within tab navigator, keeps bottom nav bar visible).
void openPodcastDetail(BuildContext context, Podcast podcast) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => PodcastDetailScreen(podcast: podcast)),
  );
}

/// Opens UserDetailScreen (pushes within tab navigator, keeps bottom nav bar visible).
void openUserDetail(BuildContext context, UserProfile user) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => UserDetailScreen(user: user)),
  );
}
