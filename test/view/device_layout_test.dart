import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/localization_controller.dart';
import 'package:zabi/controller/offline_quran_controller.dart';
import 'package:zabi/data/api/api_client.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/view/screens/home/modern/widget/modern_quick_actions.dart';
import 'package:zabi/view/screens/offline_quran/widgets/offline_quran_search.dart';
import 'package:zabi/view/screens/onboarding/first_launch_setup_screen.dart';

class _Translations extends Translations {
  _Translations(this.keys);
  @override
  final Map<String, Map<String, String>> keys;
}

class _SearchController extends OfflineQuranController {
  @override
  Future<void> initLoader() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final roboto = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/font/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/font/Roboto-Medium.ttf'))
      ..addFont(rootBundle.load('assets/font/Roboto-Bold.ttf'));
    final arabic = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/font/NotoSansArabic-Regular.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([roboto.load(), arabic.load(), icons.load()]);
  });
  tearDown(Get.reset);
  for (final locale in ['fr', 'ar']) {
    for (final size in [
      const Size(320, 568),
      const Size(640, 360),
      const Size(800, 1024),
    ]) {
      testWidgets('onboarding and quick actions fit $locale $size at 2x text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        Get.put(
          LocalizationController(
            sharedPreferences: prefs,
            apiClient: ApiClient(
              appBaseUrl: AppConstants.BASE_URL,
              sharedPreferences: prefs,
            ),
          ),
        );
        final strings = Map<String, String>.from(
          jsonDecode(
            (await tester.runAsync(
              () => rootBundle.loadString('assets/language/$locale.json'),
            ))!,
          ),
        );
        final key = GlobalKey();
        Widget app(Widget child) => GetMaterialApp(
          theme: modernLight.copyWith(
            textTheme: modernLight.textTheme.apply(
              fontFamilyFallback: ['NotoSansArabic'],
            ),
          ),
          locale: Locale(locale),
          translations: _Translations({locale: strings}),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: RepaintBoundary(key: key, child: child),
        );
        await tester.pumpWidget(app(const FirstLaunchSetupScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(strings['onboarding_next']!));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          app(
            const Scaffold(
              body: SingleChildScrollView(child: ModernQuickActions()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Optional local visual review output, without checked-in golden files.
        if (Platform.environment['SALATIME_QA_DIR'] case final String output) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(output).create(recursive: true);
            await File(
              '$output/actions-$locale-${size.width.toInt()}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }

  testWidgets('search text survives screen rebuild and clear empties field', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.put<OfflineQuranController>(_SearchController());
    await tester.pumpWidget(
      const GetMaterialApp(home: OfflineQuranSearchScreen()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'search that has no match');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byIcon(Icons.close), findsOneWidget);
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();
    expect(find.text('search that has no match'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('search that has no match'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
