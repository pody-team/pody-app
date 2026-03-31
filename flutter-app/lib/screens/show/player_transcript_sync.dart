import 'package:pody/models/models.dart';

int resolveActiveTranscriptBubbleIndex({
  required List<ChatBubble> bubbles,
  required double currentSeconds,
  required double fallbackProgress,
}) {
  if (bubbles.isEmpty) {
    return 0;
  }

  final fallbackIndex = _resolveFallbackIndex(
    bubbleCount: bubbles.length,
    progress: fallbackProgress,
  );
  if (!bubbles.any((bubble) => bubble.hasTiming)) {
    return fallbackIndex;
  }

  int? firstFutureIndex;
  var lastPastIndex = -1;

  for (var i = 0; i < bubbles.length; i += 1) {
    final bubble = bubbles[i];
    if (!bubble.hasTiming) {
      continue;
    }
    final startSeconds = bubble.startSeconds!;
    final endSeconds = bubble.endSeconds!;
    if (currentSeconds >= startSeconds && currentSeconds < endSeconds) {
      return i;
    }
    if (currentSeconds >= endSeconds) {
      lastPastIndex = i;
      continue;
    }
    if (currentSeconds < startSeconds) {
      firstFutureIndex ??= i;
    }
  }

  if (firstFutureIndex != null) {
    return firstFutureIndex;
  }
  if (lastPastIndex >= 0) {
    return lastPastIndex;
  }
  return fallbackIndex;
}

double resolveTranscriptBubbleProgress({
  required List<ChatBubble> bubbles,
  required int activeBubbleIndex,
  required double currentSeconds,
  required double fallbackProgress,
}) {
  if (bubbles.isEmpty ||
      activeBubbleIndex < 0 ||
      activeBubbleIndex >= bubbles.length) {
    return 0;
  }

  final bubble = bubbles[activeBubbleIndex];
  if (bubble.hasTiming) {
    final startSeconds = bubble.startSeconds!;
    final endSeconds = bubble.endSeconds!;
    final duration = endSeconds - startSeconds;
    if (duration > 0) {
      return ((currentSeconds - startSeconds) / duration).clamp(0.0, 1.0);
    }
  }

  final rawProgress = (fallbackProgress * bubbles.length) - activeBubbleIndex;
  return rawProgress.clamp(0.0, 1.0);
}

int resolveTranscriptWordIndex({
  required ChatBubble bubble,
  required double currentSeconds,
  required double fallbackProgress,
}) {
  if (bubble.words.isEmpty) {
    return _resolveFallbackIndex(
      bubbleCount: bubble.text
          .split(' ')
          .where((word) => word.isNotEmpty)
          .length,
      progress: fallbackProgress,
    );
  }

  final wordsWithText = [
    for (final word in bubble.words)
      if (word.text.trim().isNotEmpty) word,
  ];
  if (wordsWithText.isEmpty) {
    return 0;
  }

  for (var i = 0; i < wordsWithText.length; i += 1) {
    final word = wordsWithText[i];
    if (currentSeconds >= word.startSeconds &&
        currentSeconds < word.endSeconds) {
      return i;
    }
  }

  for (var i = wordsWithText.length - 1; i >= 0; i -= 1) {
    if (currentSeconds >= wordsWithText[i].endSeconds) {
      return i;
    }
  }

  return 0;
}

int _resolveFallbackIndex({
  required int bubbleCount,
  required double progress,
}) {
  if (bubbleCount <= 1) {
    return 0;
  }
  final scaled = (progress * bubbleCount).floor();
  return scaled.clamp(0, bubbleCount - 1);
}
