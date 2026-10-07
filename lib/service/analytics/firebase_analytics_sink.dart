import 'package:firebase_analytics/firebase_analytics.dart';

import 'app_analytics_service.dart';

/// Only fixed, parameter-free usage events are sent to Firebase.
class FirebaseAnalyticsSink implements AppAnalyticsSink {
  FirebaseAnalyticsSink(this.analytics);

  final FirebaseAnalytics analytics;
  int _selectionVersion = 0;
  bool _requestedEnabled = false;

  @override
  Future<void> setCollectionEnabled(bool enabled) {
    _requestedEnabled = enabled;
    final version = ++_selectionVersion;
    return _applySelection(version, enabled);
  }

  Future<void> _applySelection(int version, bool enabled) async {
    // Native defaults also keep collection off until bootstrap applies consent.
    final steps = <Future<void> Function()>[
      () => analytics.setAnalyticsCollectionEnabled(false),
      () => analytics.setConsent(
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
        analyticsStorageConsentGranted: enabled,
      ),
      () => analytics.setUserId(id: null),
      () => analytics.setDefaultEventParameters(null),
      () => analytics.setAnalyticsCollectionEnabled(enabled),
    ];
    for (final step in steps) {
      if (version != _selectionVersion) {
        return _applySelection(_selectionVersion, _requestedEnabled);
      }
      try {
        await step();
      } catch (_) {
        if (version != _selectionVersion) {
          return _applySelection(_selectionVersion, _requestedEnabled);
        }
        rethrow;
      }
      // A Future.timeout does not cancel a native call. Reconcile a late
      // completion with the newest choice instead of continuing an old opt-in.
      if (version != _selectionVersion) {
        return _applySelection(_selectionVersion, _requestedEnabled);
      }
    }
  }

  @override
  Future<void> screenViewed(String screenName) =>
      analytics.logScreenView(screenName: screenName, screenClass: 'SalaTime');

  @override
  Future<void> appAction(String eventName) =>
      analytics.logEvent(name: eventName);

  @override
  Future<void> resetData() => analytics.resetAnalyticsData();
}
