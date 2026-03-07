import 'package:flutter/material.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';


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
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1F1F1F),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 32),
                    Text(
                      '${comments.length} comments',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      iconSize: 20,
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Comments List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    return _buildCommentItem(comments[index]);
                  },
                ),
              ),

              // Bottom Input Bar
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1F1F1F),
                  border: Border(top: BorderSide(color: Colors.white12)),
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
                      radius: 16,
                      backgroundImage: NetworkImage(MockData.currentUser.avatarUrl),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262626),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: TextField(
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Add comment...',
                                  hintStyle: TextStyle(
                                    color: Colors.white54,
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
                                color: Colors.white54,
                              ),
                              iconSize: 20,
                              onPressed: () {},
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.sentiment_satisfied,
                                color: Colors.white54,
                              ),
                              iconSize: 20,
                              onPressed: () {},
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
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
        bottom: isReply ? 12 : 16,
        top: isReply ? 12 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: isReply ? 24 : 32,
            height: isReply ? 24 : 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: comment.isStoryAvatar
                  ? Border.all(color: Colors.cyanAccent, width: 2)
                  : Border.all(color: Colors.white24, width: 1),
            ),
            padding: EdgeInsets.all(comment.isStoryAvatar ? 2 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(comment.avatarUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.author,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      comment.time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Reply',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),

                // Replies section
                if (hasReplies)
                  Column(
                    children: comment.replies.map((reply) {
                      return _buildCommentItem(reply, isReply: true);
                    }).toList(),
                  ),

                // View More Replies
                if (comment.viewMoreRepliesCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 1,
                          color: Colors.white24,
                          margin: const EdgeInsets.only(right: 8),
                        ),
                        Text(
                          'View ${comment.viewMoreRepliesCount} replies',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54,
                          ),
                        ),
                        const Icon(
                          Icons.expand_more,
                          color: Colors.white54,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Like Button
          Column(
            children: [
              Icon(
                comment.likes > 0 ? Icons.favorite : Icons.favorite_border,
                color: comment.likes > 0
                    ? const Color(0xFFEF4444)
                    : Colors.white54,
                size: 16,
              ),
              const SizedBox(height: 4),
              if (comment.likes > 0)
                Text(
                  '${comment.likes}',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
