import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pody/theme/app_colors.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/utils/player_utils.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  int _selectedTab = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isHeaderVisible = true;

  final List<String> _recentSearches = [
    'Technology',
    'True Crime',
    'Design Systems',
  ];

  final List<Map<String, dynamic>> _topResults = [
    {
      'title': MockData.podcasts[0].title,
      'subtitle': 'Hosted by ${MockData.podcasts[0].hostsLabel}',
      'tag': MockData.podcasts[0].category.toUpperCase(),
      'eps': '${MockData.podcasts[0].totalEpisodeCount} eps',
      'image': MockData.podcasts[0].imageUrl,
      'isImage': true,
      'podcastIndex': 0,
    },
    {
      'title': MockData.podcasts[1].title,
      'subtitle': 'Hosted by ${MockData.podcasts[1].hostsLabel}',
      'tag': MockData.podcasts[1].category.toUpperCase(),
      'eps': '${MockData.podcasts[1].totalEpisodeCount} eps',
      'image': MockData.podcasts[1].imageUrl,
      'isImage': true,
      'podcastIndex': 1,
    },
    {
      'title': 'The Creative Loop',
      'subtitle': 'Design Weekly',
      'tag': 'ART',
      'eps': '205 eps',
      'icon': Icons.graphic_eq,
      'isImage': false,
    },
    {
      'title': 'Nature Calls',
      'subtitle': 'Earth Foundation',
      'tag': 'NATURE',
      'eps': '42 eps',
      'icon': Icons.forest,
      'isImage': false,
    },
  ];

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Comedy', 'icon': Icons.theater_comedy},
    {'name': 'News', 'icon': Icons.newspaper},
    {'name': 'Education', 'icon': Icons.school},
    {'name': 'Business', 'icon': Icons.trending_up},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
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
    final showHeader = _isHeaderVisible || _searchFocus.hasFocus;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E13),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: showHeader
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        children: [
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: kBgCard,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(left: 16),
                                  child: Icon(
                                    Icons.search,
                                    color: Colors.white38,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocus,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    decoration: const InputDecoration(
                                      filled: false,
                                      hintText:
                                          'Search podcasts, episodes, or hosts...',
                                      hintStyle: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 14,
                                      ),
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
                                IconButton(
                                  icon: const Icon(
                                    Icons.mic,
                                    color: Colors.white38,
                                  ),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedTab = 0),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 0
                                          ? Colors.white
                                          : kBgCard,
                                      borderRadius: BorderRadius.circular(24),
                                      border: _selectedTab == 0
                                          ? null
                                          : Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.05,
                                              ),
                                            ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Podcasts',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedTab == 0
                                            ? Colors.black
                                            : Colors.white54,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedTab = 1),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 1
                                          ? Colors.white
                                          : kBgCard,
                                      borderRadius: BorderRadius.circular(24),
                                      border: _selectedTab == 1
                                          ? null
                                          : Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.05,
                                              ),
                                            ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Episodes',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedTab == 1
                                            ? Colors.black
                                            : Colors.white54,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Scrollable Content
            Expanded(
              child: NotificationListener<UserScrollNotification>(
                onNotification: _handleScroll,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  children: [
                    // Recent Searches
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'RECENT SEARCHES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _recentSearches.clear()),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _recentSearches.map((search) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: kBgCard,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.history,
                                size: 16,
                                color: Colors.white38,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                search,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _recentSearches.remove(search),
                                  );
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white24,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // Top Results
                    const Text(
                      'TOP RESULTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._topResults.map((item) => _buildResultCard(item)),
                    const SizedBox(height: 32),

                    // Browse Categories
                    const Text(
                      'BROWSE CATEGORIES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.7,
                      children: _categories
                          .map((cat) => _buildCategoryCard(cat))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () {
        if (item.containsKey('podcastIndex')) {
          final podcast = MockData.podcasts[item['podcastIndex'] as int];
          openPodcastDetail(context, podcast);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item['isImage'] == true
                  ? Image.network(
                      item['image'],
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: Colors.white54,
                        size: 32,
                      ),
                    ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['subtitle'],
                    style: const TextStyle(fontSize: 12, color: Colors.white38),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
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
                          item['tag'],
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white54,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${item['eps']}',
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

            // Add button
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white54, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Stack(
        children: [
          // Background icon
          Positioned(
            top: 8,
            right: 8,
            child: Icon(
              cat['icon'] as IconData,
              size: 40,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          // Label
          Positioned(
            left: 14,
            bottom: 14,
            child: Text(
              cat['name'],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
