import 'package:pody/models/models.dart';

/// Centralized mock data for the entire app.
/// Replace with real API calls / database reads later.
class MockData {
  MockData._(); // prevent instantiation

  // ─────────────────────────── AVATARS ─────────────────────────────────────

  static const _avatarHost =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuB4EIkdO1i3-4hGeSAtEzTxcNQ8qnrTI6kPdXnUgmw9dbsvrmq1hV3q1s_5TIbjYmpT0Q206FiA1ZGDGpg0jLGpyBKEpU9y4Im0cAa_rJXSMEwLuTHReSD3-ztzaFcACqv8-UM7dIb97V_tskBEYjZp1glNRlAo-yS1D-fbUXHESR6Tz_wBE1uZjFZAwpHO3DHnfFrLYPqklXvAcRC9urQxh-a7J23PghYOXri3n7xRx9Y4LzpExbVD_lAChzEbhE3u-OEfpuLTLsc';

  static const _avatarUser =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAJlu142meaFRiNBmTXUaPbEKd0igUPtcf5RkJ_ALpSCIEp-H2jF4DP7yw1MFVwsVwC5Eo0oGTenuncfYaIl4ulnHkY26JJE-Q8UqF1ufpD8RA27S06ZSdpVCBox2AnorUKSonBonwAiuvbkL7FYBs1WSjFUFvLB57O3FdwfoerXqscU_nVGWcp39CHe3BNEJx5C664I6bW0unGIJSxxkYdO5C6gKHO1L3iaCia_4Z2n-y-NDRXfPZCYz3xYa_Wtj6WJdzpYyl1Yx0';

  static const _avatarLinh =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAWGX1z6hXmkcfBIlhDnk0zE9cv8lX5A5B_hsXdZwH57h3bdtokrT2CGW01UyaWneHx-8azq8ciqAjJQe3nJ7y5tREangqFs1BmRkWxfA98Mt0qCf5PuiB9U1DGLRFd9qOwV25TMb1uyyjoWi6gXf10TJRWnKursAmQTO0bgJ8Vqu9aPD_3OlBzSyKZSuntBKn6nEek-FUektilhtlyXBb3aUAj9Y3Zt1y_xgR7IvsTaWFf4UILkhoKo_6OpaEJJYqFpgedWemeUfoo';

  static const _avatarAnhBa =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBXxaIrUBG6uaxLRdgFLmXZRZOXa-4kEx5w4uuChjtHFq1nwsvjdfcRGefYdKgFNn4kVvW_v8kkD8uZ0SOAJ5JX8Uyp7KCEBpKWL-Ps-4lFOpviwCcZCXVxvYD35Ur2DJttpijqFr9_YK4E-bF4ApxeHY5ziXZZ0cR0BA3zR7CQq-V996pVWsqRrcxH44_lcySHGplz8KweWfgzOB0FHaB2CEFKh7YuFjAYHYVlQey6yQDhofs03-SnFBCpOCwH5APs1RA1y6vCmWsV';

  static const _avatarMaiAnh =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDB3RvJGL4ymSXKqgcf2lNqSv3cq179HXKWiZiCohETt28E1m9Z_7KC0cDZEUC5YV8wuMr8CPuagHWk9zKJLlXHPuyW0S96RCC2KUilP7rJn23yYsEjIX8YYefxyUh8M47ur7U6tZeXwMOWj9vWOyg46sZN5Xga8oRbi4IVwn1ba-B26NDOetx7_fnFLS9Om9LMhztFUCXD-72pMA6oZoityrwcYDRPabxnz_bQRT8ahfmK_V7SCwwaWgO9g_EKfyIVU4jzMkAtxFA_';

  // ─────────────────────────── COVERS ──────────────────────────────────────

  static const _coverFutureMinds =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuATYB8bGdInAe7ldY3ArRuwbXNgOSgCv93cf_umwxaersMiO-6idUlT4JXFpwUSTBWYaUxs3W4foHJSlIi116P_v-NXG1WPJ_bG3LJmYWFg4oQQe6aZkwYco6UVqt5O8iR2wfmhsQjOt59_QQnvE0ghwkHNXC0FjBst-UPCqL89lfv7T1IDKzYBZRgz7a0j3sSYJxx9nO8pU4XRcinnkKjwcYGD03mXKcfS3FbB6EBA_e0mvrG959LmvX520iuBE7NzNr-AbyPChHk';

