import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:salatime/helper/islamic_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/helper/local_prayer_calculator.dart';
import 'package:salatime/helper/additional_reminder_plan.dart';
import 'package:salatime/helper/prayer_alarm_health.dart';
import 'package:salatime/helper/prayer_notification_preferences.dart';
import 'package:salatime/helper/salat_waqt_service.dart';
import 'package:salatime/helper/prayer_widget_sync.dart';

class CachedPrayerController extends PrayerTimeController {
  CachedPrayerController(SharedPreferences prefs, this.date)
    : super(
        apiClient: ApiClient(
          appBaseUrl: 'https://unused.invalid',
          sharedPreferences: prefs,
        ),
      );
  String date;
  final extraDates = <String>{};
  bool fresh = true;
  @override
  String? get prayerTimeZone => 'UTC';
  @override
  Future<void> refreshConfiguredPrayerTime() async {}
  @override
  Future<PrayerTimeModel?> getPrayerTimeForDate(
    DateTime value, {
    bool allowNetwork = true,
  }) async {
    expect(allowNetwork, false);
    final requested = value.toIso8601String().split('T').first;
    if (!fresh || (requested != date && !extraDates.contains(requested))) {
      return null;
    }
    return PrayerTimeModel(
      data: Data(
        date: requested,
        fajrStart: '05:30',
        sunrise: '07:00',
        zuhrStart: '13:00',
        asrStart: '16:00',
        maghribStart: '19:00',
        ishaStart: '21:00',
      ),
    );
  }
}

class SchedulerHarness {
  final pending = <int, Map<String, dynamic>>{};
  final cancellations = <int>[];
  final scheduled = <int>[];
  final nativeCalls = <MethodCall>[];
  int initializeCalls = 0;
  bool failInitialization = false;
  bool failBatch = false;
  Future<void> Function(Map<String, dynamic>)? beforeSchedule;
  late final CachedPrayerController controller;

