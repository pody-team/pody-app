import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/models/show/episode.dart';
import 'package:pody/models/show/host.dart';
import 'package:pody/models/show/show.dart';
import 'package:pody/state/player_state.dart';
import 'package:pody/widgets/mini_player.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final episode = const Episode(
    id: 'episode-1',
    showId: 'show-1',
    episodeNumber: 1,
    title: 'Tap 1',
    description: 'Mo ta',
    duration: Duration(minutes: 10),
    images: ['https://example.com/episode.png'],
    audioUrl: '',
  );
  final show = Show(
    id: 'show-1',
    title: 'Future Minds',
    hosts: const [
      Host(
        id: 'host-1',
        name: 'Nova',
        avatarUrl: 'https://example.com/host.png',
      ),
    ],
    category: 'Cong nghe',
    imageUrl: 'https://example.com/show.png',
    episodes: [episode],
    subscriberCount: '1000',
    totalEpisodeCount: 1,
    authorId: 'author-1',
  );

  setUp(() async {
    await PlayerState.instance.dismissPlayer();
  });

  tearDown(() async {
    await PlayerState.instance.dismissPlayer();
  });

  testWidgets('swiping mini player left dismisses it', (tester) async {
    await _pumpMiniPlayer(tester, show: show, episode: episode);

    expect(find.text('Tap 1'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(PlayerState.instance.episode, isNull);
    expect(PlayerState.instance.show, isNull);
    expect(find.text('Tap 1'), findsNothing);
  });

  testWidgets('swiping mini player right dismisses it', (tester) async {
    await _pumpMiniPlayer(tester, show: show, episode: episode);

    expect(find.text('Tap 1'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(PlayerState.instance.episode, isNull);
    expect(PlayerState.instance.show, isNull);
    expect(find.text('Tap 1'), findsNothing);
  });
}

Future<void> _pumpMiniPlayer(
  WidgetTester tester, {
  required Show show,
  required Episode episode,
}) async {
  await PlayerState.instance.play(
    show: show,
    episode: episode,
    autoplay: false,
  );

  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Align(alignment: Alignment.bottomCenter, child: MiniPlayer()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
