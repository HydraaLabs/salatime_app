import 'package:flutter_test/flutter_test.dart';

/// Render nested theme, text and route transitions before native screenshots.
///
/// A single long pump can complete AnimatedTheme while starting a descendant
/// AnimatedDefaultTextStyle at t=0. Unlike pumpAndSettle, this remains bounded
/// when the actual screen has a repeating animation or an active network load.
Future<void> renderCaptureFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 30; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
