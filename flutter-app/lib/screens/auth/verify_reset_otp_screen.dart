import 'package:flutter/material.dart';

import 'package:pody/features/auth/presentation/auth_error_message.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/screens/auth/auth_components.dart';
import 'package:pody/screens/auth/reset_password_screen.dart';
import 'package:pody/theme/app_colors.dart';

class VerifyResetOTPScreen extends StatefulWidget {
  const VerifyResetOTPScreen({
    required this.initialEmail,
    this.otpLength = 6,
    this.otpExpiresAt,
    super.key,
  });

  final String initialEmail;
  final int otpLength;
  final DateTime? otpExpiresAt;

  @override
  State<VerifyResetOTPScreen> createState() => _VerifyResetOTPScreenState();
}

class _VerifyResetOTPScreenState extends State<VerifyResetOTPScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  late int _otpLength;
  DateTime? _otpExpiresAt;
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _otpLength = widget.otpLength;
    _otpExpiresAt = widget.otpExpiresAt;
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
    _otpController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String? _validateOTP(String? value) {
    final otp = value?.trim() ?? '';
    if (otp.isEmpty) {
      return 'Nhập mã OTP $_otpLength số từ email.';
    }
    if (otp.length != _otpLength || int.tryParse(otp) == null) {
      return 'Mã OTP cần đúng $_otpLength chữ số.';
    }
    return null;
  }

  Future<void> _verifyOTP() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authController = AuthScope.of(context);
    setState(() => _isVerifying = true);
    try {
      await authController.verifyResetOTP(
        email: widget.initialEmail,
        otp: _otpController.text.trim(),
      );
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            email: widget.initialEmail,
            otp: _otpController.text.trim(),
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
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOTP() async {
    final authController = AuthScope.of(context);
    setState(() => _isResending = true);
    try {
      final challenge = await authController.forgotPassword(
        widget.initialEmail,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _otpLength = challenge.otpLength;
        _otpExpiresAt = challenge.otpExpiresAt;
        _otpController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mình đã gửi lại mã OTP mới tới ${challenge.email.isNotEmpty ? challenge.email : widget.initialEmail}.',
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
        setState(() => _isResending = false);
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
                        'Nhập mã OTP',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Chúng tôi đã gửi mã OTP $_otpLength số tới ${widget.initialEmail}. Xác thực xong, Pody sẽ chuyển bạn sang màn đặt mật khẩu mới.',
                        style: const TextStyle(
                          fontSize: 15,
                          color: kTextSec,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
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
                              Icons.looks_one_outlined,
                              color: kTikTeal,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Bước 1/2: Xác minh mã OTP trước khi đặt mật khẩu mới.',
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
                      const SizedBox(height: 32),
                      AuthInfoCard(
                        title: 'Email nhận mã',
                        message:
                            '${widget.initialEmail}${_otpExpiresAt == null ? '' : '\nMã OTP hiện tại sẽ hết hạn lúc ${_formatExpiry(_otpExpiresAt!)}.'}',
                        icon: Icons.mark_email_unread_outlined,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: _otpController,
                        label: 'Mã OTP',
                        hintText: 'Nhập mã $_otpLength số',
                        prefixIcon: Icons.pin_outlined,
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.number,
                        validator: _validateOTP,
                        onFieldSubmitted: (_) => _verifyOTP(),
                      ),
                      const SizedBox(height: 24),
                      AuthPrimaryButton(
                        label: 'Xác minh mã OTP',
                        backgroundColor: kTikTeal,
                        foregroundColor: Colors.black,
                        isLoading: _isVerifying,
                        onPressed: _verifyOTP,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _isVerifying || _isResending
                              ? null
                              : _resendOTP,
                          child: Text(
                            _isResending
                                ? 'Đang gửi lại mã...'
                                : 'Gửi lại mã OTP',
                            style: const TextStyle(color: kTikTeal),
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

  String _formatExpiry(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$hour:$minute ngày $day/$month';
  }
}
