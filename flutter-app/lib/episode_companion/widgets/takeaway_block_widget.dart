import 'package:flutter/material.dart';

import 'package:pody/episode_companion/models/episode_companion_block.dart';
import 'package:pody/episode_companion/widgets/companion_section_card.dart';

class TakeawayBlockWidget extends StatelessWidget {
  const TakeawayBlockWidget({
    super.key,
    required this.data,
    this.isPreview = false,
    this.showCard = true,
  });

  final TakeawayBlockData data;
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
                  color: const Color(0xFF25F4EE).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFF25F4EE),
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
          ...data.items.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25F4EE).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF25F4EE).withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      maxLines: isPreview ? 2 : null,
                      overflow: isPreview ? TextOverflow.ellipsis : null,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
