import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/home_layout_controller.dart';
import 'package:zabi/controller/theme_controller.dart';
import 'package:zabi/helper/theme_helper.dart';
import 'package:zabi/util/app_constants.dart';
import 'package:zabi/view/screens/settings/widgets/theme_mode_dw_widget.dart';

class _Translations extends Translations {
  _Translations(this.keys);
  @override
  final Map<String, Map<String, String>> keys;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final roboto = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/font/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/font/Roboto-Medium.ttf'));
    final arabic = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/font/NotoSansArabic-Regular.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([roboto.load(), arabic.load(), icons.load()]);
  });
  tearDown(Get.reset);

  for (final layout in [
    HomeLayoutController.modern,
    HomeLayoutController.classic,
  ]) {
    for (final locale in ['fr', 'ar']) {
      testWidgets(
        'theme settings apply and persist in $layout/$locale at 2x text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({
            AppConstants.HOME_LAYOUT_OVERRIDE_KEY: layout,
          });
          final prefs = await SharedPreferences.getInstance();
          Get.put(HomeLayoutController(sharedPreferences: prefs));
          var now = DateTime(2026, 9, 9, 12);
          final controller = Get.put(
            ThemeController(sharedPreferences: prefs, now: () => now),
          );
          final strings = Map<String, String>.from(
            jsonDecode(
              (await tester.runAsync(
                () => rootBundle.loadString('assets/language/$locale.json'),
              ))!,
            ),
          );
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            GetBuilder<ThemeController>(
              builder: (theme) {
                final appTheme = getAppTheme(theme.darkTheme);
                return GetMaterialApp(
                  theme: appTheme.copyWith(
                    textTheme: appTheme.textTheme.apply(
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
                  home: RepaintBoundary(
                    key: boundaryKey,
                    child: const Scaffold(
                      body: SingleChildScrollView(child: ThemeModeDWWidget()),
                    ),
                  ),
                );
              },
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const PageStorageKey('appearance-settings')),
            findsOneWidget,
          );
          expect(find.byType(ExpansionTile), findsOneWidget);
          expect(find.byType(RadioListTile<String>), findsNothing);
          final heading = find.text(strings['theme_mode_title']!);
          await tester.tap(heading);
          await tester.pumpAndSettle();
          for (final key in [
            'theme_mode_light',
            'theme_mode_dark',
            'theme_mode_auto',
          ]) {
            expect(find.text(strings[key]!), findsOneWidget);
          }

          Future<void> select(String mode, Brightness brightness) async {
            final option = find.byWidgetPredicate(
              (widget) =>
                  widget is RadioListTile<String> && widget.value == mode,
            );
            await tester.ensureVisible(option);
            await tester.tap(option);
            await tester.pumpAndSettle();
            expect(controller.mode, mode);
            expect(prefs.getString(AppConstants.THEME_MODE_KEY), mode);
            expect(
              Theme.of(
                tester.element(find.byType(ThemeModeDWWidget)),
              ).brightness,
              brightness,
            );
            expect(tester.takeException(), isNull);
            if (Platform.environment['SALATIME_QA_DIR']
                case final String output) {
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              await tester.runAsync(() async {
                final image = await boundary.toImage();
                final png = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(output).create(recursive: true);
                await File(
                  '$output/theme-$layout-$locale-$mode.png',
                ).writeAsBytes(png!.buffer.asUint8List());
                image.dispose();
              });
            }
          }

          await select(ThemeController.dark, Brightness.dark);
          await tester.ensureVisible(heading);
          await tester.tap(heading);
          await tester.pumpAndSettle();
          expect(find.byType(RadioListTile<String>), findsNothing);
          expect(controller.mode, ThemeController.dark);
          expect(
            prefs.getString(AppConstants.THEME_MODE_KEY),
            ThemeController.dark,
          );
          await tester.tap(heading);
          await tester.pumpAndSettle();
          final selectedDark = find.byWidgetPredicate(
            (widget) =>
                widget is RadioListTile<String> &&
                widget.value == ThemeController.dark,
          );
          final semantics = tester.ensureSemantics();
          await tester.pump();
          try {
            expect(
              tester
                  .getSemantics(selectedDark)
                  .getSemanticsData()
                  .flagsCollection
                  .isChecked,
              ui.CheckedState.isTrue,
            );
          } finally {
            semantics.dispose();
          }
          await controller.updateDaylightTimes('07:00', '19:00');
          controller.refreshForCurrentTime();
          expect(controller.darkTheme, isTrue);
          await select(ThemeController.light, Brightness.light);
          now = DateTime(2026, 9, 9, 22);
          controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
          expect(controller.darkTheme, isFalse);
          await select(ThemeController.daylight, Brightness.dark);
          await select(ThemeController.dark, Brightness.dark);
          await tester.pumpWidget(const SizedBox.shrink());
          await Get.delete<ThemeController>();
          final restored = Get.put(
            ThemeController(
              sharedPreferences: prefs,
              now: () => DateTime(2026, 9, 10, 12),
            ),
          );
          expect(restored.mode, ThemeController.dark);
          expect(restored.darkTheme, isTrue);
        },
      );
    }
  }
}
