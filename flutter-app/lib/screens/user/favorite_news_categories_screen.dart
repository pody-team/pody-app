import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/data/article_scope.dart';
import 'package:pody/models/news/news_category.dart';

const _favoriteCanvas = Color(0xFFF7F0E8);
const _favoritePrimary = Color(0xFFBF5700);
const _favoriteNeutral = Color(0xFF3E2723);
const _favoriteSurface = Color(0xFFFFFBF6);
const _favoriteSurfaceStrong = Color(0xFFF1E2D3);
const _favoriteMaxSelection = 5;

class FavoriteNewsCategoriesScreen extends StatefulWidget {
  const FavoriteNewsCategoriesScreen({super.key});

  @override
  State<FavoriteNewsCategoriesScreen> createState() =>
      _FavoriteNewsCategoriesScreenState();
}

class _FavoriteNewsCategoriesScreenState
    extends State<FavoriteNewsCategoriesScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  List<NewsCategory> _allCategories = const <NewsCategory>[];
  List<String> _selectedCategoryIds = const <String>[];
  List<String> _savedCategoryIds = const <String>[];
  bool _didLoadOnce = false;

  bool get _hasChanges => !_sameIds(_selectedCategoryIds, _savedCategoryIds);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadOnce) {
      return;
    }
    _didLoadOnce = true;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ArticleScope.of(context);
      final results = await Future.wait<dynamic>([
        service.fetchCategories(),
        service.fetchFavoriteCategories(),
      ]);
      if (!mounted) {
        return;
      }

      final allCategories = results[0] as List<NewsCategory>;
      final favoriteCategories = results[1] as List<NewsCategory>;
      final favoriteIds = favoriteCategories
          .map((category) => category.id)
          .where((id) => id.isNotEmpty)
          .toList();

      setState(() {
        _allCategories = allCategories;
        _savedCategoryIds = favoriteIds;
        _selectedCategoryIds = List<String>.from(favoriteIds);
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
    return 'Không thể tải danh sách thể loại lúc này.';
  }

  void _toggleCategory(NewsCategory category) {
    final isSelected = _selectedCategoryIds.contains(category.id);
    if (!isSelected && _selectedCategoryIds.length >= _favoriteMaxSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn chỉ có thể chọn tối đa 5 thể loại yêu thích.'),
        ),
      );
      return;
    }

    setState(() {
      if (isSelected) {
        _selectedCategoryIds = _selectedCategoryIds
            .where((id) => id != category.id)
            .toList();
      } else {
        _selectedCategoryIds = [..._selectedCategoryIds, category.id];
      }
    });
  }

  Future<void> _savePreferences() async {
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy chọn ít nhất 1 thể loại yêu thích.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final savedCategories = await ArticleScope.of(
        context,
      ).saveFavoriteCategoryIds(_selectedCategoryIds);
      if (!mounted) {
        return;
      }

      final savedIds = savedCategories
          .map((category) => category.id)
          .where((id) => id.isNotEmpty)
          .toList();
      setState(() {
        _savedCategoryIds = savedIds;
        _selectedCategoryIds = List<String>.from(savedIds);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật thể loại yêu thích.')),
      );
      Navigator.of(context).pop(savedCategories);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _favoriteCanvas,
      appBar: AppBar(
        backgroundColor: _favoriteSurface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: _favoriteNeutral,
        ),
        title: Text(
          'Thể loại báo yêu thích',
          style: GoogleFonts.workSans(
            color: _favoriteNeutral,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : _errorMessage != null
            ? _FavoriteErrorState(message: _errorMessage!, onRetry: _loadData)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _favoriteSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _favoritePrimary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chọn 1 - 5 thể loại để ưu tiên trên mục "Tất cả".',
                            style: GoogleFonts.newsreader(
                              color: _favoriteNeutral,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Đã chọn ${_selectedCategoryIds.length}/$_favoriteMaxSelection thể loại.',
                            style: GoogleFonts.workSans(
                              color: _favoriteNeutral.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                      itemCount: _allCategories.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final category = _allCategories[index];
                        final isSelected = _selectedCategoryIds.contains(
                          category.id,
                        );
                        return _FavoriteCategoryTile(
                          category: category,
                          isSelected: isSelected,
                          onTap: () => _toggleCategory(category),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving || !_hasChanges
                            ? null
                            : _savePreferences,
                        style: FilledButton.styleFrom(
                          backgroundColor: _favoritePrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Lưu thể loại yêu thích',
                                style: GoogleFonts.workSans(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FavoriteCategoryTile extends StatelessWidget {
  const _FavoriteCategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final NewsCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? _favoriteSurfaceStrong : _favoriteSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? _favoritePrimary
                  : _favoriteNeutral.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: GoogleFonts.workSans(
                        color: _favoriteNeutral,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((category.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        category.description!,
                        style: GoogleFonts.workSans(
                          color: _favoriteNeutral.withValues(alpha: 0.64),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? _favoritePrimary
                    : _favoriteNeutral.withValues(alpha: 0.34),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteErrorState extends StatelessWidget {
  const _FavoriteErrorState({required this.message, required this.onRetry});

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
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.workSans(color: _favoriteNeutral, height: 1.5),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

bool _sameIds(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
