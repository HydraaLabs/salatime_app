import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/view/base/apple_sign_in_button.dart';

void main() {
  Widget host(
    Widget child, {
    Brightness brightness = Brightness.light,
    TextDirection direction = TextDirection.ltr,
  }) => MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Center(child: SizedBox(width: 320, child: child)),
      ),
    ),
  );

  ButtonStyle styleOf(WidgetTester tester) =>
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).style!;

  for (final (brightness, fill, text) in [
    (Brightness.light, AppleSignInButton.black, AppleSignInButton.white),
    (Brightness.dark, AppleSignInButton.white, AppleSignInButton.black),
  ]) {
    testWidgets('uses the Apple style for $brightness backgrounds', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          AppleSignInButton(
            label: 'Continuer avec Apple',
            onPressed: () => taps++,
          ),
          brightness: brightness,
        ),
      );
      final style = styleOf(tester);
      expect(style.backgroundColor!.resolve({}), fill);
      expect(style.foregroundColor!.resolve({}), text);
      expect(style.shape!.resolve({}), isA<StadiumBorder>());
      final logo = tester.widget<SvgPicture>(
        find.byKey(const ValueKey('apple_logo')),
      );
      expect(logo.colorFilter, ColorFilter.mode(text, BlendMode.srcIn));
      expect(find.text('Continuer avec Apple'), findsOneWidget);
      await tester.tap(find.byType(AppleSignInButton));
      expect(taps, 1);
    });
  }

  testWidgets('the system font is used on Apple platforms only', (
    tester,
  ) async {
    Future<String?> family(TargetPlatform platform) async {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(
        host(AppleSignInButton(label: 'Link Apple', onPressed: () {})),
      );
      final value = styleOf(tester).textStyle!.resolve({})!.fontFamily;
      debugDefaultTargetPlatformOverride = null;
      return value;
    }

    expect(await family(TargetPlatform.iOS), '.SF Pro Text');
    expect(await family(TargetPlatform.android), 'Roboto');
  });

  testWidgets('a disabled button is dimmed and reports its state', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const AppleSignInButton(label: 'Associer Apple', onPressed: null)),
    );
    expect(
      styleOf(tester).backgroundColor!.resolve({})!.a,
      closeTo(0.38, 0.01),
    );
    expect(
      tester.getSemantics(find.byType(AppleSignInButton)),
      matchesSemantics(
        label: 'Associer Apple',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
  });

  testWidgets('the logo stays on the leading side in Arabic', (tester) async {
    await tester.pumpWidget(
      host(
        AppleSignInButton(label: 'ربط Apple', onPressed: () {}),
        direction: TextDirection.rtl,
      ),
    );
    final logo = tester.getCenter(find.byKey(const ValueKey('apple_logo')));
    final label = tester.getCenter(find.text('ربط Apple'));
    expect(logo.dx, greaterThan(label.dx));
  });
}
