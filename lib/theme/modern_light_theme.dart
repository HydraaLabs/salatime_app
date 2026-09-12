import 'brand_colors.dart';
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

ThemeData modernLight = ThemeData(
  useMaterial3: false,
  fontFamily: 'Roboto',
  primaryColor: AppColorModern.primaryColor,
  scaffoldBackgroundColor: BrandColors.canvas,
  disabledColor: const Color(0xFFA0A4A8),
  brightness: Brightness.light,
  hintColor: const Color(0xFF9F9F9F),
  cardColor: Colors.white,
  colorScheme: ColorScheme.fromSeed(
    seedColor: BrandColors.primary,
    brightness: Brightness.light,
    primary: BrandColors.primary,
    error: const Color(0xFFE84D4F),
  ),
  primarySwatch: AppColorModern.primarySwatchValueColor,
);

class AppColorModern {
  static const int primarySwatchValue = BrandColors.primaryValue;
  static const Color primaryColor = BrandColors.primary;

  // Modern (emerald) home layout palette
  static const Color emerald = BrandColors.primary;
  static const Color emeraldDark = BrandColors.primary;
  static const Color emeraldLight = BrandColors.light;
  static const Color emeraldSoftBg = BrandColors.soft;

  // Backgrounds
  static const Color scaffoldBackground = BrandColors.canvas;
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Greens (prayer card + brand)
  static const Color primaryGreenDark = BrandColors.primary;
  static const Color primaryGreen = BrandColors.secondary;
  static const Color primaryGreenLight = BrandColors.light;
  static const Color accentGreen = BrandColors.secondary;
  static const Color chipGreenBackground = BrandColors.soft;

  // Text
  static const Color textPrimary = Color(0xFF1E2A22);
  static const Color textSecondary = Color(0xFF6B7570);
  static const Color textOnGreen = Color(0xFFFFFFFF);
  static const Color textOnGreenMuted = Color(0xFFDCE7DC);

  // Feature card tints
  static const Color tintGreen = Color(0xFFE3ECE0);
  static const Color tintCream = Color(0xFFF6EEE0);
  static const Color tintGray = Color(0xFFE9EAEC);
  static const Color tintBlue = Color(0xFFE3EEF0);

  // Misc
  static const Color divider = Color(0xFFE3E6E0);
  static const Color progressTrack = Color(0xFFE7EAE3);
  static const Color iconChipBackground = Color(0xFFF1F3ED);

  static const MaterialColor primarySwatchValueColor =
      MaterialColor(primarySwatchValue, <int, Color>{
        50: Color(primarySwatchValue),
        100: Color(primarySwatchValue),
        200: Color(primarySwatchValue),
        300: Color(primarySwatchValue),
        400: Color(primarySwatchValue),
        500: Color(primarySwatchValue),
        600: Color(primarySwatchValue),
        700: Color(primarySwatchValue),
        800: Color(primarySwatchValue),
        900: Color(primarySwatchValue),
      });
}
