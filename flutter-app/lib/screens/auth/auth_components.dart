import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kAuthCanvas = Color(0xFFFFFBF6);
const Color kAuthCanvasSoft = Color(0xFFF8F0E6);
const Color kAuthSurface = Color(0xFFFFFEFC);
const Color kAuthSurfaceStrong = Color(0xFFF2E6D9);
const Color kAuthPrimary = Color(0xFFBF5700);
const Color kAuthSecondary = Color(0xFFE1AD01);
const Color kAuthTertiary = Color(0xFF566931);
const Color kAuthNeutral = Color(0xFF3E2723);
const Color kAuthMuted = Color(0xFF7E665F);

class AuthBackgroundOrb extends StatelessWidget {
  const AuthBackgroundOrb({
    super.key,
    required this.color,
    required this.diameter,
    this.top,
    this.left,
    this.right,
    this.bottom,
    this.blurSigma = 80,
  });

  final Color color;
  final double diameter;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ).blurred(sigma: blurSigma),
    );
  }
}

class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    required this.child,
    super.key,
    this.topPadding = 24,
  });

  final Widget child;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthCanvas,
      body: Stack(
        children: [
          const AuthBackgroundOrb(
            top: -120,
            left: -90,
            diameter: 260,
            blurSigma: 80,
            color: Color(0x33E1AD01),
          ),
          const AuthBackgroundOrb(
            top: 140,
            right: -110,
            diameter: 260,
            blurSigma: 90,
            color: Color(0x26BF5700),
          ),
          const AuthBackgroundOrb(
            bottom: -110,
            left: 20,
            diameter: 280,
            blurSigma: 90,
            color: Color(0x22566931),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, topPadding, 24, 32),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthHeroHeader extends StatelessWidget {
  const AuthHeroHeader({
    required this.title,
    required this.subtitle,
    super.key,
    this.badge,
    this.alignCenter = false,
  });

  final String title;
  final String subtitle;
  final String? badge;
  final bool alignCenter;

  @override
  Widget build(BuildContext context) {
    final alignment = alignCenter
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        if ((badge ?? '').trim().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kAuthSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kAuthPrimary.withValues(alpha: 0.12)),
            ),
            child: Text(
              badge!,
              style: GoogleFonts.workSans(
                color: kAuthPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          title,
          textAlign: alignCenter ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.newsreader(
            color: kAuthNeutral,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.02,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: alignCenter ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.workSans(
            color: kAuthMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton.filledTonal(
        onPressed: onPressed ?? () => Navigator.maybePop(context),
        style: IconButton.styleFrom(
          backgroundColor: kAuthSurface,
          foregroundColor: kAuthNeutral,
          side: BorderSide(color: kAuthNeutral.withValues(alpha: 0.08)),
          minimumSize: const Size(44, 44),
        ),
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.workSans(
            color: kAuthNeutral,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          autofillHints: autofillHints,
          style: GoogleFonts.workSans(color: kAuthNeutral, fontSize: 15),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.workSans(
              color: kAuthMuted.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            filled: true,
            fillColor: kAuthSurface,
            prefixIcon: Icon(prefixIcon, size: 20, color: kAuthPrimary),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: kAuthNeutral.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: kAuthNeutral.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              borderSide: BorderSide(color: kAuthPrimary, width: 1.4),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              borderSide: BorderSide(color: Color(0xFFC16452)),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              borderSide: BorderSide(color: Color(0xFFC16452), width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor = kAuthPrimary,
    this.foregroundColor = Colors.white,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: backgroundColor.withValues(alpha: 0.45),
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: GoogleFonts.workSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
              ),
            )
          : Text(label),
    );
  }
}

class AuthInfoCard extends StatelessWidget {
  const AuthInfoCard({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.accentColor = kAuthTertiary,
    this.footer,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color accentColor;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kAuthSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.workSans(
                    color: kAuthNeutral,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.workSans(
              color: kAuthMuted,
              height: 1.5,
              fontSize: 13,
            ),
          ),
          if (footer != null) ...[const SizedBox(height: 14), footer!],
        ],
      ),
    );
  }
}

class AuthStepList extends StatelessWidget {
  const AuthStepList({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle,
                      color: kAuthTertiary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.workSans(
                        color: kAuthMuted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: kAuthNeutral,
          backgroundColor: kAuthSurface,
          side: BorderSide(color: kAuthNeutral.withValues(alpha: 0.08)),
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
    );
  }
}

class AuthDividerLabel extends StatelessWidget {
  const AuthDividerLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: kAuthNeutral.withValues(alpha: 0.08))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: GoogleFonts.workSans(color: kAuthMuted, fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: kAuthNeutral.withValues(alpha: 0.08))),
      ],
    );
  }
}

extension AuthBlur on Widget {
  Widget blurred({double sigma = 10.0}) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: this,
      ),
    );
  }
}
