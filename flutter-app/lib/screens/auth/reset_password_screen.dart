import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pody/features/auth/domain/auth_policy.dart';
import 'package:pody/features/auth/presentation/auth_error_message.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/screens/auth/auth_components.dart';
import 'package:pody/screens/auth/sign_in_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    required this.email,
    required this.otp,
    super.key,
  });

  final String email;
  final String otp;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  bool _isSubmitting = false;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Nhập mật khẩu mới.';
    }
    if (password.length < AuthPolicy.minPasswordLength) {
      return 'Mật khẩu mới cần ít nhất ${AuthPolicy.minPasswordLength} ký tự.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if ((value ?? '') != _passwordController.text) {
      return 'Mật khẩu nhập lại chưa khớp.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authController = AuthScope.of(context);
    setState(() => _isSubmitting = true);
    try {
      await authController.resetPassword(
        email: widget.email,
        otp: widget.otp,
        newPassword: _passwordController.text,
      );
      if (!mounted) {
        return;
      }

      setState(() => _isCompleted = true);
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

  void _returnToSignIn() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SignInScreen(initialEmail: widget.email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      topPadding: 20,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBackButton(),
              const SizedBox(height: 30),
              AuthHeroHeader(
                title: 'Đặt mật khẩu mới',
                subtitle: _isCompleted
                    ? 'Mật khẩu đã được cập nhật. Bạn có thể đăng nhập lại ngay bây giờ.'
                    : 'Mã OTP cho ${widget.email} đã được xác thực thành công. Bây giờ bạn chỉ cần đặt mật khẩu mới để hoàn tất.',
                badge: 'Bước 2/2',
              ),
              const SizedBox(height: 22),
              if (!_isCompleted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: kAuthSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: kAuthNeutral.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.looks_two_outlined,
                        color: kAuthTertiary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Đặt mật khẩu mới cho tài khoản của bạn.',
                          style: GoogleFonts.workSans(
                            color: kAuthNeutral,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AuthInfoCard(
                  title: 'Đang đổi mật khẩu cho',
                  message: widget.email,
                  icon: Icons.verified_user_outlined,
                  accentColor: kAuthSecondary,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: kAuthCanvasSoft.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: kAuthNeutral.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      AuthTextField(
                        controller: _passwordController,
                        label: 'Mật khẩu mới',
                        hintText: AuthPolicy.passwordHint,
                        prefixIcon: Icons.lock_outline,
                        textInputAction: TextInputAction.next,
                        obscureText: _isPasswordObscured,
                        validator: _validatePassword,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _isPasswordObscured = !_isPasswordObscured;
                            });
                          },
                          icon: Icon(
                            _isPasswordObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: kAuthMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: _confirmPasswordController,
                        label: 'Nhập lại mật khẩu mới',
                        hintText: 'Nhập lại để xác nhận',
                        prefixIcon: Icons.lock_reset_outlined,
                        textInputAction: TextInputAction.done,
                        obscureText: _isConfirmPasswordObscured,
                        validator: _validateConfirmPassword,
                        onFieldSubmitted: (_) => _submit(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordObscured =
                                  !_isConfirmPasswordObscured;
                            });
                          },
                          icon: Icon(
                            _isConfirmPasswordObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: kAuthMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      AuthPrimaryButton(
                        label: 'Cập nhật mật khẩu',
                        isLoading: _isSubmitting,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const AuthInfoCard(
                  title: 'Đặt lại mật khẩu thành công',
                  message:
                      'Mật khẩu mới đã được lưu. Bạn có thể quay lại màn đăng nhập và dùng mật khẩu mới ngay bây giờ.',
                  icon: Icons.check_circle_outline,
                  accentColor: kAuthTertiary,
                ),
                const SizedBox(height: 24),
                AuthPrimaryButton(
                  label: 'Đăng nhập ngay',
                  onPressed: _returnToSignIn,
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: _returnToSignIn,
                  child: Text(
                    'Quay lại đăng nhập',
                    style: GoogleFonts.workSans(color: kAuthMuted),
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
