import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:salatime/service/app_update_service.dart';
import 'package:salatime/view/base/app_update_banner.dart';
import 'package:salatime/view/base/app_update_notice_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Translations extends Translations {
  _Translations(this.keys);
  @override
  final Map<String, Map<String, String>> keys;
}

void main() {
  late _Translations translations;
  setUpAll(() async {
    final values = <String, Map<String, String>>{};
    for (final language in ['fr', 'ar']) {
      values[language] = Map<String, String>.from(
        jsonDecode(File('assets/language/$language.json').readAsStringSync())
            as Map,
      );
    }
    translations = _Translations(values);
    final font = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/font/Roboto-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
  });
  tearDown(Get.reset);

  AppUpdateService service({
    Future<String> Function(Uri)? lookup,
    Future<bool> Function(Uri)? open,
  }) => AppUpdateService(
    enabled: true,
    platform: () => TargetPlatform.iOS,
    installedApp: () async => PackageInfo(
      appName: 'SalaTime',
      packageName: 'net.salatime.app',
      version: '1.0.28',
      buildNumber: '33',
    ),
    iosStoreContext: () async =>
        const IosStoreContext(storeCountry: 'MA', systemVersion: '26.0.1'),
    lookup:
        lookup ??
        ((_) async =>
            '{"resultCount":1,"results":[{"trackId":6812923710,"bundleId":"net.salatime.app","wrapperType":"software","version":"1.0.29","minimumOsVersion":"15.0"}]}'),
    openUrl: open ?? ((_) async => true),
  );

  Widget app({
    required Widget home,
    String language = 'fr',
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) => GetMaterialApp(
    translations: translations,
    locale: Locale(language),
    theme: ThemeData(
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2F5233),
        brightness: brightness,
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );

  Widget host(AppUpdateService check, List<bool> paused, {bool home = true}) =>
      AppUpdateNoticeHost(
        isHome: home,
        service: check,
        builder: (context, banner, pauseReview) {
          paused.add(pauseReview);
          return Scaffold(
            body: const Text('Prayer times'),
            bottomNavigationBar: banner,
          );
        },
      );

  testWidgets('home loads first, then the banner appears without a dialog', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var calls = 0;
    final delayed = Completer<String>();
    final check = service(
      lookup: (_) {
        calls++;
        return delayed.future;
      },
    );
    final paused = <bool>[];
    await tester.pumpWidget(app(home: host(check, paused)));
    expect(find.text('Prayer times'), findsOneWidget);
    expect(calls, 0);
    await tester.pump(AppUpdateNoticeHost.quietTime);
    await tester.pump();
    expect(calls, 1);
    expect(paused.last, isTrue);
    delayed.complete(
      '{"resultCount":1,"results":[{"trackId":6812923710,"bundleId":"net.salatime.app","wrapperType":"software","version":"1.0.29","minimumOsVersion":"15.0"}]}',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-update-banner')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('SalaTime 1.0.29 est disponible.'), findsOneWidget);
    expect(paused.last, isTrue);
    await tester.tap(find.byKey(const ValueKey('app-update-later')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-update-banner')), findsNothing);
    expect(paused.last, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('update opens the fixed store and offers retry after failure', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final pending = Completer<bool>();
    var launches = 0;
    Uri? opened;
    final check = service(
      open: (uri) {
        launches++;
        opened = uri;
        return pending.future;
      },
    );
    await tester.pumpWidget(app(home: host(check, [])));
    await tester.pump(AppUpdateNoticeHost.quietTime);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-update-now')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('app-update-now')));
    expect(launches, 1);
    expect(opened, Uri.parse('https://apps.apple.com/app/id6812923710'));
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(
      find.text('Impossible d’ouvrir la boutique. Réessayez.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('app-update-banner')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background and non-home pages never check or show a banner', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var calls = 0;
    final check = service(
      lookup: (_) async {
        calls++;
        return '{"resultCount":0,"results":[]}';
      },
    );
    await tester.pumpWidget(app(home: host(check, [], home: false)));
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 0);
    await tester.pumpWidget(app(home: host(check, [])));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final language in ['fr', 'ar']) {
    for (final size in [const Size(320, 640), const Size(800, 1280)]) {
      testWidgets('$language banner fits $size with text 200% in dark mode', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          app(
            language: language,
            scale: 2,
            brightness: Brightness.dark,
            home: Scaffold(
              bottomNavigationBar: AppUpdateBanner(
                version: '1.0.29',
                onUpdate: () {},
                onLater: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('app-update-now')), findsOneWidget);
        expect(find.byKey(const ValueKey('app-update-later')), findsOneWidget);
        final expectedDirection = language == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr;
        expect(
          Directionality.of(tester.element(find.byType(AppUpdateBanner))),
          expectedDirection,
        );
      });
    }
  }

  testWidgets('optional screenshot records the actual French banner', (
    tester,
  ) async {
    final path = Platform.environment['SALATIME_UPDATE_PREVIEW_PATH'];
    if (path == null) return;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      app(
        home: Scaffold(
          bottomNavigationBar: RepaintBoundary(
            key: boundaryKey,
            child: AppUpdateBanner(
              version: '1.0.29',
              onUpdate: () {},
              onLater: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(path).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}
