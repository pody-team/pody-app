import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:pody/data/article_service.dart';
import 'package:pody/data/article_scope.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';
import 'package:pody/theme/app_colors.dart';

class ArticleDetailScreen extends StatefulWidget {
  final NewsArticle article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  ArticleApiService? _apiService;
  late NewsArticle _article;
  late bool _isLiked;
  late bool _isLoved;
  late bool _isDisliked;
  bool _isLoadingDetail = false;
  int _secondsRead = 0;
  Timer? _timer;
  final int _userId = 1;

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
      _fetchFreshDetail();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService ??= ArticleScope.of(context);
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
        _article = detail.copyWith(
          isAdded: _article.isAdded,
          isLiked: _isLiked,
          isLoved: _isLoved,
          isDisliked: _isDisliked,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();

    if (_apiService != null && _secondsRead > 0) {
      unawaited(
        _apiService!.sendMetric(widget.article.id, _userId, _secondsRead),
      );
    }

    super.dispose();
  }

  void _syncInteractionState(NewsArticle article) {
    _isLiked = article.isLiked;
    _isLoved = article.isLoved;
    _isDisliked = article.isDisliked;
  }

  Future<void> _handleInteraction(String type) async {
    setState(() {
      if (type == 'LIKE') {
        _isLiked = !_isLiked;
        if (_isLiked) {
          _isDisliked = false;
        }
      } else if (type == 'LOVE') {
        _isLoved = !_isLoved;
      } else if (type == 'DISLIKE') {
        _isDisliked = !_isDisliked;
        if (_isDisliked) {
          _isLiked = false;
        }
      }

      _article = _article.copyWith(
        isLiked: _isLiked,
        isLoved: _isLoved,
        isDisliked: _isDisliked,
      );
      widget.article.isLiked = _isLiked;
      widget.article.isLoved = _isLoved;
      widget.article.isDisliked = _isDisliked;
    });

    final success = await _apiService!.sendInteraction(
      widget.article.id,
      _userId,
      type,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Da gui tuong tac: $type'
              : 'Khong gui duoc tuong tac toi backend.',
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: success ? kTikRed : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBlack,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
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
                  Image.network(_article.imageUrl, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          kBgBlack.withValues(alpha: 0.8),
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: kTikRed.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _article.category,
                          style: TextStyle(
                            color: kTikRed,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.visibility_outlined,
                        color: Colors.white54,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_article.viewCount} luot xem',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
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
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.white12,
                        child: Icon(
                          Icons.business,
                          size: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _article.publisher,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Colors.white38)),
                      const SizedBox(width: 8),
                      Text(
                        _article.time,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 40, color: Colors.white10),
                  if (_isLoadingDetail && _article.content.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(color: kTikRed),
                      ),
                    )
                  else if (_article.content.isEmpty)
                    const Text(
                      'Bai viet nay chua co noi dung chi tiet.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.6,
                      ),
                    )
                  else
                    HtmlWidget(
                      _article.content,
                      textStyle: const TextStyle(
                        fontSize: 17,
                        color: Colors.white,
                        height: 1.6,
                        letterSpacing: 0.2,
                        fontFamily: 'Inter',
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
                        if (element.className == 'Image') {
                          return {
                            'font-size': '13px',
                            'color': 'rgba(255,255,255,0.5)',
                            'text-align': 'center',
                            'font-style': 'italic',
                            'margin-top': '8px',
                          };
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 40),
                  const Text(
                    'Binh luan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...MockData.comments.take(2).map(_buildCommentTile),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: kBgBlack,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          children: [
            _buildInteractionBtn(
              icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
              label: 'Thich',
              color: _isLiked ? kTikRed : Colors.white70,
              onTap: () => _handleInteraction('LIKE'),
            ),
            const SizedBox(width: 20),
            _buildInteractionBtn(
              icon: _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
              label: 'Ghet',
              color: _isDisliked ? Colors.orange : Colors.white70,
              onTap: () => _handleInteraction('DISLIKE'),
            ),
            const SizedBox(width: 20),
            _buildInteractionBtn(
              icon: _isLoved ? Icons.favorite : Icons.favorite_outline,
              label: 'Yeu',
              color: _isLoved ? Colors.pink : Colors.white70,
              onTap: () => _handleInteraction('LOVE'),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  final nextAdded = !_article.isAdded;
                  _article = _article.copyWith(isAdded: nextAdded);
                  widget.article.isAdded = nextAdded;
                });
              },
              icon: Icon(_article.isAdded ? Icons.check : Icons.auto_awesome),
              label: Text(_article.isAdded ? 'Da them' : 'Nghe AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _article.isAdded ? Colors.white10 : kTikRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(Comment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(comment.avatarUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.author,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.time,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}
