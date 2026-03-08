import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

ThemeData buildAppTheme() {
  final baseTheme = ThemeData.dark(useMaterial3: true);
  const primaryColor = Colors.white;
  final subtleBorder = BorderSide(color: Colors.white.withValues(alpha: 0.08));
  final focusedBorder = BorderSide(color: kTikTeal.withValues(alpha: 0.65));
  final errorBorder = BorderSide(color: kTikRed.withValues(alpha: 0.85));

  OutlineInputBorder buildBorder(BorderSide side) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: side,
    );
  }

  return baseTheme.copyWith(
    scaffoldBackgroundColor: kBgBlack,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: kTikTeal,
      surface: kBgBlack,
      error: kTikRed,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      baseTheme.textTheme,
    ).apply(bodyColor: Colors.white, displayColor: Colors.white),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: kBgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kBgCard,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.34),
        fontSize: 15,
      ),
      prefixIconColor: Colors.white.withValues(alpha: 0.55),
      suffixIconColor: Colors.white.withValues(alpha: 0.55),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: buildBorder(subtleBorder),
      enabledBorder: buildBorder(subtleBorder),
      focusedBorder: buildBorder(focusedBorder),
      errorBorder: buildBorder(errorBorder),
      focusedErrorBorder: buildBorder(errorBorder),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        foregroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kBgCard,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
