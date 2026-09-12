import 'dart:async';
import 'dart:convert';
import 'package:zabi/helper/notification_sound_catalog.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:zabi/helper/additional_reminder_plan.dart';
import 'package:zabi/helper/local_prayer_calculator.dart';
import 'package:zabi/helper/prayer_alarm_plan.dart';

class _DelayedReminderPreferences implements SharedPreferences {
  final entered = Completer<void>();
  final release = Completer<void>();
  bool succeeds = true;
  String? written;

  @override
  Future<bool> setString(String key, String value) async {
    entered.complete();
    await release.future;
    if (succeeds) written = value;
    return succeeds;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(LocalPrayerCalculator.initializeTimeZones);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Data day(String date, {String dawn = '06:00', String sunset = '18:00'}) =>
      Data(
        date: date,
        fajrStart: dawn,
        sunrise: '07:10',
        zuhrStart: '13:00',
        asrStart: '16:00',
        maghribStart: sunset,
        ishaStart: '20:00',
      );
  AdditionalReminderSetting enabled(
    AdditionalReminderType type, {
    int? minutes,
  }) => AdditionalReminderSetting.defaults(
    type,
  ).copyWith(enabled: true, minutes: minutes);
  List<PlannedAdditionalReminder> plan(
    List<Data> days,
    List<AdditionalReminderSetting> settings, {
    String zone = 'UTC',
    DateTime? now,
    Map<String, int> offsets = const {},
    int hijri = 0,
  }) => buildAdditionalReminderPlan(
    days: days,
    zone: tz.getLocation(zone),
    now: now ?? tz.TZDateTime(tz.getLocation('UTC'), 2026, 1, 1),
    settings: settings,
    adjustments: offsets,
    hijriAdjustment: hijri,
  );

  test(
    'all reminders remain disabled on first run or corrupt preferences',
    () async {
      expect(
        (await AdditionalReminderPreferences.load()).every((s) => !s.enabled),
        isTrue,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AdditionalReminderPreferences.storageKey, 'broken');
      expect(
        (await AdditionalReminderPreferences.load()).every((s) => !s.enabled),
        isTrue,
      );
      expect(
        plan([day('2026-09-12')], await AdditionalReminderPreferences.load()),
        isEmpty,
      );
    },
  );

  test(
    'each reminder preserves its own custom sound and clock after restart',
    () async {
      final settings = await AdditionalReminderPreferences.load();
      final key = 'custom_${List.filled(64, 'b').join()}';
      settings[0] = settings[0].copyWith(
        enabled: true,
        sound: key,
        minutes: 30,
      );
      settings[5] = settings[5].copyWith(
        enabled: true,
        sound: 'silent',
        minutes: 19 * 60 + 5,
      );
      await AdditionalReminderPreferences.save(settings);
      final reloaded = await AdditionalReminderPreferences.load();
      expect(reloaded[0].sound, key);
      expect(reloaded[0].minutes, 30);
      expect(reloaded[5].sound, 'silent');
      expect(reloaded[5].minutes, 1145);
      expect(reloaded[1].enabled, isFalse);
    },
  );

  test(
    'every bundled sound survives saving and reloading extra reminders',
    () async {
      for (final key in NotificationSoundCatalog.keys) {
        final preferences = [
          AdditionalReminderSetting.defaults(
            AdditionalReminderType.duha,
          ).copyWith(sound: key, enabled: true),
        ];
        await AdditionalReminderPreferences.save(preferences);
        final actual = await AdditionalReminderPreferences.load();
        expect(actual.first.sound, key);
        expect(actual.first.enabled, true);
      }
    },
  );

  test('invalid stored offsets and sounds are bounded safely', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AdditionalReminderPreferences.storageKey,
      jsonEncode({
        'duha': {'enabled': true, 'minutes': -30, 'sound': '../../file'},
        'friday': {'minutes': 999},
        'whiteDays': {'minutes': 9999},
      }),
    );
    final settings = await AdditionalReminderPreferences.load();
    expect(settings[0].minutes, 0);
    expect(settings[0].sound, 'moatheni_duha');
    expect(settings[2].minutes, 120);
    expect(settings[6].minutes, 1439);
  });

  test('Duha includes the sunrise correction and cannot overlap Dhuhr', () {
    final result = plan(
      [day('2026-09-12')],
      [
        enabled(
          AdditionalReminderType.duha,
          minutes: 20,
        ).copyWith(anchor: 'afterSunrise'),
      ],
      offsets: {'sunrise': 7},
    );
    expect(
      result.single.time,
      tz.TZDateTime(tz.getLocation('UTC'), 2026, 9, 12, 7, 37),
    );
    final lateSunrise = day('2026-09-12')..sunrise = '12:55';
    expect(
      plan([lateSunrise], [enabled(AdditionalReminderType.duha)]),
      isEmpty,
    );
  });

  test('last third uses previous sunset and this dawn across midnight', () {
    final result = plan(
      [day('2026-09-11'), day('2026-09-12')],
      [enabled(AdditionalReminderType.lastThird)],
    );
    expect(result.single.date, '2026-09-12');
    expect(
      result.single.time,
      tz.TZDateTime(tz.getLocation('UTC'), 2026, 9, 12, 1, 45),
    );
    expect(
      plan([day('2026-09-12')], [enabled(AdditionalReminderType.lastThird)]),
      isEmpty,
    );
  });

  test('last third uses real night duration through a DST transition', () {
    final zone = tz.getLocation('Europe/Paris');
    final result = plan(
      [day('2026-03-28'), day('2026-03-29')],
      [enabled(AdditionalReminderType.lastThird)],
      zone: zone.name,
    );
    final sunset = tz.TZDateTime(zone, 2026, 3, 28, 18);
    final dawn = tz.TZDateTime(zone, 2026, 3, 29, 6);
    expect(dawn.difference(sunset), const Duration(hours: 11));
    expect(
      result.single.time,
      sunset.add(const Duration(hours: 7, minutes: 5)),
    );
  });

  test(
    'Friday and adhkar follow adjusted local prayers and ignore elapsed times',
    () {
      final result = plan(
        [day('2026-09-11'), day('2026-09-12')],
        [
          enabled(
            AdditionalReminderType.friday,
            minutes: 60,
          ).copyWith(anchor: 'beforeDhuhr'),
          enabled(AdditionalReminderType.morning),
          enabled(AdditionalReminderType.evening),
        ],
        now: tz.TZDateTime(tz.getLocation('UTC'), 2026, 9, 11, 10),
        offsets: {'zuhr': 5, 'asr': 7},
      );
      expect(
        result
            .where((r) => r.setting.type == AdditionalReminderType.friday)
            .single
            .time,
        tz.TZDateTime(tz.getLocation('UTC'), 2026, 9, 11, 12, 5),
      );
      expect(
        result.where((r) => r.setting.type == AdditionalReminderType.morning),
        hasLength(1),
      );
      expect(
        result
            .where((r) => r.setting.type == AdditionalReminderType.evening)
            .first
            .time,
        tz.TZDateTime(tz.getLocation('UTC'), 2026, 9, 11, 16, 37),
      );
    },
  );

  test(
    'Monday and Thursday reminders belong to previous civil evening, including DST',
    () {
      final zone = tz.getLocation('Europe/Paris');
      final result = plan(
        [day('2026-03-30'), day('2026-03-31'), day('2026-04-02')],
        [enabled(AdditionalReminderType.mondayThursday, minutes: 20 * 60 + 30)],
        zone: zone.name,
      );
      expect(result, hasLength(2));
      expect(result.first.date, '2026-03-30');
      expect(result.first.time, tz.TZDateTime(zone, 2026, 3, 29, 20, 30));
      expect(result.last.time, tz.TZDateTime(zone, 2026, 4, 1, 20, 30));
    },
  );

  test('white days respect Hijri correction and omit Eid and Tashriq days', () {
    final days = [
      for (var d = 0; d < 365; d++)
        day(
          tz.TZDateTime(
            tz.getLocation('UTC'),
            2026,
            1,
            1 + d,
          ).toIso8601String().split('T').first,
        ),
    ];
    for (final correction in [-2, 0, 2]) {
      final result = plan(
        days,
        [
          enabled(AdditionalReminderType.whiteDays),
        ].map((s) => s.copyWith(anchor: 'clock', minutes: 1200)).toList(),
        hijri: correction,
      );
      expect(result.length, greaterThan(30));
      for (final reminder in result) {
        final civil = DateTime.parse(reminder.date);
        final hijri = HijriCalendar.fromDate(
          DateTime(civil.year, civil.month, civil.day + correction),
        );
        expect(hijri.hDay, inInclusiveRange(13, 15));
        expect(hijri.hMonth == 12 && hijri.hDay == 13, isFalse);
        expect(
          reminder.time.day,
          DateTime(civil.year, civil.month, civil.day - 1).day,
        );
      }
    }
  });

  test(
    'reference offers exactly eleven independent cards and verified defaults',
    () {
      expect(AdditionalReminderPreferences.visibleTypes, [
        AdditionalReminderType.fajrAlarm,
        AdditionalReminderType.duha,
        AdditionalReminderType.morning,
        AdditionalReminderType.evening,
        AdditionalReminderType.bedtime,
        AdditionalReminderType.monday,
        AdditionalReminderType.thursday,
        AdditionalReminderType.whiteDays,
        AdditionalReminderType.middleNight,
        AdditionalReminderType.lastThird,
        AdditionalReminderType.friday,
      ]);
      final minutes = [20, 30, 30, 30, 60, 60, 60, 60, 15, 15, 40];
      final sounds = [
        'ring1',
        'duha',
        'morning_azkar1',
        'evening_azkar1',
        'sleep_azkar',
        'monday_fasting',
        'thursday_fasting',
        'white_days',
        'midnight',
        'last_third',
        'jumaa_hour',
      ];
      for (var i = 0; i < 11; i++) {
        final setting = AdditionalReminderSetting.defaults(
          AdditionalReminderPreferences.visibleTypes[i],
        );
        expect(setting.enabled, false);
        expect(setting.minutes, minutes[i]);
        expect(setting.sound, 'moatheni_${sounds[i]}');
        expect(NotificationSoundCatalog.contains(setting.sound), true);
      }
    },
  );
  test(
    'generic stock migrates once while explicit sounds and unusual timings survive',
    () async {
      final raw = {
        'duha': {'enabled': true, 'minutes': 20, 'sound': 'noti_beep'},
        'friday': {'enabled': true, 'minutes': 17, 'sound': 'silent'},
        'morning': {
          'enabled': true,
          'minutes': 42,
          'sound': 'moatheni_morning_azkar2',
        },
        'mondayThursday': {
          'enabled': true,
          'minutes': 1200,
          'sound': 'noti_beep',
        },
      };
      final migrated = AdditionalReminderPreferences.decode(raw);
      AdditionalReminderSetting get(AdditionalReminderType t) =>
          migrated.singleWhere((s) => s.type == t);
      expect(get(AdditionalReminderType.duha).sound, 'moatheni_duha');
      expect(get(AdditionalReminderType.duha).effectiveAnchor, 'beforeDhuhr');
      expect(get(AdditionalReminderType.duha).minutes, 30);
      expect(get(AdditionalReminderType.friday).sound, 'silent');
      expect(get(AdditionalReminderType.friday).minutes, 17);
      expect(get(AdditionalReminderType.friday).effectiveAnchor, 'beforeDhuhr');
      expect(
        get(AdditionalReminderType.morning).sound,
        'moatheni_morning_azkar2',
      );
      expect(get(AdditionalReminderType.morning).minutes, 42);
      expect(get(AdditionalReminderType.mondayThursday).enabled, false);
      expect(get(AdditionalReminderType.monday).enabled, true);
      expect(get(AdditionalReminderType.thursday).enabled, true);
      expect(
        get(AdditionalReminderType.monday).sound,
        'moatheni_monday_fasting',
      );
      expect(
        get(AdditionalReminderType.thursday).sound,
        'moatheni_thursday_fasting',
      );
      expect(get(AdditionalReminderType.monday).effectiveAnchor, 'afterIsha');
      expect(raw.containsKey('monday'), false);
      await AdditionalReminderPreferences.save(migrated);
      final again = await AdditionalReminderPreferences.load();
      expect(
        again.map((s) => s.toJson()).toList(),
        migrated.map((s) => s.toJson()).toList(),
      );
    },
  );
  test(
    'old fasting clock and imported sound split without changing the actual events or IDs',
    () {
      final original = AdditionalReminderSetting(
        type: AdditionalReminderType.mondayThursday,
        enabled: true,
        minutes: 1187,
        sound: 'custom_${'a' * 64}',
      );
      final migrated = AdditionalReminderPreferences.decode({
        'mondayThursday': {
          'enabled': true,
          'minutes': 1187,
          'sound': original.sound,
        },
      });
      final days = [
        day('2026-09-13'),
        day('2026-09-14'),
        day('2026-09-16'),
        day('2026-09-17'),
      ];
      final oldPlan = plan(days, [original]);
      final newPlan = plan(days, migrated);
      expect(
        newPlan.map((e) => e.id).toList(),
        oldPlan.map((e) => e.id).toList(),
      );
      expect(
        newPlan.map((e) => e.time).toList(),
        oldPlan.map((e) => e.time).toList(),
      );
      expect(newPlan.map((e) => e.setting.sound).toSet(), {original.sound});
      expect(newPlan.map((e) => e.setting.type).toSet(), {
        AdditionalReminderType.monday,
        AdditionalReminderType.thursday,
      });
    },
  );
  test(
    'Fajr before/after and sleep reminders use adjusted times across civil midnight',
    () {
      final d = day('2026-09-12', dawn: '00:10')..ishaStart = '23:50';
      final before = plan(
        [d],
        [enabled(AdditionalReminderType.fajrAlarm, minutes: 30)],
        offsets: {'fajr': 5},
      );
      expect(before.single.time, tz.TZDateTime(tz.UTC, 2026, 9, 11, 23, 45));
      final after = plan(
        [d],
        [
          enabled(
            AdditionalReminderType.fajrAlarm,
            minutes: 30,
          ).copyWith(anchor: 'afterFajr'),
        ],
        offsets: {'fajr': 5},
      );
      expect(after.single.time, tz.TZDateTime(tz.UTC, 2026, 9, 12, 0, 45));
      final sleep = plan(
        [d],
        [enabled(AdditionalReminderType.bedtime)],
        offsets: {'isha': 10},
      );
      expect(sleep.single.time, tz.TZDateTime(tz.UTC, 2026, 9, 13, 1));
      expect(sleep.single.date, '2026-09-12');
    },
  );
  test(
    'midnight and last third subtract independent configured offsets across DST',
    () {
      final zone = tz.getLocation('Europe/Paris');
      final results = plan(
        [day('2026-03-28'), day('2026-03-29')],
        [
          enabled(AdditionalReminderType.middleNight, minutes: 15),
          enabled(AdditionalReminderType.lastThird, minutes: 30),
        ],
        zone: zone.name,
      );
      final sunset = tz.TZDateTime(zone, 2026, 3, 28, 18);
      expect(
        results.first.time,
        sunset.add(const Duration(hours: 5, minutes: 15)),
      );
      expect(
        results.last.time,
        sunset.add(const Duration(hours: 6, minutes: 50)),
      );
      expect(
        plan(
          [day('2026-03-29')],
          [enabled(AdditionalReminderType.middleNight)],
        ),
        isEmpty,
      );
    },
  );
  test(
    'default Duha, evening alternate and Friday follow the correct reference prayer',
    () {
      final result = plan(
        [day('2026-09-11')],
        [
          enabled(AdditionalReminderType.duha),
          enabled(
            AdditionalReminderType.evening,
          ).copyWith(anchor: 'beforeMaghrib'),
          enabled(AdditionalReminderType.friday),
        ],
        offsets: {'zuhr': 5, 'maghrib': 10},
      );
      expect(
        result
            .singleWhere((e) => e.setting.type == AdditionalReminderType.duha)
            .time,
        tz.TZDateTime(tz.UTC, 2026, 9, 11, 12, 35),
      );
      expect(
        result
            .singleWhere(
              (e) => e.setting.type == AdditionalReminderType.evening,
            )
            .time,
        tz.TZDateTime(tz.UTC, 2026, 9, 11, 17, 40),
      );
      expect(
        result
            .singleWhere((e) => e.setting.type == AdditionalReminderType.friday)
            .time,
        tz.TZDateTime(tz.UTC, 2026, 9, 11, 17, 30),
      );
    },
  );
  test(
    'Monday and Thursday have independent sounds and follow the previous Isha',
    () {
      final result = plan(
        [
          day('2026-09-13'),
          day('2026-09-14'),
          day('2026-09-16'),
          day('2026-09-17'),
        ],
        [
          enabled(AdditionalReminderType.monday),
          enabled(AdditionalReminderType.thursday, minutes: 30),
        ],
        offsets: {'isha': 7},
      );
      expect(result.map((e) => e.setting.sound).toList(), [
        'moatheni_monday_fasting',
        'moatheni_thursday_fasting',
      ]);
      expect(result.first.time, tz.TZDateTime(tz.UTC, 2026, 9, 13, 21, 7));
      expect(result.last.time, tz.TZDateTime(tz.UTC, 2026, 9, 16, 20, 37));
    },
  );
  test(
    'white-day reference mode emits only one eve-of-13 reminder per Hijri month',
    () {
      final days = [
        for (var i = 0; i < 365; i++)
          day(DateTime.utc(2026, 1, 1 + i).toIso8601String().split('T').first),
      ];
      for (final correction in [-2, 0, 2]) {
        final result = plan(days, [
          enabled(AdditionalReminderType.whiteDays),
        ], hijri: correction);
        expect(result.length, inInclusiveRange(10, 13));
        for (final event in result) {
          final d = DateTime.parse(event.date);
          final hijri = HijriCalendar.fromDate(
            DateTime(d.year, d.month, d.day + correction),
          );
          expect(hijri.hDay, 13);
          expect(hijri.hMonth, isNot(12));
          expect(event.time.hour, 21);
        }
      }
    },
  );
  test(
    'new alarm bank cannot collide with old stride at day and year boundaries',
    () {
      for (final date in ['2026-12-31', '2027-01-01']) {
        final dayNumber =
            DateTime.parse(date).toUtc().millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay;
        for (var i = 0; i < 7; i++) {
          final e = PlannedAdditionalReminder(
            enabled(AdditionalReminderType.values[i]),
            date,
            tz.TZDateTime(tz.UTC, 2026, 12, 31),
          );
          expect(e.id, 20000000 + dayNumber * 10 + i);
        }
      }
      final result = plan(
        [day('2026-12-30'), day('2026-12-31'), day('2027-01-01')],
        [
          for (final type in AdditionalReminderPreferences.visibleTypes)
            enabled(type),
        ],
      );
      expect(result.map((e) => e.id).toSet().length, result.length);
      expect(
        result
            .where(
              (e) => [
                AdditionalReminderType.fajrAlarm,
                AdditionalReminderType.bedtime,
                AdditionalReminderType.middleNight,
              ].contains(e.setting.type),
            )
            .every((e) => e.id >= 21000000),
        true,
      );
    },
  );

  test(
    'simultaneous patches preserve unrelated fields and the final toggle',
    () async {
      await Future.wait([
        AdditionalReminderPreferences.update(
          AdditionalReminderType.fajrAlarm,
          enabled: true,
        ),
        AdditionalReminderPreferences.update(
          AdditionalReminderType.fajrAlarm,
          sound: 'moatheni_water',
        ),
        AdditionalReminderPreferences.update(
          AdditionalReminderType.morning,
          enabled: true,
          minutes: 75,
        ),
        AdditionalReminderPreferences.update(
          AdditionalReminderType.fajrAlarm,
          minutes: 47,
          anchor: 'afterFajr',
        ),
        AdditionalReminderPreferences.update(
          AdditionalReminderType.fajrAlarm,
          enabled: false,
        ),
      ]);
      final settings = await AdditionalReminderPreferences.load();
      final fajr = settings.singleWhere(
        (s) => s.type == AdditionalReminderType.fajrAlarm,
      );
      expect(fajr.enabled, false);
      expect(fajr.sound, 'moatheni_water');
      expect(fajr.useDefaultSound, false);
      expect(fajr.minutes, 47);
      expect(fajr.anchor, 'afterFajr');
      final morning = settings.singleWhere(
        (s) => s.type == AdditionalReminderType.morning,
      );
      expect(morning.enabled, true);
      expect(morning.minutes, 75);
    },
  );

  test(
    'queued cloud replacement precedes later patches and returns fresh validated setting',
    () async {
      final cloud = AdditionalReminderPreferences.decode({
        'fajrAlarm': {
          'enabled': false,
          'sound': 'moatheni_bird',
          'minutes': 27,
          'anchor': 'afterFajr',
          'useDefaultSound': false,
        },
        'morning': {
          'enabled': true,
          'sound': 'silent',
          'minutes': 54,
          'anchor': 'afterFajr',
        },
      });
      final replacement = AdditionalReminderPreferences.save(cloud);
      final enabled = AdditionalReminderPreferences.update(
        AdditionalReminderType.fajrAlarm,
        enabled: true,
      );
      final bounded = AdditionalReminderPreferences.update(
        AdditionalReminderType.fajrAlarm,
        minutes: 999,
      );
      await replacement;
      final first = await enabled;
      final latest = await bounded;
      expect(first.sound, 'moatheni_bird');
      expect(first.minutes, 27);
      expect(latest.enabled, true);
      expect(latest.sound, 'moatheni_bird');
      expect(latest.minutes, 120);
      expect(latest.anchor, 'afterFajr');
      final morning = (await AdditionalReminderPreferences.load()).singleWhere(
        (s) => s.type == AdditionalReminderType.morning,
      );
      expect(morning.enabled, true);
      expect(morning.sound, 'silent');
      expect(morning.minutes, 54);
    },
  );

  test(
    'a read waits for previously queued edits and preserves named defaults',
    () async {
      final edit = AdditionalReminderPreferences.update(
        AdditionalReminderType.evening,
        enabled: true,
        sound: 'moatheni_evening_azkar2',
        minutes: 32,
      );
      final reading = AdditionalReminderPreferences.load();
      final rows = await reading;
      final actual = rows.singleWhere(
        (s) => s.type == AdditionalReminderType.evening,
      );
      expect(actual.enabled, true);
      expect(actual.minutes, 32);
      expect(actual.sound, 'moatheni_evening_azkar2');
      await edit;
      final resetSound = await AdditionalReminderPreferences.update(
        AdditionalReminderType.evening,
        sound: AdditionalReminderSetting.defaults(
          AdditionalReminderType.evening,
        ).sound,
        useDefaultSound: true,
      );
      expect(resetSound.useDefaultSound, true);
      expect(resetSound.enabled, true);
      expect(resetSound.minutes, 32);
    },
  );

  test(
    'failed writes release the queue and only successful writes notify listeners',
    () async {
      final delayed = _DelayedReminderPreferences()..succeeds = false;
      var events = 0;
      final subscription = AdditionalReminderPreferences.changes.listen(
        (_) => events++,
      );
      addTearDown(subscription.cancel);
      final failing = AdditionalReminderPreferences.save([], delayed);
      final rejected = expectLater(failing, throwsStateError);
      await delayed.entered.future;
      var completed = false;
      final next =
          AdditionalReminderPreferences.update(
            AdditionalReminderType.duha,
            enabled: true,
          ).then((value) {
            completed = true;
            return value;
          });
      await Future<void>.delayed(Duration.zero);
      expect(completed, false);
      expect(events, 0);
      delayed.release.complete();
      await rejected;
      expect((await next).enabled, true);
      await Future<void>.delayed(Duration.zero);
      expect(events, 1);
      expect((await AdditionalReminderPreferences.load()).first.enabled, true);
    },
  );

  test(
    'replacement snapshots are captured before waiting and readers wait for completion',
    () async {
      final delayed = _DelayedReminderPreferences();
      final requested = [
        AdditionalReminderSetting.defaults(
          AdditionalReminderType.morning,
        ).copyWith(minutes: 53),
      ];
      final saving = AdditionalReminderPreferences.save(requested, delayed);
      await delayed.entered.future;
      requested.clear();
      var readCompleted = false;
      final reading = AdditionalReminderPreferences.load().then((rows) {
        readCompleted = true;
        return rows;
      });
      await Future<void>.delayed(Duration.zero);
      expect(readCompleted, false);
      delayed.release.complete();
      await saving;
      await reading;
      expect(jsonDecode(delayed.written!)['morning']['minutes'], 53);
    },
  );

  test(
    'stable IDs are disjoint from prayer alarms and shared budgets retain nearest times',
    () {
      final zone = tz.getLocation('UTC');
      final days = [
        for (var d = 1; d <= 30; d++)
          day('2026-09-${d.toString().padLeft(2, '0')}'),
      ];
      final extras = plan(days, [
        for (final type in AdditionalReminderType.values) enabled(type),
      ]);
      final prayers = buildPrayerAlarmPlan(
        prayers: [
          for (final day in days) ...PrayerOccurrence.fromDay(day, zone, {}),
        ],
        now: tz.TZDateTime(tz.getLocation('UTC'), 2026, 9, 1),
        enabledPrayerIds: {1, 2, 3, 4, 5},
        beforeMinutes: 10,
        afterMinutes: 10,
      );
      expect(
        extras
            .map((r) => r.id)
            .toSet()
            .intersection(prayers.map((p) => p.id).toSet()),
        isEmpty,
      );
      final candidates = [
        for (final p in prayers) (id: p.id, time: p.time),
        for (final r in extras) (id: r.id, time: r.time),
      ]..sort((a, b) => a.time.compareTo(b.time));
      for (final limit in [0, 57, 447]) {
        final ids = selectReminderAlarmIds(
          candidates: [...candidates, candidates.first],
          limit: limit,
        );
        expect(ids.length, limit);
        expect(ids, candidates.take(limit).map((r) => r.id).toSet());
      }
    },
  );
}
