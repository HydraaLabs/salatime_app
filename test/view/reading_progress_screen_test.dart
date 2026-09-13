import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/home_layout_controller.dart';
import 'package:zabi/service/reading/reading_progress_service.dart';
import 'package:zabi/theme/modern_dark_theme.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/view/screens/reading/reading_progress_screen.dart';

import '../support/fake_reading_progress.dart';

class _Strings extends Translations {
  _Strings(this.keys);
  @override
  final Map<String, Map<String, String>> keys;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final strings = <String, Map<String, String>>{};
  late FakeReadingProgress reading;

  setUpAll(() async {
    for (final locale in ['en', 'fr', 'ar']) {
      strings[locale] = Map<String, String>.from(
        jsonDecode(await rootBundle.loadString('assets/language/$locale.json')),
      );
    }
    for (final (name, asset) in [
      ('Roboto', 'assets/font/Roboto-Regular.ttf'),
      ('NotoSansArabic', 'assets/font/NotoSansArabic-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(name)..addFont(rootBundle.load(asset))).load();
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(
      HomeLayoutController(
        sharedPreferences: await SharedPreferences.getInstance(),
      ),
    );
    reading = FakeReadingProgress();
    reading.targets.addAll({'morning:1': 3, 'evening:1': 3});
    await reading.setCount(
      ReadingProgressKind.athkar,
      'morning:1',
      3,
      day: '2026-09-12',
    );
    await reading.setCount(ReadingProgressKind.athkar, 'morning:1', 1);
    await reading.setCount(ReadingProgressKind.athkar, 'evening:1', 3);
    await reading.setCount(
      ReadingProgressKind.quran,
      '1:1',
      1,
      day: '2026-09-12',
    );
    await reading.setCount(ReadingProgressKind.quran, '1:1', 1);
    await reading.setMany(ReadingProgressKind.quran, {
      for (var verse = 1; verse <= 4; verse++) '112:$verse': 1,
    });
    reading.writes = 0;
  });
  tearDown(Get.reset);

  Widget app({
    String locale = 'fr',
    bool dark = false,
    double scale = 1,
    GlobalKey? capture,
  }) => GetMaterialApp(
    locale: Locale(locale),
    translations: _Strings(strings),
    supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: (dark ? modernDark : modernLight).copyWith(
      textTheme: (dark ? modernDark : modernLight).textTheme.apply(
        fontFamilyFallback: ['NotoSansArabic'],
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: RepaintBoundary(key: capture, child: child!),
    ),
    home: ReadingProgressScreen(service: reading),
  );

  Finder key(String name) => find.byKey(ValueKey(name));
  Future<void> reach(
    WidgetTester tester,
    String name, {
    bool up = false,
  }) async {
    await tester.scrollUntilVisible(
      key(name),
      up ? -250 : 250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 40,
    );
    await tester.pumpAndSettle();
  }

  String metric(WidgetTester tester, String name) =>
      tester.widget<Text>(key('reading-progress-$name')).data!;

  testWidgets(
    'day, seven-day and unique totals reflect saved readings without marking new ones',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await reach(tester, 'reading-progress-selected-quran');
      expect(metric(tester, 'selected-athkar'), '1');
      expect(metric(tester, 'selected-quran'), '5');
      await reach(tester, 'reading-progress-selected-surahs');
      expect(metric(tester, 'selected-surahs'), '1');
      await reach(tester, 'reading-progress-week-quran');
      expect(metric(tester, 'week-athkar'), '2');
      expect(metric(tester, 'week-quran'), '6');
      await reach(tester, 'reading-progress-quran-coverage');
      expect(metric(tester, 'quran-coverage'), contains('5'));
      expect(metric(tester, 'quran-coverage'), contains('6236'));
      expect(reading.historyCalls, 1);
      expect(reading.writes, 0);
    },
  );

  testWidgets(
    'chart and history select a day, and today follows midnight until another day is selected',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await reach(tester, 'reading-week-2026-09-12');
      await tester.tap(key('reading-week-2026-09-12'));
      await tester.pump();
      await reach(tester, 'reading-progress-selected-quran', up: true);
      expect(metric(tester, 'selected-quran'), '1');
      reading.today = '2026-09-14';
      reading.refresh();
      await tester.pump();
      expect(metric(tester, 'selected-quran'), '1');
      await reach(tester, 'reading-progress-today', up: true);
      await tester.tap(key('reading-progress-today'));
      await tester.pump();
      await reach(tester, 'reading-progress-selected-quran');
      expect(metric(tester, 'selected-quran'), '0');
      await reach(tester, 'reading-history-2026-09-13');
      await tester.tap(key('reading-history-2026-09-13'));
      await tester.pump();
      await reach(tester, 'reading-progress-selected-quran', up: true);
      expect(metric(tester, 'selected-quran'), '5');
      expect(reading.writes, 0);
    },
  );

  testWidgets(
    'guest, pending, offline and manual synchronization states stay reactive',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(key('reading-progress-account'), findsOneWidget);
      expect(key('reading-progress-sync'), findsNothing);
      reading.status = 'cloud_pending';
      reading.refresh();
      await tester.pump();
      expect(key('reading-progress-account'), findsNothing);
      expect(key('reading-progress-sync'), findsOneWidget);
      reading.status = 'cloud_syncing';
      reading.refresh();
      await tester.pump();
      expect(
        tester.widget<TextButton>(key('reading-progress-sync')).onPressed,
        isNull,
      );
      reading.status = 'cloud_offline';
      reading.refresh();
      await tester.pump();
      await tester.tap(key('reading-progress-sync'));
      await tester.pumpAndSettle();
      expect(reading.syncCalls, 1);
      expect(reading.writes, 0);
    },
  );

  for (final locale in ['fr', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        '$locale ${dark ? 'dark' : 'light'} statistics fit 320px with double-size text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final capture = GlobalKey();
          await tester.pumpWidget(
            app(locale: locale, dark: dark, scale: 2, capture: capture),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await reach(tester, 'reading-week-2026-09-12');
          expect(tester.takeException(), isNull);
          final outputDirectory =
              Platform.environment['SALATIME_READING_PREVIEW_DIR'];
          if (outputDirectory != null) {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(outputDirectory).create(recursive: true);
              await File(
                '$outputDirectory/reading-$locale-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await reach(tester, 'reading-history-2026-09-12');
          expect(tester.takeException(), isNull);
          tester.view.physicalSize = const Size(800, 320);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
