import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/theme/modern_dark_theme.dart';
import 'package:salatime/theme/modern_light_theme.dart';

import '../../integration_test/support/capture_frames.dart';

void main() {
  for (final withOverlay in [false, true]) {
    testWidgets(
      'capture finishes nested dark text animation with overlay=$withOverlay',
      (tester) async {
        final darkMode = ValueNotifier(false);
        addTearDown(darkMode.dispose);
        await tester.pumpWidget(
          ValueListenableBuilder<bool>(
            valueListenable: darkMode,
            builder: (_, isDark, _) => MaterialApp(
              theme: isDark ? modernDark : modernLight,
              builder: withOverlay
                  ? (_, child) => Overlay(
                      initialEntries: [OverlayEntry(builder: (_) => child!)],
                    )
                  : null,
              home: const Scaffold(
                body: Material(child: Text('Reading progress')),
              ),
            ),
          ),
        );
        Color? inheritedTextColor() => DefaultTextStyle.of(
          tester.element(find.text('Reading progress')),
        ).style.color;
        final lightText = inheritedTextColor();

        darkMode.value = true;
        // Reproduce the original capture sequence. Its final frame completes
        // AnimatedTheme and starts Material's nested text-style animation.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 3));
        await renderCaptureFrames(tester);

        final actualTheme = Theme.of(
          tester.element(find.text('Reading progress')),
        );
        expect(actualTheme.brightness, Brightness.dark);
        expect(inheritedTextColor(), actualTheme.textTheme.bodyMedium!.color);
        expect(inheritedTextColor(), isNot(lightText));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
