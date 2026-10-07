import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Read from StoreKit and UIDevice, rather than the UI language or GPS.
class IosStoreContext {
  const IosStoreContext({
    required this.storeCountry,
    required this.systemVersion,
  });

  final String storeCountry;
  final String systemVersion;

  static IosStoreContext? fromMap(Map<String, dynamic>? values) {
    if (values?['storeCountry'] is! String ||
        values?['systemVersion'] is! String) {
      return null;
    }
    final context = IosStoreContext(
      storeCountry: (values!['storeCountry'] as String).toUpperCase(),
      systemVersion: values['systemVersion'] as String,
    );
    return context.isValid ? context : null;
  }

  bool get isValid =>
      RegExp(r'^[A-Za-z]{2}$').hasMatch(storeCountry) &&
      AppUpdateService._numericVersion(systemVersion) != null;
}

/// A store-confirmed update. Store links are fixed, never taken from a payload.
class AvailableAppUpdate {
  const AvailableAppUpdate.android(int versionCode)
    : platform = TargetPlatform.android,
      key = 'android:$versionCode',
      version = null;

  const AvailableAppUpdate.ios(String latestVersion)
    : platform = TargetPlatform.iOS,
      key = 'ios:$latestVersion',
      version = latestVersion;

  final TargetPlatform platform;
  final String key;
  final String? version;

  Uri get storeUri => platform == TargetPlatform.iOS
      ? AppUpdateService.appStoreUri
      : AppUpdateService.playStoreUri;
}

/// Optional store checks run after the first frame, outside prayer startup.
/// No account details, GPS position or SalaTime server requests are involved.
class AppUpdateService {
  AppUpdateService({
    Future<PackageInfo> Function()? installedApp,
    Future<AppUpdateInfo> Function()? androidUpdate,
    Future<String> Function(Uri)? lookup,
    Future<SharedPreferences> Function()? preferences,
    Future<bool> Function(Uri)? openUrl,
    TargetPlatform Function()? platform,
    Future<IosStoreContext?> Function()? iosStoreContext,
    DateTime Function()? now,
    bool? enabled,
    this.timeout = const Duration(seconds: 5),
  }) : _installedApp = installedApp ?? PackageInfo.fromPlatform,
       _androidUpdate = androidUpdate ?? InAppUpdate.checkForUpdate,
       _lookup = lookup ?? _fetchLookup,
       _preferences = preferences ?? SharedPreferences.getInstance,
       _openUrl = openUrl ?? _launchExternal,
       _platform = platform ?? (() => defaultTargetPlatform),
       _iosStoreContext = iosStoreContext ?? _readIosStoreContext,
       _now = now ?? DateTime.now,
       _enabled = enabled ?? (!kIsWeb && kReleaseMode);

  static final instance = AppUpdateService();
  static const applicationId = 'net.salatime.app';
  static const appStoreId = 6812923710;
  static const snoozeKey = 'app_update_notice_snooze_v1';
  static const checkInterval = Duration(hours: 6);
  static const retryInterval = Duration(minutes: 30);
  static const snoozeDuration = Duration(days: 1);
  static final playStoreUri = Uri.https(
    'play.google.com',
    '/store/apps/details',
    {'id': applicationId},
  );
  static final appStoreUri = Uri.https('apps.apple.com', '/app/id$appStoreId');

  final Future<PackageInfo> Function() _installedApp;
  final Future<AppUpdateInfo> Function() _androidUpdate;
  final Future<String> Function(Uri) _lookup;
  final Future<SharedPreferences> Function() _preferences;
  final Future<bool> Function(Uri) _openUrl;
  final TargetPlatform Function() _platform;
  final Future<IosStoreContext?> Function() _iosStoreContext;
  final DateTime Function() _now;
  final bool _enabled;
  final Duration timeout;
  final availableUpdate = ValueNotifier<AvailableAppUpdate?>(null);

  Future<AvailableAppUpdate?>? _pending;
  AvailableAppUpdate? _cachedUpdate;
  DateTime? _nextCheck;
  DateTime? _snoozedUntil;
  String? _snoozedVersion;

  static Future<IosStoreContext?> _readIosStoreContext() async {
    const channel = MethodChannel('net.salatime.app/store_updates');
    final values = await channel.invokeMapMethod<String, dynamic>('getContext');
    return IosStoreContext.fromMap(values);
  }