  static const _coverTrueCrime =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDRyNqWoebcCRyWA9Z01YumR31TnNjxnIwbUUAIbiubmjZz8n4AqMoO_sGjMeNG9Nb5gzGPgVIVWGpwrvBm6AKbhhLVVjvTi1jDJgwDe29EvYIS5fTqEDuGmIu8PVbWTTNfzZp6w09dErSJe5hnQS-DRuyYAfHBMd9Pk7pzFEQ-x0q_Zo_VBGtA1tYEnGVIAM1dDf56POWot-PMEFogFBBMzZrd10Iv26tCL3goroNsN7APhD9BZ1kHtKP7X0v1Am6ntCf_BwLHIY0';

  static const _coverMindful =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBXxaIrUBG6uaxLRdgFLmXZRZOXa-4kEx5w4uuChjtHFq1nwsvjdfcRGefYdKgFNn4kVvW_v8kkD8uZ0SOAJ5JX8Uyp7KCEBpKWL-Ps-4lFOpviwCcZCXVxvYD35Ur2DJttpijqFr9_YK4E-bF4ApxeHY5ziXZZ0cR0BA3zR7CQq-V996pVWsqRrcxH44_lcySHGplz8KweWfgzOB0FHaB2CEFKh7YuFjAYHYVlQey6yQDhofs03-SnFBCpOCwH5APs1RA1y6vCmWsV';

  static const _coverAiNewsExtra =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuA_WasjbTwvfuUzfmiQ7adeTtkOq96d9eVBI55URTUMSxbY80T6Gyx4pNqag9GhJjiVlzvGAhwGy7wxEYS9NZ0H7MycBwaJI5IB5dlsmsntPHhMZH5ihYcE4gvLKCPCbP76yi7HBmrC2qLo09pHi6C4ndA9-guMkYrjDZhbloRNCYnOD6BgKpuIzEi_T3LooR_huwwoFOA_pwPc_aN7BdWZoIi9LAkWDJvoCGx5YaQu6mnazcsps5TuwSZGieXs2pNOe_oIHqhJmB0i';

  static const _coverVnExpress =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAebWbaJhEISYKavHmqyyfaTOnExvH26vkZtcZ1S5NZ7DFIbsovehIuGwXiL0jhEtaNLbErAn9aBfGgfnrPtlQl3NC6S2paFtaFLlbevFSpLqgILPbuzjwad2aZQC4uGD7nwXeOKnMkv9H1_4w8_rkbMQTayE9M0XST4j0vu5-LXlalPyFAMCXOV0Qf3puL9BXypPRRFPoboZALB8Wfw5JFmxqpcOLIAotCb3WzXfHozaVeC-xD6807djjSdOlOSYCaWL1TQGSUEp1R';

  // Unsplash extra imgs for episode carousel
  static const _unsplash1 = 'https://images.unsplash.com/photo-1516280440502-861f1c7eb1ea?q=80&w=600&auto=format&fit=crop';
  static const _unsplash2 = 'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?q=80&w=600&auto=format&fit=crop';
  static const _unsplash3 = 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?q=80&w=600&auto=format&fit=crop';
  static const _unsplash4 = 'https://images.unsplash.com/photo-1628155930542-3c7a64e2c833?q=80&w=600&auto=format&fit=crop';

