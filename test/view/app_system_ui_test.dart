import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/view/base/app_system_ui.dart';

void main() {
  const contentKey = Key('screen-content');

  Future<void> showScreen(
    WidgetTester tester, {
    required FakeViewPadding padding,
    FakeViewPadding viewInsets = const FakeViewPadding(),
    FakeViewPadding? viewPadding,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.padding = padding;
    tester.view.viewPadding = viewPadding ?? padding;
    tester.view.viewInsets = viewInsets;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => AppSystemUi(child: child!),
        home: const Scaffold(
          body: SafeArea(child: SizedBox.expand(key: contentKey)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final navigationInset in [16.0, 48.0]) {
    testWidgets(
      'controls clear a $navigationInset px navigation bar once',
      (tester) async {
        await showScreen(
          tester,
          padding: FakeViewPadding(top: 24, bottom: navigationInset),
        );

        expect(
          tester.getRect(find.byKey(contentKey)),
          Rect.fromLTRB(0, 24, 800, 600 - navigationInset),
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'landscape controls clear the cutout and side navigation',
    (tester) async {
      await showScreen(
        tester,
        padding: const FakeViewPadding(left: 32, right: 48),
      );

      expect(
        tester.getRect(find.byKey(contentKey)),
        const Rect.fromLTRB(32, 0, 752, 600),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iPhone content clears the notch and home indicator once',
    (tester) async {
      await showScreen(
        tester,
        padding: const FakeViewPadding(top: 59, bottom: 34),
      );
      expect(
        tester.getRect(find.byKey(contentKey)),
        const Rect.fromLTRB(0, 59, 800, 566),
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'keyboard replaces the navigation inset without extra padding',
    (tester) async {
      await showScreen(
        tester,
        padding: const FakeViewPadding(top: 24),
        viewPadding: const FakeViewPadding(top: 24, bottom: 24),
        viewInsets: const FakeViewPadding(bottom: 280),
      );

      expect(
        tester.getRect(find.byKey(contentKey)),
        const Rect.fromLTRB(0, 24, 800, 320),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'system icons follow changes to the app theme',
    (tester) async {
      await showScreen(tester, padding: const FakeViewPadding(bottom: 24));
      SystemUiOverlayStyle currentStyle() => tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.descendant(
              of: find.byType(AppSystemUi),
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            ),
          )
          .value;

      expect(currentStyle().systemNavigationBarIconBrightness, Brightness.dark);
      await showScreen(
        tester,
        padding: const FakeViewPadding(bottom: 24),
        brightness: Brightness.dark,
      );
      expect(
        currentStyle().systemNavigationBarIconBrightness,
        Brightness.light,
      );
      expect(currentStyle().statusBarIconBrightness, Brightness.light);
      expect(currentStyle().statusBarBrightness, Brightness.dark);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
