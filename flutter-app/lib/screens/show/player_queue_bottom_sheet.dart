import 'package:flutter/material.dart';
import 'package:pody/models/models.dart';

class PlayerQueueBottomSheet extends StatelessWidget {
  const PlayerQueueBottomSheet({
    required this.episodes,
    required this.currentIndex,
    required this.onSelectEpisode,
    super.key,
  });

  final List<Episode> episodes;
  final int currentIndex;
  final ValueChanged<int> onSelectEpisode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF15141B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Danh sách phát',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${episodes.length} tập đang chờ',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: episodes.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                      child: Text(
                        'Chưa có queue phát.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      itemCount: episodes.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      itemBuilder: (context, index) {
                        final episode = episodes[index];
                        final isCurrent = index == currentIndex;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          onTap: () => onSelectEpisode(index),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isCurrent
                                  ? Icons.equalizer_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            episode.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: Colors.white.withValues(
                                alpha: isCurrent ? 0.95 : 0.82,
                              ),
                            ),
                          ),
                          subtitle: Text(
                            episode.formattedDuration,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.42),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
