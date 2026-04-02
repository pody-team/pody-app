import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/data/article_service.dart';
import 'package:pody/data/article_scope.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/creation/ai_summary_setup_screen.dart';
import 'package:pody/screens/news/article_detail_screen.dart';
import 'package:pody/screens/news/article_podcast_library_screen.dart';
import 'package:pody/screens/news/article_podcast_job_screen.dart';
import 'package:pody/screens/user/favorite_news_categories_screen.dart';

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

  Timer? _searchDebounce;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoadingCategories = false;
  bool _isCreatingPodcast = false;
  bool _hasMore = true;
  int _offset = 0;
  String _searchQuery = '';
  String? _selectedCategorySlug;
  String? _selectedCategoryName;
  String? _errorMessage;
  List<NewsCategory> _categories = const <NewsCategory>[];
  List<NewsArticle> _articles = const <NewsArticle>[];
  ArticleApiService? _articleService;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = ArticleScope.of(context);
    if (!identical(_articleService, service)) {
      _articleService?.favoritePreferencesVersion.removeListener(
        _handleFavoritePreferencesChanged,
      );
      _articleService = service;
      _articleService?.favoritePreferencesVersion.addListener(
        _handleFavoritePreferencesChanged,
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _articleService?.favoritePreferencesVersion.removeListener(
      _handleFavoritePreferencesChanged,
    );
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleFavoritePreferencesChanged() {
    if (!mounted) {
      return;
    }
    if ((_selectedCategorySlug?.isNotEmpty ?? false) ||
        _searchQuery.isNotEmpty) {
      return;
    }
    _fetchArticles(reset: true);
  }

  Future<void> _loadInitialData() async {
    await _fetchCategories();
    await _fetchArticles(reset: true);
  }

  Future<void> _fetchCategories() async {
    if (!mounted) {
      return;
    }

    setState(() => _isLoadingCategories = true);

    try {
      final categories = await ArticleScope.of(context).fetchCategories();
      if (!mounted) {
        return;
      }

      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
        final stillExists = _categories.any(
          (category) => category.slug == _selectedCategorySlug,
        );
        if (!stillExists) {
          _selectedCategorySlug = null;
          _selectedCategoryName = null;
        }
      });
    } on ApiException {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingCategories = false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingCategories = false);
    }
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

    try {
      final results = await ArticleScope.of(context).fetchArticles(
        category: _selectedCategorySlug,
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
        if (_categories.isEmpty && results.isNotEmpty) {
          _categories = _buildFallbackCategories(results);
        }
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

  Future<void> _refreshArticles() async {
    await _fetchCategories();
    await _fetchArticles(reset: true);
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

  void _handleSearchChanged(String value) {
    if (mounted) {
      setState(() {});
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      final trimmed = value.trim();
      if (trimmed == _searchQuery) {
        return;
      }
      setState(() => _searchQuery = trimmed);
      _fetchArticles(reset: true);
    });
  }

  void _submitSearch([String? value]) {
    _searchDebounce?.cancel();
    final trimmed = (value ?? _searchController.text).trim();
    if (trimmed == _searchQuery) {
      return;
    }
    setState(() => _searchQuery = trimmed);
    _fetchArticles(reset: true);
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _searchQuery = '');
    _fetchArticles(reset: true);
  }

  void _selectCategory(NewsCategory? category) {
    setState(() {
      _selectedCategorySlug = category?.slug;
      _selectedCategoryName = category?.name;
    });
    _fetchArticles(reset: true);
  }

  List<NewsCategory> _buildFallbackCategories(List<NewsArticle> articles) {
    final counts = <String, int>{};
    final labels = <String, String>{};

    for (final article in articles) {
      final names = article.categories.isNotEmpty
          ? article.categories
          : <String>[article.category];
      for (final name in names) {
        final trimmed = name.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final slug = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
        labels.putIfAbsent(slug, () => trimmed);
        counts[slug] = (counts[slug] ?? 0) + 1;
      }
    }

    final categories = counts.entries.map((entry) {
      return NewsCategory(
        id: entry.key,
        slug: entry.key,
        name: labels[entry.key] ?? entry.key,
        articleCount: entry.value,
      );
    }).toList();

    categories.sort((a, b) {
      final byCount = b.articleCount.compareTo(a.articleCount);
      if (byCount != 0) {
        return byCount;
      }
      return a.name.compareTo(b.name);
    });
    return categories;
  }

  void _toggleAdded(NewsArticle article) {
    setState(() {
      article.isAdded = !article.isAdded;
    });
  }

  Future<void> _createPodcastFromSelection() async {
    final selectedArticles = _articles
        .where((article) => article.isAdded)
        .toList(growable: false);

    if (selectedArticles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hay chon it nhat mot bai bao de tao podcast.'),
        ),
      );
      return;
    }

    if (_isCreatingPodcast) {
      return;
    }

    setState(() => _isCreatingPodcast = true);

    try {
      final job = await ArticleScope.of(context).createPodcastJob(
        articleIds: selectedArticles.map((article) => article.id).toList(),
      );
      if (!mounted) {
        return;
      }

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ArticlePodcastJobScreen(
            jobId: job.jobId,
            initialArticles: selectedArticles,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.isUnauthorized
          ? 'Ban can dang nhap de tao podcast bai bao.'
          : error.message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Khong the tao podcast luc nay. Hay thu lai.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingPodcast = false);
      }
    }
  }

  Future<void> _openFavoriteCategories() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const FavoriteNewsCategoriesScreen(),
      ),
    );
    if (!mounted) {
      return;
    }
    await _fetchCategories();
    if ((_selectedCategorySlug?.isNotEmpty ?? false) ||
        _searchQuery.isNotEmpty) {
      return;
    }
    await _fetchArticles(reset: true);
  }

  Future<void> _openPodcastLibrary() async {
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const ArticlePodcastLibraryScreen(),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.isUnauthorized
          ? 'Ban can dang nhap de xem podcast bao da tao.'
          : error.message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Khong mo duoc danh sach podcast bao luc nay.'),
        ),
      );
    }
  }

  String get _heroTitle {
    if (_searchQuery.isNotEmpty) {
      return 'Kết quả theo từ khóa';
    }
    if (_selectedCategoryName != null && _selectedCategoryName!.isNotEmpty) {
      return _selectedCategoryName!;
    }
    return 'Bản tin công nghệ sáng nay';
  }

  String get _heroSubtitle {
    if (_searchQuery.isNotEmpty && _selectedCategoryName != null) {
      return 'Đang lọc bài viết về $_selectedCategoryName theo từ khóa "$_searchQuery".';
    }
    if (_searchQuery.isNotEmpty) {
      return 'Những bài viết mới nhất khớp với "$_searchQuery".';
    }
    if (_selectedCategoryName != null && _selectedCategoryName!.isNotEmpty) {
      return 'Những bài nổi bật mới nhất trong chủ đề $_selectedCategoryName.';
    }
    return 'Tổng hợp các bài báo mới từ article service để bạn đọc, chọn và tạo bản tin.';
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Danh mục',
                          style: GoogleFonts.newsreader(
                            color: _newsNeutral,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _openFavoriteCategories,
                        tooltip: 'Chon the loai yeu thich',
                        style: IconButton.styleFrom(
                          backgroundColor: _newsSurface,
                          foregroundColor: _newsPrimary,
                          minimumSize: const Size(40, 40),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 20),
                      ),
                    ],
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
                  _selectedCategoryName ?? 'AI Playlist',
                  style: GoogleFonts.workSans(
                    color: _newsPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_articles.length} bài',
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
            _heroTitle,
            style: GoogleFonts.newsreader(
              color: _newsNeutral,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _heroSubtitle,
            style: GoogleFonts.workSans(
              fontSize: 14,
              color: _newsMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMiniStat(
                icon: Icons.check_circle_outline,
                label:
                    '${highlightedCount > 0 ? highlightedCount : 0} bài đã chọn',
              ),
              _buildMiniStat(
                icon: Icons.grid_view_rounded,
                label: '${_categories.length} chủ đề',
              ),
              _buildMiniStat(
                icon: Icons.newspaper_rounded,
                label: _hasMore ? 'Còn thêm bài viết' : 'Đã tải hết',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _isCreatingPodcast
                      ? null
                      : _createPodcastFromSelection,
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
                  child: Text(
                    _isCreatingPodcast ? 'Dang tao...' : 'Tạo và nghe',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: _openPodcastLibrary,
                tooltip: 'Mo podcast bao cua toi',
                style: IconButton.styleFrom(
                  backgroundColor: _newsSurface,
                  foregroundColor: _newsPrimary,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.library_music_rounded),
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

  Widget _buildMiniStat({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _newsSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _newsPrimary, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.workSans(
              color: _newsNeutral,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      clipBehavior: Clip.antiAlias,
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
              onChanged: _handleSearchChanged,
              onSubmitted: _submitSearch,
              cursorColor: _newsPrimary,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.workSans(color: _newsNeutral, fontSize: 15),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFFFFEFC),
                hintText: 'Tìm bài báo, chủ đề hoặc tác giả...',
                hintStyle: GoogleFonts.workSans(color: _newsMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: _clearSearch,
              icon: const Icon(Icons.close_rounded, color: _newsMuted),
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
    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 12),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        children: [
          _buildCategoryChip(
            label: 'Tất cả',
            isSelected: _selectedCategorySlug == null,
            onTap: () => _selectCategory(null),
          ),
          ..._categories.map(
            (category) => _buildCategoryChip(
              label: category.name,
              isSelected: _selectedCategorySlug == category.slug,
              onTap: () => _selectCategory(category),
              count: category.articleCount,
            ),
          ),
          if (_isLoadingCategories)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _newsPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int? count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.workSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : _newsNeutral,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: GoogleFonts.workSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : _newsMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightStory(NewsArticle article) {
    final categories = article.categories.isNotEmpty
        ? article.categories
        : <String>[article.category];

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
                child: _ArticleThumbnail(imageUrl: article.imageUrl),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.take(3).map((category) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _newsSurfaceStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    category,
                    style: GoogleFonts.workSans(
                      color: _newsPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
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
                Expanded(
                  child: Text(
                    '${article.publisher} • ${article.time}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.workSans(
                      color: _newsNeutral,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                child: _ArticleThumbnail(
                  imageUrl: article.imageUrl,
                  width: 82,
                  height: 82,
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
                    Text(
                      '${article.publisher} • ${article.time}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.workSans(
                        color: _newsMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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

class _ArticleThumbnail extends StatelessWidget {
  const _ArticleThumbnail({required this.imageUrl, this.width, this.height});

  final String imageUrl;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty) {
      return _ArticleThumbnailFallback(width: width, height: height);
    }

    return Image.network(
      trimmedUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _ArticleThumbnailFallback(width: width, height: height);
      },
    );
  }
}

class _ArticleThumbnailFallback extends StatelessWidget {
  const _ArticleThumbnailFallback({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFE0B8), Color(0xFFBF5700)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -16,
            right: -10,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -18,
            left: -12,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pody News',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.newsreader(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bài viết nổi bật',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.workSans(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
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
