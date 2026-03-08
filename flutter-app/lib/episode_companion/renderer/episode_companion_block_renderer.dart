import 'package:flutter/material.dart';

import 'package:pody/episode_companion/models/episode_companion_block.dart';
import 'package:pody/episode_companion/widgets/chapter_list_block_widget.dart';
import 'package:pody/episode_companion/widgets/diagram_image_block_widget.dart';
import 'package:pody/episode_companion/widgets/flashcards_block_widget.dart';
import 'package:pody/episode_companion/widgets/flashcards_block_preview_widget.dart';
import 'package:pody/episode_companion/widgets/quiz_block_widget.dart';
import 'package:pody/episode_companion/widgets/quiz_block_preview_widget.dart';
import 'package:pody/episode_companion/widgets/quote_block_widget.dart';
import 'package:pody/episode_companion/widgets/story_cast_block_widget.dart';
import 'package:pody/episode_companion/widgets/takeaway_block_widget.dart';
import 'package:pody/episode_companion/widgets/timeline_block_widget.dart';

enum EpisodeCompanionRendererMode { preview, full }

class EpisodeCompanionBlockRenderer extends StatelessWidget {
  const EpisodeCompanionBlockRenderer({
    super.key,
    required this.block,
    this.mode = EpisodeCompanionRendererMode.full,
  });

  final EpisodeCompanionBlock block;
  final EpisodeCompanionRendererMode mode;

  @override
  Widget build(BuildContext context) {
    final isPreview = mode == EpisodeCompanionRendererMode.preview;
    final showCard = isPreview;

    switch (block.type) {
      case EpisodeCompanionBlockType.timeline:
        final data = block.data as TimelineBlockData;
        return TimelineBlockWidget(
          data: TimelineBlockData(
            title: data.title,
            subtitle: data.subtitle,
            items: isPreview ? data.items.take(2).toList() : data.items,
          ),
          isPreview: isPreview,
          showCard: showCard,
        );
      case EpisodeCompanionBlockType.diagramImage:
        return DiagramImageBlockWidget(
          data: block.data as DiagramImageBlockData,
          isPreview: isPreview,
          showCard: showCard,
        );
      case EpisodeCompanionBlockType.takeaway:
        final data = block.data as TakeawayBlockData;
        return TakeawayBlockWidget(
          data: TakeawayBlockData(
            title: data.title,
            items: isPreview ? data.items.take(2).toList() : data.items,
          ),
          isPreview: isPreview,
          showCard: showCard,
        );
      case EpisodeCompanionBlockType.quiz:
        final data = block.data as QuizBlockData;
        return isPreview
            ? QuizBlockPreviewWidget(data: data)
            : QuizBlockWidget(data: data, showCard: false);
      case EpisodeCompanionBlockType.storyCast:
        final data = block.data as StoryCastBlockData;
        return StoryCastBlockWidget(
          data: StoryCastBlockData(
            title: data.title,
            cards: isPreview ? data.cards.take(2).toList() : data.cards,
          ),
          isPreview: isPreview,
          showCard: showCard,
        );
      case EpisodeCompanionBlockType.quote:
        return QuoteBlockWidget(
          data: block.data as QuoteBlockData,
          isPreview: isPreview,
          showCard: showCard,
        );
      case EpisodeCompanionBlockType.chapterList:
        final data = block.data as ChapterListBlockData;
        return ChapterListBlockWidget(
          data: ChapterListBlockData(
            title: data.title,
            chapters: isPreview
                ? data.chapters.take(2).toList()
                : data.chapters,
          ),
          isPreview: isPreview,
          showCard: showCard,
        );
      case EpisodeCompanionBlockType.flashcards:
        final data = block.data as FlashcardsBlockData;
        return isPreview
            ? FlashcardsBlockPreviewWidget(data: data)
            : FlashcardsBlockWidget(data: data);
    }
  }
}
