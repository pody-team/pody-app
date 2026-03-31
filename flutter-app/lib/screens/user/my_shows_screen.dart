import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/features/content/presentation/content_scope.dart';
import 'package:pody/screens/show/content_show_detail_screen.dart';
import 'package:pody/screens/user/create_show_screen.dart';

const Color _showsCanvas = Color(0xFFFFFBF6);
const Color _showsSurface = Color(0xFFFFFEFC);
const Color _showsSurfaceStrong = Color(0xFFF2E6D9);
const Color _showsPrimary = Color(0xFFBF5700);
const Color _showsNeutral = Color(0xFF3E2723);
const Color _showsMuted = Color(0xFF7E665F);

class MyShowsScreen extends StatefulWidget {
  const MyShowsScreen({super.key});

  @override
  State<MyShowsScreen> createState() => _MyShowsScreenState();
}

class _MyShowsScreenState extends State<MyShowsScreen> {
  List<ContentShowSummary> _shows = const [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) {
      return;
    }
    _didLoad = true;
    _loadShows();
  }

  Future<void> _loadShows() async {
    final authController = AuthScope.of(context);
    if (!authController.isAuthenticated) {
      setState(() {
        _shows = const [];
        _errorMessage = 'Hãy đăng nhập để xem danh sách show của bạn.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shows = await ContentScope.of(context).listMyShows();
      if (!mounted) {
        return;
      }
      setState(() {
        _shows = shows;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _humanizeError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _humanizeError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Không thể tải show của bạn lúc này.';
  }

  Future<void> _openCreateShow() async {
    final authController = AuthScope.of(context);
    if (!authController.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy đăng nhập để tạo show mới.')),
      );
      return;
    }

    final createdShow = await Navigator.of(context).push<ContentShowDetail>(
      MaterialPageRoute<ContentShowDetail>(
        builder: (_) => const CreateShowScreen(),
      ),
    );
    if (!mounted || createdShow == null) {
      return;
    }

    await _loadShows();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã tạo show "${createdShow.title}" thành công.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _showsCanvas,
      appBar: AppBar(
        backgroundColor: _showsCanvas,
        surfaceTintColor: _showsCanvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _showsNeutral),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Show của tôi',
          style: GoogleFonts.newsreader(
            color: _showsNeutral,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _openCreateShow,
            icon: const Icon(Icons.add_circle_outline, color: _showsPrimary),
            tooltip: 'Tạo show mới',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _showsPrimary,
        onRefresh: _loadShows,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _shows.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_errorMessage != null && _shows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 120),
        children: [
          _StateCard(
            icon: Icons.cloud_off_outlined,
            title: 'Chưa tải được danh sách show',
            message: _errorMessage!,
            actionLabel: 'Thử lại',
            onPressed: _loadShows,
          ),
        ],
      );
    }
    if (_shows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          _HeroCard(onPressed: _openCreateShow),
          const SizedBox(height: 18),
          _StateCard(
            icon: Icons.podcasts_outlined,
            title: 'Bạn chưa có show nào',
            message:
                'Tạo show đầu tiên để bắt đầu định hình format, danh sách host, category và nội dung cho creator studio.',
            actionLabel: 'Tạo show đầu tiên',
            onPressed: _openCreateShow,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        _HeroCard(onPressed: _openCreateShow, showCount: _shows.length),
        const SizedBox(height: 18),
        Text(
          'Danh sách show',
          style: GoogleFonts.newsreader(
            color: _showsNeutral,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_shows.length} show đang dùng dữ liệu thật từ content service.',
          style: GoogleFonts.workSans(
            color: _showsMuted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ..._shows.map((show) => _ShowCard(show: show)),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onPressed, this.showCount = 0});

  final VoidCallback onPressed;
  final int showCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4E6), Color(0xFFF4E7D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _showsPrimary.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _showsSurface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              showCount == 0 ? 'Bắt đầu mới' : '$showCount show',
              style: GoogleFonts.workSans(
                color: _showsPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Quản lý danh mục\nshow của bạn',
            style: GoogleFonts.newsreader(
              color: _showsNeutral,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Từ đây bạn có thể xem các show đã tạo và mở nhanh creator flow để thêm show mới.',
            style: GoogleFonts.workSans(
              color: _showsMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: const Text('Tạo show mới'),
            style: FilledButton.styleFrom(
              backgroundColor: _showsPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: GoogleFonts.workSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowCard extends StatelessWidget {
  const _ShowCard({required this.show});

  final ContentShowSummary show;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ContentShowDetailScreen(
                showId: show.id,
                initialSummary: show,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _showsSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _showsNeutral.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  show.coverImageUrl,
                  width: 78,
                  height: 78,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 78,
                    height: 78,
                    color: _showsSurfaceStrong,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.podcasts_rounded,
                      color: _showsPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.title,
                      style: GoogleFonts.workSans(
                        color: _showsNeutral,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${show.totalEpisodeCount} tập • ${show.formattedSubscriberCount} theo dõi',
                      style: GoogleFonts.workSans(
                        color: _showsMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(label: show.primaryCategory),
                        _MetaChip(
                          label: show.contentType == 'storytelling'
                              ? 'Storytelling'
                              : 'Podcast',
                          highlighted: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: _showsMuted, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? _showsPrimary.withValues(alpha: 0.10)
            : _showsSurfaceStrong,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.workSans(
          color: highlighted ? _showsPrimary : _showsMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _showsSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _showsNeutral.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _showsSurfaceStrong,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: _showsPrimary, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              color: _showsNeutral,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.workSans(
              color: _showsMuted,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: _showsPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              textStyle: GoogleFonts.workSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
