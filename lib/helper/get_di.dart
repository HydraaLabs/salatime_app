import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/alphabet_controller.dart';
import 'package:salatime/controller/audio_player_controller.dart';
import 'package:salatime/controller/bookmark_controller.dart';
import 'package:salatime/controller/category_controller.dart';
import 'package:salatime/controller/dhikr_controller.dart';
import 'package:salatime/controller/dua_controller.dart';
import 'package:salatime/controller/hadith_controller.dart';
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/controller/internet_check_controller.dart';
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
import 'package:salatime/data/repository/dikir_list_repo.dart';
import 'package:salatime/data/repository/dua_list_repo.dart';
import 'package:salatime/data/repository/quran_setting_repo.dart';
import 'package:salatime/data/repository/sifatname_list_repo.dart';
import 'package:salatime/data/repository/wallpaper_repo.dart';
import 'package:salatime/helper/app_translations.dart';
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
  Get.lazyPut(() => BookMarkController(), fenix: true);
  Get.lazyPut(() => CategoryListController());
  Get.lazyPut(() => ZakatCalculatorController());

  // Interface strings: only the active language and the English fallback are
  // read before the first frame; the other languages load when selected.
  final locale = LocalizationController.resolveLocale(
    systemLocale: WidgetsBinding.instance.platformDispatcher.locale,
    savedLanguageCode: sharedPreferences.getString(AppConstants.LANGUAGE_CODE),
    savedCountryCode: sharedPreferences.getString(AppConstants.COUNTRY_CODE),
  );
  final codes = {locale.languageCode, AppConstants.languages.first.languageCode!};
  final languages = <String, Map<String, String>>{};
  await Future.wait(
    codes.map((code) async {
      languages[AppTranslations.keyFor(code)] = await AppTranslations.load(code);
    }),
  );
  return languages;
}
