# Startup translations and bundled assets (2026-10-14)

## Interface strings are read on demand

Before this change `di.init()` read and decoded the ten `assets/language/*.json`
files one after the other, before `runApp`. Only one of them is displayed.

- `AppTranslations` (`lib/helper/app_translations.dart`) reads one language
  file at a time and caches it. Concurrent requests share a single read; a
  failed read is retried on the next request.
- Startup loads the resolved language and the English fallback in parallel.
- `LocalizationController.setLanguage` and the cloud restoration in
  `AppPreferenceDevice._reload` register the chosen language with GetX
  (`Get.addTranslations`) before `Get.updateLocale`, so no raw key is ever
  displayed. A selection made while a language file is still being read wins
  over the older request.
- Tests use `test/support/memory_translations.dart`: widget tests run under a
  fake clock and cannot wait for a real asset read, so `AppTranslations.bundle`
  is replaced by an in-memory bundle in `setUp`.

## Unused bundled files removed

- `assets/quran/ar`, `assets/quran/bn` and `assets/quran/sp` were bundled but
  never read: chapters come from the canonical `assets/quran/en/s00N.json` and
  the displayed text from `assets/quran/translations/<language>/`.
  The chapter integrity test now covers the English files only.
- Twenty-one `assets/language/*.json` files had no matching entry in
  `AppConstants.languages` and were not reachable. Adding a language still
  means adding both its JSON file and its `LanguageModel`.

## Checks

- `flutter analyze`, `flutter test`, `./gradlew app:testDebugUnitTest`.
- Debug APK installed on an Android 15 emulator: onboarding, language switch
  to a language that was not loaded at startup, home screen.
