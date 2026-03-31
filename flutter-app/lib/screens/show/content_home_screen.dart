import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/features/content/presentation/content_scope.dart';
import 'package:pody/screens/show/content_show_detail_screen.dart';

const _homeCanvas = Color(0xFFF7F0E8);
const _homePrimary = Color(0xFFBF5700);
const _homeSecondary = Color(0xFFE1AD01);
const _homeTertiary = Color(0xFF566931);
const _homeNeutral = Color(0xFF3E2723);
const _homeSurface = Color(0xFFFFFBF6);
const _homeSurfaceStrong = Color(0xFFF1E2D3);

class ContentHomeScreen extends StatefulWidget {
  const ContentHomeScreen({super.key});

  @override
  State<ContentHomeScreen> createState() => _ContentHomeScreenState();
}

class _ContentHomeScreenState extends State<ContentHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  ContentHomeFeed? _feed;
  String _selectedCategory = 'Tất cả';
  bool _isLoading = false;
  String? _errorMessage;
  bool _didLoad = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) {
      return;
    }
    _didLoad = true;
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = ContentScope.of(context);
      final feed = await repository.getHomeFeed();
      if (!mounted) {
        return;
      }

      setState(() {
        _feed = feed;
        if (!_allCategories(feed).contains(_selectedCategory)) {
          _selectedCategory = 'Tất cả';
        }
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

  List<String> _allCategories(ContentHomeFeed feed) {
    final items = <String>{
      'Tất cả',
      ...feed.categories.where((item) => item.isNotEmpty),
    };
    return items.toList(growable: false);
  }

  List<ContentHomeShowCard> get _filteredShows {
    final feed = _feed;
    if (feed == null) {
      return const [];
    }

    final query = _searchController.text.trim().toLowerCase();
    return feed.shows
        .where((card) {
          final matchesCategory =
              _selectedCategory == 'Tất cả' ||
              card.show.primaryCategory.toLowerCase() ==
                  _selectedCategory.toLowerCase();
          if (!matchesCategory) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          return card.show.title.toLowerCase().contains(query) ||
              card.show.primaryCategory.toLowerCase().contains(query) ||
              card.show.hostNames.toLowerCase().contains(query) ||
              card.previewEpisodes.any(
                (episode) => episode.title.toLowerCase().contains(query),
              );
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final filteredShows = _filteredShows;
    final categories = feed == null ? const ['Tất cả'] : _allCategories(feed);
    final featured = filteredShows.isEmpty ? null : filteredShows.first;
    final editorialList = featured == null
        ? const <ContentHomeShowCard>[]
        : filteredShows.skip(1).toList(growable: false);

    return Scaffold(
      backgroundColor: _homeCanvas,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_homeSurface, _homeCanvas],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: _homePrimary,
            backgroundColor: _homeSurface,
            onRefresh: _loadFeed,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    child: _HomeHero(
                      searchBar: _buildSearchBar(),
                      categories: categories,
                      selectedCategory: _selectedCategory,
                      onCategorySelected: (category) {
                        setState(() => _selectedCategory = category);
                      },
                    ),
                  ),
                ),
                if (_isLoading && feed == null)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  )
                else if (_errorMessage != null && feed == null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorState(
                      message: _errorMessage!,
                      onRetry: _loadFeed,
                    ),
                  )
                else if (filteredShows.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else ...[
                  if (featured != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                        child: _FeaturedShowCard(card: featured),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
                      child: _SectionHeading(
                        eyebrow: 'Gợi ý hôm nay',
                        title: editorialList.isEmpty
                            ? 'Show nổi bật'
                            : 'Thêm cho hàng chờ',
                        description: editorialList.isEmpty
                            ? 'Mở show nổi bật để nghe ngay các tập đầu tiên.'
                            : 'Danh sách show còn lại được sắp theo nội dung mới và host nổi bật.',
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final card = editorialList.isEmpty
                            ? featured!
                            : editorialList[index];
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            18,
                            0,
                            18,
                            index ==
                                    (editorialList.isEmpty
                                        ? 1
                                        : editorialList.length)
                                ? 120
                                : 14,
                          ),
                          child: _EditorialShowCard(card: card),
                        );
                      },
                      childCount: editorialList.isEmpty
                          ? 1
                          : editorialList.length,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _homePrimary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: _homeNeutral.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Icon(
              Icons.search_rounded,
              color: _homeNeutral.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              cursorColor: _homePrimary,
              style: GoogleFonts.workSans(
                color: _homeNeutral,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFFFFEFC),
                hintText: 'Tìm show, host hoặc tên tập...',
                hintStyle: GoogleFonts.workSans(
                  color: _homeNeutral.withValues(alpha: 0.42),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: _searchController.clear,
              icon: Icon(
                Icons.close_rounded,
                color: _homeNeutral.withValues(alpha: 0.42),
              ),
            ),
        ],
      ),
    );
  }

  String _humanizeError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Không thể tải nội dung lúc này.';
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.searchBar,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final Widget searchBar;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _homePrimary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _homePrimary.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -12,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _homeSecondary.withValues(alpha: 0.28),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -12,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: _homeTertiary.withValues(alpha: 0.26),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Pody hằng ngày',
                        style: GoogleFonts.workSans(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white.withValues(alpha: 0.78),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Âm thanh chọn lọc, mở là nghe ngay.',
                  style: GoogleFonts.newsreader(
                    color: Colors.white,
                    fontSize: 26,
                    height: 0.96,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Công nghệ, phân tích và storytelling theo nhịp gọn hơn.',
                  style: GoogleFonts.workSans(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                searchBar,
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = selectedCategory == category;
                      return GestureDetector(
                        onTap: () => onCategorySelected(category),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _homeSecondary
                                : Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            category,
                            style: GoogleFonts.workSans(
                              color: isSelected ? _homeNeutral : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: GoogleFonts.workSans(
            color: _homePrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: GoogleFonts.newsreader(
            color: _homeNeutral,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 0.98,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: GoogleFonts.workSans(
            color: _homeNeutral.withValues(alpha: 0.7),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _FeaturedShowCard extends StatelessWidget {
  const _FeaturedShowCard({required this.card});

  final ContentHomeShowCard card;

  @override
  Widget build(BuildContext context) {
    final show = card.show;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ContentShowDetailScreen(showId: show.id, initialSummary: show),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: _homeSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _homePrimary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: _homeNeutral.withValues(alpha: 0.08),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: _NetworkImage(
                    imageUrl: show.coverImageUrl,
                    fallbackColor: _homeSurfaceStrong,
                    iconColor: _homePrimary,
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      show.primaryCategory,
                      style: GoogleFonts.workSans(
                        color: _homePrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _homeSecondary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: _homeNeutral,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    show.title,
                    style: GoogleFonts.newsreader(
                      color: _homeNeutral,
                      fontSize: 30,
                      height: 0.96,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Dẫn bởi ${show.hostNames}',
                    style: GoogleFonts.workSans(
                      color: _homeNeutral.withValues(alpha: 0.72),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      _MetaPill(
                        icon: Icons.people_outline_rounded,
                        text: '${show.formattedSubscriberCount} theo dõi',
                      ),
                      _MetaPill(
                        icon: Icons.queue_music_rounded,
                        text: '${show.totalEpisodeCount} tập',
                      ),
                      _MetaPill(
                        icon: Icons.graphic_eq_rounded,
                        text: show.contentType,
                      ),
                    ],
                  ),
                  if (card.previewEpisodes.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: _homeCanvas,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < card.previewEpisodes.length;
                            index += 1
                          )
                            _PreviewEpisodeRow(
                              episode: card.previewEpisodes[index],
                              isLast: index == card.previewEpisodes.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorialShowCard extends StatelessWidget {
  const _EditorialShowCard({required this.card});

  final ContentHomeShowCard card;

  @override
  Widget build(BuildContext context) {
    final show = card.show;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ContentShowDetailScreen(showId: show.id, initialSummary: show),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _homeNeutral.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 92,
                height: 112,
                child: _NetworkImage(
                  imageUrl: show.coverImageUrl,
                  fallbackColor: _homeSurfaceStrong,
                  iconColor: _homePrimary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _homeTertiary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          show.primaryCategory,
                          style: GoogleFonts.workSans(
                            color: _homeTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_outward_rounded,
                        color: _homeNeutral.withValues(alpha: 0.34),
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    show.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.newsreader(
                      color: _homeNeutral,
                      fontSize: 24,
                      height: 0.96,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    show.hostNames,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.workSans(
                      color: _homeNeutral.withValues(alpha: 0.64),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    card.previewEpisodes.isEmpty
                        ? 'Show này đang chờ tập đầu tiên được phát hành.'
                        : card.previewEpisodes.first.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.workSans(
                      color: _homeNeutral.withValues(alpha: 0.76),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _TinyMeta(text: show.formattedSubscriberCount),
                      const SizedBox(width: 10),
                      _TinyMeta(text: '${show.totalEpisodeCount} tập'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewEpisodeRow extends StatelessWidget {
  const _PreviewEpisodeRow({required this.episode, required this.isLast});

  final ContentPreviewEpisode episode;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: _homeNeutral.withValues(alpha: 0.08)),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _homeSecondary.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '${episode.durationSeconds > 0 ? episode.durationSeconds ~/ 60 : 0}',
              style: GoogleFonts.workSans(
                color: _homeNeutral,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              episode.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.workSans(
                color: _homeNeutral,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            episode.formattedDuration,
            style: GoogleFonts.workSans(
              color: _homeNeutral.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _homePrimary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _homePrimary),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.workSans(
              color: _homeNeutral,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyMeta extends StatelessWidget {
  const _TinyMeta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.workSans(
        color: _homeNeutral.withValues(alpha: 0.46),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({
    required this.imageUrl,
    required this.fallbackColor,
    required this.iconColor,
  });

  final String imageUrl;
  final Color fallbackColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return DecoratedBox(
          decoration: BoxDecoration(color: fallbackColor),
          child: Center(
            child: Icon(
              Icons.podcasts_rounded,
              color: iconColor.withValues(alpha: 0.6),
              size: 30,
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _homePrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: _homePrimary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Chưa có show phù hợp',
              style: GoogleFonts.newsreader(
                color: _homeNeutral,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Thử đổi category hoặc từ khóa tìm kiếm để mở rộng danh sách đề xuất.',
              textAlign: TextAlign.center,
              style: GoogleFonts.workSans(
                color: _homeNeutral.withValues(alpha: 0.68),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _homeSecondary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.wifi_tethering_error_rounded,
                color: _homePrimary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Không tải được home feed',
              style: GoogleFonts.newsreader(
                color: _homeNeutral,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.workSans(
                color: _homeNeutral.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                onRetry();
              },
              style: FilledButton.styleFrom(
                backgroundColor: _homePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Thử lại',
                style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
