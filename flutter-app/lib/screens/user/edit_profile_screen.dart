import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/auth/domain/auth_user.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';

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
  late final TextEditingController _avatarUrlController;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  final ImagePicker _imagePicker = ImagePicker();

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
    _avatarUrlController = TextEditingController(
      text: widget.user.avatarUrl ?? '',
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  String get _previewAvatarUrl => _avatarUrlController.text.trim();

  String get _effectiveDisplayName {
    final value = _displayNameController.text.trim();
    if (value.isNotEmpty) {
      return value;
    }
    return widget.user.displayName;
  }

  String? _validateLocally() {
    final displayName = _displayNameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    final bioLength = _bioController.text.trim().characters.length;
    final avatarUrl = _previewAvatarUrl;

    if (displayName.isEmpty || displayName.characters.length > 120) {
      return 'Tên hiển thị phải từ 1 đến 120 ký tự.';
    }

    final usernamePattern = RegExp(r'^[a-z0-9._]+$');
    if (username.isEmpty ||
        username.characters.length > 120 ||
        !usernamePattern.hasMatch(username)) {
      return 'Username chỉ được gồm chữ thường, số, dấu chấm và dấu gạch dưới.';
    }

    if (bioLength > 150) {
      return 'Tiểu sử tối đa 150 ký tự.';
    }

    if (avatarUrl.isNotEmpty) {
      final parsed = Uri.tryParse(avatarUrl);
      if (parsed == null ||
          parsed.host.isEmpty ||
          (parsed.scheme != 'http' && parsed.scheme != 'https')) {
        return 'Avatar URL phải bắt đầu bằng http hoặc https.';
      }
    }

    return null;
  }

  Future<void> _saveProfile() async {
    final localError = _validateLocally();
    if (localError != null) {
      _showMessage(localError);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final authController = AuthScope.of(context);
      await authController.updateProfile(
        displayName: _displayNameController.text.trim(),
        username: _usernameController.text.trim().toLowerCase(),
        bio: _bioController.text.trim(),
        avatarUrl: _previewAvatarUrl,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_humanizeError(error));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isSaving || _isUploadingAvatar) {
      return;
    }
    final authController = AuthScope.of(context);

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1600,
      );
      if (pickedFile == null) {
        return;
      }

      setState(() => _isUploadingAvatar = true);
      final bytes = await pickedFile.readAsBytes();
      final avatarUrl = await authController.uploadAvatar(
        bytes: bytes,
        fileName: pickedFile.name,
        contentType: pickedFile.mimeType,
      );
      if (!mounted) {
        return;
      }

      _avatarUrlController.text = avatarUrl;
      setState(() {});
      _showMessage('Đã tải avatar lên server.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_humanizeError(error));
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  String _humanizeError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 409) {
        return 'Username đã tồn tại. Hãy chọn tên khác.';
      }
      return error.message;
    }
    return 'Không thể cập nhật hồ sơ lúc này.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _editNeutral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _editCanvas,
      appBar: AppBar(
        backgroundColor: _editCanvas,
        surfaceTintColor: _editCanvas,
        elevation: 0,
        leading: IconButton(
          onPressed: (_isSaving || _isUploadingAvatar)
              ? null
              : () => Navigator.pop(context),
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
            onPressed: (_isSaving || _isUploadingAvatar) ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
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
                _AvatarPreview(
                  imageUrl: _previewAvatarUrl,
                  displayName: _effectiveDisplayName,
                ),
                const SizedBox(height: 14),
                Text(
                  'Chọn ảnh từ máy của bạn, ứng dụng sẽ tải lên identity-service và lưu liên kết public trên MinIO vào hồ sơ.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.workSans(
                    fontSize: 12,
                    color: _editMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_isSaving || _isUploadingAvatar)
                        ? null
                        : _pickAndUploadAvatar,
                    style: FilledButton.styleFrom(
                      backgroundColor: _editPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: _isUploadingAvatar
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.file_upload_outlined),
                    label: Text(
                      _isUploadingAvatar
                          ? 'Đang tải avatar...'
                          : 'Tải ảnh từ máy',
                      style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _FormField(
                  controller: _avatarUrlController,
                  label: 'Avatar URL',
                  hintText: 'URL sẽ được điền sau khi tải lên',
                  keyboardType: TextInputType.url,
                  readOnly: true,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: (_isSaving || _isUploadingAvatar)
                        ? null
                        : () {
                            _avatarUrlController.clear();
                            setState(() {});
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Xóa avatar'),
                    style: TextButton.styleFrom(foregroundColor: _editTertiary),
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
                onChanged: (_) => setState(() {}),
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
              'Sau khi lưu thành công, phần đầu hồ sơ sẽ cập nhật ngay trong ứng dụng mà không cần đăng nhập lại.',
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

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.imageUrl, required this.displayName});

  final String imageUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: imageUrl.isEmpty
            ? _AvatarFallback(displayName: displayName)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _AvatarFallback(displayName: displayName),
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _editSurfaceStrong,
      alignment: Alignment.center,
      child: Text(
        _initialsFor(displayName),
        style: GoogleFonts.workSans(
          color: _editNeutral,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
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
    this.hintText,
    this.keyboardType,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final String? prefix;
  final int maxLines;
  final int? maxLength;
  final String? footer;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool readOnly;

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
          readOnly: readOnly,
          keyboardType: keyboardType,
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
            hintText: hintText,
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
