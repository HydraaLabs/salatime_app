import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/offline_quran_controller.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/helper/automatic_prayer_method.dart';
import 'package:salatime/helper/get_di.dart' as di;
import 'package:salatime/helper/route_helper.dart';
import 'package:salatime/main.dart' as app;
import 'package:salatime/service/reading/reading_progress_service.dart';
import 'package:salatime/util/app_constants.dart';
import 'package:salatime/view/base/bottom_navbar.dart';
import 'package:salatime/view/screens/dhikr/dhikr_screen.dart';
import 'package:salatime/view/screens/home/modern/modern_home_screen.dart';
import 'package:salatime/view/screens/offline_quran/offline_surah_detail_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'capture real SalaTime screens for the App Store',
    (tester) async {
      // Fresh simulator only. Persist ordinary user choices, without fake data,
      // fake platform channels, a signed-in account, or calls that write to an API.
      final preferences = await SharedPreferences.getInstance();
      await preferences.clear();
      await preferences.setString(AppConstants.LANGUAGE_CODE, 'fr');
      await preferences.setString(AppConstants.COUNTRY_CODE, 'FR');
      await preferences.setString(AppConstants.THEME_MODE_KEY, 'light');
      await preferences.setString(
        AppConstants.HOME_LAYOUT_OVERRIDE_KEY,
        'modern',
      );
      await preferences.setBool(AppConstants.isPrayerTme, true);
      await preferences.setBool(AppConstants.IS_MANUAL_PRAYER_TIME, true);
      await preferences.setString(AppConstants.saveCityName, 'Fès');
      await preferences.setDouble(AppConstants.manualCityLat, 34.0331);
      await preferences.setDouble(AppConstants.manualCityLng, -5.0003);
      await AutomaticPrayerMethod.saveCountry(
        preferences,
        manual: true,
        code: 'MA',
        latitude: 34.0331,
        longitude: -5.0003,
      );
      final languages = await di.init();
      await ReadingProgressService.instance.initialize();
      final prayer = Get.find<PrayerTimeController>();
      await Get.find<PrayerTimeAdjustmentController>().init();
      await prayer.refreshConfiguredPrayerTime();
      expect(prayer.prayerTimeModel?.data, isNotNull);

      // Keep the production navigation shell and screen. Its location/notification
      // onboarding has been completed through the saved manual-city state above;
      // do not request OS permissions or schedule alerts during a capture run.
      const captureRoute = '/app-store-capture';
      RouteHelper.routes.add(
        GetPage(
          name: captureRoute,
          page: () => BottomNavbarScreen(
            pageBuilder: (_, index, active, returnHome) => index == 0
                ? const ModernHomeScreen()
                : DhikrScreen(appBackButton: true, onBackPressed: returnHome),
          ),
        ),
      );
      runApp(app.MyApp(languages: languages, initialRoute: captureRoute));
      await _waitFor(
        tester,
        () => find.byType(ModernHomeScreen).evaluate().isNotEmpty,
      );
      await _capture(tester, '01-prayer-times');

      Get.to<void>(
        () => const OfflineSuraDetaileScreen(
          appBackButton: true,
          surahNumber: '1',
        ),
      );
      await _waitFor(
        tester,
        () =>
            Get.isRegistered<OfflineQuranController>() &&
            Get.find<OfflineQuranController>().suraDetailsApiData != null &&
            !Get.find<OfflineQuranController>().isSurahDetailsLoading.value,
      );
      await _capture(tester, '02-quran-al-fatiha');

      Get.back<void>();
      await tester.pump(const Duration(seconds: 1));
      Get.to<void>(() => const DhikrScreen(appBackButton: true));
      await _waitFor(
        tester,
        () =>
            find.byType(DhikrScreen).evaluate().isNotEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty,
      );
      await _capture(tester, '03-athkar');
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _waitFor(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (ready()) return;
  }
  fail('The real screen did not finish loading within 30 seconds.');
}

Future<void> _capture(WidgetTester tester, String name) async {
  // Live native screenshot collection is handled on the Mac by capture_ios.py.
  // Unlike the integration_test UIKit renderer, simctl includes UIScene windows
  // and captures the simulator's original full-resolution pixels/status bar.
  await tester.pump(const Duration(seconds: 3));
  expect(tester.takeException(), isNull);
  // ignore: avoid_print
  print('SALATIME_STORE_CAPTURE:$name');
  await tester.pump(const Duration(seconds: 10));
}
