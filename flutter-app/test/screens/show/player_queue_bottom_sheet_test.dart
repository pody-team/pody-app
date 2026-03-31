import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/show/player_queue_bottom_sheet.dart';

void main() {
  testWidgets('renders queue episodes and selects an item on tap', (
    WidgetTester tester,
  ) async {
    final tappedIndexes = <int>[];
    final episodes = [
      const Episode(
        id: 'episode-1',
        showId: 'show-1',
        title: 'Tap 1',
        description: 'Mo ta 1',
        duration: Duration(minutes: 2),
        images: ['https://example.com/cover-1.jpg'],
        audioUrl: 'https://example.com/audio-1.mp3',
      ),
      const Episode(
        id: 'episode-2',
        showId: 'show-1',
        title: 'Tap 2',
        description: 'Mo ta 2',
        duration: Duration(minutes: 3),
        images: ['https://example.com/cover-2.jpg'],
        audioUrl: 'https://example.com/audio-2.mp3',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerQueueBottomSheet(
            episodes: episodes,
            currentIndex: 0,
            onSelectEpisode: tappedIndexes.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Danh sách phát'), findsOneWidget);
    expect(find.text('Tap 1'), findsOneWidget);
    expect(find.text('Tap 2'), findsOneWidget);

    await tester.tap(find.text('Tap 2'));
    await tester.pump();

    expect(tappedIndexes, [1]);
  });
}
