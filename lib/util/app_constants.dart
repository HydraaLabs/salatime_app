// ignore_for_file: constant_identifier_name, constant_identifier_names
import 'package:zabi/data/model/response/language_model.dart';
import 'package:zabi/util/images.dart';

class AppConstants {
  // Flutter SDK Version  3.44.0
  static const String APP_NAME = 'SalaTime';
  static const String APP_VERSION = "7.0";

  // main base url
  // static const String BASE_URL = "https://zabi.theme29.com";
  // static const String BASE_URL = "https://zabi-dev.theme29.com";
  // Backend production (nœud .17, via HAProxy)
  static const String BASE_URL = "https://salatime.net";
  // Backend local (php artisan serve). Sur émulateur Android, utiliser http://10.0.2.2:8000
  // static const String BASE_URL = "http://127.0.0.1:8000";

  // API's and API Kay's
  @Deprecated('hadithapi.com n\'est plus utilisé — hadiths via CDN jsDelivr (fawazahmed0/hadith-api), voir HadithController')
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
  static const String MOSQUE_SETTINGS = "/api/settings";
  static const String TRANSLATOR = "/api/translators";
  static const String DONATION_Category = "/api/donation-categories";
  static const String DONATED_LIST = "/api/donation-list";
  static const String DONATION_STORE = "/api/donation-store";
  static const String PAYMENT_METHODS = "/api/payment-methods";
  static const String CITY_LIST = "/api/get-cities";
  static const String RECITERS = "/api/reciters";
  static const String AUDIO_LIST = "/api/reciter-sura/";
  static const String WALLPAPER_LIST = "/api/wallpapers";

  //others key
  @Deprecated('Clé démo hadithapi.com invalide (401) — plus nécessaire avec le CDN jsDelivr')
  static const String HADITH_API_KEY =
      "\$2y\$10\$IpN2jMeSLbrGxZ6zwEu3KAEr1ZmUjwQCYhRbiReqscXswndm";
  static const String MAPS_API_KEY = 'AIzaSyCQc4sar_LVjT8M_vC_ubqCoGwGlR-TU3Q';

  // Shared Key
  static const String THEME = 'theme';
  static const String isPrayerTme = 'isPrayerTme';
  static const String saveCityName = 'saveCityName';
  static const String notificationSettingsKey = 'prayer_notification_settings';
  static const String SELECTED_NOTIFICATION_SOUND_KEY = 'selectedSoundName';
  static const String DEFAULT_NOTIFICATION_SOUND = 'azan_2';
  static const String DEFAULT_NOTIFICATION_SOUND_ASSET =
      'assets/audio/$DEFAULT_NOTIFICATION_SOUND.mp3';
  static const String IS_MANUAL_PRAYER_TIME = 'is_manual_prayer_time';
  static const String manualCityLat = 'manual_city_lat';
  static const String manualCityLng = 'manual_city_lng';
  static const String HOME_LAYOUT_OVERRIDE_KEY = 'home_layout_override';
  static const String QURAN_MILESTONE_GOAL_KEY = 'quran_milestone_daily_goal';
  static const String QURAN_MILESTONE_PROGRESS_KEY =
      'quran_milestone_progress';

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
