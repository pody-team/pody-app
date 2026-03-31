import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/data/article_scope.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/creation/ai_summary_setup_screen.dart';
import 'package:pody/screens/news/article_detail_screen.dart';

const Color _newsCanvas = Color(0xFFFFFBF6);
const Color _newsSurface = Color(0xFFFFFEFC);
const Color _newsSurfaceStrong = Color(0xFFF2E6D9);
const Color _newsPrimary = Color(0xFFBF5700);
const Color _newsNeutral = Color(0xFF3E2723);
const Color _newsMuted = Color(0xFF7E665F);

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _errorMessage;
  List<NewsArticle> _articles = const <NewsArticle>[];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchArticles(reset: true);
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchArticles({bool reset = false}) async {
    if (!mounted) {
      return;
    }

    if (reset) {
      setState(() {
        _isLoading = true;
        _isLoadingMore = false;
        _hasMore = true;
        _offset = 0;
        _errorMessage = null;
      });
    } else {
      if (_isLoading || _isLoadingMore || !_hasMore) {
        return;
      }
      setState(() => _isLoadingMore = true);
    }

    final articleService = ArticleScope.of(context);
    String? categoryFilter = _categoryFilterForIndex(_selectedCategoryIndex);

    try {
      final results = await articleService.fetchArticles(
        category: categoryFilter,
        query: _searchQuery.isEmpty ? null : _searchQuery,
        limit: _pageSize,
        offset: reset ? 0 : _offset,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _articles = reset ? results : [..._articles, ...results];
        _offset = (reset ? 0 : _offset) + results.length;
        _hasMore = results.length == _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = error.message;
        if (reset) {
          _articles = const <NewsArticle>[];
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'Không tải được danh sách bài báo.';
        if (reset) {
          _articles = const <NewsArticle>[];
        }
      });
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _fetchArticles();
    }
  }

  Future<void> _refreshArticles() => _fetchArticles(reset: true);

  void _submitSearch() {
    setState(() => _searchQuery = _searchController.text.trim());
    _fetchArticles(reset: true);
  }

  String? _categoryFilterForIndex(int index) {
    if (index == 0) {
      return null;
    }
    final raw = MockData.newsCategories[index];
    final withoutEmoji = raw.replaceAll(RegExp(r'^[^\wÀ-ỹ]+'), '').trim();
    if (withoutEmoji.isEmpty) {
      return null;
    }
    final parts = withoutEmoji.split(' ');
    return parts.length > 1 ? parts.last : withoutEmoji;
  }

  void _toggleAdded(NewsArticle article) {
    setState(() {
      article.isAdded = !article.isAdded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final highlightedCount = _articles
        .where((article) => article.isAdded)
        .length;
    final topArticle = _articles.isEmpty ? null : _articles.first;

    return Scaffold(
      backgroundColor: _newsCanvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshArticles,
          color: _newsPrimary,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _buildDigestHero(context, highlightedCount),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: _buildSearchBar(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Text(
                    'Danh mục',
                    style: GoogleFonts.newsreader(
                      color: _newsNeutral,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildCategories()),
              if (_isLoading && _articles.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else if (_errorMessage != null && _articles.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    child: _NewsStateCard(
                      icon: Icons.cloud_off_outlined,
                      title: 'Chưa tải được bản tin',
                      message: _errorMessage!,
                      actionLabel: 'Thử lại',
                      onPressed: () => _fetchArticles(reset: true),
                    ),
                  ),
                )
              else if (topArticle == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    child: _NewsStateCard(
                      icon: Icons.newspaper_outlined,
                      title: 'Chưa có bài viết',
                      message:
                          'Hiện chưa có bài báo phù hợp với bộ lọc đang chọn.',
                      actionLabel: 'Tải lại',
                      onPressed: () => _fetchArticles(reset: true),
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: _buildHighlightStory(topArticle),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index >= _articles.length - 1) {
                        return _isLoadingMore
                            ? const Padding(
                                padding: EdgeInsets.only(top: 6, bottom: 18),
                                child: Center(
                                  child: CircularProgressIndicator.adaptive(),
                                ),
                              )
                            : const SizedBox.shrink();
                      }
                      return _buildCompactNewsRow(_articles[index + 1]);
                    }, childCount: _articles.length),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigestHero(BuildContext context, int highlightedCount) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4E6), Color(0xFFF4E7D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _newsPrimary.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _newsSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'AI Playlist',
                  style: GoogleFonts.workSans(
                    color: _newsPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '~12 phút',
                style: GoogleFonts.workSans(
                  color: _newsMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Bản tin công nghệ\nsáng nay của bạn',
            style: GoogleFonts.newsreader(
              color: _newsNeutral,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Dựa trên ${highlightedCount > 0 ? highlightedCount : 5} bài viết bạn đã chọn và dòng tin mới nhất từ article service.',
            style: GoogleFonts.workSans(
              fontSize: 14,
              color: _newsMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: _newsPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: GoogleFonts.workSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  child: const Text('Tạo và nghe'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AiSummarySetupScreen(),
                    ),
                  );
                },
                style: IconButton.styleFrom(
                  backgroundColor: _newsSurface,
                  foregroundColor: _newsPrimary,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.schedule),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _newsSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _newsNeutral.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Icon(Icons.search, color: _newsPrimary),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _submitSearch(),
              style: GoogleFonts.workSans(color: _newsNeutral, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Tìm bài báo, chủ đề hoặc tác giả...',
                hintStyle: GoogleFonts.workSans(color: _newsMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _submitSearch,
            icon: const Icon(Icons.arrow_forward_rounded, color: _newsMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final categories = MockData.newsCategories;
    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 12),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryIndex = index;
              });
              _fetchArticles(reset: true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? _newsPrimary : _newsSurface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected
                      ? _newsPrimary
                      : _newsNeutral.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                categories[index],
                style: GoogleFonts.workSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : _newsNeutral,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHighlightStory(NewsArticle article) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ArticleDetailScreen(article: article),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _newsSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _newsNeutral.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(article.imageUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              article.title,
              style: GoogleFonts.newsreader(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: _newsNeutral,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              article.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.workSans(
                fontSize: 14,
                color: _newsMuted,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  article.publisher,
                  style: GoogleFonts.workSans(
                    color: _newsNeutral,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text('•', style: GoogleFonts.workSans(color: _newsMuted)),
                const SizedBox(width: 8),
                Text(
                  article.time,
                  style: GoogleFonts.workSans(color: _newsMuted, fontSize: 12),
                ),
                const Spacer(),
                _buildAddButton(article),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactNewsRow(NewsArticle article) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ArticleDetailScreen(article: article),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _newsSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _newsNeutral.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  article.imageUrl,
                  width: 82,
                  height: 82,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.workSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _newsNeutral,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        color: _newsMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          article.publisher,
                          style: GoogleFonts.workSans(
                            color: _newsMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: GoogleFonts.workSans(color: _newsMuted),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          article.time,
                          style: GoogleFonts.workSans(
                            color: _newsMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildAddButton(article),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(NewsArticle article) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _toggleAdded(article),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: article.isAdded ? _newsPrimary : _newsSurfaceStrong,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          article.isAdded ? 'Đã chọn' : 'Thêm',
          style: GoogleFonts.workSans(
            color: article.isAdded ? Colors.white : _newsNeutral,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _NewsStateCard extends StatelessWidget {
  const _NewsStateCard({
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
        color: _newsSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _newsNeutral.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _newsSurfaceStrong,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: _newsPrimary, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              color: _newsNeutral,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.workSans(
              color: _newsMuted,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: _newsPrimary,
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
