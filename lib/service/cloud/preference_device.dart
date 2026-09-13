import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/controller/localization_controller.dart';
import 'package:salatime/controller/noti_sound_controller.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_reminder_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/controller/quran_milestone_controller.dart';
import 'package:salatime/controller/quran_settings_controller.dart';
import 'package:salatime/controller/theme_controller.dart';
import 'package:salatime/helper/additional_reminder_plan.dart';
import 'package:salatime/helper/islamic_calendar.dart';
import 'package:salatime/helper/prayer_notification_preferences.dart';
import 'package:salatime/helper/salat_waqt_service.dart';
import 'package:salatime/view/screens/notification/widgets/salat_waqt_repository.dart';
import 'preference_schema.dart';
import 'preference_sync_engine.dart';

class AppPreferenceDevice implements GuardedPreferenceDevice {
  AppPreferenceDevice(
    this.prefs, {
    required this.scope,
    this.reloadControllers = true,
  });
  final SharedPreferences prefs;
  final String scope;
  final bool reloadControllers;
  static const widgetChannel = MethodChannel('net.salatime.app/prayer_widget');
  static const silenceChannel = MethodChannel(
    'net.salatime.app/automatic_silence',
  );
  static final personalSoundsLocal = false.obs;
  static final silenceNeedsActivation = false.obs;
  static const fields = <String, String>{
    'themeMode': 'theme_mode',
    'language': 'language_code',
    'country': 'country_code',
    'homeLayout': 'home_layout_override',
    'use24HourFormat': 'is24HrFormat',
    'calculationMethod': 'selectedCalculationMethod',
    'madhab': 'selectedPrayerMadhab',
    'hijriOffset': 'hijri_date_adjustment_v1',
  };
  static const sounds = <String, String>{
    'adhan': 'selectedSoundName',
    'before': 'before_adhan_reminder_sound',
    'after': 'after_adhan_reminder_sound',
  };
  static const reminders = <String, String>{
    'beforeEnabled': 'before_adhan_reminder_enabled',
    'afterEnabled': 'after_adhan_reminder_enabled',
    'beforeMinutes': 'before_adhan_reminder_minutes',
    'afterMinutes': 'after_adhan_reminder_minutes',
  };
  static const reader = <String, String>{
    'arabicSize': 'arabic_font_size_key',
    'translationSize': 'tanslate_font_size_key',
    'font': 'selectedFont',
    'translator': 'selectedTranslatorId',
    'translation': 'apiTranslateDropdown',
    'goal': 'quran_milestone_daily_goal',
  };
  dynamic _json(String key, dynamic fallback) {
    try {
      return jsonDecode(prefs.getString(key) ?? '');
    } catch (_) {
      return fallback;
    }
  }

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<Document> _native(MethodChannel channel) async {
    if (!_android &&
        (kIsWeb ||
            defaultTargetPlatform != TargetPlatform.iOS ||
            channel.name != widgetChannel.name)) {
      return {};
    }
    try {
      return await channel.invokeMapMethod<String, dynamic>('get') ?? {};
    } on MissingPluginException {
      return {};
    } on PlatformException {
      return {};
    }
  }

