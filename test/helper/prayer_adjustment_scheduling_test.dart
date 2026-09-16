import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/helper/local_prayer_calculator.dart';
import 'package:salatime/helper/prayer_alarm_health.dart';
import 'package:salatime/helper/prayer_notification_preferences.dart';
import 'package:salatime/helper/salat_waqt_service.dart';
import 'package:salatime/util/app_constants.dart';

class _OfflineApi extends ApiClient {
  _OfflineApi(SharedPreferences prefs)
    : super(appBaseUrl: 'https://unused.invalid', sharedPreferences: prefs);

  int attempts = 0;

  @override
  Future<Response> postData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    attempts++;
    throw StateError('A passive adjustment refresh must use cached times');
  }
}

class _NoNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('A passive adjustment refresh must not access HTTP');
  }
}

class _AdjustmentHarness {
  static const _notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  static const _timezone = MethodChannel('flutter_timezone');
  static const _location = MethodChannel('flutter.baseflow.com/geolocator');
  static const _geocoding = MethodChannel('flutter.baseflow.com/geocoding');
  static const _permissions = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  static const beforeMinutes = 17;
  static const afterMinutes = 23;

  final pending = <int, Map<String, dynamic>>{};
  final scheduled = <int>[];
  final cancelled = <int>[];
  final routed = <int>[];
  final forbiddenPlatformCalls = <String>[];
  late final SharedPreferences prefs;
  late final _OfflineApi api;
  late final PrayerTimeAdjustmentController adjustment;
  late final DateTime day;
  late final Data raw;
  late PrayerTimeController prayer;

  String get date => day.toIso8601String().split('T').first;

