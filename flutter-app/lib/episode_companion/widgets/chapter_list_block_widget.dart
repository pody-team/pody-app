import 'package:flutter/material.dart';

import 'package:pody/episode_companion/models/episode_companion_block.dart';
import 'package:pody/episode_companion/widgets/companion_section_card.dart';

class ChapterListBlockWidget extends StatelessWidget {
  const ChapterListBlockWidget({
    super.key,
    required this.data,
    this.isPreview = false,
    this.showCard = true,
  });

  final ChapterListBlockData data;
  final bool isPreview;
  final bool showCard;

  @override
  Widget build(BuildContext context) {
    return CompanionSectionCard(
      enabled: showCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: Color(0xFF7C4DFF),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (isPreview)
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.25),
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...data.chapters.asMap().entries.map((entry) {
            final chapter = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == data.chapters.length - 1 ? 0 : 8,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        chapter.timeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(
                            0xFF7C4DFF,
                          ).withValues(alpha: 0.85),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chapter.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (!isPreview) ...[
                            const SizedBox(height: 3),
                            Text(
                              chapter.detail,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.45),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.play_circle_outline,
                      color: Colors.white.withValues(alpha: 0.2),
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