  Future<void> initialize() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    Get.testMode = true;
    Get.locale = const Locale('en');
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toUtc();
    final tomorrow = DateTime.utc(
      today.year,
      today.month,
      today.day + 1,
    ).toIso8601String().split('T').first;
    controller = CachedPrayerController(prefs, tomorrow);
    Get.put<PrayerTimeController>(controller);
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    const timezone = MethodChannel('flutter_timezone');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'initialize':
          initializeCalls++;
          if (failInitialization) {
            throw PlatformException(code: 'initialization_failed');
          }
          return true;
        case 'getNotificationChannels':
          return <Object>[];
        case 'canScheduleExactNotifications':
          return true;
        case 'pendingNotificationRequests':
          return pending.values.toList();
        case 'zonedSchedule':
          final args = Map<String, dynamic>.from(call.arguments);
          final id = args['id'] as int;
          await beforeSchedule?.call(args);
          scheduled.add(id);
          pending[id] = args;
          return null;
        case 'cancel':
          final id = call.arguments['id'] as int;
          pending.remove(id);
          cancellations.add(id);
          return null;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(timezone, (_) async => 'UTC');
    messenger.setMockMethodCallHandler(PrayerAlarmHealth.channel, (call) async {
      nativeCalls.add(call);
      if (call.method == 'applyScheduleChanges') {
        if (failBatch) throw PlatformException(code: 'reserve_write_failed');
        for (final id in (call.arguments['cancelIds'] as List).cast<int>()) {
          pending.remove(id);
          cancellations.add(id);
        }
        for (final raw in call.arguments['notifications'] as List) {
          final args = Map<String, dynamic>.from(raw);
          final id = args['id'] as int;
          await beforeSchedule?.call(args);
          scheduled.add(id);
          pending[id] = args;
        }
      }
      return {'failed': 0};
    });
    addTearDown(() async {
      await PrayerWidgetSync.refresh();
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(timezone, null);
      messenger.setMockMethodCallHandler(PrayerAlarmHealth.channel, null);
      debugDefaultTargetPlatformOverride = null;
      Get.clearTranslations();
      Get.reset();
    });
    for (final phase in PrayerNotificationPhase.values) {
      await PrayerNotificationPreferences.setPhaseEnabled(phase, false);
    }
  }

  Future<void> refresh() =>
      SalatWaqtService.initializeSalatWaqt(requestPermissions: false);
  Map<String, dynamic> payload(int id) => jsonDecode(pending[id]!['payload']);
  int prayerId(PrayerNotificationPrayer prayer) =>
      pending.keys.singleWhere((id) => payload(id)['prayer'] == prayer.name);
  int extraId(AdditionalReminderType type) =>
      pending.keys.singleWhere((id) => payload(id)['type'] == type.name);
  void clearCalls() {
    scheduled.clear();
    cancellations.clear();
    nativeCalls.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(LocalPrayerCalculator.initializeTimeZones);
  late SchedulerHarness harness;
  setUp(() async {
    harness = SchedulerHarness();
    await harness.initialize();
  });

  test('a failed native reserve commit preserves legacy alarms', () async {
    await PrayerNotificationPreferences.update(
      PrayerNotificationPrayer.fajr,
      PrayerNotificationPhase.adhan,
      enabled: true,
    );
    harness.pending[1] = {'id': 1, 'title': 'Fajr', 'body': '', 'payload': ''};
    harness.failBatch = true;
    await expectLater(harness.refresh(), throwsA(isA<PlatformException>()));
    expect(harness.pending.containsKey(1), isTrue);
    expect(harness.cancellations, isNot(contains(1)));
    expect(
      (await SharedPreferences.getInstance()).getBool(
        SalatWaqtService.failedKey,
      ),
      isTrue,
    );
  });

  test(
    'only an applied native batch skips the final full routing pass',
    () async {
      await PrayerNotificationPreferences.update(
        PrayerNotificationPrayer.fajr,
        PrayerNotificationPhase.adhan,
        enabled: true,
      );
      await harness.refresh();
      expect(
        harness.nativeCalls.where(
          (call) => call.method == 'applyScheduleChanges',
        ),
        hasLength(1),
      );
      expect(
        harness.nativeCalls
            .singleWhere((call) => call.method == 'update')
            .arguments['scheduleAlreadyApplied'],
        isTrue,
      );

      harness.clearCalls();
      await harness.refresh();
      expect(
        harness.nativeCalls.where(
          (call) => call.method == 'applyScheduleChanges',
        ),
        isEmpty,
      );
      expect(
        harness.nativeCalls
            .singleWhere((call) => call.method == 'update')
            .arguments['scheduleAlreadyApplied'],
        isFalse,
      );
    },
  );

  for (final (weekday, prayer) in [
    (DateTime.friday, PrayerNotificationPrayer.jumaa),
    (DateTime.saturday, PrayerNotificationPrayer.dhuhr),
  ]) {
    test(
      'adhan carries localized date and timer metadata and refreshes presentation for ${prayer.name}',
      () async {
        // Keep the occurrence in the real scheduler's future, but fix the weekday
        // explicitly: Friday uses the independent Jumaa preference, not Dhuhr.
        final tomorrow = DateTime.parse(
          '${harness.controller.date}T00:00:00Z',
        );
        final day = tomorrow.add(
          Duration(days: (weekday - tomorrow.weekday + 7) % 7),
        );
        harness.controller.date = day.toIso8601String().split('T').first;
        expect(day.weekday, weekday);
        Get.addTranslations({
          'en': {
            for (var month = 1; month <= 12; month++)
              'hijri_month_$month': 'Month $month',
            'time_since_prayer': 'Time since @prayer',
          },
        });
        await PrayerNotificationPreferences.save(
          PrayerNotificationSetting.defaults(
            prayer,
            PrayerNotificationPhase.adhan,
          ).copyWith(enabled: true),
        );
        await harness.refresh();
        expect(harness.pending, hasLength(1));
        final id = harness.pending.keys.single;
        var payload = harness.payload(id);
        final hijri = HijriCalendar.fromDate(day);
        expect(payload['prayer'], prayer.name);
        expect(payload['prayerName'], prayer.titleKey);
        expect(payload['prayerTime'], '13:00');
        expect(
          payload['hijriDate'],
          '${hijri.hDay} Month ${hijri.hMonth} ${hijri.hYear}',
        );
        expect(payload['elapsedLabel'], 'Time since ${payload['prayerName']}');
        expect(payload['locale'], 'en');
        expect(payload['prayerAt'], payload['at']);
        expect(payload['nextPrayer']['prayerName'], 'asr');
        expect(payload['nextPrayer']['prayerTime'], '16:00');
        expect(
          payload['nextPrayer']['prayerAt'] - payload['at'],
          const Duration(hours: 3).inMilliseconds,
        );
        harness.controller.fresh = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(IslamicCalendarPreferences.storageKey, 1);
        harness.controller.is24HourFormat.value = false;
        harness.clearCalls();
        await harness.refresh();
        payload = harness.payload(id);
        expect(payload['prayer'], prayer.name);
        expect(payload['prayerTime'], '1:00\u202fPM');
        expect(payload['nextPrayer']['prayerName'], 'asr');
        expect(payload['nextPrayer']['prayerTime'], '4:00\u202fPM');
        final adjusted = HijriCalendar.fromDate(
          day.add(const Duration(days: 1)),
        );
        expect(
          payload['hijriDate'],
          '${adjusted.hDay} Month ${adjusted.hMonth} ${adjusted.hYear}',
        );
        expect(harness.scheduled, [id]);
      },
    );
  }

  test(
    'next prayer ignores disabled sounds and sunrise and crosses midnight',
    () async {
      final followingDay = DateTime.parse(
        harness.controller.date,
      ).add(const Duration(days: 1));
      harness.controller.extraDates.add(
        followingDay.toIso8601String().split('T').first,
      );
      for (final prayer in [
        PrayerNotificationPrayer.fajr,
        PrayerNotificationPrayer.isha,
      ]) {
        await PrayerNotificationPreferences.save(
          PrayerNotificationSetting.defaults(
            prayer,
            PrayerNotificationPhase.adhan,
          ).copyWith(enabled: true),
        );
      }
      await harness.refresh();
      final payloads = harness.pending.keys.map(harness.payload).toList();
      final fajr = payloads.firstWhere(
        (row) =>
            row['date'] == harness.controller.date && row['prayer'] == 'fajr',
      );
      expect(fajr['nextPrayer']['prayerTime'], '13:00');
      final isha = payloads.firstWhere(
        (row) =>
            row['date'] == harness.controller.date && row['prayer'] == 'isha',
      );
      expect(isha['nextPrayer']['prayerName'], 'fajr');
      expect(
        isha['nextPrayer']['prayerAt'],
        DateTime.utc(
          followingDay.year,
          followingDay.month,
          followingDay.day,
          5,
          30,
        ).millisecondsSinceEpoch,
      );
    },
  );

  test('widget data is available without initializing notifications', () async {
    harness.failInitialization = true;
    await PrayerWidgetSync.refresh();
    expect(harness.initializeCalls, 0);
    expect(harness.scheduled, isEmpty);
    final update = harness.nativeCalls.single;
    expect(update.method, 'updateWidget');
    final args = Map<String, dynamic>.from(update.arguments);
    expect(jsonDecode(args['prayers']), hasLength(5));
    expect(args['timeZone'], 'UTC');
    expect(args.containsKey('alarms'), false);
  });

  test('widget is filled while alarm registration is still blocked', () async {
    await PrayerNotificationPreferences.save(
      PrayerNotificationSetting.defaults(
        PrayerNotificationPrayer.fajr,
        PrayerNotificationPhase.adhan,
      ).copyWith(enabled: true),
    );
    final entered = Completer<void>();
    final release = Completer<void>();
    harness.beforeSchedule = (_) async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    final refresh = harness.refresh();
    try {
      await entered.future;
      await PrayerWidgetSync.refresh();
      final updates = harness.nativeCalls.where(
        (c) => c.method == 'updateWidget',
      );
      expect(updates, isNotEmpty);
      expect(jsonDecode(updates.last.arguments['prayers']), hasLength(5));
      expect(harness.scheduled, isEmpty);
    } finally {
      release.complete();
      await refresh;
    }
  });

  test(
    'unavailable offline dates do not overwrite native widget data',
    () async {
      harness.controller.fresh = false;
      await PrayerWidgetSync.refresh();
      expect(harness.nativeCalls, isEmpty);
      expect(harness.initializeCalls, 0);
    },
  );

  test(
    'scheduler updates sound and delay from offline base time then cancels a disabled phase',
    () async {
      final setting = PrayerNotificationSetting.defaults(
        PrayerNotificationPrayer.fajr,
        PrayerNotificationPhase.before,
      ).copyWith(enabled: true);
      await PrayerNotificationPreferences.save(setting);
      await harness.refresh();
      expect(harness.pending, hasLength(1));
      final id = harness.pending.keys.single;
      var payload = harness.payload(id);
      expect(payload['minutes'], 5);
      expect(payload['sound'], 'moatheni_before_prayer_fajr');
      final originalAt = payload['at'] as int;
      harness.controller.fresh = false;
      await PrayerNotificationPreferences.save(
        setting.copyWith(minutes: 17, sound: 'moatheni_water'),
      );
      await harness.refresh();
      expect(harness.pending.keys.single, id);
      payload = harness.payload(id);
      expect(payload['sound'], 'moatheni_water');
      expect(
        payload['at'],
        originalAt - const Duration(minutes: 12).inMilliseconds,
      );
      expect(
        harness.cancellations,
        isEmpty,
        reason: 'The native transaction replaces the existing alarm atomically',
      );
      harness.clearCalls();
      await harness.refresh();
      expect(
        harness.scheduled,
        isEmpty,
        reason: 'Unchanged cached occurrences must not be rewritten',
      );
      await PrayerNotificationPreferences.save(
        setting.copyWith(enabled: false),
      );
      await harness.refresh();
      expect(harness.pending, isEmpty);
      expect(await SalatWaqtService.readSchedule(), isEmpty);
    },
  );

  for (final selectedPhase in PrayerNotificationPhase.values) {
    test(
      'disabling the ${selectedPhase.name} series cancels only its cached alarms including sunrise',
      () async {
        for (final phase in PrayerNotificationPhase.values) {
          await PrayerNotificationPreferences.setPhaseEnabled(phase, true);
          await PrayerNotificationPreferences.update(
            PrayerNotificationPrayer.sunrise,
            phase,
            enabled: true,
          );
        }
        await harness.refresh();
        expect(harness.pending, hasLength(18));
        final disabledIds = harness.pending.keys
            .where((id) => harness.payload(id)['kind'] == selectedPhase.name)
            .toSet();
        final retainedIds = harness.pending.keys.toSet().difference(
          disabledIds,
        );
        expect(disabledIds, hasLength(6));
        expect(
          disabledIds.map((id) => harness.payload(id)['prayer']),
          contains('sunrise'),
        );
        final retainedPayloads = {
          for (final id in retainedIds) id: harness.pending[id]!['payload'],
        };

        harness.controller.fresh = false;
        harness.clearCalls();
        await PrayerNotificationPreferences.setPhaseEnabled(
          selectedPhase,
          false,
        );
        await harness.refresh();

        expect(harness.cancellations.toSet(), disabledIds);
        expect(harness.pending.keys.toSet(), retainedIds);
        expect(harness.scheduled, isEmpty);
        expect({
          for (final id in retainedIds) id: harness.pending[id]!['payload'],
        }, retainedPayloads);
        final manifest = await SalatWaqtService.readSchedule();
        expect(manifest.map((entry) => entry['id']).toSet(), retainedIds);
        expect(
          manifest.every((entry) => entry['kind'] != selectedPhase.name),
          true,
        );
      },
    );
  }

  test(
    'unchanged alarms are reused, missing requests recreated and only edited prayers rewritten',
    () async {
      await PrayerNotificationPreferences.update(
        PrayerNotificationPrayer.fajr,
        PrayerNotificationPhase.after,
        enabled: true,
      );
      await PrayerNotificationPreferences.update(
        PrayerNotificationPrayer.asr,
        PrayerNotificationPhase.adhan,
        enabled: true,
      );
      await harness.refresh();
      expect(harness.scheduled, hasLength(2));
      final fajr = harness.prayerId(PrayerNotificationPrayer.fajr);
      final asr = harness.prayerId(PrayerNotificationPrayer.asr);
      harness.clearCalls();
      await harness.refresh();
      expect(harness.scheduled, isEmpty);
      expect(harness.pending.keys, containsAll([fajr, asr]));

      harness.pending.remove(fajr);
      await harness.refresh();
      expect(
        harness.scheduled,
        [fajr],
        reason: 'A manifest entry alone cannot prove the alarm exists',
      );
      harness.clearCalls();
      await PrayerNotificationPreferences.update(
        PrayerNotificationPrayer.fajr,
        PrayerNotificationPhase.after,
        sound: 'moatheni_water',
        minutes: 21,
      );
      await harness.refresh();
      expect(harness.scheduled, [fajr]);
      expect(harness.payload(fajr)['sound'], 'moatheni_water');
      expect(harness.payload(fajr)['minutes'], 21);
      expect(harness.cancellations, isNot(contains(asr)));

      harness.clearCalls();
      await PrayerNotificationPreferences.update(
        PrayerNotificationPrayer.fajr,
        PrayerNotificationPhase.after,
        enabled: false,
      );
      await harness.refresh();
      expect(harness.scheduled, isEmpty);
      expect(harness.pending.keys, [asr]);
      expect(harness.cancellations, contains(fajr));
      expect(harness.cancellations, isNot(contains(asr)));
      expect((await SalatWaqtService.readSchedule()).map((row) => row['id']), [
        asr,
      ]);
    },
  );

  test(
    'localized notification text and changed delivery payload invalidate reuse',
    () async {
      Get.addTranslations({
        'en': {
          'fajr': 'Fajr',
          'time_for': 'Time for',
          'started_at': 'at',
          'stop_adhan': 'Stop',
        },
        'fr': {
          'fajr': 'Sobh',
          'time_for': 'Heure de',
          'started_at': 'à',
          'stop_adhan': 'Arrêter',
        },
      });
      await PrayerNotificationPreferences.update(
        PrayerNotificationPrayer.fajr,
        PrayerNotificationPhase.adhan,
        enabled: true,
      );
      await harness.refresh();
      final id = harness.pending.keys.single;
      expect(harness.pending[id]!['title'], 'Fajr');
      harness.clearCalls();
      Get.locale = const Locale('fr');
      await harness.refresh();
      expect(harness.scheduled, [id]);
      expect(harness.pending[id]!['title'], 'Sobh');
      expect(harness.payload(id)['stopLabel'], 'Arrêter');
      harness.clearCalls();
      harness.pending[id]!['payload'] = jsonEncode({
        ...harness.payload(id),
        'stopLabel': 'Old label',
      });
      await harness.refresh();
      expect(harness.scheduled, [id]);
      expect(harness.payload(id)['stopLabel'], 'Arrêter');
    },
  );

  test(
    'extra reminders reuse stable requests but refresh sound, time and legacy payloads',
    () async {
      final morning = AdditionalReminderSetting.defaults(
        AdditionalReminderType.morning,
      ).copyWith(enabled: true);
      final bedtime = AdditionalReminderSetting.defaults(
        AdditionalReminderType.bedtime,
      ).copyWith(enabled: true);
      await AdditionalReminderPreferences.save([morning, bedtime]);
      await PrayerNotificationPreferences.update(
        PrayerNotificationPrayer.asr,
        PrayerNotificationPhase.adhan,
        enabled: true,
      );
      await harness.refresh();
      expect(harness.scheduled, hasLength(3));
      final morningId = harness.extraId(AdditionalReminderType.morning);
      final bedtimeId = harness.extraId(AdditionalReminderType.bedtime);
      final asr = harness.prayerId(PrayerNotificationPrayer.asr);
      harness.clearCalls();
      await harness.refresh();
      expect(harness.scheduled, isEmpty);

      final differentSound = morning.copyWith(sound: 'moatheni_water');
      await AdditionalReminderPreferences.save([differentSound, bedtime]);
      await harness.refresh();
      expect(harness.scheduled, [morningId]);
      expect(harness.payload(morningId)['sound'], 'moatheni_water');
      harness.clearCalls();
      await AdditionalReminderPreferences.save([
        differentSound.copyWith(minutes: 45),
        bedtime,
      ]);
      await harness.refresh();
      expect(harness.scheduled, [morningId]);
      harness.clearCalls();
      final legacyPayload = harness.payload(morningId)..remove('sound');
      harness.pending[morningId]!['payload'] = jsonEncode(legacyPayload);
      await harness.refresh();
      expect(
        harness.scheduled,
        [morningId],
        reason: 'Old payloads without a sound need one replacement',
      );
      harness.clearCalls();
      await AdditionalReminderPreferences.save([
        differentSound.copyWith(enabled: false),
        bedtime,
      ]);
      await harness.refresh();
      expect(harness.scheduled, isEmpty);
      expect(harness.pending.keys, containsAll([bedtimeId, asr]));
      expect(harness.pending, hasLength(2));
      expect(harness.cancellations, contains(morningId));
      expect(harness.cancellations, isNot(contains(bedtimeId)));
      expect(harness.cancellations, isNot(contains(asr)));
    },
  );
  test(
    'rapid saved edits are applied by one passive scheduling pass',
    () async {
      final requests = <Future<void>>[];
      for (var i = 0; i < 11; i++) {
        await PrayerNotificationPreferences.update(
          PrayerNotificationPrayer.fajr,
          PrayerNotificationPhase.after,
          enabled: i.isEven,
          minutes: i,
        );
        requests.add(SalatWaqtService.requestRefresh());
      }
      expect(harness.initializeCalls, 0);
      await Future.wait(requests);
      expect(harness.initializeCalls, 1);
      expect(harness.scheduled, hasLength(1));
      expect(harness.payload(harness.pending.keys.single)['minutes'], 10);
    },
  );

  test(
    'an edit during registration stops stale work and cancels the checkpointed alarm',
    () async {
      await PrayerNotificationPreferences.update(
        PrayerNotificationPrayer.fajr,
        PrayerNotificationPhase.after,
        enabled: true,
      );
      await PrayerNotificationPreferences.update(
        PrayerNotificationPrayer.asr,
        PrayerNotificationPhase.adhan,
        enabled: true,
      );
      final started = Completer<void>();
      final release = Completer<void>();
      harness.beforeSchedule = (args) async {
        if (!started.isCompleted) {
          started.complete();
          await release.future;
        }
      };
      final first = harness.refresh();
      await started.future;
      await PrayerNotificationPreferences.update(
        PrayerNotificationPrayer.fajr,
        PrayerNotificationPhase.after,
        enabled: false,
      );
      final latest = SalatWaqtService.requestRefresh();
      release.complete();
      await Future.wait([first, latest]);
      expect(harness.initializeCalls, 2);
      expect(
        harness.scheduled,
        hasLength(2),
        reason: 'The committed batch is reused by the latest scheduling pass',
      );
      expect(harness.pending, hasLength(1));
      final asr = harness.prayerId(PrayerNotificationPrayer.asr);
      final staleFajr = harness.scheduled.first;
      expect(harness.cancellations, contains(staleFajr));
      expect((await SalatWaqtService.readSchedule()).map((row) => row['id']), [
        asr,
      ]);
    },
  );

  test(
    'background refresh failures persist health state and a later successful pass clears it',
    () async {
      harness.failInitialization = true;
      await expectLater(
        SalatWaqtService.requestRefresh(),
        throwsA(isA<PlatformException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SalatWaqtService.failedKey), true);
      harness.failInitialization = false;
      await SalatWaqtService.requestRefresh();
      expect(prefs.getBool(SalatWaqtService.failedKey), false);
    },
  );
}
