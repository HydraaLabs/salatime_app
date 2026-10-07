import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/util/sentry_configuration.dart';

void main() {
  test(
    'release builds keep production error and native hang reporting enabled',
    () {
      final configuration = AppSentryConfiguration.forBuild(isRelease: true);

      expect(configuration.enabled, isTrue);
      expect(configuration.environment, 'production');
    },
  );

  test(
    'debug and simulator test builds do not initialize Sentry by default',
    () {
      final configuration = AppSentryConfiguration.forBuild(isRelease: false);

      expect(configuration.enabled, isFalse);
      expect(configuration.environment, 'development');
    },
  );

  test('CI explicitly disables reporting even if an archive is compiled', () {
    final configuration = AppSentryConfiguration.forBuild(
      isRelease: true,
      enabledOverride: false,
      environmentOverride: 'ci',
    );

    expect(configuration.enabled, isFalse);
    expect(configuration.environment, 'ci');
  });

  test('explicit development reporting is separated from production', () {
    final configuration = AppSentryConfiguration.forBuild(
      isRelease: false,
      enabledOverride: true,
    );

    expect(configuration.enabled, isTrue);
    expect(configuration.environment, 'development');
  });

  test(
    'release configuration explicitly restores reporting after simulator CI',
    () {
      final configuration = AppSentryConfiguration.forBuild(
        isRelease: true,
        enabledOverride: true,
        environmentOverride: 'production',
      );

      expect(configuration.enabled, isTrue);
      expect(configuration.environment, 'production');
    },
  );

  test(
    'empty environment override preserves the build-specific environment',
    () {
      expect(
        AppSentryConfiguration.forBuild(
          isRelease: true,
          environmentOverride: '  ',
        ).environment,
        'production',
      );
    },
  );
}
