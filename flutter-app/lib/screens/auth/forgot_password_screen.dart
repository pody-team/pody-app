import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pody/features/auth/presentation/auth_error_message.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/screens/auth/auth_components.dart';
import 'package:pody/screens/auth/verify_reset_otp_screen.dart';

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
              Center(
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: kAuthSurface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: kAuthPrimary.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: kAuthPrimary,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const AuthHeroHeader(
                title: 'Quên mật khẩu?',
                subtitle:
                    'Nhập email của bạn, Pody sẽ gửi mã OTP để đặt lại mật khẩu.',
                badge: 'Khôi phục',
                alignCenter: true,
              ),
              const SizedBox(height: 28),
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
                    const SizedBox(height: 22),
                    const AuthInfoCard(
                      title: 'Điều gì sẽ xảy ra tiếp theo?',
                      message:
                          'Sau khi gửi OTP, Pody sẽ chuyển bạn thẳng sang màn nhập mã. Bạn sẽ chỉ đổi được mật khẩu sau khi mã OTP hợp lệ.',
                      icon: Icons.info_outline,
                      accentColor: kAuthSecondary,
                    ),
                    const SizedBox(height: 22),
                    AuthPrimaryButton(
                      label: 'Tiếp tục',
                      isLoading: _isSubmitting,
                      onPressed: _sendResetLink,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 16,
                    color: kAuthMuted,
                  ),
                  label: Text(
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