  @override
  Future<Document> capture() async {
    final language =
        prefs.getString('language_code') ?? (Get.locale?.languageCode ?? 'en');
    final widgets = await _native(widgetChannel);
    final silence = await _native(silenceChannel);
    final savedSilence =
        _json('cloud_silence_options_v1', <String, dynamic>{}) as Map;
    if (silence['enabled'] == true) {
      await prefs.remove('cloud_silence_pending_v1');
    }
    silenceNeedsActivation.value =
        prefs.getBool('cloud_silence_pending_v1') ?? false;
    final extra = await AdditionalReminderPreferences.load(prefs);
    final prayerSettings = await PrayerNotificationPreferences.loadOverrides(
      prefs,
    );
    bool phaseEnabled(PrayerNotificationPhase phase) =>
        PrayerNotificationPrayer.values.any(
          (prayer) => PrayerNotificationSetting.fromJson(
            prayer,
            phase,
            prayerSettings[phase.name]?[prayer.name],
          ).enabled,
        );
    final defaults = <String, dynamic>{
      'schemaVersion': 1,
      'themeMode': 'daylight',
      'language': language,
      'country':
          const {
            'en': 'US',
            'fr': 'FR',
            'ar': 'SA',
            'tr': 'TR',
            'ur': 'PK',
            'id': 'ID',
            'ms': 'MY',
            'es': 'ES',
            'bn': 'BD',
            'fa': 'AF',
          }[language] ??
          'US',
      'homeLayout': 'modern',
      'use24HourFormat': true,
      'calculationMethod': '1',
      'madhab': 'STANDARD',
      'hijriOffset': 0,
    };
    for (final e in fields.entries) {
      final v = prefs.get(e.value);
      if (v != null) defaults[e.key] = v;
    }
    personalSoundsLocal.value =
        sounds.values.any(
          (key) => (prefs.getString(key) ?? '').startsWith('custom_'),
        ) ||
        extra.any((e) => e.sound.startsWith('custom_')) ||
        PreferenceSchema.flatten(prayerSettings).entries.any(
          (e) =>
              e.key.endsWith('.sound') &&
              e.value is String &&
              (e.value as String).startsWith('custom_'),
        );
    return PreferenceSchema.clean({
      ...defaults,
      'prayerAdjustments': {
        for (final key in [
          'fajr',
          'sunrise',
          'zuhr',
          'asr',
          'maghrib',
          'isha',
          'sehri',
          'iftar',
        ])
          key: 0,
        ...(_json('prayerAdjustments', <String, dynamic>{}) as Map),
      },
      'sounds': {
        for (final e in sounds.entries)
          e.key:
              prefs.getString(e.value) ??
              (e.key == 'adhan' ? 'azan_2' : 'noti_beep'),
      },
      'reminders': {
        for (final e in reminders.entries)
          e.key: switch (e.key) {
            'beforeEnabled' => phaseEnabled(PrayerNotificationPhase.before),
            'afterEnabled' => phaseEnabled(PrayerNotificationPhase.after),
            _ => prefs.get(e.value) ?? 5,
          },
      },
      'prayerNotifications': {
        for (var id = 1; id <= 5; id++)
          '$id': PrayerNotificationSetting.fromJson(
            PrayerNotificationPrayer.fromLegacyId(id),
            PrayerNotificationPhase.adhan,
            prayerSettings['adhan']?[PrayerNotificationPrayer.fromLegacyId(
              id,
            ).name],
          ).enabled,
      },
      'prayerNotificationSettings': prayerSettings,
      'widgets': {
        'countdown': true,
        'seconds': true,
        'city': true,
        'date': true,
        'illustration': true,
        'opacity': 100,
        ...(_json('cloud_widget_options_v1', {}) as Map),
        ...widgets,
      },
      'silence': {
        'enabled': false,
        'delay': 5,
        'duration': 20,
        'fridayDuration': 45,
        'fridayOverride': false,
        'prayers': [1, 2, 3, 4, 5],
        ...savedSilence,
        ...silence,
        if (silenceNeedsActivation.value) 'enabled': true,
      },
      'reader': {
        'arabicSize': 22.0,
        'translationSize': 14.0,
        'font': 'Scheherazade New',
        'translator': '1',
        'translation': 'English',
        'goal': 20,
        for (final e in reader.entries)
          if (prefs.get(e.value) != null) e.key: prefs.get(e.value),
      },
      'additionalReminders': {for (final e in extra) e.type.name: e.toJson()},
    });
  }

  Future<void> _store(String key, dynamic value, {bool decimal = false}) async {
    bool success;
    if (decimal && value is num) {
      success = await prefs.setDouble(key, value.toDouble());
    } else if (value is bool) {
      success = await prefs.setBool(key, value);
    } else if (value is int) {
      success = await prefs.setInt(key, value);
    } else if (value is double) {
      success = await prefs.setDouble(key, value);
    } else if (value is String) {
      success = await prefs.setString(key, value);
    } else {
      throw const FormatException('Unsupported preference');
    }
    if (!success) throw StateError('Preference could not be saved');
  }

  @override
  Future<void> apply(Document raw) async {
    await applyIfCurrent(raw, () => true);
  }

