import 'package:adhan/adhan.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'prayer_time_zones.dart';
import 'ramadan_isha_settings.dart';

/// Automatic prayer times. Shared methods use the named Adhan presets, including
/// their minute adjustments; additional regional methods retain SalaTime's rules.
class LocalPrayerCalculator {
  static const _standardMethods = <String, CalculationMethod>{
    '3': CalculationMethod.muslim_world_league,
    '5': CalculationMethod.egyptian,
    '1': CalculationMethod.karachi,
    '4': CalculationMethod.umm_al_qura,
    '16': CalculationMethod.dubai,
    '15': CalculationMethod.moon_sighting_committee,
    '2': CalculationMethod.north_america,
    '9': CalculationMethod.kuwait,
    '10': CalculationMethod.qatar,
    '11': CalculationMethod.singapore,
    '13': CalculationMethod.turkey,
  };

  static void initializeTimeZones() => PrayerTimeZones.initialize();

  static CalculationParameters? parameters(
    String method,
    String school, {
    double? latitude,
  }) {
    // Fajr, Isha, Maghrib angle, Isha interval, Maghrib adjustment.
    const methods = <String, List<double>>{
      '0': [16, 14, 4, 0, 0],
      '7': [17.7, 14, 4.5, 0, 0],
      '8': [19.5, 0, 0, 90, 0],
      '12': [12, 12, 0, 0, 0],
      '14': [16, 15, 0, 0, 0],
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
    final standard = _standardMethods[method];
    if (standard != null) {
      result = standard.getParameters();
      // Match the named preset convention: above 48 degrees north use one
      // seventh of the night; otherwise use its midpoint. Moonsighting keeps
      // its own seasonal bounds inside the Adhan calculation engine.
      result.highLatitudeRule = latitude != null && latitude > 48
          ? HighLatitudeRule.seventh_of_the_night
          : HighLatitudeRule.middle_of_the_night;
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
      result.highLatitudeRule = HighLatitudeRule.twilight_angle;
    }
    result.madhab = school == 'HANAFI' ? Madhab.hanafi : Madhab.shafi;
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
      latitude: latitude,
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
      final zone = PrayerTimeZones.location(
        '${request['timezone']}',
        date: date,
      );
      final times = PrayerTimes(
        Coordinates(latitude, longitude),
        DateComponents(date.year, date.month, date.day),
        params,
      );
      final isha = RamadanIshaSettings.ishaForNight(
        request: request,
        civilDate: date,
        maghrib: times.maghrib,
        calculatedIsha: times.isha,
      );
      final localIsha = tz.TZDateTime.from(isha, zone);
      final ishaDayOffset = isha == times.isha
          ? null
          : DateTime.utc(
              localIsha.year,
              localIsha.month,
              localIsha.day,
            ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
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
          ishaStart: clock(isha),
          ishaDayOffset: ishaDayOffset,
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
