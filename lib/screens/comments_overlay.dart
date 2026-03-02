import 'package:flutter/material.dart';
import 'package:pody/theme/app_colors.dart';


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
  final List<Map<String, dynamic>> _comments = [
    {
      'author': 'Thành Thái 💖⚜️',
      'avatar':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCwav8HCsHoGShZLePXNYDnEqlljOqeN9npoXE3Jd_oieDkFu8om3nUw-ifXvs1mEMWQD2CsqxauTDE9DhDh2R3x1Cp7Yh5J9J9QOyu0VCOwKhNPGq6p4n2NVZI_8mC7-XfAXA2zQa6FIo52eopyqnt-NfHowLqSy24dVZzPF2zRktZHr_9A3XCRgEJVZSY1AESLZ7RPZbozA53WIJDlQ7BlTkRDzl5NS3xyaFCWZ0f5wPmy4DnzuegYpj1C5Q3kzf6Ci0h-lpN9nk',
      'text': 'Looks exactly like Ba Dinh Nga Son',
      'time': '02-09',
      'likes': 5,
      'replies': [
        {
          'author': '10a10-k62',
          'avatar':
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBFDuLpFGYxEYaEPBLOnFOWPC7zike63O_KvwHojgzQzUJOQ8nTWEldD9Sub1dj0RrTcZs02mNqM-M98am8g5WdMpIOgnnE1hIuFOi79Oaz2Kqz7Kub-N_7hXYjRLJFwahwEHuQif1-bqcG1LuZSE5fJGlcH23mfWLjJKUs9ka_MOQWurRKQOp4z2tzX383EDZnmzLKj0728KkDESPWo4tibnVMutPx90oJaOaTZjFFVIHwyBp307aCZF8NUOt-GhUIyRUZE8Oanw0',
          'text': 'Correct!',
          'time': '02-09',
          'likes': 4,
        },
      ],
      'viewMoreRepliesCount': 2,
    },
    {
      'author': 'ghuy',
      'avatar':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuB2WPNzAviC7iU8ms3KiKBaxmA2_G6GWsC9GJklw_b6Lk0XifL2dPD3H5dY24im9MDw_cPipKeAioqs1LkdzK5nye7sFGffPbP2pVWwX1o6Ae_ixdbAYq9vYY9R0QME3PCxqhw2mu4STaFlebmJLyByc7HGsQd8ZIdBkdy47SPq2a1mhfIE7UEFaoat1tBwv8mAEMM3Tst6vZbFpOysq15gSuRZhJCWKn6wHJnDFC7ALQZQn20K1bCfINzZxxOsOh5EVdft76LGddE',
      'text': 'So trendy ladies',
      'time': '02-08',
      'likes': 2,
      'isStoryAvatar': true,
      'viewMoreRepliesCount': 3,
      'replies': <Map<String, dynamic>>[],
    },
    {
      'author': 'khi nào xinh gái thì đổi tên',
      'avatar':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDDk5ayrz3kEo3MUJQ5ldnvSHrQslnEJmW4dMxd_i6jqJ8NGtl4N3nqcXlxRVNkB1t_GrFu9P3tWG_tqCBOJ1u_UuiG6YXHSOKWoKiLO5NXoxSUyZ4yxbDfo80RXlbWmzZKWz0PMG14R1gVLyhLuryHuf8LRYyCFSvw8uXXurpXaYMoGjS_yWsUcrRoK7r3-UM6EYKi5hr5bsSlmB-XU1qw-Hkp0gCSYHqLEyOZmL_WSu-eUDxro7ev9aJ0YQYrLsZr3tsps6NWQyc',
      'text': 'Which school is this please?',
      'time': '02-09',
      'likes': 2,
      'replies': <Map<String, dynamic>>[],
    },
    {
      'author': 'Mai Linh',
      'avatar':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAs3sto2wNNC31DB7ptTK8fc4qze0_A4Do3oLD1U_vn3KdV0fxSAHtkkuz0tBq3jjLLkEx7VLJeIwg6_lwlNRLl10XxH4x6ICoEa7Ol_Xis9CC1ux66c1UaoqaV3nXgXHtBsd6BDyOH7A9AplAsZC__pflGYIMuMW6X7V7cDdip4aRLB2MBSQzGrmAQSDprwXrJxWF_c0yQjm9ej-0qgj-G3XPBl3j5sJQFryQdbiKkCspgM6VsXTOdpM3GFu3ubhCtjR4agLky8u8',
      'text': 'The vibe is immaculate! Miss my high school days 🥺',
      'time': '1h ago',
      'likes': 0,
      'replies': <Map<String, dynamic>>[],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1F1F1F), // kBgCard raw value
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
                    const Text(
                      '738 comments',
                      style: TextStyle(
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
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    return _buildCommentItem(comment);
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
                      backgroundImage: const NetworkImage(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuAJlu142meaFRiNBmTXUaPbEKd0igUPtcf5RkJ_ALpSCIEp-H2jF4DP7yw1MFVwsVwC5Eo0oGTenuncfYaIl4ulnHkY26JJE-Q8UqF1ufpD8RA27S06ZSdpVCBox2AnorUKSonBonwAiuvbkL7FYBs1WSjFUFvLB57O3FdwfoerXqscU_nVGWcp39CHe3BNEJx5C664I6bW0unGIJSxxkYdO5C6gKHO1L3iaCia_4Z2n-y-NDRXfPZCYz3xYa_Wtj6WJdzpYyl1Yx0',
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
                          color: const Color(0xFF262626), // text field surface
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

  Widget _buildCommentItem(
    Map<String, dynamic> comment, {
    bool isReply = false,
  }) {
    final bool hasReplies =
        comment['replies'] != null && (comment['replies'] as List).isNotEmpty;
    final int viewMoreCount = comment['viewMoreRepliesCount'] ?? 0;
    final bool isStoryAvatar = comment['isStoryAvatar'] == true;

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
              border: isStoryAvatar
                  ? Border.all(color: Colors.cyanAccent, width: 2)
                  : Border.all(color: Colors.white24, width: 1),
            ),
            padding: EdgeInsets.all(isStoryAvatar ? 2 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(comment['avatar'], fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment['author'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment['text'],
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
                      comment['time'],
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
                    children: (comment['replies'] as List).map((reply) {
                      return _buildCommentItem(
                        reply as Map<String, dynamic>,
                        isReply: true,
                      );
                    }).toList(),
                  ),

                // View More Replies
                if (viewMoreCount > 0)
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
                          'View $viewMoreCount replies',
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
                comment['likes'] > 0 ? Icons.favorite : Icons.favorite_border,
                color: comment['likes'] > 0
                    ? const Color(0xFFEF4444)
                    : Colors.white54,
                size: 16,
              ),
              const SizedBox(height: 4),
              if (comment['likes'] > 0)
                Text(
                  '${comment['likes']}',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
