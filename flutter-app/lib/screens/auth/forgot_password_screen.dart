import 'package:flutter/material.dart';

import 'package:pody/features/auth/presentation/auth_error_message.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/screens/auth/auth_components.dart';
import 'package:pody/screens/auth/verify_reset_otp_screen.dart';
import 'package:pody/theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  bool _isSubmitting = false;

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
    _emailController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Nhập email để nhận mã OTP.';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Email chưa đúng định dạng.';
    }
    return null;
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authController = AuthScope.of(context);
    setState(() => _isSubmitting = true);
    try {
      final challenge = await authController.forgotPassword(
        _emailController.text.trim(),
      );
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyResetOTPScreen(
            initialEmail: challenge.email.isNotEmpty
                ? challenge.email
                : _emailController.text.trim(),
            otpLength: challenge.otpLength,
            otpExpiresAt: challenge.otpExpiresAt,
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
          AuthBackgroundOrb(
            top: -80,
            right: -80,
            diameter: 260,
            blurSigma: 70,
            color: kTikTeal.withValues(alpha: 0.12),
          ),
          AuthBackgroundOrb(
            bottom: -60,
            left: -60,
            diameter: 240,
            blurSigma: 70,
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
                      const SizedBox(height: 36),
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: kTikRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.lock_reset,
                            color: kTikRed,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Quên mật khẩu?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nhập email của bạn, chúng tôi sẽ gửi mã OTP đặt lại mật khẩu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: kTextSec,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 36),
                      AuthTextField(
                        controller: _emailController,
                        label: 'Email',
                        hintText: 'name@example.com',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        validator: _validateEmail,
                        onFieldSubmitted: (_) => _sendResetLink(),
                      ),
                      const SizedBox(height: 24),
                      const AuthInfoCard(
                        title: 'Điều gì sẽ xảy ra tiếp theo?',
                        message:
                            'Sau khi gửi OTP, Pody sẽ chuyển bạn thẳng sang màn nhập mã. Bạn sẽ chỉ đổi được mật khẩu sau khi mã OTP hợp lệ.',
                        icon: Icons.info_outline,
                      ),
                      const SizedBox(height: 24),
                      AuthPrimaryButton(
                        label: 'Tiếp tục',
                        isLoading: _isSubmitting,
                        onPressed: _sendResetLink,
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.arrow_back,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          label: Text(
                            'Quay lại đăng nhập',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
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
