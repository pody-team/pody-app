import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/data/article_scope.dart';
import 'package:pody/data/article_service.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/models/models.dart';

const Color _newsCanvas = Color(0xFFFFFBF6);
const Color _newsSurface = Color(0xFFFFFEFC);
const Color _newsSurfaceStrong = Color(0xFFF2E6D9);
const Color _newsPrimary = Color(0xFFBF5700);
const Color _newsNeutral = Color(0xFF3E2723);
const Color _newsMuted = Color(0xFF7E665F);

class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({super.key, required this.article});

  final NewsArticle article;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final GlobalKey _commentsSectionKey = GlobalKey();

  ArticleApiService? _apiService;
  late NewsArticle _article;
  late bool _isLiked;
  late bool _isLoved;
  late bool _isDisliked;
  bool _isLoadingDetail = false;
  bool _isLoadingComments = false;
  bool _isSubmittingComment = false;
  int _secondsRead = 0;
  Timer? _timer;
  List<Comment> _comments = const <Comment>[];

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    _syncInteractionState(_article);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _secondsRead++);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArticleData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService ??= ArticleScope.of(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _commentController.dispose();

    if (_apiService != null && _secondsRead > 0) {
      unawaited(_apiService!.sendMetric(widget.article.id, _secondsRead));
    }

    super.dispose();
  }

  Future<void> _loadArticleData() async {
    await _fetchFreshDetail();
    await _loadComments();
  }

  Future<void> _fetchFreshDetail() async {
    if (_isLoadingDetail) {
      return;
    }

    setState(() => _isLoadingDetail = true);
    final detail = await _apiService!.fetchArticleDetail(widget.article.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingDetail = false;
      if (detail != null) {
        _article = detail.copyWith(isAdded: _article.isAdded);
        widget.article
          ..isLiked = detail.isLiked
          ..isLoved = detail.isLoved
          ..isDisliked = detail.isDisliked;
        _syncInteractionState(_article);
      }
    });
  }

  Future<void> _loadComments() async {
    if (_isLoadingComments) {
      return;
    }

    setState(() => _isLoadingComments = true);
    final comments = await _apiService!.fetchComments(widget.article.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _comments = comments;
      _isLoadingComments = false;
    });
  }

  void _syncInteractionState(NewsArticle article) {
    _isLiked = article.isLiked;
    _isLoved = article.isLoved;
    _isDisliked = article.isDisliked;
  }

  Future<void> _handleInteraction(String type) async {
    final authController = AuthScope.of(context);
    if (authController.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần đăng nhập để tương tác với bài viết.'),
        ),
      );
      return;
    }

    final updatedArticle = await _apiService!.sendInteraction(
      widget.article.id,
      type,
    );

    if (!mounted) {
      return;
    }

    if (updatedArticle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không gửi được tương tác tới backend.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _article = updatedArticle.copyWith(isAdded: _article.isAdded);
      widget.article
        ..isLiked = updatedArticle.isLiked
        ..isLoved = updatedArticle.isLoved
        ..isDisliked = updatedArticle.isDisliked;
      _syncInteractionState(_article);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã cập nhật tương tác $type.'),
        duration: const Duration(seconds: 1),
        backgroundColor: _newsPrimary,
      ),
    );
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSubmittingComment) {
      return;
    }

    final authController = AuthScope.of(context);
    final session = authController.session;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để bình luận.')),
      );
      return;
    }

    setState(() => _isSubmittingComment = true);
    final createdComment = await _apiService!.createComment(
      widget.article.id,
      content: content,
      userName: session.user.displayName,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmittingComment = false;
      if (createdComment != null) {
        _commentController.clear();
        _comments = <Comment>[createdComment, ..._comments];
        _article = _article.copyWith(commentsCount: _article.commentsCount + 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _newsCanvas,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_newsSurface, _newsCanvas],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: _newsCanvas,
              surfaceTintColor: Colors.transparent,
              leading: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: _CircleIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              leadingWidth: 56,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ArticleHeroImage(imageUrl: _article.imageUrl),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _newsCanvas.withValues(alpha: 0.06),
                            _newsCanvas.withValues(alpha: 0.12),
                            _newsCanvas.withValues(alpha: 0.72),
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 132),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildArticleHeader(),
                    const SizedBox(height: 24),
                    _buildArticleBody(),
                    const SizedBox(height: 24),
                    _buildCommentsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildArticleHeader() {
    final categories = _article.categories.isNotEmpty
        ? _article.categories
        : <String>[_article.category];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _newsSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _newsNeutral.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.take(3).map((category) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
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
          const SizedBox(height: 16),
          Text(
            _article.title,
            style: GoogleFonts.newsreader(
              color: _newsNeutral,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          if (_article.description.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _article.description,
              style: GoogleFonts.workSans(
                color: _newsMuted,
                fontSize: 14,
                height: 1.65,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatPill(
                icon: Icons.person_outline_rounded,
                label: _article.publisher,
              ),
              _StatPill(icon: Icons.schedule_rounded, label: _article.time),
              _StatPill(
                icon: Icons.visibility_outlined,
                label: '${_article.viewCount} lượt xem',
              ),
              _StatPill(
                icon: Icons.mode_comment_outlined,
                label: '${_article.commentsCount} bình luận',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArticleBody() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _newsSurface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _newsNeutral.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _newsSurfaceStrong,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu_book_rounded, color: _newsPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chi tiết bài viết',
                  style: GoogleFonts.workSans(
                    color: _newsNeutral,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_isLoadingDetail)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _newsPrimary.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingDetail && _article.content.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else if (_article.content.isEmpty)
            Text(
              'Bài viết này chưa có nội dung chi tiết.',
              style: GoogleFonts.workSans(
                color: _newsMuted,
                fontSize: 15,
                height: 1.7,
              ),
            )
          else
            HtmlWidget(
              _article.content,
              textStyle: GoogleFonts.workSans(
                fontSize: 16,
                color: _newsNeutral,
                height: 1.8,
              ),
              customStylesBuilder: (element) {
                if (element.className == 'Normal' || element.localName == 'p') {
                  return {
                    'margin': '0 0 18px 0',
                    'line-height': '1.8',
                    'color': '#3E2723',
                  };
                }
                if (element.localName == 'h1' ||
                    element.localName == 'h2' ||
                    element.localName == 'h3') {
                  return {
                    'margin': '28px 0 14px 0',
                    'color': '#3E2723',
                    'font-weight': '700',
                    'line-height': '1.3',
                  };
                }
                if (element.localName == 'img') {
                  return {
                    'display': 'block',
                    'width': '100%',
                    'height': 'auto',
                    'margin': '20px 0 10px 0',
                    'border-radius': '18px',
                  };
                }
                if (element.localName == 'figure' ||
                    element.localName == 'blockquote') {
                  return {
                    'margin': '24px 0',
                    'padding': '16px 18px',
                    'background-color': '#F2E6D9',
                    'border-radius': '20px',
                    'color': '#3E2723',
                  };
                }
                if (element.localName == 'a') {
                  return {'color': '#BF5700', 'text-decoration': 'none'};
                }
                return null;
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      key: _commentsSectionKey,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _newsNeutral.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bình luận',
                  style: GoogleFonts.workSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _newsNeutral,
                  ),
                ),
              ),
              _StatPill(
                icon: Icons.mode_comment_outlined,
                label: '${_comments.length} mới nhất',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Chia sẻ góc nhìn để cuộc thảo luận quanh bài viết có thêm chiều sâu.',
            style: GoogleFonts.workSans(
              color: _newsMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildCommentComposer(),
          const SizedBox(height: 16),
          if (_isLoadingComments)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator.adaptive(),
              ),
            )
          else if (_comments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Chưa có bình luận nào. Hãy là người mở đầu cuộc trò chuyện.',
                style: GoogleFonts.workSans(
                  color: _newsMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            )
          else
            ..._comments.map(_buildCommentTile),
        ],
      ),
    );
  }

  Widget _buildCommentComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _newsNeutral.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              minLines: 1,
              maxLines: 3,
              style: GoogleFonts.workSans(
                color: _newsNeutral,
                fontSize: 13,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Viết bình luận của bạn...',
                hintStyle: GoogleFonts.workSans(
                  color: _newsMuted.withValues(alpha: 0.85),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isSubmittingComment ? null : _submitComment,
            style: FilledButton.styleFrom(
              minimumSize: const Size(40, 40),
              maximumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
              backgroundColor: _newsPrimary,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _isSubmittingComment
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Comment comment) {
    final initials = comment.author.trim().isEmpty
        ? '?'
        : comment.author
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _newsNeutral.withValues(alpha: 0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _newsPrimary.withValues(alpha: 0.1),
            child: Text(
              initials,
              style: GoogleFonts.workSans(
                color: _newsPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.author,
                        style: GoogleFonts.workSans(
                          color: _newsNeutral,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      comment.time,
                      style: GoogleFonts.workSans(
                        color: _newsMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.text,
                  style: GoogleFonts.workSans(
                    color: _newsNeutral,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: BoxDecoration(
          color: _newsSurface.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(color: _newsNeutral.withValues(alpha: 0.08)),
          ),
          boxShadow: [
            BoxShadow(
              color: _newsNeutral.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildInteractionBtn(
                icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                label: 'Thích ${_article.likeCount}',
                color: _newsPrimary,
                isActive: _isLiked,
                onTap: () => _handleInteraction('LIKE'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildInteractionBtn(
                icon: _isDisliked
                    ? Icons.thumb_down
                    : Icons.thumb_down_outlined,
                label: 'Ghét ${_article.dislikeCount}',
                color: const Color(0xFFB86E28),
                isActive: _isDisliked,
                onTap: () => _handleInteraction('DISLIKE'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildInteractionBtn(
                icon: _isLoved ? Icons.favorite : Icons.favorite_outline,
                label: 'Yêu thích ${_article.loveCount}',
                color: const Color(0xFFD9486B),
                isActive: _isLoved,
                onTap: () => _handleInteraction('LOVE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.12)
                : _newsSurfaceStrong,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.34)
                  : _newsNeutral.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.workSans(
                    color: isActive ? color : _newsNeutral,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            shape: BoxShape.circle,
            border: Border.all(color: _newsNeutral.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: _newsNeutral, size: 14),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _newsSurfaceStrong,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _newsPrimary),
          const SizedBox(width: 6),
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
}

class _ArticleHeroImage extends StatelessWidget {
  const _ArticleHeroImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty) {
      return const _ArticleHeroFallback();
    }

    return Image.network(
      trimmedUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const _ArticleHeroFallback();
      },
    );
  }
}

class _ArticleHeroFallback extends StatelessWidget {
  const _ArticleHeroFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFE0B8), Color(0xFFBF5700)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -40,
            right: -16,
            child: Container(
              width: 152,
              height: 152,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -56,
            left: -20,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                color: _newsNeutral.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Pody News',
                  style: GoogleFonts.newsreader(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    height: 0.94,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tin tức tuyển chọn mỗi ngày',
                  style: GoogleFonts.workSans(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 14,
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