  // Comment avatars
  static const _avatarComment1 =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCwav8HCsHoGShZLePXNYDnEqlljOqeN9npoXE3Jd_oieDkFu8om3nUw-ifXvs1mEMWQD2CsqxauTDE9DhDh2R3x1Cp7Yh5J9J9QOyu0VCOwKhNPGq6p4n2NVZI_8mC7-XfAXA2zQa6FIo52eopyqnt-NfHowLqSy24dVZzPF2zRktZHr_9A3XCRgEJVZSY1AESLZ7RPZbozA53WIJDlQ7BlTkRDzl5NS3xyaFCWZ0f5wPmy4DnzuegYpj1C5Q3kzf6Ci0h-lpN9nk';
  static const _avatarComment2 =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBFDuLpFGYxEYaEPBLOnFOWPC7zike63O_KvwHojgzQzUJOQ8nTWEldD9Sub1dj0RrTcZs02mNqM-M98am8g5WdMpIOgnnE1hIuFOi79Oaz2Kqz7Kub-N_7hXYjRLJFwahwEHuQif1-bqcG1LuZSE5fJGlcH23mfWLjJKUs9ka_MOQWurRKQOp4z2tzX383EDZnmzLKj0728KkDESPWo4tibnVMutPx90oJaOaTZjFFVIHwyBp307aCZF8NUOt-GhUIyRUZE8Oanw0';
  static const _avatarComment3 =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuB2WPNzAviC7iU8ms3KiKBaxmA2_G6GWsC9GJklw_b6Lk0XifL2dPD3H5dY24im9MDw_cPipKeAioqs1LkdzK5nye7sFGffPbP2pVWwX1o6Ae_ixdbAYq9vYY9R0QME3PCxqhw2mu4STaFlebmJLyByc7HGsQd8ZIdBkdy47SPq2a1mhfIE7UEFaoat1tBwv8mAEMM3Tst6vZbFpOysq15gSuRZhJCWKn6wHJnDFC7ALQZQn20K1bCfINzZxxOsOh5EVdft76LGddE';
  static const _avatarComment4 =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDDk5ayrz3kEo3MUJQ5ldnvSHrQslnEJmW4dMxd_i6jqJ8NGtl4N3nqcXlxRVNkB1t_GrFu9P3tWG_tqCBOJ1u_UuiG6YXHSOKWoKiLO5NXoxSUyZ4yxbDfo80RXlbWmzZKWz0PMG14R1gVLyhLuryHuf8LRYyCFSvw8uXXurpXaYMoGjS_yWsUcrRoK7r3-UM6EYKi5hr5bsSlmB-XU1qw-Hkp0gCSYHqLEyOZmL_WSu-eUDxro7ev9aJ0YQYrLsZr3tsps6NWQyc';
  static const _avatarComment5 =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAs3sto2wNNC31DB7ptTK8fc4qze0_A4Do3oLD1U_vn3KdV0fxSAHtkkuz0tBq3jjLLkEx7VLJeIwg6_lwlNRLl10XxH4x6ICoEa7Ol_Xis9CC1ux66c1UaoqaV3nXgXHtBsd6BDyOH7A9AplAsZC__pflGYIMuMW6X7V7cDdip4aRLB2MBSQzGrmAQSDprwXrJxWF_c0yQjm9ej-0qgj-G3XPBl3j5sJQFryQdbiKkCspgM6VsXTOdpM3GFu3ubhCtjR4agLky8u8';

  // ══════════════════════════════════════════════════════════════════════════
  // CURRENT USER
  // ══════════════════════════════════════════════════════════════════════════

