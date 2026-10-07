import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/service/mobile_auth_service.dart';
import 'package:salatime/service/analytics/app_analytics_service.dart';
import 'package:salatime/controller/localization_controller.dart';
import 'package:salatime/util/app_constants.dart';
import 'package:salatime/helper/additional_reminder_plan.dart';
import 'package:salatime/helper/prayer_notification_preferences.dart';
import 'cloud/preference_sync_scheduler.dart';
import 'cloud/preference_device.dart';
import 'cloud/preference_remote.dart';
import 'cloud/preference_sync_engine.dart';

class PreferenceCloudSync with WidgetsBindingObserver {
  PreferenceCloudSync._();
  static final instance = PreferenceCloudSync._();
  final status = 'cloud_signed_out'.obs;
  PreferenceSyncEngine? _engine;
  PreferenceSyncScheduler? _scheduler;
  final _changes = <StreamSubscription<void>>[];
  StreamSubscription<Locale>? _languageChanges;
  String? _selectedAccount;
  bool _accountSelected = false;
  int _accountGeneration = 0;
  bool _disposed = false;
  Worker? _authWorker;
  Future<void>? _initializing;
  bool _foreground = true;
  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    final auth = MobileAuthService.instance;
    Document? earlyLanguageChoice;
    _languageChanges = LocalizationController.languageChanges.listen((locale) {
      final choice = <String, dynamic>{
        'language': locale.languageCode,
        if (locale.countryCode != null) 'country': locale.countryCode,
      };
      earlyLanguageChoice = choice;
      noteLocalChange(languageChoice: choice);
    });
    final prefs = await SharedPreferences.getInstance();
    _engine = PreferenceSyncEngine(
      HttpPreferenceRemote(
        baseUrl: auth.baseUrl,
        onUnauthorized: (id, token) => clearRejectedSession(auth, id, token),
        tokenFor: (id) async {
          if (auth.user.value?.id != id) return null;
          final token = await auth.accessToken();
          return auth.user.value?.id == id ? token : null;
        },
      ),
      AppPreferenceDevice(prefs, scope: auth.baseUrl),
      initialLanguageChoice: prefs.containsKey(AppConstants.LANGUAGE_CODE)
          ? {
              'language': prefs.getString(AppConstants.LANGUAGE_CODE),
              'country': prefs.getString(AppConstants.COUNTRY_CODE),
            }
          : null,
      onStatus: (value) {
        if (_disposed) return;
        status.value = value;
        // The engine emits this only after the account copy and local cache
        // agree. Failed attempts, conflicts and partial updates are excluded.
        if (value == 'cloud_synced') {
          unawaited(
            AppAnalyticsService.instance.appAction(
              AppAnalyticsAction.cloudSync,
            ),
          );
        }
      },
    );
    if (earlyLanguageChoice != null) {
      _engine!.noteLanguageChoice(earlyLanguageChoice!);
    }
    _scheduler = PreferenceSyncScheduler(
      synchronize: () => _engine!.sync(),
      checkpoint: () => _engine!.checkpoint(),
      onError: (_) {
        if (!_disposed) status.value = 'cloud_offline';
      },
    );
    for (final stream in [
      PrayerNotificationPreferences.changes,
      AdditionalReminderPreferences.changes,
    ]) {
      _changes.add(stream.listen((_) => _notificationChanged()));
    }
    _authWorker = ever(auth.user, (_) => unawaited(_accountChanged()));
    WidgetsBinding.instance.addObserver(this);
    await auth.initialize();
    await _accountChanged();
  }

  static Future<void> clearRejectedSession(
    MobileAuthService auth,
    String account,
    String token,
  ) async {
    if (auth.user.value?.id != account) return;
    final current = await auth.accessToken();
    if (auth.user.value?.id == account && current == token) {
      await auth.clearSession(expectedToken: token);
    }
  }

  void _notificationChanged() {
    if (_disposed || _engine?.isApplyingPreferences == true) return;
    noteLocalChange();
  }

  /// Explicit UI edits must also be recorded while a cloud reload is running.
  /// The model streams above suppress only the cloud's own restoration signals.
  void noteLocalChange({Document? languageChoice}) {
    if (_disposed) return;
    if (languageChoice == null) {
      _engine?.noteLocalChange();
    } else {
      _engine?.noteLanguageChoice(languageChoice);
    }
    _scheduler?.noteChange();
    if (_engine?.account != null && status.value != 'cloud_conflict') {
      status.value = 'cloud_pending';
    }
  }

  Future<void> _accountChanged() async {
    if (_disposed) return;
    final profile = MobileAuthService.instance.user.value;
    final next = profile?.id;
    final language = profile?.locale;
    final languageFallback = language == null
        ? null
        : <String, dynamic>{
            'language': language,
            'country': AppConstants.languages
                .firstWhere((item) => item.languageCode == language)
                .countryCode,
          };
    if (_accountSelected && _selectedAccount == next) return;
    _accountSelected = true;
    _selectedAccount = next;
    final generation = ++_accountGeneration;
    _scheduler?.setEnabled(false);
    try {
      // Save the previous owner and restore the new local account copy first.
      // HTTP work starts separately; authentication callbacks never await it.
      await _engine?.selectAccount(
        next,
        synchronize: false,
        languageFallback: languageFallback,
      );
    } catch (_) {
      if (!_disposed && generation == _accountGeneration) {
        status.value = 'cloud_offline';
      }
    }
    if (_disposed || generation != _accountGeneration) return;
    _scheduler?.setEnabled(next != null);
    _scheduler?.setForeground(_foreground);
    if (_foreground) unawaited(_scheduler?.requestAutomatic());
  }

  Future<void> sync() async {
    await _scheduler?.requestNow();
  }

  Future<void> resolveConflict({required bool keepLocal}) async {
    try {
      await _engine?.resolveConflict(keepLocal: keepLocal);
    } catch (_) {
      status.value = 'cloud_offline';
    }
  }

  Future<void> _resume() async {
    final unchanged =
        _accountSelected &&
        _selectedAccount == MobileAuthService.instance.user.value?.id;
    await _accountChanged();
    if (unchanged && !_disposed) await _scheduler?.requestAutomatic();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _scheduler?.setForeground(_foreground);
    if (_foreground) unawaited(_resume());
  }

  void dispose() {
    _disposed = true;
    _scheduler?.dispose();
    _authWorker?.dispose();
    for (final subscription in _changes) {
      unawaited(subscription.cancel());
    }
    _changes.clear();
    unawaited(_languageChanges?.cancel());
    WidgetsBinding.instance.removeObserver(this);
  }
}