  static Future<String> _fetchLookup(Uri uri) async {
    final client = http.Client();
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200 ||
          response.bodyBytes.length > 1024 * 1024) {
        throw const FormatException('App Store lookup unavailable');
      }
      return response.body;
    } finally {
      client.close();
    }
  }

  static Future<bool> _launchExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<AvailableAppUpdate?> checkForUpdate() {
    if (_pending != null) return _pending!;
    final pending = _check();
    _pending = pending;
    unawaited(pending.then((_) => _pending = null));
    return pending;
  }

  Future<AvailableAppUpdate?> _check() async {
    final target = _platform();
    if (!_enabled ||
        (target != TargetPlatform.android && target != TargetPlatform.iOS)) {
      return _publish(null);
    }
    try {
      if (_nextCheck != null && _now().isBefore(_nextCheck!)) {
        return _publish(_visibleUpdate());
      }
      final installed = await _installedApp().timeout(timeout);
      // Preview/sideload package variants must never point at production.
      if (installed.packageName != applicationId) return _publish(null);
      final preferences = await _preferences().timeout(timeout);
      _restoreSnooze(preferences);
      AvailableAppUpdate? update;
      if (target == TargetPlatform.android) {
        final info = await _androidUpdate().timeout(timeout);
        final installedCode = int.tryParse(installed.buildNumber);
        final code = info.availableVersionCode;
        if (info.packageName == applicationId &&
            installedCode != null &&
            code != null &&
            code > installedCode &&
            (info.updateAvailability == UpdateAvailability.updateAvailable ||
                info.updateAvailability ==
                    UpdateAvailability.developerTriggeredUpdateInProgress)) {
          update = AvailableAppUpdate.android(code);
        }
      } else {
        final context = await _iosStoreContext().timeout(timeout);
        // Unknown storefront/system state cannot establish an installable
        // update. Never replace it with a UI-locale or US-country guess.
        if (context == null || !context.isValid) {
          throw const FormatException('App Store context unavailable');
        }
        final uri = Uri.https('itunes.apple.com', '/lookup', {
          'id': '$appStoreId',
          'country': context.storeCountry.toUpperCase(),
          'entity': 'software',
        });
        update = updateFromAppStore(
          await _lookup(uri).timeout(timeout),
          installed.version,
          systemVersion: context.systemVersion,
        );
      }
      _cachedUpdate = update;
      _nextCheck = _now().add(checkInterval);
      return _publish(_visibleUpdate());
    } catch (_) {
      // Offline, Play not installed, unpublished apps and invalid store data
      // must all leave SalaTime usable and avoid promising a false update.
      _cachedUpdate = null;
      _nextCheck = _now().add(retryInterval);
      return _publish(null);
    }
  }

  AvailableAppUpdate? _visibleUpdate() {
    if (_cachedUpdate?.key == _snoozedVersion &&
        _snoozedUntil != null &&
        _now().isBefore(_snoozedUntil!)) {
      return null;
    }
    return _cachedUpdate;
  }

  AvailableAppUpdate? _publish(AvailableAppUpdate? update) {
    if (availableUpdate.value?.key != update?.key) {
      availableUpdate.value = update;
    }
    return update;
  }

  void _restoreSnooze(SharedPreferences preferences) {
    try {
      final value = jsonDecode(preferences.getString(snoozeKey) ?? '{}');
      if (value is Map && value['version'] is String && value['until'] is int) {
        final until = DateTime.fromMillisecondsSinceEpoch(
          value['until'] as int,
        );
        if (_snoozedUntil == null || until.isAfter(_snoozedUntil!)) {
          _snoozedUntil = until;
          _snoozedVersion = value['version'] as String;
        }
      }
    } catch (_) {
      // A damaged optional local setting should not hide an update forever.
    }
  }

  Future<void> dismiss(AvailableAppUpdate update) async {
    _snoozedVersion = update.key;
    _snoozedUntil = _now().add(snoozeDuration);
    _publish(null);
    try {
      final preferences = await _preferences().timeout(timeout);
      await preferences
          .setString(
            snoozeKey,
            jsonEncode({
              'version': _snoozedVersion,
              'until': _snoozedUntil!.millisecondsSinceEpoch,
            }),
          )
          .timeout(timeout);
    } catch (_) {
      // Still dismissed for this session if local storage is unavailable.
    }
  }

  Future<bool> openStore(AvailableAppUpdate update) async {
    try {
      return await _openUrl(update.storeUri).timeout(timeout);
    } catch (_) {
      return false;
    }
  }

  static AvailableAppUpdate? updateFromAppStore(
    String response,
    String installedVersion, {
    required String systemVersion,
  }) {
    try {
      final payload = jsonDecode(response);
      if (payload is! Map || payload['resultCount'] != 1) return null;
      final results = payload['results'];
      if (results is! List || results.length != 1) return null;
      final app = results.single;
      if (app is! Map ||
          app['trackId'] != appStoreId ||
          app['bundleId'] != applicationId ||
          app['wrapperType'] != 'software' ||
          app['version'] is! String ||
          app['minimumOsVersion'] is! String) {
        return null;
      }
      final version = app['version'] as String;
      final minimumOS = _numericVersion(app['minimumOsVersion'] as String);
      final system = _numericVersion(systemVersion);
      if (minimumOS == null ||
          system == null ||
          _compareNumericVersions(minimumOS, system) > 0) {
        return null;
      }
      return isNewerVersion(version, installedVersion)
          ? AvailableAppUpdate.ios(version)
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Apple marketing versions are numeric dot-separated components. Build
  /// numbers do not constitute a new App Store release of the same version.
  static bool isNewerVersion(String available, String installed) {
    final latest = _numericVersion(available);
    final current = _numericVersion(installed.split('+').first);
    if (latest == null || current == null) return false;
    return _compareNumericVersions(latest, current) > 0;
  }

  static List<int>? _numericVersion(String version) {
    if (!RegExp(r'^\d+(?:\.\d+){0,2}$').hasMatch(version)) return null;
    final parts = version.split('.').map(int.tryParse).toList();
    return parts.any((part) => part == null) ? null : parts.cast<int>();
  }

  static int _compareNumericVersions(List<int> latest, List<int> current) {
    for (var i = 0; i < 3; i++) {
      final a = i < latest.length ? latest[i] : 0;
      final b = i < current.length ? current[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }
}
