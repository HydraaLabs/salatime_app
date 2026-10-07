import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/helper/route_helper.dart';
import 'package:salatime/service/analytics/analytics_navigator_observer.dart';
import 'package:salatime/service/analytics/screen_catalog.dart';

MaterialPageRoute<void> page(String? name, {Object? arguments}) =>
    MaterialPageRoute<void>(
      settings: RouteSettings(name: name, arguments: arguments),
      builder: (_) => const SizedBox(),
    );

void main() {
  test('catalog covers every named page, excluding the tab shell', () {
    for (final route in RouteHelper.routes) {
      if (route.name == RouteHelper.bottomNavbar) continue;
      expect(
        AnalyticsScreenCatalog.fromRouteName(route.name),
        isNotNull,
        reason: route.name,
      );
    }
    expect(AnalyticsScreenCatalog.fromRouteName('/bottomNavbar'), isNull);
    for (var tab = 0; tab < 5; tab++) {
      expect(
        AnalyticsScreenCatalog.screenNames,
        contains(AnalyticsScreenCatalog.forTab(tab)),
      );
    }
    expect(
      AnalyticsScreenCatalog.screenNames.every(
        (name) => RegExp(r'^[a-z_]+$').hasMatch(name),
      ),
      isTrue,
    );
  });

  test('catalog covers explicit Get and Navigator route names across lib', () {
    final explicitNames = <String>{};
    final getRouteNames = RegExp(
      r'''\brouteName\s*:\s*(['"])(/[^'"\r\n]*)\1''',
    );
    final routeSettings = RegExp(r'\bRouteSettings\s*\(([^)]*)\)');
    final settingsName = RegExp(r'''\bname\s*:\s*(['"])(/[^'"\r\n]*)\1''');
    for (final file
        in Directory('lib')
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      final literals = <String>[
        ...getRouteNames.allMatches(source).map((match) => match.group(2)!),
        ...routeSettings
            .allMatches(source)
            .expand(
              (settings) => settingsName
                  .allMatches(settings.group(1)!)
                  .map((match) => match.group(2)!),
            ),
      ];
      for (final name in literals) {
        explicitNames.add(name);
        expect(
          AnalyticsScreenCatalog.fromRouteName(name),
          isNotNull,
          reason: '${file.path}: $name must map to a fixed analytics screen',
        );
      }
    }
    // Exercise both navigation forms, including pages absent from RouteHelper.
    expect(
      explicitNames,
      containsAll([
        '/account',
        '/offlineQuranReader',
        '/calculationMethod',
        '/notificationPhase',
        '/prayerMonth',
        '/athkarCategory',
      ]),
    );
  });

  test('only fixed catalog names are recorded, never arguments or queries', () {
    final seen = <String>[];
    final observer = AnalyticsNavigatorObserver(onScreenViewed: seen.add);
    final home = page('/home');
    final account = page('/account', arguments: 'private@example.com');
    final unsafe = page('/account?email=private@example.com');
    observer.didPush(home, null);
    observer.didPush(account, home);
    observer.didPush(unsafe, account);
    observer.didPush(page('/arbitrary/private'), unsafe);
    observer.didPush(page(null), unsafe);
    expect(seen, ['home', 'account']);
  });

  test('push, pop and top replacement report the newly visible page', () {
    final seen = <String>[];
    final observer = AnalyticsNavigatorObserver(onScreenViewed: seen.add);
    final home = page('/home');
    final quran = page('/suraList');
    final reader = page('/suraDetaile', arguments: {'surah': 18});
    final account = page('/account');
    observer.didPush(home, null);
    observer.didPush(quran, home);
    observer.didPush(reader, quran);
    observer.didReplace(newRoute: account, oldRoute: reader);
    observer.didPop(account, quran);
    observer.didPop(quran, home);
    expect(seen, [
      'home',
      'quran_surahs',
      'quran_reader',
      'account',
      'quran_surahs',
      'home',
    ]);
  });

  test('dialogs and removing or replacing a covered page do not count', () {
    final seen = <String>[];
    final observer = AnalyticsNavigatorObserver(onScreenViewed: seen.add);
    final home = page('/home');
    final settings = page('/settings');
    final dialog = RawDialogRoute<void>(
      settings: const RouteSettings(name: '/account'),
      pageBuilder: (_, animation, secondaryAnimation) => const SizedBox(),
    );
    observer.didPush(home, null);
    observer.didPush(settings, home);
    observer.didPush(dialog, settings);
    observer.didPop(dialog, settings);
    final quran = page('/suraList');
    observer.didReplace(newRoute: quran, oldRoute: home);
    observer.didRemove(quran, null);
    expect(seen, ['home', 'settings']);
  });

  test('adjacent copies deduplicate; returning after another page counts', () {
    final seen = <String>[];
    final observer = AnalyticsNavigatorObserver(onScreenViewed: seen.add);
    final first = page('/account');
    final second = page('/account');
    final settings = page('/settings');
    observer.didPush(first, null);
    observer.didPush(second, first);
    observer.didPop(second, first);
    observer.didPush(settings, first);
    observer.didRemove(settings, first);
    expect(seen, ['account', 'settings', 'account']);
  });

  test('statistics failures do not throw during navigation', () async {
    final sync = AnalyticsNavigatorObserver(
      onScreenViewed: (_) => throw StateError('SDK unavailable'),
    );
    final async = AnalyticsNavigatorObserver(
      onScreenViewed: (_) async => throw StateError('offline'),
    );
    expect(() => sync.didPush(page('/home'), null), returnsNormally);
    expect(() => async.didPush(page('/home'), null), returnsNormally);
    await Future<void>.delayed(Duration.zero);
  });
}
