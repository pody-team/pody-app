import 'package:flutter_test/flutter_test.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/show/player_transcript_sync.dart';

void main() {
  group('resolveActiveTranscriptBubbleIndex', () {
    test(
      'uses transcript timestamps instead of evenly dividing by bubble count',
      () {
        final bubbles = [
          const ChatBubble(
            speakerId: 'host-1',
            speaker: 'Atlas',
            text: 'Mo dau ngan.',
            isRight: true,
            startSeconds: 0,
            endSeconds: 5,
          ),
          const ChatBubble(
            speakerId: 'host-1',
            speaker: 'Atlas',
            text: 'Doan dai hon rat nhieu so voi dong dau.',
            isRight: true,
            startSeconds: 5,
            endSeconds: 40,
          ),
        ];

        final index = resolveActiveTranscriptBubbleIndex(
          bubbles: bubbles,
          currentSeconds: 6,
          fallbackProgress: 0.15,
        );

        expect(index, 1);
      },
    );
  });

  group('resolveTranscriptBubbleProgress', () {
    test('computes progress within the active transcript segment', () {
      final bubbles = [
        const ChatBubble(
          speakerId: 'host-1',
          speaker: 'Atlas',
          text: 'Doan transcript.',
          isRight: true,
          startSeconds: 10,
          endSeconds: 30,
        ),
      ];

      final progress = resolveTranscriptBubbleProgress(
        bubbles: bubbles,
        activeBubbleIndex: 0,
        currentSeconds: 15,
        fallbackProgress: 0.5,
      );

      expect(progress, closeTo(0.25, 0.001));
    });
  });

  group('resolveTranscriptWordIndex', () {
    test(
      'falls back to proportional highlight when word timings are missing',
      () {
        const bubble = ChatBubble(
          speakerId: 'host-1',
          speaker: 'Atlas',
          text: 'Mot hai ba bon',
          isRight: true,
        );

        final index = resolveTranscriptWordIndex(
          bubble: bubble,
          currentSeconds: 0,
          fallbackProgress: 0.74,
        );

        expect(index, 2);
      },
    );
  });

  group('shouldShowReturnToCurrentTranscriptButton', () {
    test('shows the button when transcript drifts away from the live line', () {
      final visible = shouldShowReturnToCurrentTranscriptButton(
        currentOffset: 420,
        targetOffset: 240,
      );

      expect(visible, isTrue);
    });

    test('hides the button when transcript is already near the live line', () {
      final visible = shouldShowReturnToCurrentTranscriptButton(
        currentOffset: 248,
        targetOffset: 240,
      );

      expect(visible, isFalse);
    });
  });
}
