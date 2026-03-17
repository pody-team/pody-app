import 'package:flutter/material.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/features/content/presentation/content_scope.dart';
import 'package:pody/screens/show/content_show_detail_screen.dart';
import 'package:pody/screens/user/create_show_screen.dart';

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
        _errorMessage = 'Hay dang nhap de xem danh sach show cua ban.';
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
    return 'Khong the tai show cua ban luc nay.';
  }

  Future<void> _openCreateShow() async {
    final authController = AuthScope.of(context);
    if (!authController.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hay dang nhap de tao show moi.')),
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
      SnackBar(content: Text('Da tao show "${createdShow.title}" thanh cong.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E13),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: const Text(
          'Podcast của tôi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _openCreateShow,
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            tooltip: 'Tao show moi',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadShows,
        color: Colors.white,
        child: _isLoading && _shows.isEmpty
            ? const Center(child: CircularProgressIndicator.adaptive())
            : _errorMessage != null && _shows.isEmpty
            ? ListView(
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 100),
                children: [
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.68),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      _loadShows();
                    },
                    child: const Text('Thu lai'),
                  ),
                ],
              )
            : _shows.isEmpty
            ? ListView(
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 120),
                children: [
                  Icon(
                    Icons.podcasts_outlined,
                    size: 52,
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Ban chua co show nao',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tao show dau tien de bat dau dinh hinh AI host, category va noi dung cho creator studio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _openCreateShow,
                    icon: const Icon(Icons.add),
                    label: const Text('Tao show dau tien'),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                itemCount: _shows.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final show = _shows[index];
                  return GestureDetector(
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
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              show.coverImageUrl,
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
                                  show.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${show.totalEpisodeCount} tap • ${show.formattedSubscriberCount} theo doi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    show.primaryCategory,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
