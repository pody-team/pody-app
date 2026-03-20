import 'package:flutter/material.dart';
import 'package:pody/data/article_scope.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/creation/ai_summary_setup_screen.dart';
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

  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  List<NewsArticle> _articles = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchArticles(reset: true);
    });
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
      });
    } else {
      if (_isLoading || _isLoadingMore || !_hasMore) {
        return;
      }
      setState(() => _isLoadingMore = true);
    }

    final apiService = ArticleScope.of(context);
    final categories = MockData.newsCategories;
    String? categoryFilter = _selectedCategoryIndex == 0
        ? null
        : categories[_selectedCategoryIndex];

    if (categoryFilter != null && categoryFilter.contains(' ')) {
      categoryFilter = categoryFilter.split(' ').last;
    }

    final results = await apiService.fetchArticles(
      category: categoryFilter,
      query: _searchQuery.isEmpty ? null : _searchQuery,
      limit: _pageSize,
      offset: reset ? 0 : _offset,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      if (reset) {
        _articles = results;
        _isLoading = false;
      } else {
        _articles = [..._articles, ...results];
        _isLoadingMore = false;
      }

      _offset = (reset ? 0 : _offset) + results.length;
      _hasMore = results.length == _pageSize;

      if (reset) {
        _isLoadingMore = false;
      }
    });
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

  Future<void> _refreshArticles() {
    return _fetchArticles(reset: true);
  }

  void _submitSearch(String value) {
    setState(() => _searchQuery = value.trim());
    _fetchArticles(reset: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
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
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Báº£n tin',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSearchBar(),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildAIPodcastStation(context)),
              SliverToBoxAdapter(child: _buildCategories()),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: kTikRed),
                  ),
                )
              else if (_articles.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        const Text(
                          'KhÃ´ng tÃ¬m tháº¥y bÃ i viáº¿t nÃ o',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: _buildHighlightStory(_articles.first),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: _submitSearch,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'TÃ¬m kiáº¿m tin tá»©c...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _fetchArticles(reset: true);
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildAIPodcastStation(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kTikRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: kTikRed, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'AI Playlist',
                      style: TextStyle(
                        color: kTikRed,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                '~12 phÃºt',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Báº£n tin sÃ¡ng cá»§a báº¡n',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dá»±a trÃªn cÃ¡c bÃ i bÃ¡o báº¡n Ä‘Ã£ chá»n vÃ  xu hÆ°á»›ng.',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kTikRed, kTikRed.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'â–¶ Táº¡o & Nghe',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AiSummarySetupScreen(),
                  ),
                ),
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.schedule, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final categories = MockData.newsCategories;
    return Container(
      height: 36,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategoryIndex = index);
              _fetchArticles(reset: true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? kTikRed
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                categories[index],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
            ),
          );
        },
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
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(article.imageUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              article.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              article.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      article.publisher,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      article.time,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                article.imageUrl,
                width: 76,
                height: 76,
                fit: BoxFit.cover,
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
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.publisher,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'Da hien thi het bai viet',
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
        width: 32,
        height: 32,
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
