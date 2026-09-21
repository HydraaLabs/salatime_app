import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/view/screens/home/modern/widget/modern_prayer_dashboard.dart';
import 'package:salatime/theme/brand_colors.dart';

PrayerTimeModel _day(DateTime date, {String fajr = '05:30'}) => PrayerTimeModel(
  data: Data(
    date: date.toIso8601String().split('T').first,
    fajrStart: fajr,
    sunrise: '08:00',
    zuhrStart: '13:00',
    asrStart: '16:00',
    maghribStart: '19:00',
    ishaStart: '21:00',
  ),
);

class _Controller extends PrayerTimeController {
  _Controller(SharedPreferences prefs)
    : super(
        apiClient: ApiClient(
          appBaseUrl: 'https://example.invalid',
          sharedPreferences: prefs,
        ),
      );
  Future<PrayerTimeModel?> Function(DateTime)? handler;
  final requests = <DateTime>[];
  @override
  Future<PrayerTimeModel?> getPrayerTimeForDate(
    DateTime date, {
    bool allowNetwork = true,
  }) async {
    requests.add(date);
    if (handler != null) return handler!(date);
    if (prayerTimeModel == null) return null;
    return _day(date, fajr: currentAddress.value == 'B' ? '07:00' : '05:30');
  }
}

class _Strings extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en': {
      'countdown_prefix': 'in',
      'next_prayer': 'Next prayer',
      'fajr': 'Fajr',
      'asr': 'Asr',
      'magrib': 'Maghrib',
      'time_since_prayer': 'Time since @prayer',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Controller controller;
  var now = DateTime(2026, 9, 12, 23, 55);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SharedPreferences>(prefs);
    controller = _Controller(prefs);
    now = DateTime(2026, 9, 12, 23, 55);
  });
  tearDown(Get.reset);
  Widget app({Brightness brightness = Brightness.light}) => GetMaterialApp(
    theme: ThemeData(brightness: brightness),
    translations: _Strings(),
    locale: const Locale('en'),
    home: Scaffold(
      body: SingleChildScrollView(
        child: ModernPrayerDashboard(
          prayerTimeController: controller,
          now: () => now,
        ),
      ),
    ),
  );
  for (final brightness in Brightness.values) {
    testWidgets('countdown changes color on the timer tick in $brightness', (
      tester,
    ) async {
      now = DateTime(2026, 9, 12, 12);
      controller.prayerTimeModel = _day(now);
      await tester.pumpWidget(app(brightness: brightness));
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('in 01:00:00')).style!.color,
        Colors.white,
      );
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<Text>(find.text('in 00:59:59')).style!.color,
        BrandColors.countdownWarningOnPrimary,
      );
      now = DateTime(2026, 9, 12, 13);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('in 00:00:00'), findsNothing);
      expect(
        tester.widget<Text>(find.text('00:00:00')).style!.color,
        Colors.white,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
      'home switches one hour after Asr without reopening in $brightness',
      (tester) async {
        now = DateTime(2026, 9, 21, 17, 39, 59);
        controller.prayerTimeModel = PrayerTimeModel(
          data: Data(
            date: '2026-09-21',
            asrStart: '16:40',
            maghribStart: '19:18',
            ishaStart: '20:37',
          ),
        );
        await tester.pumpWidget(app(brightness: brightness));
        await tester.pump();
        expect(find.text('Time since Asr'), findsOneWidget);
        expect(find.text('00:59:59'), findsOneWidget);

        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Time since Asr'), findsNothing);
        expect(find.text('Next prayer'), findsOneWidget);
        expect(
          tester.widget<Text>(find.text('in 01:38:00')).style!.color,
          Colors.white,
        );

        now = DateTime(2026, 9, 21, 18, 6, 37);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('in 01:11:23'), findsOneWidget);
        now = DateTime(2026, 9, 21, 18, 18);
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester.widget<Text>(find.text('in 01:00:00')).style!.color,
          Colors.white,
        );
        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester.widget<Text>(find.text('in 00:59:59')).style!.color,
          BrandColors.countdownWarningOnPrimary,
        );
        now = DateTime(2026, 9, 21, 19, 18);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Time since Maghrib'), findsOneWidget);
        expect(find.text('00:00:00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'neighbors reload after startup data arrives and today follows midnight',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();
      expect(controller.requests, hasLength(2));
      controller.prayerTimeModel = _day(DateTime(2026, 9, 12));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(controller.requests, hasLength(4));
      expect(find.text('in 05:35:00'), findsOneWidget);
      now = DateTime(2026, 9, 13, 0, 5);
      controller.prayerTimeModel = _day(DateTime(2026, 9, 13));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('gregorian_date_text')))
            .data,
        'Sunday, September 13, 2026',
      );
      expect(find.text('in 05:25:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('an asynchronous neighbor from a previous city is discarded', (
    tester,
  ) async {
    final pending = Completer<PrayerTimeModel?>();
    controller.prayerTimeModel = _day(DateTime(2026, 9, 12));
    controller.currentAddress.value = 'A';
    controller.handler = (_) => pending.future;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(controller.requests, hasLength(1));
    controller.currentAddress.value = 'B';
    controller.handler = null;
    pending.complete(_day(DateTime(2026, 9, 11)));
    await tester.pump();
    // The old request must not continue into the following day's lookup.
    expect(controller.requests, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(controller.requests, hasLength(3));
    expect(find.text('in 07:05:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('midnight preserves a day deliberately selected by the user', (
    tester,
  ) async {
    controller.prayerTimeModel = _day(DateTime(2026, 9, 12));
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('prayer_date_previous')));
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('gregorian_date_text')))
          .data,
      'Friday, September 11, 2026',
    );
    now = DateTime(2026, 9, 13, 0, 5);
    controller.prayerTimeModel = _day(DateTime(2026, 9, 13));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('gregorian_date_text')))
          .data,
      'Friday, September 11, 2026',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
