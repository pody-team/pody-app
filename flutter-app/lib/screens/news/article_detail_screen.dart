import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:pody/data/article_scope.dart';
import 'package:pody/data/article_service.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/models/models.dart';
import 'package:pody/theme/app_colors.dart';

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
        const SnackBar(content: Text('Bạn cần đăng nhập để react bài viết.')),
      );
      return;
    }

    final updatedArticle = await _apiService!.sendInteraction(widget.article.id, type);

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
        backgroundColor: kTikRed,
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
      backgroundColor: kBgBlack,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: kBgBlack,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _article.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.white10,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white38,
                          size: 56,
                        ),
                      );
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          kBgBlack.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaRow(),
                  const SizedBox(height: 16),
                  Text(
                    _article.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPublisherRow(),
                  const SizedBox(height: 20),
                  _buildSummaryStats(),
                  const Divider(height: 36, color: Colors.white10),
                  _buildArticleBody(),
                  const SizedBox(height: 36),
                  _buildCommentsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildMetaRow() {
    final categories = _article.categories.isNotEmpty
        ? _article.categories
        : <String>[_article.category];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((category) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kTikRed.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: kTikRed,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.visibility_outlined, color: Colors.white54, size: 16),
        const SizedBox(width: 4),
        Text(
          '${_article.viewCount} lượt xem',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPublisherRow() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 12,
          backgroundColor: Colors.white12,
          child: Icon(Icons.business, size: 14, color: Colors.white70),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _article.publisher,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _article.time,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSummaryStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tương tác',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Chạm vào từng nút để react nhanh hoặc nhảy tới phần bình luận.',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildActionChip(
              icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
              label: '${_article.likeCount} likes',
              color: _isLiked ? kTikRed : Colors.white70,
              isActive: _isLiked,
              onTap: () => _handleInteraction('LIKE'),
            ),
            _buildActionChip(
              icon: _isLoved ? Icons.favorite : Icons.favorite_outline,
              label: '${_article.loveCount} tim',
              color: _isLoved ? Colors.pink : Colors.white70,
              isActive: _isLoved,
              onTap: () => _handleInteraction('LOVE'),
            ),
            _buildActionChip(
              icon: _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
              label: '${_article.dislikeCount} dislike',
              color: _isDisliked ? Colors.orange : Colors.white70,
              isActive: _isDisliked,
              onTap: () => _handleInteraction('DISLIKE'),
            ),
            _buildActionChip(
              icon: Icons.chat_bubble_outline,
              label: '${_article.commentsCount} bình luận',
              color: Colors.lightBlueAccent,
              isActive: false,
              onTap: _scrollToComments,
            ),
          ],
        ),
      ],
    );
  }

  void _scrollToComments() {
    final context = _commentsSectionKey.currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  Widget _buildActionChip({
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
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticleBody() {
    if (_isLoadingDetail && _article.content.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: kTikRed)),
      );
    }

    if (_article.content.isEmpty) {
      return const Text(
        'Bài viết này chưa có nội dung chi tiết.',
        style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.6),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: HtmlWidget(
        _article.content,
        textStyle: const TextStyle(
          fontSize: 17,
          color: Colors.white,
          height: 1.6,
          letterSpacing: 0.2,
        ),
        customStylesBuilder: (element) {
          if (element.className == 'Normal') {
            return {'margin-bottom': '16px'};
          }
          if (element.localName == 'img') {
            return {
              'display': 'block',
              'width': '100%',
              'height': 'auto',
              'margin': '20px 0 8px 0',
              'border-radius': '12px',
            };
          }
          if (element.localName == 'figure') {
            return {
              'margin': '24px 0',
              'border-radius': '12px',
              'overflow': 'hidden',
            };
          }
          return null;
        },
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      key: _commentsSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bình luận',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        _buildCommentComposer(),
        const SizedBox(height: 18),
        if (_isLoadingComments)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(color: kTikRed),
            ),
          )
        else if (_comments.isEmpty)
          const Text(
            'Chưa có bình luận nào.',
            style: TextStyle(color: Colors.white54),
          )
        else
          ..._comments.map(_buildCommentTile),
      ],
    );
  }

  Widget _buildCommentComposer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          TextField(
            controller: _commentController,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Viết bình luận của bạn...',
              hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _isSubmittingComment ? null : _submitComment,
              style: FilledButton.styleFrom(backgroundColor: kTikRed),
              child: _isSubmittingComment
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Gửi'),
            ),
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white12,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.author,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      comment.time,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.text,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: kBgBlack,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildInteractionBtn(
              icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
              label: 'Thích ${_article.likeCount}',
              color: _isLiked ? kTikRed : Colors.white70,
              onTap: () => _handleInteraction('LIKE'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildInteractionBtn(
              icon: _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
              label: 'Ghét ${_article.dislikeCount}',
              color: _isDisliked ? Colors.orange : Colors.white70,
              onTap: () => _handleInteraction('DISLIKE'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildInteractionBtn(
              icon: _isLoved ? Icons.favorite : Icons.favorite_outline,
              label: 'Thả tim ${_article.loveCount}',
              color: _isLoved ? Colors.pink : Colors.white70,
              onTap: () => _handleInteraction('LOVE'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
