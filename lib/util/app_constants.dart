// ignore_for_file: constant_identifier_name, constant_identifier_names
import 'package:salatime/data/model/response/language_model.dart';
import 'package:salatime/util/images.dart';

class AppConstants {
  static const String APP_NAME = 'SalaTime';
  static const String APP_VERSION = "7.0";

  // main base url
  // Override when building against a self-hosted SalaTime backend.
  static const String BASE_URL = String.fromEnvironment(
    'SALATIME_API_URL',
    defaultValue: 'https://salatime.net',
  );

  // API's and API Kay's
  @Deprecated(
    'hadithapi.com n\'est plus utilisé — hadiths via CDN jsDelivr (fawazahmed0/hadith-api), voir HadithController',
  )
  static const String HADITH_BASE_URL = 'https://www.hadithapi.com/public';
  static const String NEARBY_MOSQUE_URL =
      'https://maps.googleapis.com/maps/api/place/nearbysearch';
  // mp3quran.net API (récitateurs + récitations audio du Coran)
  static const String MP3QURAN_API_URL = 'https://mp3quran.net/api/v3';

  //Endpoint url
  static const String SURA_LIST = "/api/chapters";
  static const String SURA_Detaile = "/api/verses/";
  static const String JUZ_LIST = "/api/juzes";
  static const String TRANSLATOR_ID = "?translator_id=";
  static const String DUA_LIST = "/api/dua-list";
  static const String DUA_DETAILES = "/api/dua-details/";
  static const String DIKIR_LIST = "/api/dhikr-list";
  static const String DIKIR_DETAILES = "/api/dhikr-details/";
  static const String SIFAT_NAME_LIST = "/api/sifat-name-list";
  static const String SIFAT_NAME_DETAILES = "/api/sifat-name-details/";
  static const String HARAM_FOOD_LIST = "/api/haram-code-list";
  static const String TODAYS_PRAYER_TIME = "/api/today-prayer-time";
  static const String PRAYER_TIME_CALENDAR = "/api/prayer-time-calendar";
  static const String MOSQUE_SETTINGS = "/api/settings";
  static const String TRANSLATOR = "/api/translators";
  static const String CITY_LIST = "/api/get-cities";
  static const String RECITERS = "/api/reciters";
  static const String AUDIO_LIST = "/api/reciter-sura/";
  static const String WALLPAPER_LIST = "/api/wallpapers";

  //others key
  @Deprecated(
    'Clé démo hadithapi.com invalide (401) — plus nécessaire avec le CDN jsDelivr',
  )
  static const String HADITH_API_KEY = String.fromEnvironment(
    'SALATIME_HADITH_API_KEY',
  );
  static const String MAPS_API_KEY = String.fromEnvironment(
    'SALATIME_MAPS_API_KEY',
  );

  // Shared Key
  static const String THEME = 'theme';
  static const String THEME_MODE_KEY = 'theme_mode';
  static const String DAYLIGHT_SUNRISE_KEY = 'daylight_sunrise';
  static const String DAYLIGHT_SUNSET_KEY = 'daylight_sunset';
  static const String FIRST_LAUNCH_SETUP_COMPLETE_KEY =
      'first_launch_setup_complete_v1';
  static const String isPrayerTme = 'isPrayerTme';
  static const String saveCityName = 'saveCityName';
  static const String notificationSettingsKey = 'prayer_notification_settings';
  static const String SELECTED_NOTIFICATION_SOUND_KEY = 'selectedSoundName';
  static const String DEFAULT_NOTIFICATION_SOUND = 'azan_2';
  static const String DEFAULT_NOTIFICATION_SOUND_ASSET =
      'assets/audio/$DEFAULT_NOTIFICATION_SOUND.mp3';
  static const String BEFORE_ADHAN_REMINDER_ENABLED_KEY =
      'before_adhan_reminder_enabled';
  static const String AFTER_ADHAN_REMINDER_ENABLED_KEY =
      'after_adhan_reminder_enabled';
  static const String BEFORE_ADHAN_REMINDER_MINUTES_KEY =
      'before_adhan_reminder_minutes';
  static const String AFTER_ADHAN_REMINDER_MINUTES_KEY =
      'after_adhan_reminder_minutes';
  static const String BEFORE_ADHAN_REMINDER_SOUND_KEY =
      'before_adhan_reminder_sound';
  static const String AFTER_ADHAN_REMINDER_SOUND_KEY =
      'after_adhan_reminder_sound';
  static const int DEFAULT_PRAYER_REMINDER_MINUTES = 5;
  static const String DEFAULT_PRAYER_REMINDER_SOUND = 'noti_beep';
  static const String DEFAULT_PRAYER_REMINDER_SOUND_ASSET =
      'assets/audio/$DEFAULT_PRAYER_REMINDER_SOUND.mp3';
  static const String IS_MANUAL_PRAYER_TIME = 'is_manual_prayer_time';
  static const String manualCityLat = 'manual_city_lat';
  static const String manualCityLng = 'manual_city_lng';
  static const String HOME_LAYOUT_OVERRIDE_KEY = 'home_layout_override';
  static const String QURAN_MILESTONE_GOAL_KEY = 'quran_milestone_daily_goal';
  static const String QURAN_MILESTONE_PROGRESS_KEY = 'quran_milestone_progress';

  // Language Key
  static const String LANGUAGE_CODE = 'language_code';
  static const String COUNTRY_CODE = 'country_code';

  // Islamic Name / AI assistant (routed through our backend, 1min.ai key stays server-side)
  static const String AI_CHAT_URI = '$BASE_URL/api/ai/chat';
  static const String AI_GENERATE_NAMES_URI = '$BASE_URL/api/ai/generate-names';
  static const String FAVORITE_KEY = 'islamic_name_favorites';

  // All Language model list section
  // 10 most used languages (a .json file exists in assets/language for each).
  static List<LanguageModel> languages = [
    LanguageModel(
      imageUrl: Images.englishIcon,
      languageName: 'English',
      countryCode: 'US',
      languageCode: 'en',
    ),
    LanguageModel(
      imageUrl: Images.arabicIcon,
      languageName: 'العربية',
      countryCode: 'SA',
      languageCode: 'ar',
    ),
    LanguageModel(
      imageUrl: Images.franceIcon,
      languageName: 'Français',
      countryCode: 'FR',
      languageCode: 'fr',
    ),
    LanguageModel(
      imageUrl: Images.turukishIcon,
      languageName: 'Türkçe',
      countryCode: 'TR',
      languageCode: 'tr',
    ),
    LanguageModel(
      imageUrl: Images.pakistanIcon,
      languageName: 'اردو',
      countryCode: 'PK',
      languageCode: 'ur',
    ),
    LanguageModel(
      imageUrl: Images.indonesiaIcon,
      languageName: 'Bahasa Indonesia',
      countryCode: 'ID',
      languageCode: 'id',
    ),
    LanguageModel(
      imageUrl: Images.malaysiaIcon,
      languageName: 'Bahasa Melayu',
      countryCode: 'MY',
      languageCode: 'ms',
    ),
    LanguageModel(
      imageUrl: Images.spainIcon,
      languageName: 'Español',
      countryCode: 'ES',
      languageCode: 'es',
    ),
    LanguageModel(
      imageUrl: Images.bangladeshIcon,
      languageName: 'বাংলা',
      countryCode: 'BD',
      languageCode: 'bn',
    ),
    LanguageModel(
      imageUrl: Images.afghanistanIcon,
      languageName: 'فارسی',
      countryCode: 'AF',
      languageCode: 'fa',
    ),
  ];
}
