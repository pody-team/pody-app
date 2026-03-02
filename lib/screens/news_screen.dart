import 'package:flutter/material.dart';
import 'package:pody/theme/app_colors.dart';

import 'ai_summary_setup_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final List<String> _categories = [
    '🔥 Nóng hổi', '💻 Công nghệ', '🚀 Khởi nghiệp', '🪙 Crypto', '🎨 Design', '💰 Tài chính'
  ];
  int _selectedCategoryIndex = 0;

  final List<Map<String, dynamic>> _newsData = [
    {
      'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuATYB8bGdInAe7ldY3ArRuwbXNgOSgCv93cf_umwxaersMiO-6idUlT4JXFpwUSTBWYaUxs3W4foHJSlIi116P_v-NXG1WPJ_bG3LJmYWFg4oQQe6aZkwYco6UVqt5O8iR2wfmhsQjOt59_QQnvE0ghwkHNXC0FjBst-UPCqL89lfv7T1IDKzYBZRgz7a0j3sSYJxx9nO8pU4XRcinnkKjwcYGD03mXKcfS3FbB6EBA_e0mvrG959LmvX520iuBE7NzNr-AbyPChHk',
      'title': 'FPT giảm lao động sau nhiều năm tăng nóng: Hàng chục nghìn kỹ sư hiện hữu s...',
      'time': '9h',
      'publisher': 'CafeBiz',
      'desc': 'Ba điểm cốt lõi trong chính sách mới của FPT liên quan đến trí tuệ nhân tạo...',
      'isAdded': false,
    },
    {
      'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuDRyNqWoebcCRyWA9Z01YumR31TnNjxnIwbUUAIbiubmjZz8n4AqMoO_sGjMeNG9Nb5gzGPgVIVWGpwrvBm6AKbhhLVVjvTi1jDJgwDe29EvYIS5fTqEDuGmIu8PVbWTTNfzZp6w09dErSJe5hnQS-DRuyYAfHBMd9Pk7pzFEQ-x0q_Zo_VBGtA1tYEnGVIAM1dDf56POWot-PMEFogFBBMzZrd10Iv26tCL3goroNsN7APhD9BZ1kHtKP7X0v1Am6ntCf_BwLHIY0',
      'title': 'Lãi 120 tỷ USD/năm, Nvidia trở thành cỗ máy in tiền khổng lồ, xóa tan hoài nghi v...',
      'time': '8h',
      'publisher': 'GenK',
      'desc': 'Nvidia tiếp tục công bố mức lợi nhuận kỷ lục, khẳng định vị trí độc tôn trong mảng chip AI...',
      'isAdded': false,
    },
    {
      'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuA_WasjbTwvfuUzfmiQ7adeTtkOq96d9eVBI55URTUMSxbY80T6Gyx4pNqag9GhJjiVlzvGAhwGy7wxEYS9NZ0H7MycBwaJI5IB5dlsmsntPHhMZH5ihYcE4gvLKCPCbP76yi7HBmrC2qLo09pHi6C4ndA9-guMkYrjDZhbloRNCYnOD6BgKpuIzEi_T3LooR_huwwoFOA_pwPc_aN7BdWZoIi9LAkWDJvoCGx5YaQu6mnazcsps5TuwSZGieXs2pNOe_oIHqhJmB0i',
      'title': 'Podcast industry trends: Why short-form audio is taking over social media platforms',
      'time': '12h',
      'publisher': 'TechCrunch',
      'desc': 'Analysis on how user behavior is shifting towards bite-sized audio content...',
      'isAdded': true,
    },
    {
      'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuAebWbaJhEISYKavHmqyyfaTOnExvH26vkZtcZ1S5NZ7DFIbsovehIuGwXiL0jhEtaNLbErAn9aBfGgfnrPtlQl3NC6S2paFtaFLlbevFSpLqgILPbuzjwad2aZQC4uGD7nwXeOKnMkv9H1_4w8_rkbMQTayE9M0XST4j0vu5-LXlalPyFAMCXOV0Qf3puL9BXypPRRFPoboZALB8Wfw5JFmxqpcOLIAotCb3WzXfHozaVeC-xD6807djjSdOlOSYCaWL1TQGSUEp1R',
      'title': 'AI Overview: Hàng loạt các startup công nghệ mọc lên như nấm',
      'time': '1 ngày',
      'publisher': 'VnExpress',
      'desc': 'Bức tranh khởi nghiệp đang thay đổi liên tục với sự trỗi dậy của AI...',
      'isAdded': false,
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBlack,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // AI Podcast Station
            SliverToBoxAdapter(
              child: _buildAIPodcastStation(context),
            ),
            
            // Categories
            SliverToBoxAdapter(
              child: _buildCategories(),
            ),

            // Highlight Story
            if (_newsData.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildHighlightStory(_newsData[0]),
              ),

            // Compact List News
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == 0) return const SizedBox.shrink(); // Skips highlight
                    return _buildCompactNewsRow(index, _newsData[index]);
                  },
                  childCount: _newsData.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIPodcastStation(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kTikRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: kTikRed, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'AI Playlist',
                      style: TextStyle(color: kTikRed, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Text(
                '~12 phút',
                style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Bản tin Công nghệ\nsáng nay của bạn',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dựa trên 5 tin tức bạn đã chọn và xu hướng Tech.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '▶ Tạo & Nghe',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AiSummarySetupScreen(),
                    ),
                  );
                },
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.schedule, color: Colors.white),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _categories[index],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHighlightStory(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item['imageUrl'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  item['imageUrl'],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            item['title'],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item['desc'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    item['publisher'],
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(width: 8),
                  Text(
                    item['time'],
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              _buildAddButton(0, item),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactNewsRow(int index, Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          if (item['imageUrl'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item['imageUrl'],
                width: 76,
                height: 76,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.newspaper, color: Colors.white24, size: 30),
            ),
          const SizedBox(width: 12),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      item['publisher'],
                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    const Text('•', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    const SizedBox(width: 6),
                    Text(
                      item['time'],
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Add to queue btn
          _buildAddButton(index, item),
        ],
      ),
    );
  }

  Widget _buildAddButton(int index, Map<String, dynamic> item) {
    final bool isAdded = item['isAdded'] == true;
    return GestureDetector(
      onTap: () {
        setState(() {
          _newsData[index]['isAdded'] = !isAdded;
        });
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isAdded ? kTikRed.withOpacity(0.2) : Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isAdded ? Icons.check : Icons.add,
          color: isAdded ? kTikRed : Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
