import 'package:flutter/material.dart';

import 'package:pody/episode_companion/models/episode_companion_block.dart';
import 'package:pody/theme/app_colors.dart';

class FlashcardsBlockWidget extends StatefulWidget {
  const FlashcardsBlockWidget({super.key, required this.data});

  final FlashcardsBlockData data;

  @override
  State<FlashcardsBlockWidget> createState() => _FlashcardsBlockWidgetState();
}

class _FlashcardsBlockWidgetState extends State<FlashcardsBlockWidget> {
  int _index = 0;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.data.cards[_index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.data.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chạm vào thẻ để lật. Vuốt ngang bằng nút điều hướng phía dưới.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            setState(() => _revealed = !_revealed);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 240),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _revealed
                  ? kTikTeal.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _revealed
                    ? kTikTeal.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _revealed ? 'Mặt sau' : 'Mặt trước',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      _revealed ? card.back : card.front,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _index == 0
                  ? null
                  : () {
                      setState(() {
                        _index -= 1;
                        _revealed = false;
                      });
                    },
              icon: const Icon(Icons.chevron_left),
              label: const Text('Trước'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Text(
                '${_index + 1}/${widget.data.cards.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _index == widget.data.cards.length - 1
                  ? null
                  : () {
                      setState(() {
                        _index += 1;
                        _revealed = false;
                      });
                    },
              icon: const Icon(Icons.chevron_right),
              label: const Text('Sau'),
            ),
          ],
        ),
      ],
    );
  }
}
