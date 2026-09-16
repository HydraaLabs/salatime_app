import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/location_auto_update_service.dart';
import 'package:salatime/util/app_constants.dart';

/// Local geographic metadata. The cloud/UI `country_code` is a language region
/// and must never select a calculation method or stand in for a real location.
class AutomaticPrayerMethod {
  static const enabledKey = 'prayer_calculation_auto_v1';
  static const lastMethodKey = 'prayer_calculation_auto_method_v1';
  static const automaticCountryKey = 'prayer_time_automatic_country_v1';
  static const manualCountryKey = 'prayer_time_manual_country_v1';

  static const _methods = <String, String>{
    'AE': '16', 'EG': '5', 'KW': '9', 'LY': '4', 'SA': '4',
    'PK': '1', 'QA': '10', 'SG': '11', 'TR': '13',
    'CA': '2', 'MX': '2', 'US': '2',
    // Keep SalaTime's additional national methods available automatically.
    'MA': '21', 'FR': '12', 'DZ': '19', 'TN': '18', 'MY': '17',
    'ID': '20', 'JO': '23', 'PT': '22', 'RU': '14', 'IR': '7',
  };

  static final _countries =
      ('AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI '
              'BJ BL BM BN BO BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN '
              'CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK '
              'FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM '
              'HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN '
              'KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK '
              'ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP '
              'NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW '
              'SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF '
              'TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI '
              'VN VU WF WS YE YT ZA ZM ZW')
          .split(' ')
          .toSet();

  static String? normalizeCountry(String? code) {
    final normalized = code?.trim().toUpperCase();
    return _countries.contains(normalized) ? normalized : null;
  }

  static String? methodForCountry(String? code) {
    final country = normalizeCountry(code);
    return country == null ? null : _methods[country] ?? '15';
  }

  static bool _validCoordinates(double? latitude, double? longitude) =>
      latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  /// Bind the country to its coordinates so a moved GPS location or restored
  /// cloud city cannot silently reuse the previous city's country offline.
  static Future<void> saveCountry(
    SharedPreferences prefs, {
    required bool manual,
    required String? code,
    required double latitude,
    required double longitude,
  }) async {
    final key = manual ? manualCountryKey : automaticCountryKey;
    final country = normalizeCountry(code);
    if (country == null || !_validCoordinates(latitude, longitude)) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(
      key,
      jsonEncode({'code': country, 'lat': latitude, 'lng': longitude}),
    );
  }

  static String? configuredCountry(SharedPreferences prefs, {bool? manual}) {
    manual ??=
        !(prefs.getBool(LocationAutoUpdateService.enabledKey) ?? false) &&
        (prefs.getBool(AppConstants.isPrayerTme) ??
            prefs.getBool(AppConstants.IS_MANUAL_PRAYER_TIME) ??
            false);
    final latitude = prefs.getDouble(
      manual ? AppConstants.manualCityLat : 'prayer_time_automatic_latitude',
    );
    final longitude = prefs.getDouble(
      manual ? AppConstants.manualCityLng : 'prayer_time_automatic_longitude',
    );
    if (!_validCoordinates(latitude, longitude)) return null;
    try {
      final saved = jsonDecode(
        prefs.getString(manual ? manualCountryKey : automaticCountryKey) ??
            'null',
      );
      if (saved is! Map ||
          saved['lat'] != latitude ||
          saved['lng'] != longitude) {
        return null;
      }
      return normalizeCountry(saved['code'] is String ? saved['code'] : null);
    } on FormatException {
      return null;
    }
  }
}
