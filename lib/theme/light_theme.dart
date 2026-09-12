import 'brand_colors.dart';
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

ThemeData light = ThemeData(
  useMaterial3: false,
  fontFamily: 'Roboto',
  primaryColor: AppColor.primaryColor,
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
  primarySwatch: AppColor.primarySwatchValueColor,
);

class AppColor {
  static const int primarySwatchValue = BrandColors.primaryValue;
  static const Color primaryColor = BrandColors.primary;
  static const Color cardColor = Colors.white;
  static const Color blueColor = Color(0xFF1e2a40);
  static const Color goldColor = Color(0xFFf9a825);
  static const Color greenColorBG = BrandColors.primary;
  static const Color greenColorText = Color(0xFF81c784);

  static const Color tealColorBG = Color(0xFF80cbc4);
  static const Color tealColorText = Color(0xFF1c3030);
  static const Color blueColorText = Color(0xFF90caf9);

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
  static const Color hoverBlueColor = Color(0xFFEEEDFD);
}
