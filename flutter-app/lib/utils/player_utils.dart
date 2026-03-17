import 'package:flutter/material.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/show/player_screen.dart';
import 'package:pody/screens/show/show_detail_screen.dart';
import 'package:pody/screens/user/user_detail_screen.dart';
import 'package:pody/state/player_state.dart';

/// Opens the full-screen player as a modal bottom sheet (swipe-down to dismiss).
void openPlayerScreen(
  BuildContext context, {
  Show? show,
  Episode? episode,
  VoidCallback? onOpenShow,
}) {
  final p = show ?? MockData.shows.first;
  final e = episode ?? p.episodes.first;

  // Update global player state so mini player reflects the current episode
  PlayerState.instance.play(show: p, episode: e);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (context) {
      return SizedBox.expand(
        child: PlayerScreen(
          show: show,
          episode: episode,
          onOpenShow: onOpenShow,
        ),
      );
    },
  );
}

/// Opens ShowDetailScreen (pushes within tab navigator, keeps bottom nav bar visible).
void openShowDetail(BuildContext context, Show show) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ShowDetailScreen(show: show)),
  );
}

/// Opens UserDetailScreen (pushes within tab navigator, keeps bottom nav bar visible).
void openUserDetail(BuildContext context, UserProfile user) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => UserDetailScreen(user: user)),
  );
}
