import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pody/utils/player_utils.dart';
import 'package:pody/theme/app_colors.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'Tất cả';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearching = false;
  bool _isHeaderVisible = true;

  final List<String> _recentSearches = [
    'Technology',
    'True Crime',
    'Design Systems',
  ];

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Comedy', 'icon': Icons.theater_comedy, 'color': 0xFF6C5CE7},
    {'name': 'News', 'icon': Icons.newspaper, 'color': 0xFF00B894},
    {'name': 'Education', 'icon': Icons.school, 'color': 0xFFE17055},
    {'name': 'Business', 'icon': Icons.trending_up, 'color': 0xFF0984E3},
    {'name': 'Science', 'icon': Icons.science, 'color': 0xFFFDAA5D},
    {'name': 'Music', 'icon': Icons.music_note, 'color': 0xFFE84393},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    _searchFocus.addListener(() {
      setState(() {
        _isSearching = _searchFocus.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Show> get _filteredPodcasts {
    final query = _searchController.text.toLowerCase();
    var shows = MockData.shows.where((p) {
      if (_selectedCategory == 'Tất cả') {
        return true;
      }
      if (_selectedCategory == 'Công nghệ' && p.category == 'Công nghệ') {
        return true;
      }
      if (_selectedCategory == 'Câu chuyện' && p.category == 'Điều tra') {
        return true;
      }
      if (_selectedCategory == 'Ngắn < 15p' &&
          p.episodes.isNotEmpty &&
          p.episodes.first.duration.inMinutes < 15) {
        return true;
      }
      return p.category.contains(_selectedCategory);
    }).toList();

    if (query.isNotEmpty) {
      shows = shows.where((p) {
        return p.title.toLowerCase().contains(query) ||
            p.category.toLowerCase().contains(query) ||
            p.hostsLabel.toLowerCase().contains(query) ||
            p.episodes.any((e) => e.title.toLowerCase().contains(query));
      }).toList();
    }

    return shows;
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() => _isSearching = false);
  }

  bool _handleScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (_searchFocus.hasFocus) {
      if (!_isHeaderVisible) {
        setState(() => _isHeaderVisible = true);
      }
      return false;
    }

    if (notification.direction == ScrollDirection.reverse && _isHeaderVisible) {
      setState(() => _isHeaderVisible = false);
    } else if (notification.direction == ScrollDirection.forward &&
        !_isHeaderVisible) {
      setState(() => _isHeaderVisible = true);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final shows = _filteredPodcasts;
    final query = _searchController.text;
    final showSearchResults = _isSearching || query.isNotEmpty;
    final showHeader = _isHeaderVisible || _searchFocus.hasFocus;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: showHeader
                  ? Column(
                      children: [
                        _buildSearchBar(query),
                        const SizedBox(height: 10),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: NotificationListener<UserScrollNotification>(
                onNotification: _handleScroll,
                child: showSearchResults
                    ? _buildSearchResults(shows)
                    : _buildHomeContent(shows),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(String query) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isSearching
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Icon(Icons.search, color: Colors.white38, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                style: const TextStyle(fontSize: 14, color: Colors.white),
                decoration: const InputDecoration(
                  filled: false,
                  hintText: 'Tìm shows, episodes...',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_isSearching || query.isNotEmpty)
              GestureDetector(
                onTap: _clearSearch,
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.close, color: Colors.white38, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  // HOME CONTENT (default view)
  // ────────────────────────────────────────────
  Widget _buildHomeContent(List<Show> shows) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // Filter chips (scrollable)
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            children: [
              _buildFilterChip('Tất cả'),
              _buildFilterChip('Công nghệ'),
              _buildFilterChip('Câu chuyện'),
              _buildFilterChip('Ngắn < 15p'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Podcast Cards
        ...shows.map(
          (show) => Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: _buildPodcastCard(context, show),
          ),
        ),

        if (shows.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'Không có show nào phù hợp.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ),

        // Browse Categories section
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            'BROWSE CATEGORIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white38,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.8,
            children: _categories
                .map((cat) => _buildCategoryCard(cat))
                .toList(),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  // ────────────────────────────────────────────
  // SEARCH RESULTS
  // ────────────────────────────────────────────
  Widget _buildSearchResults(List<Show> shows) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Recent searches
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GẦN ĐÂY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white38,
                  letterSpacing: 1.5,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _recentSearches.clear()),
                child: const Text(
                  'Xóa tất cả',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((search) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = search;
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: search.length),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.history,
                        size: 14,
                        color: Colors.white30,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        search,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Results header
        Text(
          'KẾT QUẢ (${shows.length})',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        // Result cards
        if (shows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  color: Colors.white.withValues(alpha: 0.15),
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Không tìm thấy kết quả',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          )
        else
          ...shows.map((show) => _buildSearchResultCard(show)),
      ],
    );
  }

  // ────────────────────────────────────────────
  // WIDGETS
  // ────────────────────────────────────────────

  Widget _buildFilterChip(String label) {
    final isActive = _selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? kTikRed : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white60,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPodcastCard(BuildContext context, Show show) {
    return GestureDetector(
      onTap: () {
        openShowDetail(context, show);
      },
      child: Container(
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(show.imageUrl, fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.2, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  show.category,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                show.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                show.hostsLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: kTikRed,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              show.isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Episode List
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                children: [
                  ...List.generate(show.episodes.length, (index) {
                    final ep = show.episodes[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.3),
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ep.title,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.play_circle_outline_rounded,
                            color: kTikTeal,
                            size: 18,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.06),
                    height: 1,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        color: Colors.white38,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${show.subscriberCount} theo dõi',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.queue_music_rounded,
                        color: Colors.white38,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${show.totalEpisodeCount} tập',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Xem tất cả →',
                        style: TextStyle(
                          fontSize: 12,
                          color: kTikTeal,
                          fontWeight: FontWeight.w600,
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

  Widget _buildSearchResultCard(Show show) {
    return GestureDetector(
      onTap: () => openShowDetail(context, show),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                show.imageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    show.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    show.hostsLabel,
                    style: const TextStyle(fontSize: 12, color: Colors.white38),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          show.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white54,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${show.totalEpisodeCount} tập',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.2),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat) {
    final color = Color(cat['color'] as int);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            right: 8,
            child: Icon(
              cat['icon'] as IconData,
              size: 36,
              color: color.withValues(alpha: 0.3),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 12,
            child: Text(
              cat['name'],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
