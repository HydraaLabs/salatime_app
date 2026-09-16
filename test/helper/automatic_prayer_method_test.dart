import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/data/model/response/city_suggestion_model.dart';
import 'package:salatime/helper/automatic_prayer_method.dart';
import 'package:salatime/helper/prayer_calculation_methods.dart';
import 'package:salatime/util/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('country selection uses stable reference and regional method IDs', () {
    const expected = {
      'AE': '16',
      'EG': '5',
      'KW': '9',
      'LY': '4',
      'SA': '4',
      'PK': '1',
      'QA': '10',
      'SG': '11',
      'TR': '13',
      'CA': '2',
      'MX': '2',
      'US': '2',
      'MA': '21',
      'FR': '12',
      'DZ': '19',
      'TN': '18',
      'MY': '17',
      'ID': '20',
      'JO': '23',
      'PT': '22',
      'RU': '14',
      'IR': '7',
      'GB': '15',
      'DE': '15',
    };
    for (final entry in expected.entries) {
      final id = AutomaticPrayerMethod.methodForCountry(entry.key);
      expect(id, entry.value, reason: entry.key);
      expect(PrayerCalculationMethods.contains(id), isTrue);
    }
    expect(AutomaticPrayerMethod.methodForCountry(' fr '), '12');
    for (final invalid in [null, '', 'XX', 'ZZ', 'France', 'en-US']) {
      expect(AutomaticPrayerMethod.methodForCountry(invalid), isNull);
    }
  });

  test('Nominatim country is independent of its translated display name', () {
    final city = CitySuggestionModel.fromJson({
      'name': 'Paris',
      'lat': '48.8566',
      'lon': '2.3522',
      'address': {'country': 'فرنسا', 'country_code': 'fr'},
    });
    expect(city.country, 'فرنسا');
    expect(AutomaticPrayerMethod.methodForCountry(city.countryCode), '12');
  });

  test(
    'cached country only applies to its exact configured coordinates',
    () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.isPrayerTme: true,
        AppConstants.manualCityLat: 48.8566,
        AppConstants.manualCityLng: 2.3522,
      });
      final prefs = await SharedPreferences.getInstance();
      await AutomaticPrayerMethod.saveCountry(
        prefs,
        manual: true,
        code: 'fr',
        latitude: 48.8566,
        longitude: 2.3522,
      );
      expect(AutomaticPrayerMethod.configuredCountry(prefs), 'FR');
      await prefs.setDouble(AppConstants.manualCityLat, 33.5731);
      expect(AutomaticPrayerMethod.configuredCountry(prefs), isNull);
      await prefs.setDouble(AppConstants.manualCityLat, 48.8566);
      await AutomaticPrayerMethod.saveCountry(
        prefs,
        manual: true,
        code: null,
        latitude: 48.8566,
        longitude: 2.3522,
      );
      expect(AutomaticPrayerMethod.configuredCountry(prefs), isNull);
      expect(
        prefs.containsKey(AutomaticPrayerMethod.manualCountryKey),
        isFalse,
      );
    },
  );
}
