import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/noti_sound_controller.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/data/api/api_client.dart';
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/view/screens/home/modern/widget/modern_next_prayer_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SalaTime application identity is configured', () {
    expect(AppConstants.APP_NAME, 'SalaTime');
    expect(Uri.parse(AppConstants.BASE_URL).host, 'salatime.net');
  });

  test('every supported language has a bundled translation file', () async {
    for (final language in AppConstants.languages) {
      final languageCode = language.languageCode;
      expect(languageCode, isNotEmpty);

      final contents = await rootBundle.loadString(
        'assets/language/$languageCode.json',
      );
      final translations = json.decode(contents);

      expect(translations, isA<Map<String, dynamic>>());
      expect(translations, isNotEmpty);
    }
  });

  test('Adhan 2 is selected when no notification sound was saved', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = NotiSoundController();

    await controller.loadSelectedSound();

    final preferences = await SharedPreferences.getInstance();
    expect(
      controller.selectedSound.value,
      AppConstants.DEFAULT_NOTIFICATION_SOUND_ASSET,
    );
    expect(
      preferences.getString(AppConstants.SELECTED_NOTIFICATION_SOUND_KEY),
      AppConstants.DEFAULT_NOTIFICATION_SOUND,
    );
  });

  test('an existing notification sound choice is preserved', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.SELECTED_NOTIFICATION_SOUND_KEY: 'azan_3',
    });
    final controller = NotiSoundController();

    await controller.loadSelectedSound();

    expect(controller.selectedSound.value, 'assets/audio/azan_3.mp3');
  });

  testWidgets('active prayer is automatically brought into view', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    Get.put<SharedPreferences>(preferences);
    addTearDown(Get.reset);
    final controller =
        PrayerTimeController(
            apiClient: ApiClient(
              appBaseUrl: AppConstants.BASE_URL,
              sharedPreferences: preferences,
            ),
          )
          ..currentWaqtName.value = 'Maghrib'
          ..currentWaktTime.value = '19:51'
          ..prayerTimeModel = PrayerTimeModel(
            data: Data(
              fajrStart: '05:25',
              zuhrStart: '13:22',
              asrStart: '17:00',
              maghribStart: '19:51',
              ishaStart: '21:13',
            ),
          );

    await tester.pumpWidget(
      GetMaterialApp(
        translations: _TestTranslations(),
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: ModernNextPrayerCard(
                prayerTimeController: controller,
                now: () => DateTime(2026, 8, 30, 19, 49),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final prayerList = tester.widget<ListView>(find.byType(ListView));
    expect(prayerList.controller, isNotNull);
    expect(prayerList.controller!.offset, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TestTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {'adhan': 'A'},
  };
}