  static const currentUser = UserProfile(
    id: 'u001',
    name: 'Promex',
    avatarUrl: _avatarUser,
    bio: 'Podcast enthusiast 🎧',
    listeningHours: 142,
    podcastCount: 12,
    followingCount: 186,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // HOSTS
  // ══════════════════════════════════════════════════════════════════════════

  static const hostAnhBa = Host(
    id: 'h001',
    name: 'Anh Ba',
    avatarUrl: _avatarAnhBa,
    voiceId: 'vi-VN-male-01',
    role: 'host',
  );

  static const hostLinh = Host(
    id: 'h002',
    name: 'Linh',
    avatarUrl: _avatarLinh,
    voiceId: 'vi-VN-female-01',
    role: 'co-host',
  );

  static const hostDetective = Host(
    id: 'h003',
    name: 'Detective Minh',
    avatarUrl: _avatarHost,
    voiceId: 'en-US-male-01',
    role: 'host',
  );

  static const hostNarrator = Host(
    id: 'h004',
    name: 'Narrator',
    avatarUrl: _avatarMaiAnh,
    voiceId: 'en-US-female-01',
    role: 'co-host',
  );

  // ══════════════════════════════════════════════════════════════════════════
  // PODCASTS + EPISODES
  // ══════════════════════════════════════════════════════════════════════════

  static const podcasts = [
    Podcast(
      id: 'p001',
      title: 'Future Minds',
      hosts: [hostAnhBa, hostLinh],
      category: 'Công nghệ',
      imageUrl: _coverFutureMinds,
      subscriberCount: '12.5k',
      totalEpisodeCount: 42,
      episodes: [
        Episode(
          id: 'e001',
          podcastId: 'p001',
          title: 'MVC thời hiện đại: Cũ nhưng không kỹ',
          description: 'Tổng kết về ưu nhược điểm và cái nhìn nhanh về các \'họ hàng\' như MVVM hay MVP.',
          duration: Duration(minutes: 32),
          images: [_coverFutureMinds, _unsplash1, _unsplash2, _unsplash3],
          tags: ['#AI', '#Tech', '#Future'],
          bubbles: [
            ChatBubble(speakerId: 'h001', speaker: 'Anh Ba', text: 'Lùi lại một chút để nhìn bức tranh toàn cảnh hơn.', isRight: true, colorValue: 0xFFFFFFFF),
            ChatBubble(speakerId: 'h002', speaker: 'Linh', text: '"Em hiểu rồi! Kiểu như là..." nhìn lại xem cụ tổ MVC của chúng ta bây giờ đang đứng ở đâu trong thế giới công nghệ thay đổi chóng mặt này đúng không anh?', isRight: false, colorValue: 0xFFCCCCCC),
          ],
          likes: 12500,
          comments: 842,
        ),
        Episode(
          id: 'e002',
          podcastId: 'p001',
          title: 'Nhìn nhanh về MVVM và MVP',
          description: 'So sánh hai pattern phổ biến nhất trong mobile development.',
          duration: Duration(minutes: 28),
          images: [_coverFutureMinds, _unsplash2],
          tags: ['#Architecture', '#Mobile'],
          likes: 8300,
          comments: 421,

        ),
        Episode(
          id: 'e003',
          podcastId: 'p001',
          title: 'Clean Architecture thực chiến',
          description: 'Hành trình apply Clean Architecture vào dự án thực tế.',
          duration: Duration(minutes: 35),
          images: [_coverFutureMinds],
          tags: ['#CleanArch'],
          likes: 6100,
          comments: 310,

        ),
      ],
    ),
    Podcast(
      id: 'p002',
      title: 'True Crime Daily',
      hosts: [hostDetective, hostNarrator],
      category: 'Điều tra',
      imageUrl: _coverTrueCrime,
      subscriberCount: '8.2k',
      totalEpisodeCount: 31,
      episodes: [
        Episode(
          id: 'e004',
          podcastId: 'p002',
          title: '"The evidence was right there."',
          description: 'We looked at it a hundred times, but we didn\'t *see* it. A cold case from 1995 is finally solved using new DNA technology.',
          duration: Duration(minutes: 45),
          images: [_coverTrueCrime, _unsplash4],
          likes: 84200,
          comments: 5200,

        ),
        Episode(
          id: 'e005',
          podcastId: 'p002',
          title: 'Vụ án chưa có lời giải từ 1995.',
          description: 'Chi tiết vụ án từ những manh mối đầu tiên.',
          duration: Duration(minutes: 38),
          images: [_coverTrueCrime],
          likes: 21300,
          comments: 1800,

        ),
        Episode(
          id: 'e006',
          podcastId: 'p002',
          title: 'Kết quả phá án bất ngờ từ DNA.',
          description: 'Công nghệ DNA forensics đã thay đổi hoàn toàn cục diện.',
          duration: Duration(minutes: 41),
          images: [_coverTrueCrime],
          likes: 15700,
          comments: 920,

        ),
      ],
    ),
  ];

  // Convenience: get all episodes flat
  static List<Episode> get allEpisodes =>
      podcasts.expand((p) => p.episodes).toList();

  // Convenience: get podcast by id
  static Podcast? getPodcastById(String id) {
    try {
      return podcasts.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // Convenience: get episode by id
  static Episode? getEpisodeById(String id) {
    try {
      return allEpisodes.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NEWS FEED
  // ══════════════════════════════════════════════════════════════════════════

  static final newsArticles = [
    NewsArticle(
      id: 'n001',
      title: 'FPT giảm lao động sau nhiều năm tăng nóng: Hàng chục nghìn kỹ sư hiện hữu s...',
      description: 'Ba điểm cốt lõi trong chính sách mới của FPT liên quan đến trí tuệ nhân tạo...',
      imageUrl: _coverFutureMinds,
      publisher: 'CafeBiz',
      time: '9h',
    ),
    NewsArticle(
      id: 'n002',
      title: 'Lãi 120 tỷ USD/năm, Nvidia trở thành cỗ máy in tiền khổng lồ, xóa tan hoài nghi v...',
      description: 'Nvidia tiếp tục công bố mức lợi nhuận kỷ lục, khẳng định vị trí độc tôn trong mảng chip AI...',
      imageUrl: _coverTrueCrime,
      publisher: 'GenK',
      time: '8h',
    ),
    NewsArticle(
      id: 'n003',
      title: 'Podcast industry trends: Why short-form audio is taking over social media platforms',
      description: 'Analysis on how user behavior is shifting towards bite-sized audio content...',
      imageUrl: _coverAiNewsExtra,
      publisher: 'TechCrunch',
      time: '12h',
      isAdded: true,
    ),
    NewsArticle(
      id: 'n004',
      title: 'AI Overview: Hàng loạt các startup công nghệ mọc lên như nấm',
      description: 'Bức tranh khởi nghiệp đang thay đổi liên tục với sự trỗi dậy của AI...',
      imageUrl: _coverVnExpress,
      publisher: 'VnExpress',
      time: '1 ngày',
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // NEWS CATEGORIES
  // ══════════════════════════════════════════════════════════════════════════

  static const newsCategories = [
    '🔥 Nóng hổi',
    '💻 Công nghệ',
    '🚀 Khởi nghiệp',
    '🪙 Crypto',
    '🎨 Design',
    '💰 Tài chính',
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // HOME FILTER CATEGORIES
  // ══════════════════════════════════════════════════════════════════════════

  static const homeFilters = [
    'Tất cả',
    'Công nghệ',
    'Kể chuyện',
    'Điều tra',
    'Kinh doanh',
    'Sức khỏe',
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // COMMENTS
  // ══════════════════════════════════════════════════════════════════════════

  static final comments = [
    Comment(
      id: 'c001',
      author: 'Thành Thái 💖⚜️',
      avatarUrl: _avatarComment1,
      text: 'Looks exactly like Ba Dinh Nga Son',
      time: '02-09',
      likes: 5,
      viewMoreRepliesCount: 2,
      replies: [
        Comment(
          id: 'c001r1',
          author: '10a10-k62',
          avatarUrl: _avatarComment2,
          text: 'Correct!',
          time: '02-09',
          likes: 4,
        ),
      ],
    ),
    Comment(
      id: 'c002',
      author: 'ghuy',
      avatarUrl: _avatarComment3,
      text: 'So trendy ladies',
      time: '02-08',
      likes: 2,
      isStoryAvatar: true,
      viewMoreRepliesCount: 3,
    ),
    Comment(
      id: 'c003',
      author: 'khi nào xinh gái thì đổi tên',
      avatarUrl: _avatarComment4,
      text: 'Which school is this please?',
      time: '02-09',
      likes: 2,
    ),
    Comment(
      id: 'c004',
      author: 'Mai Linh',
      avatarUrl: _avatarComment5,
      text: 'The vibe is immaculate! Miss my high school days 🥺',
      time: '1h ago',
      likes: 0,
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ══════════════════════════════════════════════════════════════════════════

  static final _now = DateTime.now();

  static final notifications = [
    AppNotification(
      id: 'nt001',
      type: NotificationType.like,
      actorId: 'u_trung',
      actorName: 'Trung Phan',
      actorAvatarUrl: _avatarHost,
      action: 'liked your episode',
      targetType: NotificationTargetType.episode,
      targetId: 'e001',
      targetTitle: 'MVC thời hiện đại',
      createdAt: _now.subtract(const Duration(minutes: 2)),
    ),
    AppNotification(
      id: 'nt002',
      type: NotificationType.comment,
      actorId: 'u_linh',
      actorName: 'Linh Nguyen',
      actorAvatarUrl: _avatarLinh,
      action: 'commented on',
      targetType: NotificationTargetType.episode,
      targetId: 'e001',
      targetTitle: 'AI sẽ thay thế Dev?',
      preview: '"Anh ơi phần cuối hay quá! Em muốn nghe thêm về..."',
      createdAt: _now.subtract(const Duration(minutes: 15)),
    ),
    AppNotification(
      id: 'nt003',
      type: NotificationType.follow,
      actorId: 'h001',
      actorName: 'Anh Ba',
      actorAvatarUrl: _avatarAnhBa,
      action: 'started following you',
      targetType: NotificationTargetType.profile,
      targetId: 'h001',
      createdAt: _now.subtract(const Duration(hours: 1)),
    ),
    AppNotification(
      id: 'nt004',
      type: NotificationType.milestone,
      actorId: 'p001',
      actorName: 'Future Minds',
      actorAvatarUrl: _coverFutureMinds,
      action: 'reached 10K listens! 🎉',
      targetType: NotificationTargetType.podcast,
      targetId: 'p001',
      createdAt: _now.subtract(const Duration(hours: 3)),
      readAt: _now.subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 'nt005',
      type: NotificationType.like,
      actorId: 'u_mai',
      actorName: 'Mai Anh & 12 others',
      actorAvatarUrl: _avatarMaiAnh,
      action: 'liked your episode',
      targetType: NotificationTargetType.episode,
      targetId: 'e003',
      targetTitle: 'Chuyện làm Product',
      createdAt: _now.subtract(const Duration(hours: 5)),
      readAt: _now.subtract(const Duration(hours: 4)),
    ),
    AppNotification(
      id: 'nt006',
      type: NotificationType.newEpisode,
      actorId: 'p002',
      actorName: 'True Crime Daily',
      actorAvatarUrl: _coverTrueCrime,
      action: 'published a new episode',
      targetType: NotificationTargetType.episode,
      targetId: 'e004',
      targetTitle: '"The evidence was right there."',
      createdAt: _now.subtract(const Duration(hours: 8)),
      readAt: _now.subtract(const Duration(hours: 6)),
    ),
    AppNotification(
      id: 'nt007',
      type: NotificationType.comment,
      actorId: 'u_dev',
      actorName: 'Dev Community',
      actorAvatarUrl: _avatarAnhBa,
      action: 'replied to your comment on',
      targetType: NotificationTargetType.episode,
      targetTitle: 'Tech Trends 2024',
      preview: '"Đồng ý với bạn, micro-frontend là tương lai!"',
      createdAt: _now.subtract(const Duration(days: 1)),
      readAt: _now.subtract(const Duration(hours: 20)),
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // PROFILE: FOLLOWING CHANNELS
  // ══════════════════════════════════════════════════════════════════════════

  static const followingChannels = [
    {'name': 'Future Minds',     'category': 'Công nghệ', 'imageUrl': _coverFutureMinds},
    {'name': 'True Crime Daily', 'category': 'Điều tra',  'imageUrl': _coverTrueCrime},
    {'name': 'Mindful Hours',    'category': 'Sức khỏe',  'imageUrl': _coverMindful},
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // PROFILE: MY CREATIONS
  // ══════════════════════════════════════════════════════════════════════════

  static const myCreations = [
    {'title': 'Tech Trends 2024',   'subtitle': '24 Episodes', 'badge': 'Published', 'isPublished': true,  'imageUrl': _coverMindful},
    {'title': 'UI Design Systems',  'subtitle': '8 Episodes',  'badge': 'Draft',     'isPublished': false, 'imageUrl': _avatarMaiAnh},
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // PROFILE: SAVED EPISODES (references into podcasts above)
  // ══════════════════════════════════════════════════════════════════════════

  static List<Episode> get savedEpisodes => [
    allEpisodes.firstWhere((e) => e.id == 'e001'),
    allEpisodes.firstWhere((e) => e.id == 'e004'),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // CURRENT USER: LISTENING PROGRESS
  // ══════════════════════════════════════════════════════════════════════════

  static final currentUserProgress = [
    ListeningProgress(
      episodeId: 'e001',
      podcastId: 'p001',
      progress: 0.33,
      position: const Duration(minutes: 10, seconds: 34),
      totalDuration: const Duration(minutes: 32),
      lastPlayedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    ListeningProgress(
      episodeId: 'e004',
      podcastId: 'p002',
      progress: 0.72,
      position: const Duration(minutes: 32, seconds: 24),
      totalDuration: const Duration(minutes: 45),
      lastPlayedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  /// Get progress for a specific episode (current user)
  static ListeningProgress? getProgressForEpisode(String episodeId) {
    try {
      return currentUserProgress.firstWhere((p) => p.episodeId == episodeId);
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CREATION FLOW: HOSTS FOR PLAN
  // ══════════════════════════════════════════════════════════════════════════

  static const planHostSarah = Host(
    id: 'h_sarah',
    name: 'Sarah',
    avatarUrl: _avatarLinh,
    voiceId: 'en-US-female-pro',
    role: 'host',
  );

  static const planHostMarcus = Host(
    id: 'h_marcus',
    name: 'Marcus',
    avatarUrl: _avatarAnhBa,
    voiceId: 'en-US-male-analytical',
    role: 'co-host',
  );

  // ══════════════════════════════════════════════════════════════════════════
  // CREATION FLOW: PRODUCTION PLAN
  // ══════════════════════════════════════════════════════════════════════════

  static final samplePlan = ProductionPlan(
    id: 'plan_001',
    seriesTitle: 'The Oracle Portfolio',
    seriesDescription:
        "A deep dive into Warren Buffett's investment philosophy and early career milestones.",
    hosts: const [planHostSarah, planHostMarcus],
    tags: const ['Analytical', 'Professional'],
    toneStyle: 'Analytical, Professional',
    episodes: const [
      EpisodeDraft(
        id: 'draft_001',
        number: 1,
        title: 'The Foundation Years',
        description: 'Early partnerships and the Graham-Newman era.',
        estimatedDuration: Duration(minutes: 15),
        notes: 'Focus largely on the early 1950s.',
      ),
      EpisodeDraft(
        id: 'draft_002',
        number: 2,
        title: 'Growth & Acquisition',
        description: 'Shifting from cigar butts to quality companies.',
        estimatedDuration: Duration(minutes: 20),
        notes: 'Mention the Berkshire Hathaway textile mill purchase.',
      ),
      EpisodeDraft(
        id: 'draft_003',
        number: 3,
        title: 'The Modern Legacy',
        description: 'Global scaling and philanthropic transitions.',
        estimatedDuration: Duration(minutes: 10),
        notes: 'Conclude with the succession plan.',
      ),
    ],
    status: PlanStatus.draft,
    createdAt: DateTime(2026, 3, 1, 10, 0),
    updatedAt: DateTime(2026, 3, 1, 10, 30),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // CREATION FLOW: CHAT THREAD
  // ══════════════════════════════════════════════════════════════════════════

  static final sampleChatThread = ChatThread(
    id: 'thread_001',
    title: 'The Oracle Portfolio',
    createdAt: DateTime(2026, 3, 1, 9, 50),
    updatedAt: DateTime(2026, 3, 1, 10, 30),
    messages: [
      ChatMessage(
        id: 'msg_001',
        role: ChatRole.user,
        text: 'Make it more professional and focus on the early investment years for the first episode.',
        timestamp: DateTime(2026, 3, 1, 10, 25),
      ),
      ChatMessage(
        id: 'msg_002',
        role: ChatRole.assistant,
        text: "Sure, I've refined the tone to be more analytical and adjusted the episode breakdown to emphasize the formative years. Here is the updated production plan:",
        timestamp: DateTime(2026, 3, 1, 10, 26),
        plan: samplePlan,
      ),
    ],
  );
}
