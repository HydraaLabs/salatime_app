import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screen_catalog.dart';

/// Deliberately excludes account identifiers, searches and content metadata.
enum AppAnalyticsAction {
  accountSignIn('account_sign_in'),
  accountSignUp('account_sign_up'),
  cloudSync('cloud_sync'),
  accountSignOut('account_sign_out');

  const AppAnalyticsAction(this.eventName);
  final String eventName;
}

/// The application can use this interface without a configured Firebase app.
abstract interface class AppAnalyticsSink {
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> screenViewed(String screenName);
  Future<void> appAction(String eventName);
  Future<void> resetData();
}

typedef AnalyticsSinkFactory = Future<AppAnalyticsSink?> Function();

/// Best-effort usage statistics. No SDK operation is awaited by navigation.
///
/// The small in-memory queue covers screens opened while Firebase initializes.
/// Once initialized, the Firebase SDK handles batching and offline transport.
/// There is no server request, custom user ID or persisted application queue.
class AppAnalyticsService {
  AppAnalyticsService({
    required SharedPreferences preferences,
    AppAnalyticsSink? sink,
    AnalyticsSinkFactory? sinkFactory,
    bool? enabledInBuild,
    this.sdkTimeout = const Duration(seconds: 3),
  }) : _preferences = preferences,
       _sink = sink,
       _sinkFactory = sinkFactory,
       enabledInBuild =
           enabledInBuild ??
           (kReleaseMode ||
               const bool.fromEnvironment('SALATIME_ANALYTICS_DEBUG')),
       collectionPreference = ValueNotifier<bool>(
         preferences.getBool(preferenceKey) ?? true,
       );

  AppAnalyticsService._disabled()
    : _preferences = null,
      _sink = null,
      _sinkFactory = null,
      enabledInBuild = false,
      sdkTimeout = const Duration(seconds: 3),
      collectionPreference = ValueNotifier<bool>(true);

  /// Replaced once at bootstrap, before the first application screen is built.
  static AppAnalyticsService instance = AppAnalyticsService._disabled();

  static const preferenceKey = 'analytics_enabled';
  static const maxPendingEvents = 24;

  final SharedPreferences? _preferences;
  final AnalyticsSinkFactory? _sinkFactory;
  final bool enabledInBuild;
  final Duration sdkTimeout;

  /// The user's saved choice, independent of debug/profile build suppression.
  final ValueNotifier<bool> collectionPreference;

  AppAnalyticsSink? _sink;
  Future<void>? _initialization;
  bool _initializationFinished = false;
  bool _ready = false;
  bool _pumping = false;
  int _generation = 0;
  String? _lastScreen;
  final Queue<_PendingEvent> _pending = Queue<_PendingEvent>();

  bool get collectionEnabled => enabledInBuild && collectionPreference.value;
  bool get available => _ready && _sink != null;

  /// Call after runApp; callers can also safely ignore the returned future.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      _sink ??= await _sinkFactory?.call().timeout(sdkTimeout);
      final sink = _sink;
      if (sink != null) {
        final generation = _generation;
        await sink.setCollectionEnabled(collectionEnabled).timeout(sdkTimeout);
        if (generation == _generation) _ready = true;
      }
    } catch (_) {
      // Unavailable configuration, plugins or network cannot affect the app.
      _ready = false;
    } finally {
      _initializationFinished = true;
      if (!available || !collectionEnabled) _pending.clear();
      _startPump();
    }
  }

  /// Accept only the application's fixed screen catalog, never raw routes.
  Future<void> screenViewed(String screenName) async {
    if (!AnalyticsScreenCatalog.screenNames.contains(screenName) ||
        !collectionEnabled ||
        _lastScreen == screenName) {
      return;
    }
    _lastScreen = screenName;
    _enqueue(_PendingEvent.screen(screenName, _generation));
  }

  /// Actions have a fixed vocabulary and intentionally take no parameters.
  Future<void> appAction(AppAnalyticsAction action) async {
    if (!collectionEnabled) return;
    _enqueue(_PendingEvent.action(action.eventName, _generation));
  }

  void _enqueue(_PendingEvent event) {
    if (_initializationFinished && !available) return;
    if (_pending.length == maxPendingEvents) _pending.removeFirst();
    _pending.addLast(event);
    _startPump();
  }

  /// Disabling immediately stops our queue, even when native SDK work is slow.
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionPreference.value = enabled;
    _generation++;
    final generation = _generation;
    _ready = false;
    _pending.clear();
    _lastScreen = null;
    final sink = _sink;
    // Inform the adapter before awaiting disk storage or an older native call.
    // Its version guard prevents an in-flight opt-in from enabling later.
    final sdkUpdate = sink == null
        ? Future<void>.value()
        : _updateCollection(sink, generation, enabled);
    try {
      await _preferences?.setBool(preferenceKey, enabled);
    } catch (_) {
      // Keep the in-session choice when storage is temporarily unavailable.
    }
    await sdkUpdate;
    _startPump();
  }

  Future<void> _updateCollection(
    AppAnalyticsSink sink,
    int generation,
    bool enabled,
  ) async {
    try {
      await sink.setCollectionEnabled(collectionEnabled).timeout(sdkTimeout);
      if (!enabled) await sink.resetData().timeout(sdkTimeout);
      if (generation == _generation) _ready = true;
    } catch (_) {
      if (generation == _generation) _ready = false;
    }
  }

  void _startPump() {
    if (_pumping || !available || !collectionEnabled || _pending.isEmpty) {
      return;
    }
    _pumping = true;
    unawaited(_pump());
  }

  Future<void> _pump() async {
    try {
      while (available && collectionEnabled && _pending.isNotEmpty) {
        final event = _pending.removeFirst();
        if (event.generation != _generation) continue;
        try {
          final sink = _sink!;
          final future = event.isScreen
              ? sink.screenViewed(event.name)
              : sink.appAction(event.name);
          await future.timeout(sdkTimeout);
        } catch (_) {
          // Dropping a failed statistic is preferable to interrupting usage.
        }
      }
    } finally {
      _pumping = false;
      _startPump();
    }
  }
}

class _PendingEvent {
  const _PendingEvent.screen(this.name, this.generation) : isScreen = true;
  const _PendingEvent.action(this.name, this.generation) : isScreen = false;

  final String name;
  final int generation;
  final bool isScreen;
}
