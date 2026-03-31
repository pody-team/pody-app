import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/screens/creation/ai_summary_setup_screen.dart';

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
  int _selectedCategoryIndex = 0;
  late final List<bool> _addedStates = MockData.newsArticles
      .map((a) => a.isAdded)
      .toList();

  @override
  Widget build(BuildContext context) {
    final articles = MockData.newsArticles;
    final highlightedCount = _addedStates.where((value) => value).length;

    return Scaffold(
      backgroundColor: _newsCanvas,
      body: SafeArea(
        child: CustomScrollView(
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
            if (articles.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: _buildHighlightStory(0, articles[0]),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == 0) {
                    return const SizedBox.shrink();
                  }
                  return _buildCompactNewsRow(index, articles[index]);
                }, childCount: articles.length),
              ),
            ),
          ],
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
            'Dựa trên ${highlightedCount > 0 ? highlightedCount : 5} tin tức bạn đã chọn và xu hướng Tech.',
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
                    MaterialPageRoute(
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

  Widget _buildHighlightStory(int index, NewsArticle article) {
    return Container(
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
              _buildAddButton(index),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactNewsRow(int index, NewsArticle article) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                      Text('•', style: GoogleFonts.workSans(color: _newsMuted)),
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
            _buildAddButton(index),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(int index) {
    final isAdded = _addedStates[index];
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        setState(() {
          _addedStates[index] = !_addedStates[index];
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isAdded ? _newsPrimary : _newsSurfaceStrong,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          isAdded ? 'Đã chọn' : 'Thêm',
          style: GoogleFonts.workSans(
            color: isAdded ? Colors.white : _newsNeutral,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
