import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise the installed plugin's cache as well as its platform persistence.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/helper/local_prayer_calculator.dart';
import 'package:salatime/helper/notification_sound_catalog.dart';
import 'package:salatime/helper/prayer_alarm_plan.dart';
import 'package:salatime/helper/prayer_notification_preferences.dart';
import 'package:salatime/service/cloud/preference_device.dart';
import 'package:salatime/util/app_constants.dart';

typedef Prayer = PrayerNotificationPrayer;
typedef Phase = PrayerNotificationPhase;

class _RejectingPrayerStore extends InMemorySharedPreferencesStore {
  _RejectingPrayerStore(
    Map<String, Object> values, {
    required this.throwOnWrite,
  }) : super.withData({
         for (final entry in values.entries)
           'flutter.${entry.key}': entry.value,
       });

  final bool throwOnWrite;
  bool rejectWrites = true;
  int reads = 0;
  int writeAttempts = 0;

  @override
  Future<Map<String, Object>> getAll() async {
    reads++;
    return super.getAll();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${PrayerNotificationPreferences.storageKey}') {
      writeAttempts++;
      if (rejectWrites) {
        if (throwOnWrite) throw PlatformException(code: 'storage_failed');
        return false;
      }
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(LocalPrayerCalculator.initializeTimeZones);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  PrayerNotificationSetting setting(
    List<PrayerNotificationSetting> list,
    Prayer prayer,
    Phase phase,
  ) => list.singleWhere((s) => s.prayer == prayer && s.phase == phase);
  Data day(String date, {String fajr = '05:30'}) => Data(
    date: date,
    fajrStart: fajr,
    sunrise: '07:00',
    zuhrStart: '13:00',
    asrStart: '16:00',
    maghribStart: '19:00',
    ishaStart: '21:00',
  );

  test(
    'first run has exact Moatheni sounds, timings and six enabled prayers per phase',
    () async {
      final values = await PrayerNotificationPreferences.load();
      expect(values, hasLength(21));
      expect(values.where((s) => s.enabled), hasLength(18));
      expect(
        values
            .where((s) => s.prayer == Prayer.sunrise)
            .every((s) => !s.enabled),
        true,
      );
      expect(
        values.every((s) => NotificationSoundCatalog.contains(s.sound)),
        true,
      );
      expect(
        setting(values, Prayer.sunrise, Phase.before).sound,
        'moatheni_water',
      );
      expect(
        setting(values, Prayer.sunrise, Phase.adhan).sound,
        'moatheni_bird',
      );
      expect(
        setting(values, Prayer.sunrise, Phase.after).sound,
        'moatheni_short_sound',
      );
      expect(
        setting(values, Prayer.jumaa, Phase.after).sound,
        'moatheni_short_sound',
      );
      expect(setting(values, Prayer.jumaa, Phase.before).minutes, 120);
      expect(setting(values, Prayer.maghrib, Phase.before).minutes, 10);
      expect(setting(values, Prayer.maghrib, Phase.after).minutes, 3);
      expect(await PrayerNotificationPreferences.loadOverrides(), isEmpty);
    },
  );
  test(
    'legacy stock sounds and disabled global settings migrate to reference defaults',
    () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.SELECTED_NOTIFICATION_SOUND_KEY: 'azan_2',
        AppConstants.BEFORE_ADHAN_REMINDER_SOUND_KEY: 'noti_beep',
        AppConstants.AFTER_ADHAN_REMINDER_MINUTES_KEY: 5,
        AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY: false,
        AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY: false,
        'salat_waqt': jsonEncode([
          jsonEncode({'id': 2, 'isNotificationEnabled': false}),
        ]),
      });
      final values = await PrayerNotificationPreferences.load();
      expect(
        setting(values, Prayer.fajr, Phase.adhan).sound,
        'moatheni_on_prayer_fajr',
      );
      expect(setting(values, Prayer.dhuhr, Phase.adhan).enabled, true);
      expect(setting(values, Prayer.jumaa, Phase.adhan).enabled, true);
      expect(setting(values, Prayer.maghrib, Phase.after).minutes, 3);
      expect(
        values.every((s) => s.enabled == (s.prayer != Prayer.sunrise)),
        true,
      );
    },
  );
  test(
    'migration preserves selected personal and nonstock sounds plus explicit enabled legacy phases',
    () async {
      final personal = 'custom_${'a' * 64}';
      SharedPreferences.setMockInitialValues({
        AppConstants.SELECTED_NOTIFICATION_SOUND_KEY: personal,
        AppConstants.BEFORE_ADHAN_REMINDER_SOUND_KEY: 'moatheni_nakshabandi',
        AppConstants.AFTER_ADHAN_REMINDER_SOUND_KEY: 'silent',
        AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY: true,
        AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY: true,
        AppConstants.BEFORE_ADHAN_REMINDER_MINUTES_KEY: 17,
        'salat_waqt': jsonEncode([
          jsonEncode({'id': 1, 'isNotificationEnabled': false}),
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      // Use a verified catalogue key instead of depending on a transliteration.
      await prefs.setString(
        AppConstants.BEFORE_ADHAN_REMINDER_SOUND_KEY,
        'moatheni_water',
      );
      final values = await PrayerNotificationPreferences.load();
      expect(setting(values, Prayer.asr, Phase.adhan).sound, personal);
      expect(
        setting(values, Prayer.sunrise, Phase.adhan).sound,
        'moatheni_bird',
      );
      expect(setting(values, Prayer.sunrise, Phase.before).minutes, 5);
      expect(setting(values, Prayer.asr, Phase.before).sound, 'moatheni_water');
      expect(setting(values, Prayer.asr, Phase.before).minutes, 17);
      expect(setting(values, Prayer.asr, Phase.after).sound, 'silent');
      expect(setting(values, Prayer.asr, Phase.before).enabled, true);
      expect(setting(values, Prayer.fajr, Phase.before).enabled, false);
      await prefs.setBool(
        AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY,
        false,
      );
      expect(
        setting(
          await PrayerNotificationPreferences.load(),
          Prayer.asr,
          Phase.before,
        ).enabled,
        true,
      );
    },
  );
  test(
    'independent updates are serialized and changing Jumaa never changes Dhuhr',
    () async {
      await PrayerNotificationPreferences.load();
      await Future.wait([
        PrayerNotificationPreferences.setPrayerAdhanEnabled(
          Prayer.jumaa,
          false,
        ),
        PrayerNotificationPreferences.save(
          PrayerNotificationSetting.defaults(
            Prayer.asr,
            Phase.before,
          ).copyWith(enabled: true, sound: 'moatheni_bird', minutes: 0),
        ),
      ]);
      final values = await PrayerNotificationPreferences.load();
      expect(setting(values, Prayer.jumaa, Phase.adhan).enabled, false);
      expect(setting(values, Prayer.dhuhr, Phase.adhan).enabled, true);
      expect(setting(values, Prayer.asr, Phase.before).minutes, 0);
      expect(setting(values, Prayer.asr, Phase.before).sound, 'moatheni_bird');
    },
  );
  test(
    'atomic patches preserve cloud changes and simultaneous fields',
    () async {
      await PrayerNotificationPreferences.update(
        Prayer.asr,
        Phase.before,
        enabled: false,
      );
      await PrayerNotificationPreferences.replaceOverrides({
        'before': {
          'asr': {'enabled': false, 'sound': 'moatheni_water', 'minutes': 27},
        },
      });
      await Future.wait([
        PrayerNotificationPreferences.update(
          Prayer.asr,
          Phase.before,
          enabled: true,
        ),
        PrayerNotificationPreferences.update(
          Prayer.asr,
          Phase.before,
          minutes: 45,
        ),
      ]);
      final current = setting(
        await PrayerNotificationPreferences.load(),
        Prayer.asr,
        Phase.before,
      );
      expect(current.enabled, true);
      expect(current.sound, 'moatheni_water');
      expect(current.minutes, 45);
      await PrayerNotificationPreferences.update(
        Prayer.asr,
        Phase.before,
        enabled: false,
      );
      expect(
        setting(
          await PrayerNotificationPreferences.load(),
          Prayer.asr,
          Phase.before,
        ).enabled,
        false,
      );
    },
  );
  for (final selectedPhase in Phase.values) {
    test(
      '${selectedPhase.name} series OFF and ON retain other phases and individual sounds and delays',
      () async {
        final personal = 'custom_${'d' * 64}';
        final original = {
          for (final phase in Phase.values)
            phase.name: {
              for (final prayer in Prayer.values)
                prayer.name: PrayerNotificationSetting.defaults(prayer, phase)
                    .copyWith(
                      enabled: phase == selectedPhase || prayer.index.isEven,
                      sound: [
                        personal,
                        'silent',
                        'moatheni_water',
                      ][prayer.index % 3],
                      minutes: phase == Phase.adhan
                          ? 0
                          : 17 + phase.index * 10 + prayer.index,
                    )
                    .toJson(),
            },
        };
        await PrayerNotificationPreferences.replaceOverrides(original);

        await PrayerNotificationPreferences.setPhaseEnabled(
          selectedPhase,
          false,
        );
        final disabled = await PrayerNotificationPreferences.load();
        for (final previous in [
          for (final phase in Phase.values)
            for (final prayer in Prayer.values)
              PrayerNotificationSetting.fromJson(
                prayer,
                phase,
                original[phase.name]![prayer.name],
              ),
        ]) {
          expect(
            setting(disabled, previous.prayer, previous.phase).toJson(),
            previous
                .copyWith(
                  enabled: previous.phase == selectedPhase
                      ? false
                      : previous.enabled,
                )
                .toJson(),
            reason: '${previous.phase.name}/${previous.prayer.name}',
          );
        }
        // Read the durable document through a fresh preferences cache, so an
        // in-memory change alone cannot satisfy this assertion.
        final prefs = await SharedPreferences.getInstance();
        SharedPreferences.setMockInitialValues({
          PrayerNotificationPreferences.storageKey: prefs.getString(
            PrayerNotificationPreferences.storageKey,
          )!,
        });
        final reloaded = await PrayerNotificationPreferences.load();
        expect(
          reloaded.map((s) => s.toJson()).toList(),
          disabled.map((s) => s.toJson()).toList(),
        );

        await PrayerNotificationPreferences.setPhaseEnabled(
          selectedPhase,
          true,
        );
        final enabledAgain = await PrayerNotificationPreferences.load();
        for (final previous in disabled) {
          expect(
            setting(enabledAgain, previous.prayer, previous.phase).toJson(),
            previous
                .copyWith(
                  enabled: previous.phase == selectedPhase
                      ? previous.prayer != Prayer.sunrise
                      : previous.enabled,
                )
                .toJson(),
            reason: '${previous.phase.name}/${previous.prayer.name}',
          );
        }
      },
    );
  }
  test(
    'all disabled series survive cloud export and restore over enabled legacy defaults',
    () async {
      await PrayerNotificationPreferences.update(
        Prayer.jumaa,
        Phase.before,
        sound: 'moatheni_water',
        minutes: 37,
      );
      await PrayerNotificationPreferences.update(
        Prayer.sunrise,
        Phase.after,
        enabled: true,
        sound: 'silent',
        minutes: 11,
      );
      for (final phase in Phase.values) {
        await PrayerNotificationPreferences.setPhaseEnabled(phase, false);
      }
      final source = AppPreferenceDevice(
        await SharedPreferences.getInstance(),
        scope: 'disabled-series-source',
        reloadControllers: false,
      );
      final snapshot = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(await source.capture())),
      );
      expect(snapshot['reminders']['beforeEnabled'], false);
      expect(snapshot['reminders']['afterEnabled'], false);
      expect(
        (snapshot['prayerNotifications'] as Map).values,
        everyElement(false),
      );

      SharedPreferences.setMockInitialValues({
        AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY: true,
        AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY: true,
      });
      final destination = AppPreferenceDevice(
        await SharedPreferences.getInstance(),
        scope: 'disabled-series-destination',
        reloadControllers: false,
      );
      await destination.apply(snapshot);
      final restored = await PrayerNotificationPreferences.load();
      expect(restored, hasLength(21));
      expect(restored.every((s) => !s.enabled), true);
      expect(
        await PrayerNotificationPreferences.loadOverrides(),
        snapshot['prayerNotificationSettings'],
      );
      expect(setting(restored, Prayer.jumaa, Phase.before).minutes, 37);
      expect(
        setting(restored, Prayer.jumaa, Phase.before).sound,
        'moatheni_water',
      );
      expect(setting(restored, Prayer.sunrise, Phase.after).sound, 'silent');
      expect(setting(restored, Prayer.sunrise, Phase.after).minutes, 11);
      expect(
        (await destination.capture())['prayerNotificationSettings'],
        snapshot['prayerNotificationSettings'],
      );
    },
  );
  for (final throwOnWrite in [false, true]) {
    test(
      'rejected series write (throws=$throwOnWrite) restores cached state without a change event',
      () async {
        final original = {
          for (final phase in Phase.values)
            phase.name: {
              for (final prayer in Prayer.values)
                prayer.name: PrayerNotificationSetting.defaults(
                  prayer,
                  phase,
                ).copyWith(enabled: true).toJson(),
            },
        };
        final values = <String, Object>{
          PrayerNotificationPreferences.storageKey: jsonEncode(original),
          'unrelated_preference': 'preserved',
        };
        SharedPreferences.setMockInitialValues(values);
        final previousStore = SharedPreferencesStorePlatform.instance;
        final store = _RejectingPrayerStore(values, throwOnWrite: throwOnWrite);
        SharedPreferencesStorePlatform.instance = store;
        addTearDown(
          () => SharedPreferencesStorePlatform.instance = previousStore,
        );
        final prefs = await SharedPreferences.getInstance();
        final originalNative = Map<String, Object>.from(await store.getAll());
        final readsBeforeWrite = store.reads;
        var changes = 0;
        final subscription = PrayerNotificationPreferences.changes.listen(
          (_) => changes++,
        );
        addTearDown(subscription.cancel);

        await expectLater(
          PrayerNotificationPreferences.setPhaseEnabled(Phase.after, false),
          throwOnWrite ? throwsA(isA<PlatformException>()) : throwsStateError,
        );
        await Future<void>.delayed(Duration.zero);
        expect(changes, 0);
        expect(store.writeAttempts, 1);
        expect(store.reads, greaterThan(readsBeforeWrite));
        expect(
          prefs.getString(PrayerNotificationPreferences.storageKey),
          values[PrayerNotificationPreferences.storageKey],
        );
        expect(await store.getAll(), originalNative);
        expect(await PrayerNotificationPreferences.loadOverrides(), original);
        expect(
          (await PrayerNotificationPreferences.load()).every((s) => s.enabled),
          true,
        );
        expect(changes, 0);

        store.rejectWrites = false;
        await PrayerNotificationPreferences.setPhaseEnabled(Phase.after, false);
        await Future<void>.delayed(Duration.zero);
        expect(changes, 1);
        expect(
          (await PrayerNotificationPreferences.load())
              .where((s) => s.phase == Phase.after)
              .every((s) => !s.enabled),
          true,
        );
        expect(prefs.getString('unrelated_preference'), 'preserved');
      },
    );
  }
  test(
    'invalid input is bounded, empty overrides reset explicitly without remigrating',
    () async {
      await PrayerNotificationPreferences.replaceOverrides({
        'before': {
          'jumaa': {
            'enabled': true,
            'minutes': 999,
            'sound': 'content://private/file',
          },
        },
        'foreign': {'token': 'secret'},
      });
      var values = await PrayerNotificationPreferences.load();
      expect(setting(values, Prayer.jumaa, Phase.before).minutes, 120);
      expect(
        setting(values, Prayer.jumaa, Phase.before).sound,
        'moatheni_before_prayer_jumaa',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY, true);
      await PrayerNotificationPreferences.replaceOverrides({});
      values = await PrayerNotificationPreferences.load();
      expect(
        values.every((s) => s.enabled == (s.prayer != Prayer.sunrise)),
        true,
      );
      expect(prefs.getString(PrayerNotificationPreferences.storageKey), '{}');
    },
  );
  test(
    'read subscriptions receive migration once and successful writes only',
    () async {
      var changes = 0;
      final subscription = PrayerNotificationPreferences.changes.listen(
        (_) => changes++,
      );
      addTearDown(subscription.cancel);
      await PrayerNotificationPreferences.load();
      await PrayerNotificationPreferences.load();
      await Future<void>.delayed(Duration.zero);
      expect(changes, 1);
      await PrayerNotificationPreferences.setPrayerAdhanEnabled(
        Prayer.fajr,
        false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(changes, 2);
    },
  );
  test(
    'Friday uses Jumaa only and independent reminder still fires with its adhan disabled',
    () async {
      for (final phase in Phase.values) {
        await PrayerNotificationPreferences.setPhaseEnabled(phase, false);
      }
      await PrayerNotificationPreferences.save(
        PrayerNotificationSetting.defaults(
          Prayer.jumaa,
          Phase.before,
        ).copyWith(enabled: true),
      );
      await PrayerNotificationPreferences.save(
        PrayerNotificationSetting.defaults(
          Prayer.dhuhr,
          Phase.after,
        ).copyWith(enabled: true, minutes: 13),
      );
      final zone = tz.getLocation('UTC');
      final prayers = [
        for (final date in ['2026-09-11', '2026-09-12'])
          ...PrayerOccurrence.fromDay(day(date), zone, {'zuhr': 2}),
      ];
      final plan = buildPrayerAlarmPlan(
        prayers: prayers,
        now: DateTime.utc(2026, 9, 10),
        settings: await PrayerNotificationPreferences.load(),
      );
      expect(plan, hasLength(2));
      expect(plan.first.prayer.notificationPrayer, Prayer.jumaa);
      expect(plan.first.time, tz.TZDateTime(zone, 2026, 9, 11, 11, 2));
      expect(plan.last.prayer.notificationPrayer, Prayer.dhuhr);
      expect(plan.last.time, tz.TZDateTime(zone, 2026, 9, 12, 13, 15));
      expect(plan.every((p) => p.prayer.prayerId == 2), true);
    },
  );
  test(
    'sunrise stays outside five-prayer consumers and owns stable independent phase IDs',
    () async {
      for (final phase in Phase.values) {
        await PrayerNotificationPreferences.setPhaseEnabled(phase, false);
      }
      for (final phase in Phase.values) {
        await PrayerNotificationPreferences.save(
          PrayerNotificationSetting.defaults(
            Prayer.sunrise,
            phase,
          ).copyWith(enabled: true),
        );
      }
      final zone = tz.getLocation('UTC');
      expect(
        PrayerOccurrence.fromDay(day('2026-09-12'), zone, {}),
        hasLength(5),
      );
      final prayers = PrayerOccurrence.fromDay(day('2026-09-12'), zone, {
        'sunrise': 4,
      }, includeSunrise: true);
      final plan = buildPrayerAlarmPlan(
        prayers: [...prayers, ...prayers],
        now: DateTime.utc(2026, 9, 11),
        settings: await PrayerNotificationPreferences.load(),
      );
      expect(plan, hasLength(3));
      expect(plan.map((p) => p.id).toSet(), hasLength(3));
      expect(plan.every((p) => p.prayer.prayerId == 6), true);
      expect(plan[1].time, tz.TZDateTime(zone, 2026, 9, 12, 7, 4));
      expect(plan[1].toJson()['prayer'], 'sunrise');
      expect(
        buildPrayerAlarmPlan(
          prayers: prayers,
          now: DateTime.utc(2026, 9, 11),
          settings: await PrayerNotificationPreferences.load(),
          skippedPrayers: {'2026-09-12:6'},
        ),
        isEmpty,
      );
    },
  );
  test(
    'before reminder crossing midnight belongs to next prayer date, skip and ID remain stable',
    () async {
      for (final phase in Phase.values) {
        await PrayerNotificationPreferences.setPhaseEnabled(phase, false);
      }
      await PrayerNotificationPreferences.save(
        PrayerNotificationSetting.defaults(
          Prayer.fajr,
          Phase.before,
        ).copyWith(enabled: true, minutes: 120),
      );
      final zone = tz.getLocation('Europe/Paris');
      final prayers = PrayerOccurrence.fromDay(
        day('2026-03-29', fajr: '00:30'),
        zone,
        {},
        includeSunrise: true,
      );
      final plan = buildPrayerAlarmPlan(
        prayers: prayers,
        now: DateTime.utc(2026, 3, 27),
        settings: await PrayerNotificationPreferences.load(),
      );
      expect(plan.single.time, tz.TZDateTime(zone, 2026, 3, 28, 22, 30));
      expect(plan.single.prayer.key, '2026-03-29:1');
      final beforeId = plan.single.id;
      await PrayerNotificationPreferences.save(
        plan.single.setting!.copyWith(minutes: 60, sound: 'moatheni_water'),
      );
      final changed = buildPrayerAlarmPlan(
        prayers: prayers,
        now: DateTime.utc(2026, 3, 27),
        settings: await PrayerNotificationPreferences.load(),
      );
      expect(changed.single.id, beforeId);
      expect(changed.single.time.hour, 23);
      expect(changed.single.toJson()['sound'], 'moatheni_water');
    },
  );
  test(
    'offline stored base times reconcile sound and delay and do not duplicate fresh days',
    () async {
      final zone = tz.getLocation('UTC');
      final prayer = PrayerOccurrence.fromDay(
        day('2026-09-12'),
        zone,
        {},
      ).first;
      final alarm = PlannedPrayerAlarm(
        prayer,
        PrayerAlarmKind.before,
        prayer.time.subtract(const Duration(minutes: 5)),
      );
      final cached = restoreUncoveredPrayerOccurrences(
        alarms: [alarm.toJson(), alarm.toJson()],
        coveredDates: {},
        zone: zone,
      );
      expect(cached, hasLength(1));
      for (final phase in Phase.values) {
        await PrayerNotificationPreferences.setPhaseEnabled(phase, false);
      }
      await PrayerNotificationPreferences.save(
        PrayerNotificationSetting.defaults(
          Prayer.fajr,
          Phase.before,
        ).copyWith(enabled: true, minutes: 35, sound: 'moatheni_water'),
      );
      final plan = buildPrayerAlarmPlan(
        prayers: cached,
        now: DateTime.utc(2026, 9, 11),
        settings: await PrayerNotificationPreferences.load(),
      );
      expect(
        plan.single.time,
        prayer.time.subtract(const Duration(minutes: 35)),
      );
      expect(plan.single.setting!.sound, 'moatheni_water');
      expect(
        restoreUncoveredPrayerOccurrences(
          alarms: [alarm.toJson()],
          coveredDates: {'2026-09-12'},
          zone: zone,
        ),
        isEmpty,
      );
      expect(
        restoreUncoveredPrayerOccurrences(
          alarms: [
            {...alarm.toJson(), 'id': 8},
          ],
          coveredDates: {},
          zone: zone,
        ),
        isEmpty,
      );
    },
  );
}
