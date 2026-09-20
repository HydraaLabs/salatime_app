import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paint behind transparent system bars while keeping controls above Android's
/// gesture/three-button navigation. Individual screens own their top inset.
class AppSystemUi extends StatelessWidget {
  const AppSystemUi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        // Android 15+ owns the bar colors. Paint the backing surface in Flutter
        // and only ask the platform to update icon contrast.
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
        // Let Android protect contrast for three-button navigation as well.
        systemNavigationBarContrastEnforced: true,
      ),
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          bottom: defaultTargetPlatform == TargetPlatform.android,
          child: child,
        ),
      ),
    );
  }
}
