import 'package:flutter/material.dart';
import 'package:pody/theme/app_colors.dart';


class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = ['All', 'Podcasts', 'Episodes', 'Downloads'];

  final List<Map<String, String>> _recentlyPlayed = [
    {
      'title': 'The Daily Tech',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuABWDceSoEjSUZ3dxWs41GwBIqR2qN_sdpHh5flX74_LSk4DC7wgkRmbX1ikKmCdRyfk_x6ksjYMSLjg4QqxgwabROWx50UiOaMsrcDSNRkgDjE5OJmGiTSfqkEzOmRc8yTHms7VVcaBlYcdivqZV5GnP_8gIo3GVuO41fMiYAWFbbMGT021E_EygASLeBrmSyv-cNg3_24bWlRzR1_PfvyiZI1J0z_r7fnD_do5LFH8Uomawc7llkwQ4EnUkE_F4RWwS8YWW1NKqHN',
    },
    {
      'title': 'Indie Hackers',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDLkoHn-UOqkxGDWOvkmskev_w2pO3s5sjcDYEMFvjsTZvs4hCxNy3H5GHAvC_qXdMvsimCCdlePVhp6rIw0aHLsajvz_sz8kHY82FQ1YMOQtad1gmeoUdeqFqAaLUT-nh2QRqXTM9u_T5pBn7Q7NRkmJmQGvj4ZYbYeCbGZGGapvYVNeHozSJlgwG1V4m1YCBCJdcTvhNrs3B1Z3hjFfEqVVbMQ9DgSSG8NZE_Hg4QQDO8Nv117qkYkkOYJBwwY_Xaq70erskstHx5',
    },
    {
      'title': 'Design Matters',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAebWbaJhEISYKavHmqyyfaTOnExvH26vkZtcZ1S5NZ7DFIbsovehIuGwXiL0jhEtaNLbErAn9aBfGgfnrPtlQl3NC6S2paFtaFLlbevFSpLqgILPbuzjwad2aZQC4uGD7nwXeOKnMkv9H1_4w8_rkbMQTayE9M0XST4j0vu5-LXlalPyFAMCXOV0Qf3puL9BXypPRRFPoboZALB8Wfw5JFmxqpcOLIAotCb3WzXfHozaVeC-xD6807djjSdOlOSYCaWL1TQGSUEp1R',
    },
  ];

  final List<Map<String, String>> _yourPodcasts = [
    {
      'title': 'Darknet Diaries',
      'subtitle': '42 episodes available',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuATwdbEkgebQIl9kTtpv2J2xECsLzBRXx8JQpnkzUwR83Xtavo7WYgJhy57-lyj640vRniC9u3ilL6gN1tv62tkUb_bmr_6PFLxvJAAFHfU_qKzYknXUP5BZEplbf_1wloOMFNHsJkwXDLTdS_02zIk-Uypkgppx3idj-mkAWlVTYu3qM7z8coOX0yQ8dOUDqVhNfdK7BzLmdsrB9XC1WnEPBh5pDpGrB2H7vG3NnuONKNFSX2B0LWiorD9cQTyBlwn2O1AYt1769TG',
    },
    {
      'title': 'Lex Fridman',
      'subtitle': '12 new episodes',
      'image':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuA_WasjbTwvfuUzfmiQ7adeTtkOq96d9eVBI55URTUMSxbY80T6Gyx4pNqag9GhJjiVlzvGAhwGy7wxEYS9NZ0H7MycBwaJI5IB5dlsmsntPHhMZH5ihYcE4gvLKCPCbP76yi7HBmrC2qLo09pHi6C4ndA9-guMkYrjDZhbloRNCYnOD6BgKpuIzEi_T3LooR_huwwoFOA_pwPc_aN7BdWZoIi9LAkWDJvoCGx5YaQu6mnazcsps5TuwSZGieXs2pNOe_oIHqhJmB0i',
    },
  ];

  final List<Map<String, String>> _downloaded = [
    {
      'title': 'Ep. 240: Future of AI',
      'subtitle': 'Lex Fridman Podcast • 48 MB',
    },
    {'title': 'Why Design Systems Fail', 'subtitle': 'Design Better • 32 MB'},
    {'title': 'Cryptocurrency 101', 'subtitle': 'The Daily • 124 MB'},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 100),
      children: [
        // Filter Chips
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _filters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = _selectedFilter == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : kBgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? null
                            : Border.all(color: Colors.white12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _filters[index],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // Recently Played
            _buildSectionTitle('Recently Played'),
            const SizedBox(height: 12),
            SizedBox(
              height: 165,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _recentlyPlayed.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final item = _recentlyPlayed[index];
                  return SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            item['image']!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['title']!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // Your Podcasts
            _buildSectionTitle('Your Podcasts'),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: _yourPodcasts.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kBgCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item['image']!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title']!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['subtitle']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Downloaded
            _buildSectionTitle('Downloaded'),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: _downloaded.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isLast = index == _downloaded.length - 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : const Border(
                              bottom: BorderSide(color: Colors.white10),
                            ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title']!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['subtitle']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.download_done,
                          color: Colors.white38,
                          size: 24,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white54,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
