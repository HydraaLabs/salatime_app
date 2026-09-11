import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/data/api/api_client.dart';
import 'package:zabi/util/app_constants.dart';

class OfflineApi extends ApiClient {
  OfflineApi(SharedPreferences prefs)
    : super(appBaseUrl: 'https://example.invalid', sharedPreferences: prefs);
  int requests = 0;
  @override
  Future<Response> postData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    requests++;
    throw StateError('Automatic times must not need the network');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'automatic city works offline without GPS or preloaded cache and respects method changes',
    () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.isPrayerTme: true,
        AppConstants.IS_MANUAL_PRAYER_TIME: true,
        AppConstants.saveCityName: 'Paris',
        AppConstants.manualCityLat: 48.8566,
        AppConstants.manualCityLng: 2.3522,
        'selectedCalculationMethod': '3',
        'selectedPrayerMadhab': 'STANDARD',
      });
      const channel = MethodChannel('flutter_timezone');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => 'Europe/Paris');
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final api = OfflineApi(await SharedPreferences.getInstance());
      final controller = PrayerTimeController(apiClient: api);
      final first = await controller.fetchPrayerTime(
        reload: false,
        isManualPrayerTme: true,
        manualCity: 'Paris',
        date: DateTime(2027, 2, 1),
        applyResult: false,
      );
      expect(first?.data?.date, '2027-02-01');
      expect(first?.calculatedLocally, isTrue);
      await controller.setSelectedCalculationMethod('12');
      final second = await controller.fetchPrayerTime(
        reload: false,
        isManualPrayerTme: true,
        manualCity: 'Paris',
        date: DateTime(2027, 2, 1),
        applyResult: false,
      );
      expect(second?.data?.fajrStart, isNot(first?.data?.fajrStart));
      expect(await controller.warmPrayerTimeCache(), 0);
      expect(api.requests, 0);
    },
  );
}
