import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/firebase_options.dart';

import 'app_analytics_service.dart';
import 'firebase_analytics_sink.dart';

/// Native configuration belongs to SalaTime's registered Android/iOS apps.
/// Preview companions and unsupported platforms never initialize this SDK.
AppAnalyticsService createFirebaseAnalyticsService(
  SharedPreferences preferences,
) {
  final enabledInBuild =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      (kReleaseMode || const bool.fromEnvironment('SALATIME_ANALYTICS_DEBUG'));

  return AppAnalyticsService(
    preferences: preferences,
    enabledInBuild: enabledInBuild,
    sinkFactory: () async {
      if (!enabledInBuild) return null;
      final package = await PackageInfo.fromPlatform();
      if (package.packageName != 'net.salatime.app') return null;
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return FirebaseAnalyticsSink(FirebaseAnalytics.instance);
    },
  );
}
