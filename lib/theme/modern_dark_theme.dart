// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

ThemeData modernDark = ThemeData(
  useMaterial3: false,
  fontFamily: 'Roboto',
  primaryColor: const Color(0xFF4FA980),
  scaffoldBackgroundColor: const Color.fromARGB(255, 49, 49, 49),
  disabledColor: const Color(0xFF6F7275),
  brightness: Brightness.dark,
  hintColor: const Color(0xFFBEBEBE),
  cardColor: const Color.fromARGB(255, 38, 38, 38),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4FA980),
    brightness: Brightness.dark,
    primary: const Color(0xFF4FA980),
    error: const Color(0xFFE84D4F),
  ),
  primarySwatch: AppColorModernDark.primarySwatchValueColor,
);

class AppColorModernDark {
  static const int primarySwatchValue = 0xFF4FA980;
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
