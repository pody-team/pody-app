enum EpisodeCompanionBlockType {
  timeline,
  diagramImage,
  takeaway,
  quiz,
  storyCast,
  quote,
  chapterList,
  flashcards,
}

class EpisodeCompanionBlock {
  const EpisodeCompanionBlock({required this.type, required this.data});

  final EpisodeCompanionBlockType type;
  final Object data;
}

class TimelineBlockData {
  const TimelineBlockData({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<TimelineBlockItemData> items;
}

class TimelineBlockItemData {
  const TimelineBlockItemData({
    required this.timeLabel,
    required this.title,
    required this.body,
  });

  final String timeLabel;
  final String title;
  final String body;
}

class DiagramImageBlockData {
  const DiagramImageBlockData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.chips,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final List<String> chips;
}

class TakeawayBlockData {
  const TakeawayBlockData({required this.title, required this.items});

  final String title;
  final List<String> items;
}

class QuizBlockData {
  const QuizBlockData({
    required this.title,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String title;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

class StoryCastBlockData {
  const StoryCastBlockData({required this.title, required this.cards});

  final String title;
  final List<InfoCardData> cards;
}

class InfoCardData {
  const InfoCardData({required this.title, required this.body});

  final String title;
  final String body;
}

class QuoteBlockData {
  const QuoteBlockData({
    required this.title,
    required this.quote,
    required this.attribution,
    this.footnote,
  });

  final String title;
  final String quote;
  final String attribution;
  final String? footnote;
}

class ChapterListBlockData {
  const ChapterListBlockData({required this.title, required this.chapters});

  final String title;
  final List<ChapterListItemData> chapters;
}

class ChapterListItemData {
  const ChapterListItemData({
    required this.timeLabel,
    required this.title,
    required this.detail,
  });

  final String timeLabel;
  final String title;
  final String detail;
}

class FlashcardsBlockData {
  const FlashcardsBlockData({required this.title, required this.cards});

  final String title;
  final List<FlashcardItemData> cards;
}

class FlashcardItemData {
  const FlashcardItemData({required this.front, required this.back});

  final String front;
  final String back;
}
