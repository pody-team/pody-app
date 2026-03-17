import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pody/features/auth/presentation/auth_error_message.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/screens/auth/auth_components.dart';
import 'package:pody/screens/auth/sign_in_screen.dart';
import 'package:pody/theme/app_colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateCurrentPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Nhập mật khẩu hiện tại của bạn.';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Nhập mật khẩu mới.';
    }
    if (password.length < 8) {
      return 'Mật khẩu mới cần ít nhất 8 ký tự.';
    }
    if (password == _currentPasswordController.text) {
      return 'Hãy chọn một mật khẩu mới khác mật khẩu hiện tại.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Nhập lại mật khẩu mới để xác nhận.';
    }
    if (value != _newPasswordController.text) {
      return 'Mật khẩu xác nhận chưa khớp.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authController = AuthScope.of(context);
    final email = authController.session?.user.email ?? '';
    setState(() => _isSubmitting = true);

    try {
      await authController.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      await authController.signOut();
      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SignInScreen(
            initialEmail: email,
            noticeMessage:
                'Mật khẩu đã được cập nhật. Hãy đăng nhập lại để tiếp tục.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(humanizeAuthError(error))));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBlack,
      body: Stack(
        children: [
          const AuthBackgroundOrb(
            top: -80,
            right: -120,
            diameter: 260,
            color: Color(0x26FF6666),
          ),
          const AuthBackgroundOrb(
            bottom: -40,
            left: -80,
            diameter: 220,
            color: Color(0x2239D3C6),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuthBackButton(),
                    const SizedBox(height: 20),
                    const Text(
                      'Đổi mật khẩu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cập nhật mật khẩu mới để bảo vệ tài khoản của bạn. Sau khi đổi xong, ứng dụng sẽ yêu cầu đăng nhập lại.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const AuthInfoCard(
                      title: 'Lưu ý bảo mật',
                      message:
                          'Mật khẩu mới nên có ít nhất 8 ký tự và khác với mật khẩu hiện tại để tránh đăng nhập nhầm trên các thiết bị cũ.',
                      icon: Icons.shield_outlined,
                      accentColor: kTikTeal,
                    ),
                    const SizedBox(height: 24),
                    AutofillGroup(
                      child: Column(
                        children: [
                          AuthTextField(
                            controller: _currentPasswordController,
                            label: 'Mật khẩu hiện tại',
                            hintText: 'Nhập mật khẩu bạn đang dùng',
                            prefixIcon: Icons.lock_outline,
                            obscureText: _hideCurrentPassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.password],
                            validator: _validateCurrentPassword,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hideCurrentPassword = !_hideCurrentPassword;
                                });
                              },
                              icon: Icon(
                                _hideCurrentPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          AuthTextField(
                            controller: _newPasswordController,
                            label: 'Mật khẩu mới',
                            hintText: 'Tối thiểu 8 ký tự',
                            prefixIcon: Icons.password_outlined,
                            obscureText: _hideNewPassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: _validateNewPassword,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hideNewPassword = !_hideNewPassword;
                                });
                              },
                              icon: Icon(
                                _hideNewPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          AuthTextField(
                            controller: _confirmPasswordController,
                            label: 'Nhập lại mật khẩu mới',
                            hintText: 'Xác nhận lại mật khẩu mới',
                            prefixIcon: Icons.verified_user_outlined,
                            obscureText: _hideConfirmPassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: _validateConfirmPassword,
                            onFieldSubmitted: (_) => _submit(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hideConfirmPassword = !_hideConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _hideConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    AuthPrimaryButton(
                      label: 'Cập nhật mật khẩu',
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              Clipboard.setData(
                                ClipboardData(
                                  text:
                                      AuthScope.of(
                                        context,
                                      ).session?.user.email ??
                                      '',
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Email đăng nhập của bạn đã được sao chép để dùng khi cần khôi phục mật khẩu.',
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Sao chép email tài khoản'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
