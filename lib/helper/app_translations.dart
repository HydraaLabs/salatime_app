import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:salatime/data/model/response/language_model.dart';
import 'package:salatime/util/app_constants.dart';

/// Bundled interface strings, read one language at a time.
///
/// Startup only needs the active language and the English fallback; the other
/// files are parsed when the user (or a cloud restoration) selects them.
class AppTranslations {
  AppTranslations._();

  /// Tests replace this with an in-memory bundle; widget tests cannot wait
  /// for a real asset read.
  static AssetBundle bundle = rootBundle;

  static final _cache = <String, Map<String, String>>{};
  static final _loading = <String, Future<Map<String, String>>>{};

  /// GetX translation key, e.g. `fr_FR`, for a supported language code.
  static String keyFor(String languageCode) {
    final language = modelFor(languageCode);
    return '${language.languageCode}_${language.countryCode}';
  }

  static LanguageModel modelFor(String languageCode) {
    return AppConstants.languages.firstWhere(
      (language) => language.languageCode == languageCode,
      orElse: () => AppConstants.languages.first,
    );
  }

  static Future<Map<String, String>> load(String languageCode) {
    final code = modelFor(languageCode).languageCode!;
    final cached = _cache[code];
    if (cached != null) return Future.value(cached);
    return _loading[code] ??= _read(code)
        .then((strings) => _cache[code] = strings)
        .whenComplete(() {
          _loading.remove(code);
        });
  }

  static Future<Map<String, String>> _read(String code) async {
    final raw = await bundle.loadString('assets/language/$code.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries) entry.key: entry.value.toString(),
    };
  }

  /// Makes `.tr` resolve [languageCode] before `Get.updateLocale` switches to it.
  static Future<void> ensureRegistered(String languageCode) async {
    final key = keyFor(languageCode);
    if (Get.translations.containsKey(key)) return;
    final strings = await load(languageCode);
    if (Get.translations.containsKey(key)) return;
    Get.addTranslations({key: strings});
  }

  static void resetForTest({AssetBundle? bundle}) {
    _cache.clear();
    _loading.clear();
    AppTranslations.bundle = bundle ?? rootBundle;
  }
}
