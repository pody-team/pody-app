import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/auth/presentation/auth_error_message.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/screens/auth/auth_components.dart';
import 'package:pody/screens/auth/forgot_password_screen.dart';
import 'package:pody/screens/auth/sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    this.noticeMessage,
    this.onNoticeDismissed,
    this.initialEmail,
    super.key,
  });

  final String? noticeMessage;
  final VoidCallback? onNoticeDismissed;
  final String? initialEmail;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  bool _isObscured = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if ((widget.initialEmail ?? '').trim().isNotEmpty) {
      _emailController.text = widget.initialEmail!.trim();
    }
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

  void _finishSuccessfulSignIn() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Nhập email để tiếp tục.';
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
    return null;
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authController = AuthScope.of(context);
    setState(() => _isSubmitting = true);
    try {
      await authController.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }

      _finishSuccessfulSignIn();
    } catch (error) {
      if (!mounted) {
        return;
      }

      await _showAuthError(error);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    FocusScope.of(context).unfocus();

    final authController = AuthScope.of(context);
    setState(() => _isSubmitting = true);
    try {
      await authController.signInWithGoogle();
      if (!mounted) {
        return;
      }

      _finishSuccessfulSignIn();
    } catch (error) {
      if (!mounted) {
        return;
      }

      await _showAuthError(error);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showAuthError(Object error) async {
    final messenger = ScaffoldMessenger.of(context);

    if (error is ApiException &&
        error.message == 'email is not verified' &&
        _emailController.text.trim().isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Email này chưa được xác thực. Bạn có muốn gửi lại email xác thực không?',
          ),
          action: SnackBarAction(
            label: 'Gửi lại',
            onPressed: () {
              _resendVerification();
            },
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(humanizeAuthError(error))));
  }

  Future<void> _resendVerification() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      return;
    }

    final authController = AuthScope.of(context);
    try {
      await authController.resendVerification(email);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mình đã gửi lại email xác thực tới $email.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(humanizeAuthError(error))));
    }
  }

  void _showPlaceholderAuthMessage(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đăng nhập bằng $provider sẽ được nối tiếp khi cấu hình native hoàn tất.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      topPadding: 40,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: kAuthSurface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kAuthPrimary.withValues(alpha: 0.10),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.headphones_rounded,
                      color: kAuthPrimary,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const AuthHeroHeader(
                  title: 'Đăng nhập vào Pody',
                  subtitle:
                      'Tiếp tục nghe, tạo và quản lý show bằng dữ liệu thật.',
                  badge: 'Tài khoản',
                  alignCenter: true,
                ),
                if ((widget.noticeMessage ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  AuthInfoCard(
                    title: 'Bạn đã sẵn sàng đăng nhập',
                    message: widget.noticeMessage!.trim(),
                    icon: Icons.check_circle_outline,
                    accentColor: kAuthTertiary,
                    footer: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: widget.onNoticeDismissed,
                        child: Text(
                          'Đã hiểu',
                          style: GoogleFonts.workSans(color: kAuthPrimary),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 36),
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
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: _passwordController,
                        label: 'Mật khẩu',
                        hintText: 'Nhập mật khẩu của bạn',
                        prefixIcon: Icons.lock_outline,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        obscureText: _isObscured,
                        validator: _validatePassword,
                        onFieldSubmitted: (_) => _login(),
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
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Quên mật khẩu?',
                            style: GoogleFonts.workSans(color: kAuthPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AuthPrimaryButton(
                        label: 'Đăng nhập',
                        isLoading: _isSubmitting,
                        onPressed: _login,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const AuthDividerLabel(label: 'Hoặc tiếp tục với'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    AuthSocialButton(
                      label: 'Google',
                      icon: Icons.g_mobiledata,
                      onPressed: _isSubmitting ? null : _loginWithGoogle,
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
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Chưa có tài khoản?',
                      style: GoogleFonts.workSans(
                        color: kAuthMuted,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignUpScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Tạo tài khoản',
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
