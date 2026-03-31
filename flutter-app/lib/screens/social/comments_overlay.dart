import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';

const Color _commentsSurface = Color(0xFFFFFEFC);
const Color _commentsSurfaceStrong = Color(0xFFF2E6D9);
const Color _commentsPrimary = Color(0xFFBF5700);
const Color _commentsNeutral = Color(0xFF3E2723);
const Color _commentsMuted = Color(0xFF7E665F);

void showCommentsOverlay(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return const CommentsOverlay();
    },
  );
}

class CommentsOverlay extends StatefulWidget {
  const CommentsOverlay({super.key});

  @override
  State<CommentsOverlay> createState() => _CommentsOverlayState();
}

class _CommentsOverlayState extends State<CommentsOverlay> {
  @override
  Widget build(BuildContext context) {
    final comments = MockData.comments;
    return DraggableScrollableSheet(
      initialChildSize: 0.74,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _commentsSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _commentsNeutral.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _commentsMuted.withValues(alpha: 0.26),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${comments.length} bình luận',
                      style: GoogleFonts.workSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _commentsNeutral,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: _commentsNeutral),
                      iconSize: 20,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    return _buildCommentItem(comments[index]);
                  },
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: _commentsSurface,
                  border: Border(
                    top: BorderSide(
                      color: _commentsNeutral.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundImage: NetworkImage(
                        MockData.currentUser.avatarUrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _commentsSurfaceStrong,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                style: GoogleFonts.workSans(
                                  color: _commentsNeutral,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Thêm bình luận...',
                                  hintStyle: GoogleFonts.workSans(
                                    color: _commentsMuted,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.alternate_email,
                                color: _commentsMuted,
                              ),
                              iconSize: 20,
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.sentiment_satisfied,
                                color: _commentsMuted,
                              ),
                              iconSize: 20,
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(Comment comment, {bool isReply = false}) {
    final bool hasReplies = comment.replies.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: isReply ? 10 : 14,
        top: isReply ? 10 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isReply ? 28 : 36,
            height: isReply ? 28 : 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: comment.isStoryAvatar
                  ? Border.all(color: _commentsPrimary, width: 2)
                  : Border.all(color: _commentsNeutral.withValues(alpha: 0.08)),
            ),
            padding: EdgeInsets.all(comment.isStoryAvatar ? 2 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(comment.avatarUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _commentsSurfaceStrong,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.author,
                        style: GoogleFonts.workSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _commentsNeutral,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        comment.text,
                        style: GoogleFonts.workSans(
                          fontSize: 14,
                          color: _commentsNeutral,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      comment.time,
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        color: _commentsMuted,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Trả lời',
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _commentsMuted,
                      ),
                    ),
                  ],
                ),
                if (hasReplies)
                  Column(
                    children: comment.replies.map((reply) {
                      return _buildCommentItem(reply, isReply: true);
                    }).toList(),
                  ),
                if (comment.viewMoreRepliesCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 1,
                          color: _commentsMuted.withValues(alpha: 0.3),
                          margin: const EdgeInsets.only(right: 8),
                        ),
                        Text(
                          'Xem ${comment.viewMoreRepliesCount} phản hồi',
                          style: GoogleFonts.workSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _commentsMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Icon(
                comment.likes > 0 ? Icons.favorite : Icons.favorite_border,
                color: comment.likes > 0
                    ? const Color(0xFFC16452)
                    : _commentsMuted,
                size: 16,
              ),
              const SizedBox(height: 4),
              if (comment.likes > 0)
                Text(
                  '${comment.likes}',
                  style: GoogleFonts.workSans(
                    fontSize: 12,
                    color: _commentsMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
