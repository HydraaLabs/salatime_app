import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/home_layout_controller.dart';
import 'package:zabi/theme/light_theme.dart';
import 'package:zabi/theme/dark_theme.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/theme/modern_dark_theme.dart';

ThemeData getAppTheme(bool isDark) {
  final isClassic =
      Get.find<HomeLayoutController>().currentLayout.value ==
      HomeLayoutController.classic;

  if (isClassic) {
    return isDark ? dark : light;
  } else {
    return isDark ? modernDark : modernLight;
  }
}
