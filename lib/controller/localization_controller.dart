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
    final preferredLanguageCode =
        savedLanguageCode ?? systemLocale.languageCode;

    final language = AppConstants.languages.firstWhere(
      (candidate) => candidate.languageCode == preferredLanguageCode,
      orElse: () => AppConstants.languages.first,
    );

    return Locale(
      language.languageCode!,
      savedLanguageCode != null
          ? (savedCountryCode ?? language.countryCode)
          : language.countryCode,
    );
  }

  // Set user new selected language
  Future<void> setLanguage(Locale locale, int index) async {
    Get.updateLocale(locale);
    _locale = locale;

    _selectedIndex = index;
    _refreshQuranTranslations();
    await saveLanguage(_locale);
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
  Future<void> saveLanguage(Locale locale) async {
    await sharedPreferences.setString(
      AppConstants.LANGUAGE_CODE,
      locale.languageCode,
    );
    await sharedPreferences.setString(
      AppConstants.COUNTRY_CODE,
      locale.countryCode!,
    );
  }

  //  User select language index set
  void setSelectIndex(int index) {
    _selectedIndex = index;
    update();
  }
}
