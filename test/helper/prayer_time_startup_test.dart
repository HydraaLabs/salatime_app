import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/helper/automatic_prayer_method.dart';
import 'package:salatime/helper/date_converter.dart';
import 'package:salatime/helper/location_auto_update_service.dart';
import 'package:salatime/helper/prayer_time_startup.dart';
import 'package:salatime/util/app_constants.dart';
import 'package:salatime/view/screens/home/modern/widget/modern_prayer_dashboard.dart';

class _OfflineApi extends ApiClient {
  _OfflineApi(SharedPreferences prefs)
    : super(appBaseUrl: 'https://unused.invalid', sharedPreferences: prefs);

  int requests = 0;

  @override
  Future<Response> postData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    requests++;
    throw StateError('Startup prayer restoration must not request the API');
  }
}

class _NoNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Startup prayer restoration must work offline');
  }
}

class _Harness {
  static const timezone = MethodChannel('flutter_timezone');
  static const location = MethodChannel('flutter.baseflow.com/geolocator');
  static const geocoding = MethodChannel('flutter.baseflow.com/geocoding');
  static const permissions = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  final forbiddenCalls = <String>[];
  final locationGate = Completer<Object?>();
  late final _OfflineApi api;
  late final PrayerTimeController prayer;
  String zone = 'Africa/Casablanca';
  bool failTimezone = false;

  Future<void> initialize(Map<String, Object> values) async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    api = _OfflineApi(prefs);
    prayer = Get.put(PrayerTimeController(apiClient: api));
    Get.put(PrayerTimeAdjustmentController());
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(timezone, (_) async {
      if (failTimezone) throw PlatformException(code: 'timezone_unavailable');
      return zone;
    });
    for (final channel in [location, geocoding, permissions]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        forbiddenCalls.add('${channel.name}/${call.method}');
        // A slow GPS/reverse-geocoding result must never delay local startup.
        return locationGate.future;
      });
    }
    final previousHttp = HttpOverrides.current;
    final network = _NoNetwork();
    HttpOverrides.global = network;
    addTearDown(() async {
      if (!locationGate.isCompleted) locationGate.complete(null);
      for (final channel in [timezone, location, geocoding, permissions]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
      HttpOverrides.global = previousHttp;
      Get.reset();
      expect(api.requests, 0);
      expect(network.attempts, 0);
      expect(forbiddenCalls, isEmpty);
    });
  }
}

String _date(DateTime day) => day.toIso8601String().split('T').first;

String _cacheKey(String date) =>
    'prayer_time_response_cache_v1_${base64Url.encode(utf8.encode(jsonEncode(['manual', date, 'published city', '', '', null, null, 'Africa/Casablanca'])))}';

