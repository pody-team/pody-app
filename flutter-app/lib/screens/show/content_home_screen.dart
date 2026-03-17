import 'package:flutter/material.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/features/content/presentation/content_scope.dart';
import 'package:pody/screens/show/content_show_detail_screen.dart';
import 'package:pody/theme/app_colors.dart';

class ContentHomeScreen extends StatefulWidget {
  const ContentHomeScreen({super.key});

  @override
  State<ContentHomeScreen> createState() => _ContentHomeScreenState();
}

class _ContentHomeScreenState extends State<ContentHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  ContentHomeFeed? _feed;
  String _selectedCategory = 'Tat ca';
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
          _selectedCategory = 'Tat ca';
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
      'Tat ca',
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
              _selectedCategory == 'Tat ca' ||
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
              card.show.aiHost.displayName.toLowerCase().contains(query) ||
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
    final categories = feed == null ? const ['Tat ca'] : _allCategories(feed);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.white,
          backgroundColor: kBgCard,
          onRefresh: _loadFeed,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _buildSearchBar(),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return _buildFilterChip(category);
                    },
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemCount: categories.length,
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
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Khong co show nao phu hop voi bo loc hien tai.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.56),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final card = filteredShows[index];
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        index == 0 ? 16 : 0,
                        16,
                        index == filteredShows.length - 1 ? 120 : 16,
                      ),
                      child: _buildShowCard(card),
                    );
                  }, childCount: filteredShows.length),
                ),
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
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Icon(Icons.search, color: Colors.white38),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Tim show, AI host, episode...',
                hintStyle: TextStyle(color: Colors.white30),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: _searchController.clear,
              icon: const Icon(Icons.close, color: Colors.white38),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isActive = _selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? kTikRed : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white60,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildShowCard(ContentHomeShowCard card) {
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
          color: kBgCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 188,
                  width: double.infinity,
                  child: Image.network(show.coverImageUrl, fit: BoxFit.cover),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.86),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                show.primaryCategory,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              show.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'AI host ${show.aiHost.displayName}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'AI HOST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  if (card.previewEpisodes.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Show nay da co AI host o cap show, episode dau tien dang duoc chuan bi.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.66),
                          height: 1.5,
                        ),
                      ),
                    )
                  else
                    ...card.previewEpisodes.map((episode) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Text(
                              '${episode.formattedDuration} •',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.36),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                episode.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.play_circle_outline_rounded,
                              color: kTikTeal,
                              size: 18,
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        color: Colors.white.withValues(alpha: 0.38),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${show.formattedSubscriberCount} theo doi',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.queue_music_rounded,
                        color: Colors.white.withValues(alpha: 0.38),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${show.totalEpisodeCount} tap',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Xem chi tiet',
                        style: TextStyle(
                          color: kTikTeal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  String _humanizeError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Khong the tai noi dung luc nay.';
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
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.headphones_rounded,
              color: Colors.white.withValues(alpha: 0.22),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                onRetry();
              },
              child: const Text('Thu lai'),
            ),
          ],
        ),
      ),
    );
  }
}
