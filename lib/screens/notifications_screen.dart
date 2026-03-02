import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static final List<Map<String, dynamic>> _notifications = [
    {
      'type': 'like',
      'icon': Icons.favorite,
      'user': 'Trung Phan',
      'action': 'liked your episode',
      'target': 'MVC thời hiện đại',
      'time': '2 min ago',
      'avatar':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuB4EIkdO1i3-4hGeSAtEzTxcNQ8qnrTI6kPdXnUgmw9dbsvrmq1hV3q1s_5TIbjYmpT0Q206FiA1ZGDGpg0jLGpyBKEpU9y4Im0cAa_rJXSMEwLuTHReSD3-ztzaFcACqv8-UM7dIb97V_tskBEYjZp1glNRlAo-yS1D-fbUXHESR6Tz_wBE1uZjFZAwpHO3DHnfFrLYPqklXvAcRC9urQxh-a7J23PghYOXri3n7xRx9Y4LzpExbVD_lAChzEbhE3u-OEfpuLTLsc',
      'isNew': true,
    },
    {
      'type': 'comment',
      'icon': Icons.chat_bubble,
      'user': 'Linh Nguyen',
      'action': 'commented on',
      'target': 'AI sẽ thay thế Dev?',
      'preview': '"Anh ơi phần cuối hay quá! Em muốn nghe thêm về..."',
      'time': '15 min ago',
      'avatar':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAWGX1z6hXmkcfBIlhDnk0zE9cv8lX5A5B_hsXdZwH57h3bdtokrT2CGW01UyaWneHx-8azq8ciqAjJQe3nJ7y5tREangqFs1BmRkWxfA98Mt0qCf5PuiB9U1DGLRFd9qOwV25TMb1uyyjoWi6gXf10TJRWnKursAmQTO0bgJ8Vqu9aPD_3OlBzSyKZSuntBKn6nEek-FUektilhtlyXBb3aUAj9Y3Zt1y_xgR7IvsTaWFf4UILkhoKo_6OpaEJJYqFpgedWemeUfoo',
      'isNew': true,
    },
    {
      'type': 'follow',
      'icon': Icons.person_add,
      'user': 'Anh Ba',
      'action': 'started following you',
      'target': '',
      'time': '1 hour ago',
      'avatar':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBXxaIrUBG6uaxLRdgFLmXZRZOXa-4kEx5w4uuChjtHFq1nwsvjdfcRGefYdKgFNn4kVvW_v8kkD8uZ0SOAJ5JX8Uyp7KCEBpKWL-Ps-4lFOpviwCcZCXVxvYD35Ur2DJttpijqFr9_YK4E-bF4ApxeHY5ziXZZ0cR0BA3zR7CQq-V996pVWsqRrcxH44_lcySHGplz8KweWfgzOB0FHaB2CEFKh7YuFjAYHYVlQey6yQDhofs03-SnFBCpOCwH5APs1RA1y6vCmWsV',
      'isNew': true,
    },
    {
      'type': 'milestone',
      'icon': Icons.emoji_events,
      'user': 'Future Minds',
      'action': 'reached 10K listens! 🎉',
      'target': '',
      'time': '3 hours ago',
      'avatar':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuATYB8bGdInAe7ldY3ArRuwbXNgOSgCv93cf_umwxaersMiO-6idUlT4JXFpwUSTBWYaUxs3W4foHJSlIi116P_v-NXG1WPJ_bG3LJmYWFg4oQQe6aZkwYco6UVqt5O8iR2wfmhsQjOt59_QQnvE0ghwkHNXC0FjBst-UPCqL89lfv7T1IDKzYBZRgz7a0j3sSYJxx9nO8pU4XRcinnkKjwcYGD03mXKcfS3FbB6EBA_e0mvrG959LmvX520iuBE7NzNr-AbyPChHk',
      'isNew': false,
    },
    {
      'type': 'like',
      'icon': Icons.favorite,
      'user': 'Mai Anh & 12 others',
      'action': 'liked your episode',
      'target': 'Chuyện làm Product',
      'time': '5 hours ago',
      'avatar':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDB3RvJGL4ymSXKqgcf2lNqSv3cq179HXKWiZiCohETt28E1m9Z_7KC0cDZEUC5YV8wuMr8CPuagHWk9zKJLlXHPuyW0S96RCC2KUilP7rJn23yYsEjIX8YYefxyUh8M47ur7U6tZeXwMOWj9vWOyg46sZN5Xga8oRbi4IVwn1ba-B26NDOetx7_fnFLS9Om9LMhztFUCXD-72pMA6oZoityrwcYDRPabxnz_bQRT8ahfmK_V7SCwwaWgO9g_EKfyIVU4jzMkAtxFA_',
      'isNew': false,
    },
    {
      'type': 'new_episode',
      'icon': Icons.headphones,
      'user': 'True Crime Daily',
      'action': 'published a new episode',
      'target': 'The Missing Evidence',
      'time': 'Yesterday',
      'avatar':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDRyNqWoebcCRyWA9Z01YumR31TnNjxnIwbUUAIbiubmjZz8n4AqMoO_sGjMeNG9Nb5gzGPgVIVWGpwrvBm6AKbhhLVVjvTi1jDJgwDe29EvYIS5fTqEDuGmIu8PVbWTTNfzZp6w09dErSJe5hnQS-DRuyYAfHBMd9Pk7pzFEQ-x0q_Zo_VBGtA1tYEnGVIAM1dDf56POWot-PMEFogFBBMzZrd10Iv26tCL3goroNsN7APhD9BZ1kHtKP7X0v1Am6ntCf_BwLHIY0',
      'isNew': false,
    },
    {
      'type': 'comment',
      'icon': Icons.chat_bubble,
      'user': 'Huy Tran',
      'action': 'replied to your comment on',
      'target': 'Burnout & Mental Health',
      'preview': '"Đúng rồi bạn, mình cũng từng trải qua giai đoạn đó..."',
      'time': 'Yesterday',
      'avatar':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuA_WasjbTwvfuUzfmiQ7adeTtkOq96d9eVBI55URTUMSxbY80T6Gyx4pNqag9GhJjiVlzvGAhwGy7wxEYS9NZ0H7MycBwaJI5IB5dlsmsntPHhMZH5ihYcE4gvLKCPCbP76yi7HBmrC2qLo09pHi6C4ndA9-guMkYrjDZhbloRNCYnOD6BgKpuIzEi_T3LooR_huwwoFOA_pwPc_aN7BdWZoIi9LAkWDJvoCGx5YaQu6mnazcsps5TuwSZGieXs2pNOe_oIHqhJmB0i',
      'isNew': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E13),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
          // New section
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'NEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white38,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),

          // New notifications
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final items = _notifications
                    .where((n) => n['isNew'] == true)
                    .toList();
                if (index >= items.length) return null;
                return _NotificationTile(data: items[index]);
              },
              childCount: _notifications
                  .where((n) => n['isNew'] == true)
                  .length,
            ),
          ),

          // Earlier section
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'EARLIER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white38,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),

          // Earlier notifications
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final items = _notifications
                    .where((n) => n['isNew'] == false)
                    .toList();
                if (index >= items.length) return null;
                return _NotificationTile(data: items[index]);
              },
              childCount: _notifications
                  .where((n) => n['isNew'] == false)
                  .length,
            ),
          ),

        ],
      ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _NotificationTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final bool isNew = data['isNew'] as bool;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNew ? Colors.white.withOpacity(0.04) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: isNew
            ? Border.all(color: Colors.white.withOpacity(0.06))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with icon badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  data['avatar'],
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0E13),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0F0E13),
                      width: 2,
                    ),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(data['icon'], size: 10, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: data['user'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(text: ' ${data['action']}'),
                      if ((data['target'] as String).isNotEmpty)
                        TextSpan(
                          text: ' ${data['target']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
                if (data['preview'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    data['preview'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white38,
                      fontStyle: FontStyle.italic,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  data['time'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // New dot indicator
          if (isNew) ...[
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
