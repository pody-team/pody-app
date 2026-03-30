import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/data/article_scope.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/news/article_detail_screen.dart';
import 'package:pody/theme/app_colors.dart';

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
  bool _hasMore = true;
  int _offset = 0;
  String _searchQuery = '';
  String? _selectedCategorySlug;
  String? _selectedCategoryName;
  String? _errorMessage;
  List<NewsCategory> _categories = const <NewsCategory>[];
  List<NewsArticle> _articles = const <NewsArticle>[];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
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
    } on ApiException catch (_) {
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
        _errorMessage = error.message;
        _isLoading = false;
        _isLoadingMore = false;
        if (reset) {
          _articles = const <NewsArticle>[];
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Không tải được danh sách bài báo.';
        _isLoading = false;
        _isLoadingMore = false;
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
    if (position.pixels >= position.maxScrollExtent - 280) {
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

  void _submitSearch(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();
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

  String get _collectionTitle {
    if (_searchQuery.isNotEmpty) {
      return 'Kết quả cho "$_searchQuery"';
    }
    if (_selectedCategoryName != null && _selectedCategoryName!.isNotEmpty) {
      return _selectedCategoryName!;
    }
    return 'Tin mới trong ngày';
  }

  String get _collectionSubtitle {
    if (_searchQuery.isNotEmpty && _selectedCategoryName != null) {
      return 'Đang lọc trong $_selectedCategoryName.';
    }
    if (_searchQuery.isNotEmpty) {
      return 'Tìm nhanh theo tiêu đề và mô tả bài báo.';
    }
    if (_selectedCategoryName != null) {
      return 'Những bài viết mới nhất thuộc chủ đề này.';
    }
    return 'Khám phá các chủ đề đang cập nhật trên Pody News.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBlack,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshArticles,
          color: kTikRed,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bản tin',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Đọc, tìm kiếm và theo dõi tin tức theo từng thể loại.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSearchBar(),
                      const SizedBox(height: 16),
                      _buildOverviewCard(),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildCategories()),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: kTikRed),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(),
                )
              else if (_articles.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else ...[
                SliverToBoxAdapter(
                  child: _buildHighlightStory(_articles.first),
                ),
                if (_articles.length > 1)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final article = _articles[index + 1];
                        return _buildCompactNewsRow(article);
                      }, childCount: _articles.length - 1),
                    ),
                  ),
                SliverToBoxAdapter(child: _buildLoadingFooter()),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _handleSearchChanged,
        onSubmitted: _submitSearch,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm bài báo, chủ đề, xu hướng...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kTikRed.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _selectedCategoryName ?? 'Tất cả',
                  style: TextStyle(
                    color: kTikRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_articles.length} bài đang hiện',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _collectionTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _collectionSubtitle,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMiniStat(
                icon: Icons.grid_view_rounded,
                label: '${_categories.length} thể loại',
              ),
              _buildMiniStat(
                icon: Icons.search_rounded,
                label: _searchQuery.isEmpty ? 'Tìm kiếm mở rộng' : 'Đang tìm kiếm',
              ),
              _buildMiniStat(
                icon: Icons.newspaper_rounded,
                label: _hasMore ? 'Còn thêm bài viết' : 'Đã tải hết',
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final chips = <Widget>[
      _buildCategoryChip(
        label: 'Tất cả',
        count: null,
        isSelected: _selectedCategorySlug == null,
        onTap: () => _selectCategory(null),
      ),
      ..._categories.map(
        (category) => _buildCategoryChip(
          label: category.name,
          count: category.articleCount,
          isSelected: _selectedCategorySlug == category.slug,
          onTap: () => _selectCategory(category),
        ),
      ),
    ];

    return Container(
      height: 52,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          ...chips,
          if (_isLoadingCategories)
            const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kTikRed,
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
    required int? count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? kTikRed : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? kTikRed.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            const Text(
              'Không tải được bài báo',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _fetchArticles(reset: true),
              style: FilledButton.styleFrom(backgroundColor: kTikRed),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final title = _searchQuery.isNotEmpty
        ? 'Không tìm thấy bài viết phù hợp'
        : 'Chưa có bài viết trong bộ lọc này';
    final subtitle = _searchQuery.isNotEmpty
        ? 'Thử đổi từ khóa hoặc chọn thể loại khác để xem thêm bài báo.'
        : 'Hãy thử chuyển sang một thể loại khác hoặc kéo để tải lại.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightStory(NewsArticle article) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleDetailScreen(article: article),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  article.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.white10,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white30,
                        size: 40,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: article.categories.take(3).map((category) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: Colors.white70,
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              article.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white60,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${article.publisher} • ${article.time}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildAddButton(article),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactNewsRow(NewsArticle article) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleDetailScreen(article: article),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 88,
                height: 88,
                child: Image.network(
                  article.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.white10,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white30,
                        size: 24,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${article.category} • ${article.publisher}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildAddButton(article),
                const SizedBox(height: 18),
                Text(
                  article.time,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingFooter() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: kTikRed)),
      );
    }

    if (!_hasMore && _articles.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Text(
            'Đã hiển thị hết bài viết',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAddButton(NewsArticle article) {
    return GestureDetector(
      onTap: () => setState(() => article.isAdded = !article.isAdded),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: article.isAdded
              ? kTikRed.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          article.isAdded ? Icons.check : Icons.add,
          color: article.isAdded ? kTikRed : Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
