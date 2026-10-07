import 'package:flutter/foundation.dart';

/// Release builds report real device failures. Development builds only report
/// when explicitly enabled, and use a separate environment by default.
class AppSentryConfiguration {
  final bool enabled;
  final String environment;

  const AppSentryConfiguration({
    required this.enabled,
    required this.environment,
  });

  factory AppSentryConfiguration.fromEnvironment() {
    return AppSentryConfiguration.forBuild(
      isRelease: kReleaseMode,
      enabledOverride: const bool.hasEnvironment('SALATIME_SENTRY_ENABLED')
          ? const bool.fromEnvironment('SALATIME_SENTRY_ENABLED')
          : null,
      environmentOverride: const String.fromEnvironment(
        'SALATIME_SENTRY_ENVIRONMENT',
      ),
    );
  }

  factory AppSentryConfiguration.forBuild({
    required bool isRelease,
    bool? enabledOverride,
    String environmentOverride = '',
  }) {
    final environment = environmentOverride.trim();
    return AppSentryConfiguration(
      enabled: enabledOverride ?? isRelease,
      environment: environment.isEmpty
          ? (isRelease ? 'production' : 'development')
          : environment,
    );
  }
}
