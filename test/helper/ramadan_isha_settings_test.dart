import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/helper/islamic_calendar.dart';
import 'package:salatime/helper/local_prayer_calculator.dart';
import 'package:salatime/helper/prayer_alarm_plan.dart';
import 'package:salatime/helper/prayer_display_phase.dart';
import 'package:salatime/helper/prayer_share_data.dart';
import 'package:salatime/helper/ramadan_isha_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(LocalPrayerCalculator.initializeTimeZones);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const request = <String, dynamic>{
    'type': 'automatic',
    'date': '2026-02-25',
    'lat': '33.5731',
    'lng': '-7.5898',
    'prayer_method': '21',
    'school': 'STANDARD',
    'timezone': 'Africa/Casablanca',
  };

  String dateText(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  DateTime nightBefore(DateTime day, int offset) =>
      DateTime(day.year, day.month, day.day - 1 - offset);

  int minutes(String value) {
    final parts = value.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  test('default is opt-in and only valid choices persist', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(RamadanIshaSettings.read(prefs), 0);
    for (final value in [90, 120, 0]) {
      await RamadanIshaSettings.setInterval(value);
      expect(prefs.getInt(RamadanIshaSettings.storageKey), value);
      expect(RamadanIshaSettings.read(prefs), value);
    }
    await expectLater(RamadanIshaSettings.setInterval(60), throwsArgumentError);
    expect(RamadanIshaSettings.read(prefs), 0);
    expect(prefs.containsKey('selectedCalculationMethod'), isFalse);
  });

  test(
    'damaged values preserve the calculated method and valid siblings',
    () async {
      for (final value in ['90', 90.0, true, -90, 60]) {
        SharedPreferences.setMockInitialValues({
          RamadanIshaSettings.storageKey: value,
          IslamicCalendarPreferences.storageKey: 'invalid',
          'prayerAdjustments': jsonEncode({'maghrib': 7, 'isha': 'invalid'}),
        });
        final prefs = await SharedPreferences.getInstance();
        final enriched = RamadanIshaSettings.enrichRequest(request, prefs);
        expect(enriched[RamadanIshaSettings.intervalRequestKey], 0);
        expect(enriched[RamadanIshaSettings.hijriOffsetRequestKey], 0);
        expect(enriched[RamadanIshaSettings.maghribAdjustmentRequestKey], 7);
      }
      for (final value in [
        'broken',
        '[]',
        '{"maghrib":121}',
        '{"maghrib":7.5}',
        true,
      ]) {
        SharedPreferences.setMockInitialValues({'prayerAdjustments': value});
        final prefs = await SharedPreferences.getInstance();
        expect(
          RamadanIshaSettings.enrichRequest(
            request,
            prefs,
          )[RamadanIshaSettings.maghribAdjustmentRequestKey],
          0,
        );
      }
    },
  );

  test(
    'enrichment refreshes stale values without changing a manual timetable',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final old = {
        ...request,
        RamadanIshaSettings.intervalRequestKey: 120,
        RamadanIshaSettings.hijriOffsetRequestKey: 2,
        RamadanIshaSettings.maghribAdjustmentRequestKey: 12,
      };
      final refreshed = RamadanIshaSettings.enrichRequest(old, prefs);
      expect(refreshed[RamadanIshaSettings.intervalRequestKey], 0);
      expect(refreshed[RamadanIshaSettings.hijriOffsetRequestKey], 0);
      expect(refreshed[RamadanIshaSettings.maghribAdjustmentRequestKey], 0);
      expect(old[RamadanIshaSettings.intervalRequestKey], 120);
      final manual = {...old, 'type': 'manual'};
      expect(RamadanIshaSettings.enrichRequest(manual, prefs), manual);
      expect(LocalPrayerCalculator.calculate(manual), isNull);
    },
  );

  test(
    'both intervals include Ramadan eve and exclude Eid eve for every Hijri correction',
    () async {
      final calendar = HijriCalendar();
      final firstDay = calendar.hijriToGregorian(1447, 9, 1);
      final eid = calendar.hijriToGregorian(1447, 10, 1);
      final prefs = await SharedPreferences.getInstance();
      for (final interval in [90, 120]) {
        await RamadanIshaSettings.setInterval(interval);
        for (final offset in [-2, -1, 0, 1, 2]) {
          await prefs.setInt(IslamicCalendarPreferences.storageKey, offset);
          final firstNight = nightBefore(firstDay, offset);
          final eidNight = nightBefore(eid, offset);
          final cases = {
            DateTime(firstNight.year, firstNight.month, firstNight.day - 1):
                false,
            firstNight: true,
            DateTime(eidNight.year, eidNight.month, eidNight.day - 1): true,
            eidNight: false,
          };
          for (final entry in cases.entries) {
            final input = {...request, 'date': dateText(entry.key)};
            final original = LocalPrayerCalculator.calculate(input)!.data!;
            final actual = LocalPrayerCalculator.calculate(
              RamadanIshaSettings.enrichRequest(input, prefs),
            )!.data!;
            expect(
              actual.ishaStart,
              entry.value
                  ? '${((minutes(original.maghribStart!) + interval) ~/ 60 % 24).toString().padLeft(2, '0')}:${((minutes(original.maghribStart!) + interval) % 60).toString().padLeft(2, '0')}'
                  : original.ishaStart,
              reason:
                  '${entry.key} interval=$interval offset=$offset Ramadan=${entry.value}',
            );
            expect(actual.maghribStart, original.maghribStart);
            expect(actual.fajrStart, original.fajrStart);
          }
        }
      }
    },
  );

  test(
    'method correction and personal Maghrib/Isha corrections apply once',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await RamadanIshaSettings.setInterval(90);
      await prefs.setString(
        'prayerAdjustments',
        jsonEncode({'maghrib': 7, 'isha': 13}),
      );
      final input = {...request, 'prayer_method': '16'};
      final base = LocalPrayerCalculator.calculate(input)!.data!;
      final day = LocalPrayerCalculator.calculate(
        RamadanIshaSettings.enrichRequest(input, prefs),
      )!.data!;
      expect(minutes(day.ishaStart!) - minutes(base.maghribStart!), 97);
      final prayers = PrayerOccurrence.fromDay(
        day,
        tz.getLocation('Africa/Casablanca'),
        {'maghrib': 7, 'isha': 13},
      );
      final maghrib = prayers.singleWhere((prayer) => prayer.prayerId == 4);
      final isha = prayers.singleWhere((prayer) => prayer.prayerId == 5);
      expect(isha.time.difference(maghrib.time).inMinutes, 103);
    },
  );

  test(
    'Ramadan Isha crossing midnight keeps its following civil date in alarms',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await RamadanIshaSettings.setInterval(120);
      final input = {
        ...request,
        'date': '2015-06-20',
        'lat': '48.8566',
        'lng': '2.3522',
        'timezone': 'Europe/Paris',
        'prayer_method': '3',
      };
      for (final correction in [15, 120]) {
        final adjustments = {'maghrib': correction, 'isha': 5};
        await prefs.setString('prayerAdjustments', jsonEncode(adjustments));
        final day = LocalPrayerCalculator.calculate(
          RamadanIshaSettings.enrichRequest(input, prefs),
        )!.data!;
        expect(minutes(day.ishaStart!), lessThan(180));
        expect(day.ishaDayOffset, 1);
        final prayers = PrayerOccurrence.fromDay(
          day,
          tz.getLocation('Europe/Paris'),
          adjustments,
        );
        final maghrib = prayers.singleWhere((prayer) => prayer.prayerId == 4);
        final isha = prayers.singleWhere((prayer) => prayer.prayerId == 5);
        expect(isha.time.day, 21);
        expect(isha.date, '2015-06-20');
        expect(isha.time.difference(maghrib.time).inMinutes, 125);
        expect(
          PrayerDisplayPhase.moments([
            day,
          ], adjustments: adjustments).last.startedAt.day,
          21,
        );
        expect(
          PrayerShareData.fromDay(
            day,
            city: 'Paris',
            adjustments: adjustments,
          )!.prayers.last.time.day,
          21,
        );
      }
    },
  );

  test(
    'negative Maghrib correction keeps Isha on its actual date everywhere',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await RamadanIshaSettings.setInterval(90);
      await prefs.setString('prayerAdjustments', '{"maghrib":-120,"isha":5}');
      final day = LocalPrayerCalculator.calculate(
        RamadanIshaSettings.enrichRequest(request, prefs),
      )!.data!;
      expect(minutes(day.ishaStart!), lessThan(minutes(day.maghribStart!)));
      expect(day.ishaDayOffset, 0);
      final restored = Data.fromJson(day.toJson());
      expect(restored.ishaDayOffset, 0);
      const adjustments = {'maghrib': -120, 'isha': 5};
      final prayers = PrayerOccurrence.fromDay(
        restored,
        tz.getLocation('Africa/Casablanca'),
        adjustments,
      );
      final maghrib = prayers.singleWhere((prayer) => prayer.prayerId == 4);
      final isha = prayers.singleWhere((prayer) => prayer.prayerId == 5);
      expect(isha.time.day, 25);
      expect(isha.time.difference(maghrib.time).inMinutes, 95);
      final displayed = PrayerDisplayPhase.moments(
        [restored],
        adjustments: adjustments,
      ).singleWhere((prayer) => prayer.prayerKey == 'isha');
      final shared = PrayerShareData.fromDay(
        restored,
        city: 'Casablanca',
        adjustments: adjustments,
      )!.prayers.singleWhere((prayer) => prayer.labelKey == 'isha');
      expect(displayed.startedAt.day, 25);
      expect(shared.time, displayed.startedAt);
      expect(
        shared.clock,
        '${isha.time.hour.toString().padLeft(2, '0')}:${isha.time.minute.toString().padLeft(2, '0')}',
      );
    },
  );

  test('day metadata is bounded and absent for legacy clocks', () {
    for (final invalid in ['1', 1.5, true, -2, 3]) {
      final day = Data.fromJson({'isha_day_offset': invalid});
      expect(day.ishaDayOffset, isNull);
      expect(day.toJson().containsKey('isha_day_offset'), isFalse);
    }
    for (final value in [-1, 0, 1, 2]) {
      expect(
        Data.fromJson(Data(ishaDayOffset: value).toJson()).ishaDayOffset,
        value,
      );
    }
    expect(Data(ishaDayOffset: 3).ishaDayOffset, isNull);
    final legacy = Data(
      date: '2026-03-28',
      fajrStart: '05:00',
      sunrise: '06:30',
      zuhrStart: '12:30',
      asrStart: '16:00',
      maghribStart: '20:30',
      ishaStart: '00:15',
    );
    expect(legacy.toJson().containsKey('isha_day_offset'), isFalse);
    final prayers = PrayerOccurrence.fromDay(
      legacy,
      tz.getLocation('Europe/Paris'),
      {},
    );
    expect(prayers.last.time.day, 29);
    expect(PrayerDisplayPhase.moments([legacy]).last.startedAt.day, 29);
    expect(
      PrayerShareData.fromDay(legacy, city: 'Paris')!.prayers.last.time.day,
      29,
    );
  });

  test('dates outside the app Hijri table keep the selected method', () {
    final maghrib = DateTime.utc(1900, 1, 1, 18);
    final original = maghrib.add(const Duration(minutes: 110));
    expect(
      RamadanIshaSettings.ishaForNight(
        request: {...request, RamadanIshaSettings.intervalRequestKey: 120},
        civilDate: DateTime(1900, 1, 1),
        maghrib: maghrib,
        calculatedIsha: original,
      ),
      original,
    );
  });

  test(
    'default and non-Ramadan days keep both school presets unchanged',
    () async {
      final prefs = await SharedPreferences.getInstance();
      for (final school in ['STANDARD', 'HANAFI']) {
        for (final method in ['4', '16', '21']) {
          for (final date in ['2026-02-25', '2026-09-16']) {
            final input = {
              ...request,
              'date': date,
              'school': school,
              'prayer_method': method,
            };
            final original = LocalPrayerCalculator.calculate(input)!.toJson();
            await RamadanIshaSettings.setInterval(0);
            expect(
              LocalPrayerCalculator.calculate(
                RamadanIshaSettings.enrichRequest(input, prefs),
              )!.toJson(),
              original,
            );
            if (date == '2026-09-16') {
              await RamadanIshaSettings.setInterval(120);
              expect(
                LocalPrayerCalculator.calculate(
                  RamadanIshaSettings.enrichRequest(input, prefs),
                )!.toJson(),
                original,
              );
            }
          }
        }
      }
    },
  );
}
