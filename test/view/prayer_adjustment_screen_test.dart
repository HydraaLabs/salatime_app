import 'dart:async';
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
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/controller/prayer_time_adjustment.dart';
import 'package:zabi/data/api/api_client.dart';
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:zabi/theme/modern_dark_theme.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/view/screens/prayer_adjustment/prayer_adjustment_screen.dart';

class _Strings extends Translations {
  _Strings(this.keys);
  @override
  final Map<String, Map<String, String>> keys;
}

class _Adjustments extends PrayerTimeAdjustmentController {
  bool failLoad = false;
  bool failWrite = false;
  Completer<void>? persistence;
  int loads = 0;

  // The screen explicitly initializes the controller, so tests control errors.
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> init() async {
    loads++;
    if (failLoad) throw StateError('preferences unavailable');
    await super.init();
  }

  @override
  Future<void> updateAdjustment(String prayerKey, int adjustmentMinutes) async {
    await persistence?.future;
    if (failWrite) throw StateError('preferences write failed');
    await super.updateAdjustment(prayerKey, adjustmentMinutes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final strings = <String, Map<String, String>>{};
  late _Adjustments adjustments;
  late SharedPreferences prefs;
  late PrayerTimeController prayers;
  late List<String> events;
  setUpAll(() async {
    for (final locale in ['fr', 'ar']) {
      strings[locale] = Map<String, String>.from(
        jsonDecode(await rootBundle.loadString('assets/language/$locale.json')),
      );
    }
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/font/Roboto-Regular.ttf'))).load();
    await (FontLoader('NotoSansArabic')
          ..addFont(rootBundle.load('assets/font/NotoSansArabic-Regular.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    events = [];
    adjustments = _Adjustments();
    Get.put<PrayerTimeAdjustmentController>(adjustments);
    Get.put(HomeLayoutController(sharedPreferences: prefs));
    prayers = Get.put(
      PrayerTimeController(
        apiClient: ApiClient(
          appBaseUrl: 'https://example.invalid',
          sharedPreferences: prefs,
        ),
      ),
    );
    prayers.prayerTimeModel = PrayerTimeModel(
      data: Data(
        date: '2026-09-12',
        fajrStart: '05:30',
        sunrise: '06:57',
        zuhrStart: '13:16',
        asrStart: '16:48',
        maghribStart: '19:34',
        ishaStart: '23:59',
        sehriEnd: '05:15',
        iftarStart: '19:34',
      ),
    );
  });
  tearDown(Get.reset);

  Widget app({
    Future<void> Function()? reschedule,
    String locale = 'fr',
    bool dark = false,
    double scale = 1,
    GlobalKey? captureKey,
  }) => GetMaterialApp(
    locale: Locale(locale),
    translations: _Strings(strings),
    supportedLocales: const [Locale('fr'), Locale('ar')],
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
      child: RepaintBoundary(key: captureKey, child: child!),
    ),
    home: PrayerAdjustmentScreen(
      appBackButton: false,
      noteLocalChange: () => events.add('cloud'),
      reschedule: () {
        events.add('schedule');
        return reschedule?.call() ?? Future<void>.value();
      },
    ),
  );
  Finder card(String key) => find.byKey(ValueKey('prayer-adjustment-$key'));
  Finder plus(String key) =>
      find.byKey(ValueKey('prayer-adjustment-$key-plus'));
  Finder minus(String key) =>
      find.byKey(ValueKey('prayer-adjustment-$key-minus'));
  Finder time(String key, String value) =>
      find.descendant(of: card(key), matching: find.textContaining(value));
  Future<void> tap(WidgetTester tester, Finder button) async {
    await tester.scrollUntilVisible(button, 100);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'rapid changes remain available while rescheduling is blocked and cloud observes durable edits',
    (tester) async {
      final schedule = Completer<void>();
      await tester.pumpWidget(app(reschedule: () => schedule.future));
      await tester.pumpAndSettle();
      expect(time('fajr', '05:30'), findsOneWidget);
      await tap(tester, plus('fajr'));
      expect(events, ['cloud', 'cloud', 'schedule']);
      expect(time('fajr', '05:31'), findsOneWidget);
      expect(tester.widget<IconButton>(plus('fajr')).onPressed, isNotNull);
      await tap(tester, plus('fajr'));
      await tap(tester, minus('fajr'));
      await tap(tester, plus('asr'));
      expect(events.where((e) => e == 'schedule'), hasLength(4));
      expect(time('asr', '16:49'), findsOneWidget);
      await tester.scrollUntilVisible(card('fajr'), -100);
      expect(time('fajr', '05:31'), findsOneWidget);
      expect(prayers.prayerTimeModel!.data!.fajrStart, '05:30');
      expect(jsonDecode(prefs.getString('prayerAdjustments')!), {
        'fajr': 1,
        'asr': 1,
      });
      schedule.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'only the local persistence briefly locks controls and errors retain the previous time',
    (tester) async {
      adjustments.persistence = Completer<void>();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(plus('fajr'));
      await tester.pump();
      expect(events, ['cloud']);
      expect(tester.widget<IconButton>(plus('fajr')).onPressed, isNull);
      adjustments.failWrite = true;
      adjustments.persistence!.complete();
      await tester.pumpAndSettle();
      expect(time('fajr', '05:30'), findsOneWidget);
      expect(adjustments.getAdjustmentMinutes('fajr') ?? 0, 0);
      expect(prefs.getString('prayerAdjustments'), isNull);
      expect(find.text('prayer_adjustment_error'.tr), findsOneWidget);
      expect(events, ['cloud']);
      expect(tester.widget<IconButton>(plus('fajr')).onPressed, isNotNull);
      adjustments.failWrite = false;
      await tap(tester, plus('fajr'));
      expect(time('fajr', '05:31'), findsOneWidget);
      expect(events, ['cloud', 'cloud', 'cloud', 'schedule']);
    },
  );

  testWidgets(
    'rescheduling errors are reported without rolling back saved offsets or locking controls',
    (tester) async {
      await tester.pumpWidget(
        app(reschedule: () => Future.error(StateError('schedule failed'))),
      );
      await tester.pumpAndSettle();
      await tap(tester, plus('fajr'));
      expect(time('fajr', '05:31'), findsOneWidget);
      expect(jsonDecode(prefs.getString('prayerAdjustments')!), {'fajr': 1});
      expect(find.text('prayer_adjustment_error'.tr), findsOneWidget);
      expect(tester.widget<IconButton>(plus('fajr')).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'old scheduling failures do not replace the latest successful edit',
    (tester) async {
      final previous = Completer<void>();
      var count = 0;
      await tester.pumpWidget(
        app(
          reschedule: () =>
              count++ == 0 ? previous.future : Future<void>.value(),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, plus('fajr'));
      await tap(tester, plus('fajr'));
      previous.completeError(StateError('obsolete failure'));
      await tester.pumpAndSettle();
      expect(time('fajr', '05:32'), findsOneWidget);
      expect(find.text('prayer_adjustment_error'.tr), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'limits stop at120 minutes and midnight uses the original prayer time',
    (tester) async {
      await prefs.setString(
        'prayerAdjustments',
        jsonEncode({'fajr': 120, 'sunrise': -120}),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(plus('fajr')).onPressed, isNull);
      expect(tester.widget<IconButton>(minus('sunrise')).onPressed, isNull);
      expect(time('fajr', '07:30'), findsOneWidget);
      expect(time('sunrise', '04:57'), findsOneWidget);
      await tap(tester, minus('fajr'));
      expect(tester.widget<IconButton>(plus('fajr')).onPressed, isNotNull);
      expect(time('fajr', '07:29'), findsOneWidget);
      await tap(tester, plus('isha'));
      expect(time('isha', '00:00'), findsOneWidget);
      expect(prayers.prayerTimeModel!.data!.ishaStart, '23:59');
    },
  );

  testWidgets(
    'cloud reload updates visible values without another prayer data refresh',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(time('fajr', '05:30'), findsOneWidget);
      await prefs.setString('prayerAdjustments', jsonEncode({'fajr': 8}));
      await adjustments.init();
      await tester.pumpAndSettle();
      expect(time('fajr', '05:38'), findsOneWidget);
      expect(events, isEmpty);
    },
  );

  testWidgets('initial preference errors can be retried', (tester) async {
    adjustments.failLoad = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('please_try_again'.tr), findsOneWidget);
    expect(card('fajr'), findsNothing);
    adjustments.failLoad = false;
    await tester.tap(find.text('try_again'.tr));
    await tester.pumpAndSettle();
    expect(time('fajr', '05:30'), findsOneWidget);
    expect(adjustments.loads, 2);
  });

  for (final locale in ['fr', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        'adjustments fit320px $locale dark=$dark at2x text including Ramadan rows',
        (tester) async {
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final captureKey = GlobalKey();
          await tester.pumpWidget(
            app(locale: locale, dark: dark, scale: 2, captureKey: captureKey),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final key in [
            'fajr',
            'sunrise',
            'zuhr',
            'asr',
            'maghrib',
            'isha',
            'sehri',
            'iftar',
          ]) {
            await tester.scrollUntilVisible(plus(key), 100);
            await tester.pump();
            expect(tester.takeException(), isNull);
            expect(tester.getSize(plus(key)).width, greaterThanOrEqualTo(48));
          }
          expect(find.textContaining('sehri_end'.tr), findsOneWidget);
          expect(find.textContaining('iftar_start'.tr), findsOneWidget);
          final directory = Platform.environment['SALATIME_QA_DIR'];
          if (directory != null) {
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .jumpTo(0);
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final boundary =
                  captureKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(directory).create(recursive: true);
                await File(
                  '$directory/prayer-adjustment-$locale-${dark ? 'dark' : 'light'}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }
        },
      );
    }
  }
}
