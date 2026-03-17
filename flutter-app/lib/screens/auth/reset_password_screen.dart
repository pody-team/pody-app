import 'package:flutter/material.dart';

import 'package:pody/features/auth/domain/auth_policy.dart';
import 'package:pody/features/auth/presentation/auth_error_message.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/screens/auth/auth_components.dart';
import 'package:pody/screens/auth/sign_in_screen.dart';
import 'package:pody/theme/app_colors.dart';

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
    return Scaffold(
      backgroundColor: kBgBlack,
      body: Stack(
        children: [
          AuthBackgroundOrb(
            top: -60,
            left: -80,
            diameter: 260,
            blurSigma: 70,
            color: kTikTeal.withValues(alpha: 0.12),
          ),
          AuthBackgroundOrb(
            bottom: -80,
            right: -60,
            diameter: 280,
            blurSigma: 80,
            color: kTikRed.withValues(alpha: 0.10),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthBackButton(),
                      const SizedBox(height: 32),
                      const Text(
                        'Đặt mật khẩu mới',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isCompleted
                            ? 'Mật khẩu đã được cập nhật. Bạn có thể đăng nhập lại ngay bây giờ.'
                            : 'Mã OTP cho ${widget.email} đã được xác thực thành công. Bây giờ bạn chỉ cần đặt mật khẩu mới để hoàn tất.',
                        style: const TextStyle(
                          fontSize: 15,
                          color: kTextSec,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (!_isCompleted) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.looks_two_outlined,
                                color: kTikTeal,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Bước 2/2: Đặt mật khẩu mới cho tài khoản của bạn.',
                                  style: TextStyle(
                                    color: Colors.white,
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
                        ),
                        const SizedBox(height: 16),
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
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AuthPrimaryButton(
                          label: 'Cập nhật mật khẩu',
                          backgroundColor: kTikTeal,
                          foregroundColor: Colors.black,
                          isLoading: _isSubmitting,
                          onPressed: _submit,
                        ),
                      ] else ...[
                        const AuthInfoCard(
                          title: 'Đặt lại mật khẩu thành công',
                          message:
                              'Mật khẩu mới đã được lưu. Bạn có thể quay lại màn đăng nhập và dùng mật khẩu mới ngay bây giờ.',
                          icon: Icons.check_circle_outline,
                        ),
                        const SizedBox(height: 24),
                        AuthPrimaryButton(
                          label: 'Đăng nhập ngay',
                          onPressed: () {
                            _returnToSignIn();
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: _returnToSignIn,
                          child: const Text(
                            'Quay lại đăng nhập',
                            style: TextStyle(color: kTextSec),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
