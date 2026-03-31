import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pody/features/auth/domain/auth_policy.dart';
import 'package:pody/features/auth/domain/verification_challenge.dart';
import 'package:pody/features/auth/presentation/auth_error_message.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/screens/auth/auth_components.dart';
import 'package:pody/screens/auth/sign_in_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  bool _isObscured = true;
  bool _isSubmitting = false;
  VerificationChallenge? _verificationChallenge;

  bool get _verificationSent =>
      _verificationChallenge?.verificationRequired ?? false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Nhập tên hiển thị.';
    }
    if (name.length < 2) {
      return 'Tên cần ít nhất 2 ký tự.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Nhập email để tạo tài khoản.';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Email chưa đúng định dạng.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Nhập mật khẩu.';
    }
    if (password.length < AuthPolicy.minPasswordLength) {
      return 'Mật khẩu nên có ít nhất ${AuthPolicy.minPasswordLength} ký tự.';
    }
    return null;
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authController = AuthScope.of(context);
    setState(() => _isSubmitting = true);
    try {
      final challenge = await authController.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _verificationChallenge = challenge;
      });
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

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();

    final authController = AuthScope.of(context);
    setState(() => _isSubmitting = true);
    try {
      await authController.signInWithGoogle();
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

  Future<void> _resendVerification() async {
    final email = _verificationChallenge?.email ?? _emailController.text.trim();
    if (email.isEmpty) {
      return;
    }

    final authController = AuthScope.of(context);
    setState(() => _isSubmitting = true);
    try {
      final challenge = await authController.resendVerification(email);
      if (!mounted) {
        return;
      }

      setState(() {
        _verificationChallenge = challenge;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mình đã gửi lại email xác thực tới ${challenge.email}.',
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

  void _showPlaceholderAuthMessage(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đăng ký bằng $provider sẽ được nối tiếp khi hoàn tất cấu hình native.',
        ),
      ),
    );
  }

  String _formatVerificationDeadline(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ngày $day/$month';
  }

  void _returnToSignIn() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SignInScreen(
          initialEmail:
              _verificationChallenge?.email ?? _emailController.text.trim(),
        ),
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
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthBackButton(onPressed: _returnToSignIn),
                const SizedBox(height: 28),
                AuthHeroHeader(
                  title: _verificationSent
                      ? 'Kiểm tra hộp thư của bạn'
                      : 'Tạo tài khoản mới',
                  subtitle: _verificationSent
                      ? 'Tài khoản đã được tạo. Chỉ còn bước xác thực email để bắt đầu dùng Pody.'
                      : 'Bắt đầu với Pody để nghe, lưu và tạo podcast bằng AI.',
                  badge: 'Tài khoản mới',
                ),
                const SizedBox(height: 28),
                if (!_verificationSent) ...[
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
                          controller: _nameController,
                          label: 'Tên hiển thị',
                          hintText: 'Ví dụ: Tino Phan',
                          prefixIcon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          validator: _validateName,
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _emailController,
                          label: 'Email',
                          hintText: 'name@example.com',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _passwordController,
                          label: 'Mật khẩu',
                          hintText: AuthPolicy.passwordHint,
                          prefixIcon: Icons.lock_outline,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          obscureText: _isObscured,
                          validator: _validatePassword,
                          onFieldSubmitted: (_) => _signUp(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _isObscured = !_isObscured);
                            },
                            icon: Icon(
                              _isObscured
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: kAuthMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AuthPrimaryButton(
                          label: 'Tạo tài khoản',
                          backgroundColor: kAuthPrimary,
                          isLoading: _isSubmitting,
                          onPressed: _signUp,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const AuthDividerLabel(label: 'Hoặc đăng ký với'),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      AuthSocialButton(
                        label: 'Google',
                        icon: Icons.g_mobiledata,
                        onPressed: _isSubmitting ? null : _signInWithGoogle,
                      ),
                      const SizedBox(width: 16),
                      AuthSocialButton(
                        label: 'Apple',
                        icon: Icons.apple,
                        onPressed: () {
                          _showPlaceholderAuthMessage('Apple');
                        },
                      ),
                    ],
                  ),
                ] else ...[
                  AuthInfoCard(
                    title: 'Kiểm tra hộp thư của bạn',
                    message:
                        'Tài khoản đã được tạo cho ${_verificationChallenge?.email ?? _emailController.text.trim()}. '
                        'Mình đã gửi email xác thực, bạn chỉ cần bấm vào nút trong thư để kích hoạt tài khoản.',
                    icon: Icons.mark_email_read_outlined,
                    accentColor: kAuthSecondary,
                    footer: AuthStepList(
                      items: [
                        'Mở email xác thực trên điện thoại hoặc máy tính.',
                        'Bấm nút xác thực để hoàn tất trước ${_formatVerificationDeadline(_verificationChallenge!.verificationExpiresAt)}.',
                        'Quay lại Pody và đăng nhập bằng email vừa tạo.',
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: 'Quay lại đăng nhập',
                    onPressed: _returnToSignIn,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _resendVerification,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Gửi lại email xác thực'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kAuthNeutral,
                      backgroundColor: kAuthSurface,
                      side: BorderSide(
                        color: kAuthNeutral.withValues(alpha: 0.08),
                      ),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: GoogleFonts.workSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Đã có tài khoản?',
                      style: GoogleFonts.workSans(
                        color: kAuthMuted,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: _returnToSignIn,
                      child: Text(
                        'Đăng nhập',
                        style: GoogleFonts.workSans(
                          color: kAuthPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
