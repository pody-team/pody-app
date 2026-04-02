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

  group('resolveTranscriptSeekPosition', () {
    test('uses the segment start time when timing is available', () {
      final position = resolveTranscriptSeekPosition(
        bubbles: const [
          ChatBubble(
            speakerId: 'host-1',
            speaker: 'Atlas',
            text: 'Xin chao',
            isRight: true,
            startSeconds: 12.5,
            endSeconds: 16,
          ),
        ],
        bubbleIndex: 0,
        episodeDuration: const Duration(minutes: 5),
      );

      expect(position, const Duration(milliseconds: 12500));
    });

    test('falls back to proportional duration when timing is missing', () {
      final position = resolveTranscriptSeekPosition(
        bubbles: const [
          ChatBubble(
            speakerId: 'host-1',
            speaker: 'Atlas',
            text: 'Doan 1',
            isRight: true,
          ),
          ChatBubble(
            speakerId: 'host-2',
            speaker: 'Nova',
            text: 'Doan 2',
            isRight: false,
          ),
          ChatBubble(
            speakerId: 'host-1',
            speaker: 'Atlas',
            text: 'Doan 3',
            isRight: true,
          ),
        ],
        bubbleIndex: 1,
        episodeDuration: const Duration(seconds: 90),
      );

      expect(position, const Duration(seconds: 30));
    });
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

  group('isTranscriptBubbleOutsideFocusZone', () {
    test('returns true when the active bubble leaves the focus zone', () {
      final isOutside = isTranscriptBubbleOutsideFocusZone(
        bubbleTop: 280,
        bubbleBottom: 340,
        viewportHeight: 400,
      );

      expect(isOutside, isTrue);
    });

    test(
      'returns false when the active bubble stays inside the focus zone',
      () {
        final isOutside = isTranscriptBubbleOutsideFocusZone(
          bubbleTop: 120,
          bubbleBottom: 180,
          viewportHeight: 400,
        );

        expect(isOutside, isFalse);
      },
    );
  });

  group('shouldShowReturnToCurrentTranscriptFromFocusZone', () {
    test('shows after the active bubble moves outside the outer zone', () {
      final shouldShow = shouldShowReturnToCurrentTranscriptFromFocusZone(
        bubbleTop: 300,
        bubbleBottom: 360,
        viewportHeight: 400,
        isCurrentlyVisible: false,
      );

      expect(shouldShow, isTrue);
    });

    test(
      'stays hidden while the active bubble is still near the live zone',
      () {
        final shouldShow = shouldShowReturnToCurrentTranscriptFromFocusZone(
          bubbleTop: 150,
          bubbleBottom: 210,
          viewportHeight: 400,
          isCurrentlyVisible: false,
        );

        expect(shouldShow, isFalse);
      },
    );

    test(
      'keeps showing until the active bubble returns inside the inner zone',
      () {
        final shouldShow = shouldShowReturnToCurrentTranscriptFromFocusZone(
          bubbleTop: 250,
          bubbleBottom: 310,
          viewportHeight: 400,
          isCurrentlyVisible: true,
        );

        expect(shouldShow, isTrue);
      },
    );

    test('hides after the active bubble returns inside the inner zone', () {
      final shouldShow = shouldShowReturnToCurrentTranscriptFromFocusZone(
        bubbleTop: 140,
        bubbleBottom: 200,
        viewportHeight: 400,
        isCurrentlyVisible: true,
      );

      expect(shouldShow, isFalse);
    });
  });
}
