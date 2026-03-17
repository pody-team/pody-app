import 'package:flutter/material.dart';

import 'package:pody/episode_companion/models/episode_companion_block.dart';
import 'package:pody/episode_companion/widgets/companion_section_card.dart';

class StoryCastBlockWidget extends StatelessWidget {
  const StoryCastBlockWidget({
    super.key,
    required this.data,
    this.isPreview = false,
    this.showCard = true,
  });

  final StoryCastBlockData data;
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
                  color: const Color(0xFF26A69A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.people_outline,
                  color: Color(0xFF26A69A),
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
          ...data.cards.asMap().entries.map((entry) {
            final card = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == data.cards.length - 1 ? 0 : 10,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF26A69A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          card.title.isNotEmpty
                              ? card.title[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF26A69A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            card.body,
                            maxLines: isPreview ? 2 : null,
                            overflow: isPreview ? TextOverflow.ellipsis : null,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.55),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
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
