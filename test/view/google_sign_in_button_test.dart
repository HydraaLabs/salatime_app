import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/view/base/google_sign_in_button.dart';

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

  for (final (brightness, fill, stroke, text) in [
    (
      Brightness.light,
      GoogleSignInButton.lightFill,
      GoogleSignInButton.lightStroke,
      GoogleSignInButton.lightText,
    ),
    (
      Brightness.dark,
      GoogleSignInButton.darkFill,
      GoogleSignInButton.darkStroke,
      GoogleSignInButton.darkText,
    ),
  ]) {
    testWidgets('uses the Google $brightness palette and logo', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          GoogleSignInButton(
            label: 'Continuer avec Google',
            onPressed: () => taps++,
          ),
          brightness: brightness,
        ),
      );
      final style = styleOf(tester);
      expect(style.backgroundColor!.resolve({}), fill);
      expect(style.side!.resolve({})!.color, stroke);
      expect(style.foregroundColor!.resolve({}), text);
      expect(style.textStyle!.resolve({})!.fontFamily, 'Roboto');
      expect(style.textStyle!.resolve({})!.fontWeight, FontWeight.w500);
      expect(style.shape!.resolve({}), isA<StadiumBorder>());
      final logo = tester.widget<SvgPicture>(
        find.byKey(const ValueKey('google_logo')),
      );
      expect(logo.width, 20);
      expect(find.text('Continuer avec Google'), findsOneWidget);
      await tester.tap(find.byType(GoogleSignInButton));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a disabled button is dimmed and ignores taps', (tester) async {
    await tester.pumpWidget(
      host(const GoogleSignInButton(label: 'Associer Google', onPressed: null)),
    );
    final style = styleOf(tester);
    expect(
      style.backgroundColor!.resolve({})!.a,
      closeTo(GoogleSignInButton.lightFill.a * 0.38, 0.01),
    );
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.byKey(const ValueKey('google_logo')),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      0.38,
    );
    expect(
      tester.getSemantics(find.byType(GoogleSignInButton)),
      matchesSemantics(
        label: 'Associer Google',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
  });

  testWidgets('the logo stays on the leading side in Arabic', (tester) async {
    await tester.pumpWidget(
      host(
        GoogleSignInButton(label: 'ربط Google', onPressed: () {}),
        direction: TextDirection.rtl,
      ),
    );
    final logo = tester.getCenter(find.byKey(const ValueKey('google_logo')));
    final label = tester.getCenter(find.text('ربط Google'));
    expect(logo.dx, greaterThan(label.dx));
  });

  testWidgets('a long label stays on one line at 320 px with large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: host(
          GoogleSignInButton(
            label: 'المتابعة باستخدام Google',
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
