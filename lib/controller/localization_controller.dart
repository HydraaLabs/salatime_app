import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api/api_client.dart';
import '../data/model/response/language_model.dart';
import '../util/app_constants.dart';
import 'quran_controller.dart';
import 'offline_quran_controller.dart';

class LocalizationController extends GetxController implements GetxService {
  static final _languageChanges = StreamController<Locale>.broadcast(
    sync: true,
  );

  /// Only deliberate selections emit; restoring cloud settings never does.
  static Stream<Locale> get languageChanges => _languageChanges.stream;
  final SharedPreferences sharedPreferences;
  final ApiClient apiClient;

  LocalizationController({
    required this.sharedPreferences,
    required this.apiClient,
  }) {
    loadCurrentLanguage();
  }

  Locale _locale = Locale(
    AppConstants.languages[0].languageCode!,
    AppConstants.languages[0].countryCode,
  );

  List<LanguageModel> _languages = [];

  Locale get locale => _locale;
  List<LanguageModel> get languages => _languages;

  int _selectedIndex = 0;
  Future<void> _languageSaveQueue = Future.value();
  int get selectedIndex => _selectedIndex;

  void loadCurrentLanguage() {
    final previousLanguage = _locale.languageCode;
    _locale = resolveLocale(
      systemLocale: WidgetsBinding.instance.platformDispatcher.locale,
      savedLanguageCode: sharedPreferences.getString(
        AppConstants.LANGUAGE_CODE,
      ),
      savedCountryCode: sharedPreferences.getString(AppConstants.COUNTRY_CODE),
    );

    for (int index = 0; index < AppConstants.languages.length; index++) {
      if (AppConstants.languages[index].languageCode == _locale.languageCode) {
        _selectedIndex = index;
        break;
      }
    }
    _languages = [];
    _languages.addAll(AppConstants.languages);
    update();
    if (previousLanguage != _locale.languageCode) _refreshQuranTranslations();
  }

  static Locale resolveLocale({
    required Locale systemLocale,
    String? savedLanguageCode,
    String? savedCountryCode,
  }) {
    String code(String value) =>
        value.trim().toLowerCase().split(RegExp('[-_]')).first;
    final saved = savedLanguageCode == null ? null : code(savedLanguageCode);
    final manual = AppConstants.languages.any(
      (item) => item.languageCode == saved,
    );
    final preferredLanguageCode = manual
        ? saved
        : code(systemLocale.languageCode);
    final language = AppConstants.languages.firstWhere(
      (candidate) => candidate.languageCode == preferredLanguageCode,
      orElse: () => AppConstants.languages.first,
    );

    return Locale(
      language.languageCode!,
      manual
          ? (savedCountryCode != null &&
                    RegExp(r'^[A-Z]{2}$').hasMatch(savedCountryCode)
                ? savedCountryCode
                : language.countryCode)
          : language.countryCode,
    );
  }

  // Set user new selected language
  Future<void> setLanguage(Locale locale, int index) async {
    locale = resolveLocale(
      systemLocale: WidgetsBinding.instance.platformDispatcher.locale,
      savedLanguageCode: locale.languageCode,
      savedCountryCode: locale.countryCode,
    );
    final updatedLocale = Get.updateLocale(locale);
    _locale = locale;
    _selectedIndex =
        index >= 0 &&
            index < AppConstants.languages.length &&
            AppConstants.languages[index].languageCode == locale.languageCode
        ? index
        : AppConstants.languages.indexWhere(
            (item) => item.languageCode == locale.languageCode,
          );
    // Invalidate an in-flight cloud restoration before preference writes yield.
    _languageChanges.add(locale);
    _refreshQuranTranslations();
    await saveLanguage(_locale);
    await updatedLocale;
    update();
  }

  void _refreshQuranTranslations() {
    final language = _locale.languageCode;
    if (Get.isRegistered<QuranController>()) {
      unawaited(
        Get.find<QuranController>().refreshTranslation(languageCode: language),
      );
    }
    if (Get.isRegistered<OfflineQuranController>()) {
      unawaited(
        Get.find<OfflineQuranController>().refreshTranslation(
          languageCode: language,
        ),
      );
    }
  }

  // Save language in local database
  Future<void> saveLanguage(Locale locale) {
    final write = _languageSaveQueue.then((_) async {
      await sharedPreferences.setString(
        AppConstants.LANGUAGE_CODE,
        locale.languageCode,
      );
      await sharedPreferences.setString(
        AppConstants.COUNTRY_CODE,
        locale.countryCode!,
      );
    });
    _languageSaveQueue = write.catchError((Object _) {});
    return write;
  }

  //  User select language index set
  void setSelectIndex(int index) {
    _selectedIndex = index;
    update();
  }
}
