import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/features/auth/domain/auth_user.dart';

const Color _editCanvas = Color(0xFFFFFBF6);
const Color _editSurface = Color(0xFFFFFEFC);
const Color _editSurfaceStrong = Color(0xFFF2E6D9);
const Color _editPrimary = Color(0xFFBF5700);
const Color _editSecondary = Color(0xFFE1AD01);
const Color _editTertiary = Color(0xFF566931);
const Color _editNeutral = Color(0xFF3E2723);
const Color _editMuted = Color(0xFF7E665F);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({required this.user, super.key});

  final AuthUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.user.displayName,
    );
    _usernameController = TextEditingController(
      text: widget.user.username ?? '',
    );
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _showUnavailableMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('API cập nhật hồ sơ chưa sẵn sàng.'),
        backgroundColor: _editNeutral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.user.avatarUrl?.trim() ?? '';

    return Scaffold(
      backgroundColor: _editCanvas,
      appBar: AppBar(
        backgroundColor: _editCanvas,
        surfaceTintColor: _editCanvas,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: _editNeutral),
        ),
        title: Text(
          'Chỉnh sửa hồ sơ',
          style: GoogleFonts.newsreader(
            color: _editNeutral,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _showUnavailableMessage,
            child: Text(
              'Lưu',
              style: GoogleFonts.workSans(
                color: _editPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 44),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _editSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _editNeutral.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _editSecondary.withValues(alpha: 0.42),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _editPrimary.withValues(alpha: 0.10),
                        blurRadius: 22,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(54),
                    child: avatarUrl.isEmpty
                        ? Container(
                            color: _editSurfaceStrong,
                            alignment: Alignment.center,
                            child: Text(
                              _initialsFor(widget.user.displayName),
                              style: GoogleFonts.workSans(
                                color: _editNeutral,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : Image.network(avatarUrl, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Ảnh đại diện hiện được lấy từ tài khoản đã xác thực.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.workSans(
                    fontSize: 12,
                    color: _editMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Thông tin công khai',
            subtitle: 'Những gì người khác sẽ nhìn thấy trên hồ sơ của bạn.',
            children: [
              _FormField(
                controller: _displayNameController,
                label: 'Tên hiển thị',
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: _usernameController,
                label: 'Tên người dùng',
                prefix: '@',
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: _bioController,
                label: 'Tiểu sử',
                maxLines: 4,
                maxLength: 150,
                onChanged: (_) => setState(() {}),
                footer:
                    '${_bioController.text.trim().characters.length.clamp(0, 150)}/150',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Tài khoản',
            subtitle: 'Thông tin đang đồng bộ từ phiên đăng nhập hiện tại.',
            children: [
              _ProfileInfoTile(
                icon: Icons.email_outlined,
                title: widget.user.email,
                subtitle: 'Email đăng nhập',
              ),
              const SizedBox(height: 10),
              _ProfileInfoTile(
                icon: Icons.badge_outlined,
                title: widget.user.accountType,
                subtitle: 'Loại tài khoản',
              ),
              const SizedBox(height: 10),
              _ProfileInfoTile(
                icon: Icons.schedule_outlined,
                title: widget.user.timezone,
                subtitle: 'Múi giờ',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _editTertiary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _editTertiary.withValues(alpha: 0.16)),
            ),
            child: Text(
              'Màn này đã dùng dữ liệu thật từ session hiện tại. Chức năng cập nhật hồ sơ sẽ bật tiếp khi identity-service có write API.',
              style: GoogleFonts.workSans(
                fontSize: 12,
                color: _editNeutral.withValues(alpha: 0.82),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _editSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _editNeutral.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.newsreader(
              color: _editNeutral,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.workSans(
              color: _editMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    this.prefix,
    this.maxLines = 1,
    this.maxLength,
    this.footer,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? prefix;
  final int maxLines;
  final int? maxLength;
  final String? footer;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.workSans(
            color: _editNeutral,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          style: GoogleFonts.workSans(
            color: _editNeutral,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          decoration: InputDecoration(
            prefixText: prefix,
            prefixStyle: GoogleFonts.workSans(
              color: _editMuted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            counterText: '',
            hintStyle: GoogleFonts.workSans(
              color: _editMuted.withValues(alpha: 0.72),
            ),
            filled: true,
            fillColor: _editSurfaceStrong,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: _editNeutral.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: _editNeutral.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              borderSide: BorderSide(color: _editPrimary, width: 1.4),
            ),
          ),
        ),
        if ((footer ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                footer!,
                style: GoogleFonts.workSans(
                  color: _editMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _editSurfaceStrong,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _editSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _editPrimary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.workSans(
                    color: _editNeutral,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.workSans(color: _editMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
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
