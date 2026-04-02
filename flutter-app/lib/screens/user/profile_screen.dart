import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/auth/domain/auth_user.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/features/content/presentation/content_legacy_mapper.dart';
import 'package:pody/features/content/presentation/content_scope.dart';
import 'package:pody/screens/auth/sign_in_screen.dart';
import 'package:pody/screens/auth/sign_up_screen.dart';
import 'package:pody/screens/show/creator_show_detail_screen.dart';
import 'package:pody/screens/show/content_show_detail_screen.dart';
import 'package:pody/utils/player_utils.dart';

import 'edit_profile_screen.dart';
import 'settings_screen.dart';

const _profileCanvas = Color(0xFFF7F0E8);
const _profilePrimary = Color(0xFFBF5700);
const _profileSecondary = Color(0xFFE1AD01);
const _profileTertiary = Color(0xFF566931);
const _profileNeutral = Color(0xFF3E2723);
const _profileSurface = Color(0xFFFFFBF6);
const _profileSurfaceStrong = Color(0xFFF1E2D3);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({this.noticeMessage, this.onNoticeDismissed, super.key});

  final String? noticeMessage;
  final VoidCallback? onNoticeDismissed;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<ContentBookmarkedEpisode> _bookmarks = const [];
  List<ContentShowSummary> _shows = const [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _loadedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authController = AuthScope.of(context);
    final userId = authController.session?.user.id;
    if (!authController.isAuthenticated) {
      _loadedUserId = null;
      _bookmarks = const [];
      _shows = const [];
      _errorMessage = null;
      _isLoading = false;
      return;
    }
    if (_loadedUserId == userId) {
      return;
    }
    _loadedUserId = userId;
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final authController = AuthScope.of(context);
    if (!authController.isAuthenticated) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bookmarks = const [];
        _shows = const [];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = ContentScope.of(context);
      final results = await Future.wait<dynamic>([
        repository.listBookmarkedEpisodes(),
        repository.listMyShows(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _bookmarks = results[0] as List<ContentBookmarkedEpisode>;
        _shows = results[1] as List<ContentShowSummary>;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _humanizeError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _humanizeError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Không thể tải dữ liệu hồ sơ lúc này.';
  }

  int get _totalSubscribers {
    var total = 0;
    for (final show in _shows) {
      total += show.subscriberCount;
    }
    return total;
  }

  int get _totalEpisodes {
    var total = 0;
    for (final show in _shows) {
      total += show.totalEpisodeCount;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.of(context);
    if (!authController.isAuthenticated) {
      return _GuestProfileView(
        noticeMessage: widget.noticeMessage,
        onNoticeDismissed: widget.onNoticeDismissed,
      );
    }

    final user = authController.session!.user;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _profileCanvas,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_profileSurface, _profileCanvas],
            ),
          ),
          child: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    user: user,
                    bookmarkCount: _bookmarks.length,
                    showCount: _shows.length,
                    totalSubscribers: _totalSubscribers,
                  ),
                ),
              ],
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _profileNeutral.withValues(alpha: 0.08),
                        ),
                      ),
                      child: TabBar(
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: _profilePrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: _profilePrimary,
                        unselectedLabelColor: _profileNeutral.withValues(
                          alpha: 0.54,
                        ),
                        labelStyle: GoogleFonts.workSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                        unselectedLabelStyle: GoogleFonts.workSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: const [
                          Tab(text: 'Đã lưu'),
                          Tab(text: 'Theo dõi'),
                          Tab(text: 'Của tôi'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _SavedTab(
                          bookmarks: _bookmarks,
                          isLoading: _isLoading,
                          errorMessage: _errorMessage,
                          onRefresh: _loadProfileData,
                        ),
                        _FollowingTab(
                          isLoading: _isLoading,
                          onRefresh: _loadProfileData,
                        ),
                        _MyCreationsTab(
                          shows: _shows,
                          isLoading: _isLoading,
                          errorMessage: _errorMessage,
                          totalEpisodes: _totalEpisodes,
                          totalSubscribers: _totalSubscribers,
                          onRefresh: _loadProfileData,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.bookmarkCount,
    required this.showCount,
    required this.totalSubscribers,
  });

  final AuthUser user;
  final int bookmarkCount;
  final int showCount;
  final int totalSubscribers;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl?.trim() ?? '';
    final bio = user.bio.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: _profileSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _profilePrimary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: _profileNeutral.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _profilePrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Hồ sơ thật',
                    style: GoogleFonts.workSans(
                      color: _profilePrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                _HeaderIconButton(
                  icon: Icons.settings_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _profilePrimary.withValues(alpha: 0.14),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(42),
                child: avatarUrl.isEmpty
                    ? Container(
                        color: _profileSurfaceStrong,
                        alignment: Alignment.center,
                        child: Text(
                          _initialsFor(user.displayName),
                          style: GoogleFonts.workSans(
                            color: _profileNeutral,
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                          ),
                        ),
                      )
                    : _NetworkImageBox(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        fallback: Container(
                          color: _profileSurfaceStrong,
                          alignment: Alignment.center,
                          child: Text(
                            _initialsFor(user.displayName),
                            style: GoogleFonts.workSans(
                              color: _profileNeutral,
                              fontWeight: FontWeight.w700,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              user.displayName,
              style: GoogleFonts.newsreader(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: _profileNeutral,
                height: 0.98,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '@${user.handle}',
              style: GoogleFonts.workSans(
                fontSize: 13,
                color: _profileNeutral.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                bio,
                textAlign: TextAlign.center,
                style: GoogleFonts.workSans(
                  color: _profileNeutral.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    value: bookmarkCount.toString(),
                    label: 'Đã lưu',
                    onTap: () => DefaultTabController.of(context).animateTo(0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    value: showCount.toString(),
                    label: 'Podcast',
                    onTap: () => DefaultTabController.of(context).animateTo(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    value: _formatCount(totalSubscribers),
                    label: 'Theo dõi',
                    onTap: () => DefaultTabController.of(context).animateTo(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(user: user),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _profilePrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                'Chỉnh sửa hồ sơ',
                style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.value,
    required this.label,
    required this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: _profileCanvas,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.workSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _profileNeutral,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.workSans(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _profileNeutral.withValues(alpha: 0.5),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _profileCanvas,
          shape: BoxShape.circle,
          border: Border.all(color: _profileNeutral.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: _profileNeutral, size: 20),
      ),
    );
  }
}

class _GuestProfileView extends StatelessWidget {
  const _GuestProfileView({this.noticeMessage, this.onNoticeDismissed});

  final String? noticeMessage;
  final VoidCallback? onNoticeDismissed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _profileCanvas,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_profileSurface, _profileCanvas],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _profilePrimary.withValues(alpha: 0.08),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: _profilePrimary,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Hồ sơ của bạn',
                  style: GoogleFonts.newsreader(
                    color: _profileNeutral,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 0.98,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Đăng nhập để đồng bộ lịch sử nghe, lưu podcast yêu thích và quản lý hồ sơ của bạn trên Pody.',
                  style: GoogleFonts.workSans(
                    color: _profileNeutral.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if ((noticeMessage ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _profileTertiary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _profileTertiary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: _profileTertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Thông báo tài khoản',
                                style: GoogleFonts.workSans(
                                  color: _profileNeutral,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          noticeMessage!.trim(),
                          style: GoogleFonts.workSans(
                            color: _profileNeutral.withValues(alpha: 0.7),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: onNoticeDismissed,
                          child: Text(
                            'Đã hiểu',
                            style: GoogleFonts.workSans(
                              color: _profileTertiary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _profileSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _profileNeutral.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GuestBenefitRow(
                        icon: Icons.bookmark_outline,
                        title: 'Lưu tập yêu thích',
                        description:
                            'Giữ lại những tập bạn muốn nghe lại sau trên mọi thiết bị.',
                      ),
                      SizedBox(height: 14),
                      _GuestBenefitRow(
                        icon: Icons.graphic_eq,
                        title: 'Quản lý show của bạn',
                        description:
                            'Theo dõi các show bạn tạo và mở thẳng studio từ một chỗ.',
                      ),
                      SizedBox(height: 14),
                      _GuestBenefitRow(
                        icon: Icons.notifications_outlined,
                        title: 'Nhận thông báo hệ thống',
                        description:
                            'Biết ngay khi show, tập và transcript đã sẵn sàng.',
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SignInScreen(
                          noticeMessage: noticeMessage,
                          onNoticeDismissed: onNoticeDismissed,
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _profilePrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Đăng nhập'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _profileNeutral,
                    backgroundColor: _profileSurface,
                    side: BorderSide(
                      color: _profileNeutral.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Text('Tạo tài khoản'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bạn vẫn có thể khám phá nội dung mà chưa cần đăng nhập.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.workSans(
                    color: _profileNeutral.withValues(alpha: 0.56),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestBenefitRow extends StatelessWidget {
  const _GuestBenefitRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _profileTertiary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: _profileTertiary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.workSans(
                  color: _profileNeutral,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.workSans(
                  color: _profileNeutral.withValues(alpha: 0.7),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SavedTab extends StatelessWidget {
  const _SavedTab({
    required this.bookmarks,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
  });

  final List<ContentBookmarkedEpisode> bookmarks;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading && bookmarks.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (errorMessage != null && bookmarks.isEmpty) {
      return _EmptyTabState(
        icon: Icons.error_outline,
        title: 'Không tải được mục đã lưu',
        description: errorMessage!,
        actionLabel: 'Thử lại',
        onAction: onRefresh,
      );
    }

    if (bookmarks.isEmpty) {
      return _EmptyTabState(
        icon: Icons.bookmark_outline,
        title: 'Chưa có tập nào được lưu',
        description:
            'Khi bạn bấm tim trong player, tập đã lưu sẽ hiện ở đây trên mọi thiết bị đã đăng nhập.',
        actionLabel: 'Tải lại',
        onAction: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: bookmarks.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = bookmarks[index];
          return _SavedEpisodeRow(item: item);
        },
      ),
    );
  }
}

class _SavedEpisodeRow extends StatelessWidget {
  const _SavedEpisodeRow({required this.item});

  final ContentBookmarkedEpisode item;

  Future<void> _openEpisode(BuildContext context) async {
    try {
      final repository = ContentScope.of(context);
      final detail = await repository.getEpisodeDetail(item.episode.id);
      final bundle = await repository.getShowBundle(item.show.id);
      if (!context.mounted) {
        return;
      }
      openPlayerScreen(
        context,
        show: mapContentShowToLegacy(bundle.show, bundle.episodes),
        episode: mapContentEpisodeDetailToLegacy(
          detail,
          hosts: bundle.show.hosts,
        ),
        onOpenShow: () {
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ContentShowDetailScreen(
                showId: bundle.show.id,
                initialSummary: bundle.show.toSummary(),
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openEpisode(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _profileSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _profileNeutral.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _NetworkImageBox(
                imageUrl: item.episode.coverImageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                fallback: const _ImageFallbackBox(
                  width: 50,
                  height: 50,
                  icon: Icons.graphic_eq,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.episode.title,
                    style: GoogleFonts.workSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _profileNeutral,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.show.title}  ·  ${item.episode.formattedDuration}',
                    style: GoogleFonts.workSans(
                      fontSize: 11,
                      color: _profileNeutral.withValues(alpha: 0.52),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.play_circle_outline_rounded,
              color: _profilePrimary.withValues(alpha: 0.72),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowingTab extends StatelessWidget {
  const _FollowingTab({required this.isLoading, required this.onRefresh});

  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return _EmptyTabState(
      icon: Icons.people_outline,
      title: 'Chưa có dữ liệu theo dõi',
      description:
          'Hệ thống profile đã bỏ mock cho mục này. Khi social API sẵn sàng, danh sách creator và show đang theo dõi sẽ hiện ở đây.',
      actionLabel: isLoading ? 'Đang tải...' : 'Tải lại',
      onAction: isLoading ? null : onRefresh,
    );
  }
}

class _MyCreationsTab extends StatelessWidget {
  const _MyCreationsTab({
    required this.shows,
    required this.isLoading,
    required this.errorMessage,
    required this.totalEpisodes,
    required this.totalSubscribers,
    required this.onRefresh,
  });

  final List<ContentShowSummary> shows;
  final bool isLoading;
  final String? errorMessage;
  final int totalEpisodes;
  final int totalSubscribers;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading && shows.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (errorMessage != null && shows.isEmpty) {
      return _EmptyTabState(
        icon: Icons.error_outline,
        title: 'Không tải được danh sách show',
        description: errorMessage!,
        actionLabel: 'Thử lại',
        onAction: onRefresh,
      );
    }

    if (shows.isEmpty) {
      return _EmptyTabState(
        icon: Icons.podcasts_outlined,
        title: 'Bạn chưa có show nào',
        description:
            'Khi tạo show mới trong creator flow, nó sẽ hiện ở đây cùng số liệu subscriber và tổng số tập.',
        actionLabel: 'Tải lại',
        onAction: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Row(
            children: [
              _MiniStatCard(
                value: totalEpisodes.toString(),
                label: 'Tổng tập',
                icon: Icons.queue_music_rounded,
              ),
              const SizedBox(width: 10),
              _MiniStatCard(
                value: _formatCount(totalSubscribers),
                label: 'Người theo dõi',
                icon: Icons.people_outline,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Podcast của tôi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _profileNeutral,
            ),
          ),
          const SizedBox(height: 10),
          ...shows.map(
            (show) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CreationCard(show: show),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _profileSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _profileNeutral.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _profilePrimary, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.workSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _profileNeutral,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.workSans(
                    fontSize: 10,
                    color: _profileNeutral.withValues(alpha: 0.52),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreationCard extends StatelessWidget {
  const _CreationCard({required this.show});

  final ContentShowSummary show;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                CreatorShowDetailScreen(showId: show.id, initialSummary: show),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _profileSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _profileNeutral.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _NetworkImageBox(
                imageUrl: show.coverImageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                fallback: const _ImageFallbackBox(
                  width: 50,
                  height: 50,
                  icon: Icons.podcasts_outlined,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    show.title,
                    style: GoogleFonts.workSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _profileNeutral,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${show.totalEpisodeCount} tập  ·  ${show.formattedSubscriberCount} theo dõi',
                    style: GoogleFonts.workSans(
                      fontSize: 11,
                      color: _profileNeutral.withValues(alpha: 0.52),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _profileSecondary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'LIVE',
                style: GoogleFonts.workSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _profileNeutral,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTabState extends StatelessWidget {
  const _EmptyTabState({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 120),
      children: [
        Icon(icon, size: 48, color: _profilePrimary.withValues(alpha: 0.6)),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.newsreader(
            color: _profileNeutral,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          textAlign: TextAlign.center,
          style: GoogleFonts.workSans(
            color: _profileNeutral.withValues(alpha: 0.68),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onAction == null ? null : () => onAction!.call(),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _NetworkImageBox extends StatelessWidget {
  const _NetworkImageBox({
    required this.imageUrl,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

class _ImageFallbackBox extends StatelessWidget {
  const _ImageFallbackBox({
    required this.width,
    required this.height,
    required this.icon,
  });

  final double width;
  final double height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: _profileSurfaceStrong,
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: _profilePrimary.withValues(alpha: 0.7),
        size: 18,
      ),
    );
  }
}

String _initialsFor(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'P';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _formatCount(int value) {
  if (value >= 1000000) {
    final millions = value / 1000000;
    return millions == millions.truncateToDouble()
        ? '${millions.toInt()}M'
        : '${millions.toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    final thousands = value / 1000;
    return thousands == thousands.truncateToDouble()
        ? '${thousands.toInt()}k'
        : '${thousands.toStringAsFixed(1)}k';
  }
  return value.toString();
}

String _humanizeError(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'Không thể tải nội dung này lúc này.';
}
