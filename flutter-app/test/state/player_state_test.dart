import 'package:flutter_test/flutter_test.dart';
import 'package:pody/models/show/episode.dart';
import 'package:pody/state/player_state.dart';

void main() {
  test(
    'sortEpisodesForPlayback orders episodes by ascending episode number',
    () {
      final sorted = sortEpisodesForPlayback([
        const Episode(
          id: 'ep-5',
          showId: 'show-1',
          episodeNumber: 5,
          title: 'Tap 5',
          description: '',
          duration: Duration(minutes: 5),
          images: ['https://example.com/5.png'],
          audioUrl: 'https://example.com/5.wav',
        ),
        const Episode(
          id: 'ep-1',
          showId: 'show-1',
          episodeNumber: 1,
          title: 'Tap 1',
          description: '',
          duration: Duration(minutes: 5),
          images: ['https://example.com/1.png'],
          audioUrl: 'https://example.com/1.wav',
        ),
        const Episode(
          id: 'ep-3',
          showId: 'show-1',
          episodeNumber: 3,
          title: 'Tap 3',
          description: '',
          duration: Duration(minutes: 5),
          images: ['https://example.com/3.png'],
          audioUrl: 'https://example.com/3.wav',
        ),
      ]);

      expect(sorted.map((episode) => episode.id), ['ep-1', 'ep-3', 'ep-5']);
    },
  );
}
