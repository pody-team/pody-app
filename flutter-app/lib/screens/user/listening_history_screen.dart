import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/utils/player_utils.dart';

const Color _historyCanvas = Color(0xFFFFFBF6);
const Color _historySurface = Color(0xFFFFFEFC);
const Color _historySurfaceStrong = Color(0xFFF2E6D9);
const Color _historyPrimary = Color(0xFFBF5700);
const Color _historyTertiary = Color(0xFF566931);
const Color _historyNeutral = Color(0xFF3E2723);
const Color _historyMuted = Color(0xFF7E665F);

class ListeningHistoryScreen extends StatelessWidget {
  const ListeningHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = MockData.currentUserProgress;
    final totalHours = MockData.currentUser.listeningHours;

    return Scaffold(
      backgroundColor: _historyCanvas,
      appBar: AppBar(
        backgroundColor: _historyCanvas,
        surfaceTintColor: _historyCanvas,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: _historyNeutral),
        ),
        title: Text(
          'Lịch sử nghe',
          style: GoogleFonts.newsreader(
            color: _historyNeutral,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF4E6), Color(0xFFF5EAD8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _historyPrimary.withValues(alpha: 0.10),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhịp nghe gần đây',
                  style: GoogleFonts.newsreader(
                    color: _historyNeutral,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Theo dõi lại các tập bạn đã mở gần đây và tiếp tục nghe từ đúng điểm dở dang.',
                  style: GoogleFonts.workSans(
                    color: _historyMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        value: '${totalHours}h',
                        label: 'Tổng giờ nghe',
                        icon: Icons.headphones_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryTile(
                        value: '${progress.length}',
                        label: 'Tập đã nghe',
                        icon: Icons.queue_music_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: _SummaryTile(
                        value: '7',
                        label: 'Ngày liên tiếp',
                        icon: Icons.local_fire_department_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Gần đây',
            style: GoogleFonts.newsreader(
              color: _historyNeutral,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${progress.length} tập được lưu từ tiến độ nghe hiện tại.',
            style: GoogleFonts.workSans(
              color: _historyMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(progress.length, (index) {
            final p = progress[index];
            final episode = MockData.getEpisodeById(p.episodeId);
            final show = MockData.getShowById(p.showId);
            if (episode == null || show == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () =>
                    openPlayerScreen(context, show: show, episode: episode),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _historySurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _historyNeutral.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          episode.images.isNotEmpty
                              ? episode.images.first
                              : show.imageUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              episode.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.workSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _historyNeutral,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              show.title,
                              style: GoogleFonts.workSans(
                                fontSize: 12,
                                color: _historyMuted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: p.progress,
                                minHeight: 6,
                                backgroundColor: _historySurfaceStrong,
                                valueColor: AlwaysStoppedAnimation(
                                  p.progress >= 1
                                      ? _historyTertiary
                                      : _historyPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.progress >= 1
                                  ? 'Đã nghe xong'
                                  : 'Đã nghe ${(p.progress * 100).toInt()}%',
                              style: GoogleFonts.workSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: p.progress >= 1
                                    ? _historyTertiary
                                    : _historyMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _historySurfaceStrong,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          p.progress >= 1
                              ? Icons.replay_rounded
                              : Icons.play_arrow_rounded,
                          color: _historyPrimary,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _historySurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: _historyPrimary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.workSans(
              color: _historyNeutral,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.workSans(
              color: _historyMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
