// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/ai_assistant_controller.dart';
import 'package:salatime/controller/alphabet_controller.dart';
import 'package:salatime/controller/audio_player_controller.dart';
import 'package:salatime/controller/bookmark_controller.dart';
import 'package:salatime/controller/category_controller.dart';
import 'package:salatime/controller/dhikr_controller.dart';
import 'package:salatime/controller/dua_controller.dart';
import 'package:salatime/controller/hadith_controller.dart';
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/controller/internet_check_controller.dart';
import 'package:salatime/controller/islamic_name_controller.dart';
import 'package:salatime/controller/localization_controller.dart';
import 'package:salatime/controller/nearby_mosque_controller.dart';
import 'package:salatime/controller/noti_sound_controller.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/controller/quran_controller.dart';
import 'package:salatime/controller/quran_milestone_controller.dart';
import 'package:salatime/controller/quran_settings_controller.dart';
import 'package:salatime/controller/theme_controller.dart';
import 'package:salatime/controller/wallpaper_controller.dart';
import 'package:salatime/controller/zakat_calculator_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/language_model.dart';
import 'package:salatime/data/repository/ai_assistant_repo.dart';
import 'package:salatime/data/repository/dikir_list_repo.dart';
import 'package:salatime/data/repository/dua_list_repo.dart';
import 'package:salatime/data/repository/islamic_name_repo.dart';
import 'package:salatime/data/repository/quran_setting_repo.dart';
import 'package:salatime/data/repository/sifatname_list_repo.dart';
import 'package:salatime/data/repository/wallpaper_repo.dart';
import 'package:salatime/util/app_constants.dart';

Future<Map<String, Map<String, String>>> init() async {
  // Core
  final sharedPreferences = await SharedPreferences.getInstance();

  Get.lazyPut(() => sharedPreferences);
  Get.lazyPut(
    () => ApiClient(
      appBaseUrl: AppConstants.BASE_URL,
      sharedPreferences: Get.find(),
    ),
  );

  // Repository
  Get.lazyPut(
    () => DuaRepo(sharedPreferences: Get.find(), apiClient: Get.find()),
  );
  Get.lazyPut(
    () => DhikrRepo(sharedPreferences: Get.find(), apiClient: Get.find()),
  );
  Get.lazyPut(
    () => QuranRepo(sharedPreferences: Get.find(), apiClient: Get.find()),
  );
  Get.lazyPut(
    () =>
        QuranSettingsRepo(sharedPreferences: Get.find(), apiClient: Get.find()),
    fenix: true,
  );
  Get.lazyPut(
    () => WallpaperRepo(sharedPreferences: Get.find(), apiClient: Get.find()),
  );
  Get.lazyPut(() => IslamicNameRepo());
  Get.lazyPut(() => AiAssistantRepo(), fenix: true);

  //new controller
  Get.lazyPut(
    () => LocalizationController(
      sharedPreferences: Get.find(),
      apiClient: Get.find(),
    ),
    fenix: true,
  );
  Get.lazyPut(() => DhikrController(dhikrRepo: Get.find()));
  Get.lazyPut(() => DuaController(duaRepo: Get.find()));
  Get.lazyPut(() => QuranController(quranRepo: Get.find()));
  Get.lazyPut(() => PrayerTimeController(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => NotiSoundController());
  Get.lazyPut(() => AudioPlayerController(apiClient: Get.find()));
  Get.lazyPut(() => WallPaperController(wallpaperRepo: Get.find()));
  Get.lazyPut(() => AlphabetController());
  Get.lazyPut(() => PrayerTimeAdjustmentController(), fenix: true);
  Get.lazyPut(() => InternetController(), fenix: true);
  Get.lazyPut(() => IslamicNameController());
  Get.lazyPut(
    () => AiAssistantController(assistantRepo: Get.find()),
    fenix: true,
  );
  Get.lazyPut(
    () => HomeLayoutController(sharedPreferences: Get.find()),
    fenix: true,
  );
  Get.lazyPut(
    () => QuranMilestoneController(sharedPreferences: Get.find()),
    fenix: true,
  );

  // old controller
  Get.lazyPut(() => ThemeController(sharedPreferences: Get.find()));
  Get.lazyPut(() => HadithController());
  Get.lazyPut(() => NearbyMosqueController());
  Get.lazyPut(
    () => SettingsController(quranSettingRepo: Get.find()),
    fenix: true,
  );
  Get.lazyPut(() => BookMarkController());
  Get.lazyPut(() => CategoryListController());
  Get.lazyPut(() => ZakatCalculatorController());

  // Retrieving localized data
  Map<String, Map<String, String>> languages = {};
  for (LanguageModel languageModel in AppConstants.languages) {
    String jsonStringValues = await rootBundle.loadString(
      'assets/language/${languageModel.languageCode}.json',
    );
    Map<String, dynamic> mappedJson = json.decode(jsonStringValues);
    Map<String, String> _json = {};
    mappedJson.forEach((key, value) {
      _json[key] = value.toString();
    });
    languages['${languageModel.languageCode}_${languageModel.countryCode}'] =
        _json;
  }
  return languages;
}
