import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/data/api/api_client.dart';
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:zabi/helper/local_prayer_calculator.dart';
import 'package:zabi/helper/additional_reminder_plan.dart';
import 'package:zabi/helper/prayer_alarm_health.dart';
import 'package:zabi/helper/prayer_notification_preferences.dart';
import 'package:zabi/helper/salat_waqt_service.dart';

class CachedPrayerController extends PrayerTimeController {
  CachedPrayerController(SharedPreferences prefs, this.date)
    : super(
        apiClient: ApiClient(
          appBaseUrl: 'https://unused.invalid',
          sharedPreferences: prefs,
        ),
      );
  final String date;
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
    if (!fresh || value.toIso8601String().split('T').first != date) return null;
    return PrayerTimeModel(
      data: Data(
        date: date,
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
      return {'failed': 0};
    });
    addTearDown(() async {
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
      expect(harness.cancellations, contains(id));
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
        reason: 'The stale pass must stop before scheduling Asr',
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