Data _publishedDay(String date) => Data(
  date: date,
  fajrStart: '05:31',
  sunrise: '07:04',
  zuhrStart: '13:07',
  asrStart: '16:32',
  maghribStart: '19:13',
  ishaStart: '20:39',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cold start restores today from automatic coordinates before GPS',
    () async {
      final harness = _Harness();
      await harness.initialize({
        LocationAutoUpdateService.enabledKey: true,
        // An old manual selection must not override active travel updates.
        AppConstants.isPrayerTme: true,
        AppConstants.IS_MANUAL_PRAYER_TIME: true,
        AppConstants.saveCityName: 'Paris',
        AppConstants.manualCityLat: 48.8566,
        AppConstants.manualCityLng: 2.3522,
        'prayer_time_automatic_latitude': 34.0331,
        'prayer_time_automatic_longitude': -5.0003,
        'prayer_time_automatic_city': 'Fès',
        AutomaticPrayerMethod.enabledKey: true,
        AutomaticPrayerMethod.automaticCountryKey: jsonEncode({
          'code': 'MA',
          'lat': 34.0331,
          'lng': -5.0003,
        }),
        'selectedPrayerMadhab': 'STANDARD',
        'is24HrFormat': false,
        PrayerTimeAdjustmentController.storageKey: jsonEncode({'fajr': 7}),
      });

      expect(harness.prayer.prayerTimeModel, isNull);
      await PrayerTimeStartup.restore().timeout(const Duration(seconds: 2));

      final model = harness.prayer.prayerTimeModel!;
      expect(model.calculatedLocally, isTrue);
      expect(model.data!.date, _date(DateTime.now()));
      expect(model.data!.fajrStart, matches(r'^\d{2}:\d{2}$'));
      expect(harness.prayer.currentAddress.value, 'Fès');
      expect(harness.prayer.isManualPrayerTime.value, isFalse);
      expect(harness.prayer.selectedCalculationMethod, '21');
      expect(harness.prayer.calculationCountry, 'MA');
      expect(harness.prayer.is24HourFormat.value, isFalse);
      final rawFajr = DateTime.parse('2000-01-01 ${model.data!.fajrStart}:00');
      final adjustedFajr = rawFajr.add(const Duration(minutes: 7));
      expect(
        PrayerTimeAdjustmentController.adjustedDay(model.data)!.fajrStart,
        '${adjustedFajr.hour.toString().padLeft(2, '0')}:'
        '${adjustedFajr.minute.toString().padLeft(2, '0')}',
      );
      expect(harness.locationGate.isCompleted, isFalse);
    },
  );

  test(
    'cold start restores a manually selected city without GPS or API',
    () async {
      final harness = _Harness()..zone = 'Europe/Paris';
      await harness.initialize({
        AppConstants.isPrayerTme: true,
        AppConstants.IS_MANUAL_PRAYER_TIME: true,
        AppConstants.saveCityName: 'Paris',
        AppConstants.manualCityLat: 48.8566,
        AppConstants.manualCityLng: 2.3522,
        'selectedCalculationMethod': '12',
        'selectedPrayerMadhab': 'HANAFI',
        'is24HrFormat': true,
      });

      await PrayerTimeStartup.restore();

      expect(harness.prayer.prayerTimeModel!.calculatedLocally, isTrue);
      expect(harness.prayer.prayerTimeModel!.data!.date, _date(DateTime.now()));
      expect(harness.prayer.saveAddress.value, 'Paris');
      expect(harness.prayer.isManualPrayerTime.value, isTrue);
      expect(harness.prayer.selectedCalculationMethod, '12');
      expect(harness.prayer.selectedPrayerMadhab, 'HANAFI');
      expect(harness.prayer.prayerTimeZone, 'Europe/Paris');
      expect(harness.prayer.is24HourFormat.value, isTrue);
    },
  );

  test(
    'published timetable restores only the current date from cache',
    () async {
      final today = _date(DateTime.now());
      final yesterday = _date(DateTime.now().subtract(const Duration(days: 1)));
      final harness = _Harness();
      await harness.initialize({
        AppConstants.isPrayerTme: true,
        AppConstants.IS_MANUAL_PRAYER_TIME: true,
        AppConstants.saveCityName: 'Published city',
        _cacheKey(today): jsonEncode(
          PrayerTimeModel(status: true, data: _publishedDay(today)).toJson(),
        ),
        _cacheKey(yesterday): jsonEncode(
          PrayerTimeModel(
            status: true,
            data: _publishedDay(yesterday),
          ).toJson(),
        ),
      });

      await PrayerTimeStartup.restore();

      expect(harness.prayer.prayerTimeModel!.data!.date, today);
      expect(harness.prayer.prayerTimeModel!.data!.fajrStart, '05:31');
      expect(harness.prayer.prayerTimeModel!.calculatedLocally, isFalse);
      expect(harness.prayer.usesManualPrayerTimetable, isTrue);
    },
  );

  test(
    'yesterday alone is not presented as today for a published city',
    () async {
      final yesterday = _date(DateTime.now().subtract(const Duration(days: 1)));
      final harness = _Harness();
      await harness.initialize({
        AppConstants.isPrayerTme: true,
        AppConstants.IS_MANUAL_PRAYER_TIME: true,
        AppConstants.saveCityName: 'Published city',
        _cacheKey(yesterday): jsonEncode(
          PrayerTimeModel(
            status: true,
            data: _publishedDay(yesterday),
          ).toJson(),
        ),
      });

      await PrayerTimeStartup.restore();

      expect(harness.prayer.prayerTimeModel, isNull);
      expect(harness.prayer.fajrStart.value, '--');
    },
  );

  test('missing location never invents prayer times during startup', () async {
    final harness = _Harness();
    await harness.initialize({'is24HrFormat': false});

    await PrayerTimeStartup.restore();

    expect(harness.prayer.prayerTimeModel, isNull);
    expect(harness.prayer.fajrStart.value, '--');
    expect(harness.prayer.is24HourFormat.value, isFalse);
  });

  test(
    'a native timezone failure cannot prevent the app from starting',
    () async {
      final harness = _Harness()..failTimezone = true;
      await harness.initialize({
        AppConstants.isPrayerTme: true,
        AppConstants.IS_MANUAL_PRAYER_TIME: true,
        AppConstants.saveCityName: 'Paris',
        AppConstants.manualCityLat: 48.8566,
        AppConstants.manualCityLng: 2.3522,
      });

      await expectLater(PrayerTimeStartup.restore(), completes);

      expect(harness.prayer.prayerTimeModel, isNull);
    },
  );

  testWidgets(
    'first home frame already displays all six restored prayer times',
    (tester) async {
      final harness = _Harness();
      await harness.initialize({
        AppConstants.isPrayerTme: true,
        AppConstants.IS_MANUAL_PRAYER_TIME: true,
        AppConstants.saveCityName: 'Fès',
        AppConstants.manualCityLat: 34.0331,
        AppConstants.manualCityLng: -5.0003,
        'selectedCalculationMethod': '21',
        'selectedPrayerMadhab': 'STANDARD',
        'is24HrFormat': true,
        PrayerTimeAdjustmentController.storageKey: jsonEncode({'fajr': 7}),
      });
      await PrayerTimeStartup.restore();
      final day = PrayerTimeAdjustmentController.adjustedDay(
        harness.prayer.prayerTimeModel!.data,
      )!;
      await tester.pumpWidget(
        GetMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ModernPrayerDashboard(
                prayerTimeController: harness.prayer,
              ),
            ),
          ),
        ),
      );

      // Inspect the first rendered frame, without waiting for GPS, a network
      // response, or even the dashboard's one-second countdown timer.
      for (final value in [
        day.fajrStart,
        day.sunrise,
        day.zuhrStart,
        day.asrStart,
        day.maghribStart,
        day.ishaStart,
      ]) {
        expect(
          find.text(DateConverter.formatPrayerTime(value!, true)),
          findsWidgets,
        );
      }
      expect(find.text('--:--'), findsNothing);
      expect(find.textContaining('--:--:--'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(harness.forbiddenCalls, isEmpty);
      expect(harness.locationGate.isCompleted, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
