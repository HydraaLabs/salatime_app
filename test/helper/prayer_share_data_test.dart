import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:zabi/helper/prayer_share_data.dart';

Data _day() => Data(
  date: '2026-09-11',
  isJumma: true,
  fajrStart: '05:30',
  sunrise: '07:00',
  zuhrStart: '13:00',
  asrStart: '16:00',
  maghribStart: '19:30',
  ishaStart: '23:50',
);
void main() {
  test('shared snapshot applies all six offsets without changing source', () {
    final source = _day();
    final card = PrayerShareData.fromDay(
      source,
      city: ' Fès ',
      adjustments: {
        'fajr': -10,
        'sunrise': 5,
        'zuhr': 2,
        'asr': 3,
        'maghrib': -1,
        'isha': 20,
      },
    )!;
    expect(card.city, 'Fès');
    expect(card.prayers.map((p) => p.clock), [
      '05:20',
      '07:05',
      '13:02',
      '16:03',
      '19:29',
      '00:10',
    ]);
    expect(card.prayers[2].labelKey, 'jumuah');
    expect(source.ishaStart, '23:50');
    expect(source.sunrise, '07:00');
    final text = card.text(
      translate: (key) => key,
      formatDate: (date) => date.toIso8601String().split('T').first,
      hijriDate: '29 Safar 1448',
    );
    expect(text, contains('isha : 00:10 (2026-09-12)'));
    expect(text, contains('sunrise : 07:05'));
  });
  test('missing, malformed and impossible schedules cannot be shared', () {
    for (final bad in [
      null,
      Data(),
      _day()..date = '2026-02-30',
      _day()..sunrise = null,
      _day()..asrStart = '25:10',
      _day()..maghribStart = '17:60',
    ]) {
      expect(PrayerShareData.fromDay(bad, city: 'Fès'), isNull);
    }
  });
  test('Isha after midnight follows Maghrib before manual correction', () {
    final day = _day()
      ..maghribStart = '23:00'
      ..ishaStart = '00:30';
    final card = PrayerShareData.fromDay(
      day,
      city: 'Stockholm',
      adjustments: {'isha': -60},
    )!;
    expect(card.prayers.last.time, DateTime(2026, 9, 11, 23, 30));
    final unadjusted = PrayerShareData.fromDay(day, city: 'Stockholm')!;
    expect(unadjusted.prayers.last.time, DateTime(2026, 9, 12, 0, 30));
    expect(
      PrayerShareData.fromDay(_day()..asrStart = '12:00', city: 'Fès'),
      isNull,
    );
  });
}
