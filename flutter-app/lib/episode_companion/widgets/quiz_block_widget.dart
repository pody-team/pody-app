import 'package:flutter/material.dart';

import 'package:pody/episode_companion/models/episode_companion_block.dart';
import 'package:pody/episode_companion/widgets/companion_section_card.dart';
import 'package:pody/theme/app_colors.dart';

class QuizBlockWidget extends StatefulWidget {
  const QuizBlockWidget({super.key, required this.data, this.showCard = true});

  final QuizBlockData data;
  final bool showCard;

  @override
  State<QuizBlockWidget> createState() => _QuizBlockWidgetState();
}

class _QuizBlockWidgetState extends State<QuizBlockWidget> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final hasAnswered = _selectedIndex != null;

    return CompanionSectionCard(
      enabled: widget.showCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.quiz_outlined, color: kTikRed, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.data.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.data.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ...widget.data.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final hasThisOption = _selectedIndex == index;
            final isCorrect = index == widget.data.correctIndex;

            var borderColor = Colors.white.withValues(alpha: 0.08);
            var backgroundColor = Colors.white.withValues(alpha: 0.04);

            if (hasAnswered && isCorrect) {
              borderColor = kTikTeal.withValues(alpha: 0.5);
              backgroundColor = kTikTeal.withValues(alpha: 0.12);
            } else if (hasThisOption && !isCorrect) {
              borderColor = kTikRed.withValues(alpha: 0.45);
              backgroundColor = kTikRed.withValues(alpha: 0.12);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: hasAnswered
                    ? null
                    : () => setState(() => _selectedIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.18),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          String.fromCharCode(65 + index),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (hasAnswered) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                widget.data.explanation,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.68),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
