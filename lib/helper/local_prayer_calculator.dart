import 'package:adhan/adhan.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';

/// Automatic prayer times. Angles/intervals match the methods exposed by SalaTime's
/// backend, rather than silently substituting another country's convention.
class LocalPrayerCalculator {
  static bool _initialized = false;

  static void initializeTimeZones() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  static CalculationParameters? parameters(String method, String school) {
    // Fajr, Isha, Maghrib angle, Isha interval, Maghrib adjustment.
    const methods = <String, List<double>>{
      '0': [16, 14, 4, 0, 0],
      '1': [18, 18, 0, 0, 0],
      '2': [15, 15, 0, 0, 0],
      '3': [18, 17, 0, 0, 0],
      '4': [18.5, 0, 0, 90, 0],
      '5': [19.5, 17.5, 0, 0, 0],
      '7': [17.7, 14, 4.5, 0, 0],
      '8': [19.5, 0, 0, 90, 0],
      '9': [18, 17.5, 0, 0, 0],
      '10': [18, 0, 0, 90, 0],
      '11': [20, 18, 0, 0, 0],
      '12': [12, 12, 0, 0, 0],
      '13': [18, 17, 0, 0, 0],
      '14': [16, 15, 0, 0, 0],
      '16': [18.2, 18.2, 0, 0, 0],
      '17': [20, 18, 0, 0, 0],
      '18': [18, 18, 0, 0, 0],
      '19': [18, 17, 0, 0, 0],
      '20': [20, 18, 0, 0, 0],
      '21': [19, 17, 0, 0, 0],
      '22': [18, 0, 0, 77, 3],
      '23': [18, 18, 0, 0, 5],
    };
    if (school != 'STANDARD' && school != 'HANAFI') return null;
    CalculationParameters result;
    if (method == '15') {
      result = CalculationMethod.moon_sighting_committee.getParameters();
    } else {
      final values = methods[method];
      if (values == null) return null;
      result = CalculationParameters(
        fajrAngle: values[0],
        ishaAngle: values[1],
        maghribAngle: values[2] == 0 ? null : values[2],
        // Adhan applies prayer adjustments after computing intervals. SalaTime's
        // Portugal convention defines Isha relative to the adjusted Maghrib.
        ishaInterval: values[3] == 0 ? 0 : (values[3] + values[4]).toInt(),
        adjustments: PrayerAdjustments(maghrib: values[4].toInt()),
      );
    }
    result.madhab = school == 'HANAFI' ? Madhab.hanafi : Madhab.shafi;
    result.highLatitudeRule = HighLatitudeRule.twilight_angle;
    return result;
  }

  static PrayerTimeModel? calculate(Map<String, dynamic> request) {
    // A manually maintained timetable without coordinates must stay authoritative.
    if (request['type'] != 'automatic') return null;
    final latitude = double.tryParse('${request['lat']}');
    final longitude = double.tryParse('${request['lng']}');
    final date = DateTime.tryParse('${request['date']}');
    final params = parameters(
      '${request['prayer_method']}',
      '${request['school']}',
    );
    if (latitude == null ||
        longitude == null ||
        date == null ||
        params == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    try {
      initializeTimeZones();
      final zone = tz.getLocation('${request['timezone']}');
      final times = PrayerTimes(
        Coordinates(latitude, longitude),
        DateComponents(date.year, date.month, date.day),
        params,
      );
      String clock(DateTime instant) {
        final local = tz.TZDateTime.from(instant, zone);
        return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }

      return PrayerTimeModel(
        status: true,
        calculatedLocally: true,
        data: Data(
          date: '${request['date']}',
          isJumma: date.weekday == DateTime.friday,
          imsak: clock(times.fajr.subtract(const Duration(minutes: 10))),
          fajrStart: clock(times.fajr),
          sunrise: clock(times.sunrise),
          zuhrStart: clock(times.dhuhr),
          asrStart: clock(times.asr),
          maghribStart: clock(times.maghrib),
          ishaStart: clock(times.isha),
          sehriEnd: clock(times.fajr),
          iftarStart: clock(times.maghrib),
        ),
      );
    } on Exception {
      // Unknown time zones and polar dates without sunrise must not invent times.
      return null;
    } on ArgumentError {
      return null;
    }
  }
}
