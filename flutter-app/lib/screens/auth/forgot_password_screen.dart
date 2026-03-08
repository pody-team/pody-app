import 'package:flutter/material.dart';

import 'package:pody/screens/auth/auth_components.dart';
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

  bool _emailSent = false;
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
      return 'Nhập email để nhận link đặt lại.';
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

    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      _emailSent = true;
    });
  }

  void _resend() {
    setState(() => _emailSent = false);
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
                            color: (_emailSent ? kTikTeal : kTikRed).withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            _emailSent
                                ? Icons.mark_email_read_outlined
                                : Icons.lock_reset,
                            color: _emailSent ? kTikTeal : kTikRed,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        _emailSent ? 'Kiểm tra email' : 'Quên mật khẩu?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _emailSent
                            ? 'Chúng tôi đã gửi link đặt lại mật khẩu đến\n${_emailController.text.trim()}'
                            : 'Nhập email của bạn, chúng tôi sẽ gửi link đặt lại mật khẩu.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: kTextSec,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 36),
                      if (!_emailSent) ...[
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
                        AuthPrimaryButton(
                          label: 'Gửi link đặt lại',
                          isLoading: _isSubmitting,
                          onPressed: _sendResetLink,
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: kTikTeal.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: kTikTeal.withValues(alpha: 0.15),
                            ),
                          ),
                          child: const Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: kTikTeal,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Email đã được gửi thành công.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Vui lòng kiểm tra hộp thư và thư mục spam, sau đó làm theo hướng dẫn trong email.',
                                style: TextStyle(
                                  color: kTextSec,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AuthPrimaryButton(
                          label: 'Mở ứng dụng Email',
                          backgroundColor: kTikTeal,
                          foregroundColor: Colors.black,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Hãy mở ứng dụng email trên máy của bạn để tiếp tục.',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: _resend,
                            child: const Text(
                              'Không nhận được email? Gửi lại',
                              style: TextStyle(color: kTikTeal),
                            ),
                          ),
                        ),
                      ],
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