  @override
  Future<bool> applyIfCurrent(Document raw, bool Function() isCurrent) async {
    final before = await capture();
    if (!isCurrent()) return false;
    final next = PreferenceSchema.clean(raw);
    final changed = <String>{
      for (final key in next.keys)
        if (!PreferenceSyncEngine.same(before[key], next[key])) key,
    };
    final restoreLegacyPrayerSettings =
        !next.containsKey('prayerNotificationSettings') &&
        next.containsKey('prayerNotifications');
    if (restoreLegacyPrayerSettings) changed.add('prayerNotificationSettings');
    if (changed.isEmpty) return true;
    Future<bool> stopRestoration() async {
      // Earlier groups may already be durable. Refresh controllers from current
      // storage, which includes the user's newer choice, before deferring the rest.
      if (reloadControllers) await _reload(changed);
      return false;
    }

    for (final e in fields.entries) {
      if (!isCurrent()) return stopRestoration();
      if (changed.contains(e.key)) await _store(e.value, next[e.key]);
    }
    for (final group in {
      'sounds': sounds,
      'reminders': reminders,
      'reader': reader,
    }.entries) {
      if (!changed.contains(group.key)) continue;
      final values = next[group.key] as Map;
      final old = before[group.key] as Map? ?? {};
      for (final e in group.value.entries) {
        if (!isCurrent()) return stopRestoration();
        if (values.containsKey(e.key) &&
            !PreferenceSyncEngine.same(old[e.key], values[e.key])) {
          await _store(
            e.value,
            values[e.key],
            decimal: group.key == 'reader' && e.key.endsWith('Size'),
          );
        }
      }
    }
    if (!isCurrent()) return stopRestoration();
    if (changed.contains('prayerAdjustments')) {
      await prefs.setString(
        'prayerAdjustments',
        jsonEncode(next['prayerAdjustments']),
      );
    }
    if (changed.contains('additionalReminders')) {
      // Preserve personal files already chosen locally when their exported fallback is unchanged.
      final current = await AdditionalReminderPreferences.load(prefs);
      if (!isCurrent()) return stopRestoration();
      final incomingRaw = next['additionalReminders'] as Map;
      final incoming = {
        for (final setting in AdditionalReminderPreferences.decode(incomingRaw))
          if (incomingRaw.containsKey(setting.type.name) ||
              incomingRaw.containsKey('mondayThursday') &&
                  {'monday', 'thursday'}.contains(setting.type.name))
            setting.type.name: setting.toJson(),
      };
      final previous = before['additionalReminders'] as Map;
      final result = <String, dynamic>{};
      for (final setting in current) {
        final row = incoming[setting.type.name];
        if (row == null) {
          result[setting.type.name] = setting.toJson();
          continue;
        }
        result[setting.type.name] = {
          ...setting.toJson(),
          ...row,
          if (setting.sound.startsWith('custom_') &&
              row['sound'] == previous[setting.type.name]?['sound'])
            'sound': setting.sound,
        };
      }
      await AdditionalReminderPreferences.save(
        AdditionalReminderPreferences.decode(result),
        prefs,
      );
    }
    if (!isCurrent()) return stopRestoration();
    if (changed.contains('prayerNotifications')) {
      final repo = SalatWaqtRepository();
      final empty = (await repo.getSalatWaqtList()).isEmpty;
      if (!isCurrent()) return stopRestoration();
      if (empty) await repo.seedSalatWaqt();
      for (final e in (next['prayerNotifications'] as Map).entries) {
        if (!isCurrent()) return stopRestoration();
        await repo.setNotificationEnabled(int.parse(e.key), e.value);
      }
    }
    if (!isCurrent()) return stopRestoration();
    if (restoreLegacyPrayerSettings) {
      await PrayerNotificationPreferences.remigrateLegacy(prefs);
    } else if (changed.contains('prayerNotificationSettings')) {
      final current = PreferenceSchema.flatten(
        await PrayerNotificationPreferences.loadOverrides(prefs),
      );
      if (!isCurrent()) return stopRestoration();
      final previous = PreferenceSchema.flatten(
        Map<String, dynamic>.from(before['prayerNotificationSettings'] as Map),
      );
      final incoming = PreferenceSchema.flatten(
        Map<String, dynamic>.from(next['prayerNotificationSettings'] as Map),
      );
      for (final entry in current.entries) {
        if (entry.key.endsWith('.sound') &&
            entry.value is String &&
            (entry.value as String).startsWith('custom_') &&
            incoming.containsKey(entry.key) &&
            incoming[entry.key] == previous[entry.key]) {
          incoming[entry.key] = entry.value;
        }
      }
      await PrayerNotificationPreferences.replaceOverrides(
        PreferenceSchema.expand(incoming),
        prefs,
      );
    }
    if (!isCurrent()) return stopRestoration();
    if (changed.contains('widgets')) {
      await prefs.setString(
        'cloud_widget_options_v1',
        jsonEncode(next['widgets']),
      );
      if (!isCurrent()) return stopRestoration();
      if (_android ||
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          await widgetChannel.invokeMethod('set', next['widgets']);
        } on MissingPluginException {
          /* Older native binary. */
        }
      }
    }
    if (!isCurrent()) return stopRestoration();
    if (changed.contains('silence')) {
      final requested = Map<String, dynamic>.from(next['silence']);
      await prefs.setString('cloud_silence_options_v1', jsonEncode(requested));
      final native = await _native(silenceChannel);
      if (!isCurrent()) return stopRestoration();
      final needsActivation =
          requested['enabled'] == true && native['enabled'] != true;
      await prefs.setBool('cloud_silence_pending_v1', needsActivation);
      silenceNeedsActivation.value = needsActivation;
      // Enabling a system DND rule always remains a deliberate action on this device.
      if (needsActivation) requested.remove('enabled');
      if (_android) {
        try {
          await silenceChannel.invokeMethod('set', requested);
        } on MissingPluginException {
          // Native settings will be restored after an Android binary update.
        } on PlatformException {
          // The desired values remain pending; OS permission is never requested here.
        }
      }
    }
    if (reloadControllers) await _reload(changed);
    return true;
  }

  Future<void> _reload(Set<String> changed) async {
    if (changed.contains('themeMode') && Get.isRegistered<ThemeController>()) {
      await Get.find<ThemeController>().setMode(prefs.getString('theme_mode')!);
    }
    if ((changed.contains('language') || changed.contains('country')) &&
        Get.isRegistered<LocalizationController>()) {
      final c = Get.find<LocalizationController>();
      c.loadCurrentLanguage();
      await Get.updateLocale(c.locale);
    }
    if (changed.contains('homeLayout') &&
        Get.isRegistered<HomeLayoutController>()) {
      await Get.find<HomeLayoutController>().setUserLayout(
        prefs.getString('home_layout_override')!,
      );
    }
    if (changed.contains('prayerAdjustments') &&
        Get.isRegistered<PrayerTimeAdjustmentController>()) {
      final c = Get.find<PrayerTimeAdjustmentController>();
      await c.init();
      c.update();
    }
    if (changed.contains('sounds') && Get.isRegistered<NotiSoundController>()) {
      await Get.find<NotiSoundController>().loadSelectedSound();
    }
    if ((changed.contains('reminders') || changed.contains('sounds')) &&
        Get.isRegistered<PrayerReminderController>()) {
      await Get.find<PrayerReminderController>().loadPreferences();
    }
    if (changed.contains('hijriOffset')) {
      await IslamicCalendarPreferences.initialize(prefs);
    }
    if (changed.contains('reader') && Get.isRegistered<SettingsController>()) {
      final c = Get.find<SettingsController>();
      c.getArabicFontSizeFromLocalStorage();
      c.getTranslateFontSizeFromLocalStorage();
      await c.loadArabicFontPreference();
      c.loadSavedApiTranslateDropdownValue();
    }
    if (changed.contains('reader') &&
        Get.isRegistered<QuranMilestoneController>()) {
      Get.find<QuranMilestoneController>().dailyGoal.value =
          prefs.getInt('quran_milestone_daily_goal') ?? 20;
    }
    if (Get.isRegistered<PrayerTimeController>()) {
      final prayer = Get.find<PrayerTimeController>();
      prayer.is24HourFormat.value = prefs.getBool('is24HrFormat') ?? true;
      if (changed.any(
        {
          'calculationMethod',
          'madhab',
          'prayerAdjustments',
          'sounds',
          'reminders',
          'prayerNotifications',
          'prayerNotificationSettings',
          'additionalReminders',
          'hijriOffset',
          'language',
          'use24HourFormat',
        }.contains,
      )) {
        await SalatWaqtService.requestRefresh();
      }
    }
  }

  String _cacheKey(String key) =>
      'cloud_sync_v1_${base64Url.encode(utf8.encode('$scope|$key'))}';
  @override
  Future<Document?> readCache(String key) async {
    final value = _json(_cacheKey(key), null);
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  @override
  Future<void> writeCache(String key, Document value) async {
    if (!await prefs.setString(_cacheKey(key), jsonEncode(value))) {
      throw StateError('Cloud outbox could not be saved');
    }
  }
}
