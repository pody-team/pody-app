import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/screens/user/change_password_screen.dart';

const _settingsCanvas = Color(0xFFF7F0E8);
const _settingsPrimary = Color(0xFFBF5700);
const _settingsNeutral = Color(0xFF3E2723);
const _settingsSurface = Color(0xFFFFFBF6);
const _settingsSurfaceStrong = Color(0xFFF1E2D3);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;

  Future<void> _handleSignOut() async {
    final authController = AuthScope.of(context);
    await authController.signOut();
    if (!mounted) {
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showSoonMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmClearCache() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _settingsSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Xóa bộ nhớ đệm?',
          style: GoogleFonts.newsreader(
            color: _settingsNeutral,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Thao tác này sẽ giải phóng khoảng 1.2 GB dung lượng tạm.',
          style: GoogleFonts.workSans(
            color: _settingsNeutral.withValues(alpha: 0.72),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSoonMessage('Đã xóa bộ nhớ đệm cục bộ.');
            },
            child: Text(
              'Xóa',
              style: GoogleFonts.workSans(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _settingsSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Đăng xuất?',
          style: GoogleFonts.newsreader(
            color: _settingsNeutral,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Bạn có chắc muốn đăng xuất khỏi thiết bị này không?',
          style: GoogleFonts.workSans(
            color: _settingsNeutral.withValues(alpha: 0.72),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _handleSignOut();
            },
            child: Text(
              'Đăng xuất',
              style: GoogleFonts.workSans(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.of(context);
    final user = authController.session?.user;
    final displayName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName
        : 'Tài khoản Pody';
    final email = user?.email ?? 'creator@pody.vn';

    return Scaffold(
      backgroundColor: _settingsCanvas,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_settingsSurface, _settingsCanvas],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cài đặt hồ sơ',
                          style: GoogleFonts.workSans(
                            color: _settingsNeutral,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _settingsSurface,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: _settingsPrimary.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _settingsNeutral.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: _settingsSurfaceStrong,
                          child: Text(
                            _initialsFor(displayName),
                            style: GoogleFonts.workSans(
                              color: _settingsNeutral,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hồ sơ & quyền riêng tư',
                                style: GoogleFonts.workSans(
                                  color: _settingsPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                displayName,
                                style: GoogleFonts.newsreader(
                                  color: _settingsNeutral,
                                  fontSize: 28,
                                  height: 0.98,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: GoogleFonts.workSans(
                                  color: _settingsNeutral.withValues(
                                    alpha: 0.64,
                                  ),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
                  child: _SectionLabel(
                    title: 'Tài khoản',
                    description:
                        'Các thiết lập đăng nhập, thông báo và bảo mật cơ bản cho hồ sơ của bạn.',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.lock_outline_rounded,
                        title: 'Đổi mật khẩu',
                        subtitle: 'Cập nhật bảo mật cho tài khoản đăng nhập',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ChangePasswordScreen(),
                            ),
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        title: 'Thông báo đẩy',
                        subtitle: 'Nhận cập nhật khi show và tập đã sẵn sàng',
                        trailing: Switch(
                          value: _pushNotifications,
                          onChanged: (value) {
                            setState(() => _pushNotifications = value);
                          },
                          activeThumbColor: Colors.white,
                          activeTrackColor: _settingsPrimary,
                          inactiveThumbColor: _settingsNeutral.withValues(
                            alpha: 0.38,
                          ),
                          inactiveTrackColor: _settingsNeutral.withValues(
                            alpha: 0.12,
                          ),
                        ),
                      ),
                      _SettingsTile(
                        icon: Icons.mail_outline_rounded,
                        title: 'Thông báo email',
                        subtitle: 'Tùy chọn digest và cập nhật qua email',
                        onTap: () {
                          _showSoonMessage(
                            'Thiết lập thông báo email sẽ sớm được hỗ trợ.',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
                  child: _SectionLabel(
                    title: 'Riêng tư & dữ liệu',
                    description:
                        'Quản lý bộ nhớ đệm, tải xuống và các mục hỗ trợ hệ thống.',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.shield_outlined,
                        title: 'Trung tâm quyền riêng tư',
                        subtitle: 'Quyền, dữ liệu và các lựa chọn hiển thị',
                        onTap: () {
                          _showSoonMessage(
                            'Trung tâm quyền riêng tư sẽ sớm được hỗ trợ.',
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Icons.visibility_off_outlined,
                        title: 'Danh sách chặn',
                        subtitle: 'Quản lý tài khoản và creator đã chặn',
                        onTap: () {
                          _showSoonMessage(
                            'Danh sách chặn sẽ sớm được hỗ trợ.',
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Icons.cleaning_services_outlined,
                        title: 'Xóa bộ nhớ đệm',
                        subtitle: 'Đang dùng khoảng 1.2 GB dữ liệu tạm',
                        onTap: _confirmClearCache,
                      ),
                      _SettingsTile(
                        icon: Icons.high_quality_rounded,
                        title: 'Chất lượng tải xuống',
                        subtitle:
                            'Ưu tiên âm thanh chất lượng cao khi lưu offline',
                        trailingText: 'Cao',
                        onTap: () {
                          _showSoonMessage(
                            'Tùy chọn chất lượng tải xuống sẽ sớm được hỗ trợ.',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
                  child: _SectionLabel(
                    title: 'Hỗ trợ',
                    description:
                        'Thông tin phiên bản, trợ giúp và kênh hỗ trợ sản phẩm.',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Trung tâm trợ giúp',
                        subtitle: 'Câu hỏi thường gặp và hướng dẫn sử dụng',
                        onTap: () {
                          _showSoonMessage(
                            'Trung tâm trợ giúp sẽ sớm được hỗ trợ.',
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: 'Phiên bản ứng dụng',
                        subtitle: 'Thông tin build hiện tại của Pody',
                        trailingText: 'v2.4.1',
                        onTap: () {
                          _showSoonMessage('Bạn đang dùng Pody v2.4.1.');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 120),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _confirmSignOut,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Đăng xuất',
                              style: GoogleFonts.workSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: _settingsNeutral.withValues(alpha: 0.08)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: _settingsNeutral, size: 18),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.workSans(
            color: _settingsPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: GoogleFonts.workSans(
            color: _settingsNeutral.withValues(alpha: 0.68),
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _settingsSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _settingsNeutral.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.trailingText,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveTrailing =
        trailing ??
        Icon(
          Icons.chevron_right_rounded,
          color: _settingsNeutral.withValues(alpha: 0.3),
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _settingsPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _settingsPrimary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.workSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _settingsNeutral,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        color: _settingsNeutral.withValues(alpha: 0.6),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    trailingText!,
                    style: GoogleFonts.workSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _settingsNeutral.withValues(alpha: 0.56),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: effectiveTrailing,
              ),
            ],
          ),
        ),
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