  Future<void> initialize({bool midnight = false}) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    Get.testMode = true;
    Get.locale = const Locale('en');
    final now = DateTime.now().toUtc();
    // J+2 keeps even a negative Fajr offset safely in the future at any test hour.
    day = DateTime.utc(now.year, now.month, now.day + 2);
    raw = Data(
      date: date,
      fajrStart: midnight ? '00:05' : '05:30',
      sunrise: midnight ? '01:00' : '07:00',
      zuhrStart: '13:00',
      asrStart: '16:00',
      maghribStart: midnight ? '23:00' : '19:00',
      ishaStart: midnight ? '00:30' : '21:00',
    );
    final cacheKey = base64Url.encode(
      utf8.encode(
        jsonEncode(['manual', date, 'test city', '', '', null, null, 'UTC']),
      ),
    );
    SharedPreferences.setMockInitialValues({
      AppConstants.isPrayerTme: true,
      AppConstants.IS_MANUAL_PRAYER_TIME: true,
      AppConstants.saveCityName: 'Test city',
      'selectedCalculationMethod': '3',
      'selectedPrayerMadhab': 'STANDARD',
      'prayer_time_response_cache_v1_$cacheKey': jsonEncode(
        PrayerTimeModel(status: true, data: raw).toJson(),
      ),
    });
    prefs = await SharedPreferences.getInstance();
    api = _OfflineApi(prefs);
    prayer = Get.put<PrayerTimeController>(
      PrayerTimeController(apiClient: api),
    );
    adjustment = Get.put(PrayerTimeAdjustmentController());
    await adjustment.init();

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_timezone, (_) async => 'UTC');
    for (final channel in [_location, _geocoding, _permissions]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        forbiddenPlatformCalls.add('${channel.name}/${call.method}');
        throw StateError(
          'A passive adjustment must not request location or permissions',
        );
      });
    }
    messenger.setMockMethodCallHandler(_notifications, (call) async {
      switch (call.method) {
        case 'initialize':
        case 'canScheduleExactNotifications':
          return true;
        case 'getNotificationChannels':
          return <Object>[];
        case 'pendingNotificationRequests':
          return pending.values.toList();
        case 'zonedSchedule':
          final arguments = Map<String, dynamic>.from(call.arguments);
          final id = arguments['id'] as int;
          scheduled.add(id);
          pending[id] = arguments;
          return null;
        case 'cancel':
          final id = call.arguments['id'] as int;
          cancelled.add(id);
          pending.remove(id);
          return null;
        case 'requestNotificationsPermission':
        case 'requestExactAlarmsPermission':
          forbiddenPlatformCalls.add(call.method);
          throw StateError('A passive adjustment must not request permission');
      }
      return null;
    });
    messenger.setMockMethodCallHandler(PrayerAlarmHealth.channel, (call) async {
      if (call.method == 'applyScheduleChanges') {
        for (final id in (call.arguments['cancelIds'] as List).cast<int>()) {
          cancelled.add(id);
          pending.remove(id);
        }
        for (final raw in call.arguments['notifications'] as List) {
          final arguments = Map<String, dynamic>.from(raw);
          final id = arguments['id'] as int;
          scheduled.add(id);
          routed.add(id);
          pending[id] = arguments;
        }
      }
      if (call.method == 'route' && call.arguments is Map) {
        routed.add(call.arguments['id'] as int);
      }
      return {'failed': 0};
    });
    final originalHttp = HttpOverrides.current;
    final network = _NoNetwork();
    HttpOverrides.global = network;
    addTearDown(() async {
      try {
        expect(api.attempts, 0);
        expect(network.attempts, 0);
        expect(forbiddenPlatformCalls, isEmpty);
      } finally {
        HttpOverrides.global = originalHttp;
        for (final channel in [
          _notifications,
          _timezone,
          _location,
          _geocoding,
          _permissions,
          PrayerAlarmHealth.channel,
        ]) {
          messenger.setMockMethodCallHandler(channel, null);
        }
        debugDefaultTargetPlatformOverride = null;
        Get.reset();
      }
    });
    for (final phase in PrayerNotificationPhase.values) {
      await PrayerNotificationPreferences.setPhaseEnabled(phase, false);
    }
  }

  Future<void> enable(Iterable<PrayerNotificationPrayer> prayers) async {
    for (final prayer in prayers) {
      for (final phase in PrayerNotificationPhase.values) {
        await PrayerNotificationPreferences.update(
          prayer,
          phase,
          enabled: true,
          minutes: switch (phase) {
            PrayerNotificationPhase.before => beforeMinutes,
            PrayerNotificationPhase.adhan => 0,
            PrayerNotificationPhase.after => afterMinutes,
          },
        );
      }
    }
  }

  Future<void> refresh() =>
      SalatWaqtService.initializeSalatWaqt(requestPermissions: false);

  Map<String, dynamic> payload(int id) => jsonDecode(pending[id]!['payload']);

  Set<int> prayerIds(int prayerId) =>
      pending.keys.where((id) => payload(id)['prayerId'] == prayerId).toSet();

  void expectPhases(int prayerId, DateTime adjustedPrayer) {
    final ids = prayerIds(prayerId);
    expect(ids, hasLength(3));
    for (final id in ids) {
      final data = payload(id);
      final phaseMinutes = switch (data['kind']) {
        'before' => -beforeMinutes,
        'adhan' => 0,
        'after' => afterMinutes,
        _ => throw StateError('Unexpected phase'),
      };
      final expected = adjustedPrayer.add(Duration(minutes: phaseMinutes));
      expect(data['date'], date);
      expect(data['prayerAt'], adjustedPrayer.millisecondsSinceEpoch);
      expect(data['at'], expected.millisecondsSinceEpoch);
      expect(pending[id]!['timeZoneName'], 'UTC');
      expect(
        DateTime.parse(
          pending[id]!['scheduledDateTimeISO8601'] as String,
        ).millisecondsSinceEpoch,
        expected.millisecondsSinceEpoch,
      );
    }
  }

  void clearCalls() {
    scheduled.clear();
    cancelled.clear();
    routed.clear();
  }

  Future<void> forgetDailyCache() async {
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('prayer_time_response_cache_')) {
        await prefs.remove(key);
      }
    }
    // Recreate the real controller to also clear its in-memory day cache.
    await Get.delete<PrayerTimeController>(force: true);
    prayer = Get.put<PrayerTimeController>(
      PrayerTimeController(apiClient: api),
    );
    await prayer.refreshConfiguredPrayerTime();
    expect(
      await prayer.getPrayerTimeForDate(day, allowNetwork: false),
      isNull,
      reason:
          'Recovery must exercise the manifest rather than a live day cache',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(LocalPrayerCalculator.initializeTimeZones);

  test(
    'all six prayer offsets reach native adhan, before and after exactly once',
    () async {
      final harness = _AdjustmentHarness();
      await harness.initialize();
      await harness.enable(PrayerNotificationPrayer.values);
      const offsets = {
        'fajr': 9,
        'sunrise': -11,
        'zuhr': -4,
        'asr': 6,
        'maghrib': -7,
        'isha': 13,
      };
      for (final entry in offsets.entries) {
        await harness.adjustment.updateAdjustment(entry.key, entry.value);
      }
      final before = harness.raw.toJson();
      await harness.refresh();

      expect(harness.pending, hasLength(18));
      expect(harness.routed.toSet(), harness.pending.keys.toSet());
      harness.expectPhases(
        1,
        harness.day.add(const Duration(hours: 5, minutes: 39)),
      );
      harness.expectPhases(
        6,
        harness.day.add(const Duration(hours: 6, minutes: 49)),
      );
      harness.expectPhases(
        2,
        harness.day.add(const Duration(hours: 12, minutes: 56)),
      );
      harness.expectPhases(
        3,
        harness.day.add(const Duration(hours: 16, minutes: 6)),
      );
      harness.expectPhases(
        4,
        harness.day.add(const Duration(hours: 18, minutes: 53)),
      );
      harness.expectPhases(
        5,
        harness.day.add(const Duration(hours: 21, minutes: 13)),
      );
      final cached = await harness.prayer.getPrayerTimeForDate(
        harness.day,
        allowNetwork: false,
      );
      expect(
        cached!.data!.toJson(),
        before,
        reason: 'Notification offsets must not modify raw cached clocks',
      );
      expect(
        (await SalatWaqtService.readSchedule()).map((row) => row['at']).toSet(),
        harness.pending.keys.map((id) => harness.payload(id)['at']).toSet(),
      );

      harness.clearCalls();
      await harness.refresh();
      expect(
        harness.scheduled,
        isEmpty,
        reason: 'Re-reading the same offsets cannot shift alarms twice',
      );
    },
  );

  test(
    'passive reload reads persisted changes and reset without GPS or HTTP',
    () async {
      final harness = _AdjustmentHarness();
      await harness.initialize();
      await harness.enable([
        PrayerNotificationPrayer.fajr,
        PrayerNotificationPrayer.sunrise,
      ]);
      await harness.adjustment.updateAdjustment('fajr', 5);
      await harness.refresh();
      final fajrIds = harness.prayerIds(1);
      final sunriseIds = harness.prayerIds(6);
      harness.expectPhases(
        1,
        harness.day.add(const Duration(hours: 5, minutes: 35)),
      );
      harness.clearCalls();

      // A restore writes persisted values before the scheduler reloads its controller.
      await harness.prefs.setString(
        PrayerTimeAdjustmentController.storageKey,
        jsonEncode({'fajr': -8}),
      );
      expect(harness.adjustment.getAdjustmentMinutes('fajr'), 5);
      await harness.refresh();
      expect(harness.adjustment.getAdjustmentMinutes('fajr'), -8);
      harness.expectPhases(
        1,
        harness.day.add(const Duration(hours: 5, minutes: 22)),
      );
      harness.expectPhases(6, harness.day.add(const Duration(hours: 7)));
      expect(harness.scheduled.toSet(), fajrIds);
      expect(
        harness.cancelled,
        isEmpty,
        reason: 'Changed instants are replaced by the same native transaction',
      );
      expect(harness.prayerIds(6), sunriseIds);

      await harness.adjustment.resetPrayerTime(prayerKey: 'fajr');
      harness.clearCalls();
      await harness.refresh();
      harness.expectPhases(
        1,
        harness.day.add(const Duration(hours: 5, minutes: 30)),
      );
      expect(harness.scheduled.toSet(), fajrIds);
      harness.clearCalls();
      await harness.refresh();
      expect(harness.scheduled, isEmpty);
    },
  );

  test(
    'negative Fajr and post-midnight Isha preserve their prayer date across civil midnight',
    () async {
      final harness = _AdjustmentHarness();
      await harness.initialize(midnight: true);
      await harness.enable([
        PrayerNotificationPrayer.fajr,
        PrayerNotificationPrayer.isha,
      ]);
      await harness.adjustment.updateAdjustment('fajr', -10);
      await harness.adjustment.updateAdjustment('isha', 10);
      await harness.refresh();

      expect(harness.pending, hasLength(6));
      harness.expectPhases(1, harness.day.subtract(const Duration(minutes: 5)));
      harness.expectPhases(
        5,
        harness.day.add(const Duration(days: 1, minutes: 40)),
      );
      expect(harness.raw.fajrStart, '00:05');
      expect(harness.raw.ishaStart, '00:30');
    },
  );

  test(
    'manifest-only recovery applies the new offset delta once after losing the day cache',
    () async {
      final harness = _AdjustmentHarness();
      await harness.initialize();
      await harness.enable([PrayerNotificationPrayer.fajr]);
      await harness.adjustment.updateAdjustment('fajr', 5);
      await harness.refresh();
      final ids = harness.prayerIds(1);
      expect(
        (await SalatWaqtService.readSchedule()).map(
          (row) => row['adjustmentMinutes'],
        ),
        everyElement(5),
      );

      await harness.forgetDailyCache();
      await harness.adjustment.updateAdjustment('fajr', 20);
      harness.clearCalls();
      await harness.refresh();
      harness.expectPhases(
        1,
        harness.day.add(const Duration(hours: 5, minutes: 50)),
      );
      expect(harness.prayerIds(1), ids);
      expect(harness.scheduled.toSet(), ids);
      expect(
        (await SalatWaqtService.readSchedule()).map(
          (row) => row['adjustmentMinutes'],
        ),
        everyElement(20),
      );

      harness.clearCalls();
      await harness.refresh();
      harness.expectPhases(
        1,
        harness.day.add(const Duration(hours: 5, minutes: 50)),
      );
      expect(harness.scheduled, isEmpty);
      await harness.adjustment.resetPrayerTime(prayerKey: 'fajr');
      await harness.refresh();
      harness.expectPhases(
        1,
        harness.day.add(const Duration(hours: 5, minutes: 30)),
      );
    },
  );

  for (final invalidOffset in <Object?>[null, '5', 121, -121]) {
    test(
      'legacy manifest with missing or invalid offset ($invalidOffset) preserves its known instant',
      () async {
        final harness = _AdjustmentHarness();
        await harness.initialize();
        await harness.enable([PrayerNotificationPrayer.fajr]);
        await harness.adjustment.updateAdjustment('fajr', 5);
        await harness.refresh();
        final rows = await SalatWaqtService.readSchedule();
        for (final row in rows) {
          row.remove('adjustmentMinutes');
          if (invalidOffset != null) row['adjustmentMinutes'] = invalidOffset;
          final id = row['id'] as int;
          final payload = harness.payload(id)..remove('adjustmentMinutes');
          if (invalidOffset != null) {
            payload['adjustmentMinutes'] = invalidOffset;
          }
          harness.pending[id]!['payload'] = jsonEncode(payload);
        }
        await harness.prefs.setString(
          SalatWaqtService.scheduleKey,
          jsonEncode(rows),
        );
        await harness.forgetDailyCache();
        await harness.adjustment.updateAdjustment('fajr', 20);
        await harness.refresh();
        harness.expectPhases(
          1,
          harness.day.add(const Duration(hours: 5, minutes: 35)),
        );
        harness.clearCalls();
        await harness.refresh();
        harness.expectPhases(
          1,
          harness.day.add(const Duration(hours: 5, minutes: 35)),
        );
        expect(harness.scheduled, isEmpty);
      },
    );
  }
}
