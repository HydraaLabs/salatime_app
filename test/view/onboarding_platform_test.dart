import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/localization_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/helper/prayer_notification_preferences.dart';
import 'package:salatime/helper/route_helper.dart';
import 'package:salatime/util/app_constants.dart';
import 'package:salatime/view/screens/onboarding/first_launch_setup_screen.dart';
import 'package:salatime/view/screens/onboarding/widget_prompt.dart';

class _Translations extends Translations {
  _Translations(this.strings);
  final Map<String, String> strings;

  @override
  Map<String, Map<String, String>> get keys => {'fr_FR': strings};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> french;

  setUpAll(() async {
    french = Map<String, String>.from(
      jsonDecode(await rootBundle.loadString('assets/language/fr.json')),
    );
  });
  tearDown(Get.reset);

  testWidgets(
    'battery guidance is Android-only and finishing preserves prayer settings',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        WidgetPrompt.seenKey: true,
        'bg_location_prompt_shown': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final changed = (await PrayerNotificationPreferences.load(preferences))
          .firstWhere(
            (setting) =>
                setting.phase == PrayerNotificationPhase.after &&
                setting.prayer == PrayerNotificationPrayer.asr,
          )
          .copyWith(enabled: true, sound: 'moatheni_ring2', minutes: 22);
      await PrayerNotificationPreferences.save(changed);
      Get.put(
        LocalizationController(
          sharedPreferences: preferences,
          apiClient: ApiClient(
            appBaseUrl: AppConstants.BASE_URL,
            sharedPreferences: preferences,
          ),
        ),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          translations: _Translations(french),
          locale: const Locale('fr', 'FR'),
          home: const FirstLaunchSetupScreen(),
          getPages: [
            GetPage(
              name: RouteHelper.bottomNavbar,
              page: () => const Scaffold(body: Text('Home destination')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(french['onboarding_next']!));
      await tester.pumpAndSettle();

      expect(
        find.text(french['onboarding_battery_note']!),
        defaultTargetPlatform == TargetPlatform.android
            ? findsOneWidget
            : findsNothing,
      );
      final finish = find.widgetWithText(
        ElevatedButton,
        french['onboarding_finish']!,
      );
      expect(tester.widget<ElevatedButton>(finish).onPressed, isNotNull);
      await tester.tap(finish);
      await tester.pumpAndSettle();

      expect(find.text('Home destination'), findsOneWidget);
      expect(
        preferences.getBool(AppConstants.FIRST_LAUNCH_SETUP_COMPLETE_KEY),
        isTrue,
      );
      final saved = (await PrayerNotificationPreferences.load(preferences))
          .firstWhere(
            (setting) =>
                setting.phase == changed.phase &&
                setting.prayer == changed.prayer,
          );
      expect(saved.enabled, changed.enabled);
      expect(saved.sound, changed.sound);
      expect(saved.minutes, changed.minutes);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
