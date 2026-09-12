import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:zabi/helper/prayer_share_data.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/theme/modern_dark_theme.dart';
import 'package:zabi/view/screens/islamic_calendar/islamic_calendar_screen.dart';
import 'package:zabi/view/screens/prayer_share/prayer_share_screen.dart';

class _Strings extends Translations {
  _Strings(this.keys);
  @override
  final Map<String, Map<String, String>> keys;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/font/Roboto-Regular.ttf'))).load();
    await (FontLoader('NotoSansArabic')
          ..addFont(rootBundle.load('assets/font/NotoSansArabic-Regular.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  tearDown(Get.reset);
  for (final locale in ['fr', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        'calendar and adjusted card fit 320px $locale dark=$dark at 2x text',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final strings = Map<String, String>.from(
            jsonDecode(
              await tester.runAsync(
                    () => rootBundle.loadString('assets/language/$locale.json'),
                  ) ??
                  '{}',
            ),
          );
          final captureKey = GlobalKey();
          final cardKey = GlobalKey();
          Widget app(Widget body) => RepaintBoundary(
            key: captureKey,
            child: GetMaterialApp(
              translations: _Strings({locale: strings}),
              locale: Locale(locale),
              debugShowCheckedModeBanner: false,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [
                Locale('en'),
                Locale('fr'),
                Locale('ar'),
              ],
              theme: (dark ? modernDark : modernLight).copyWith(
                textTheme: (dark ? modernDark : modernLight).textTheme.apply(
                  fontFamilyFallback: ['NotoSansArabic'],
                ),
              ),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 568),
                  textScaler: TextScaler.linear(2),
                ),
                child: Directionality(
                  textDirection: locale == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: body,
                ),
              ),
            ),
          );
          final qaDirectory = Platform.environment['SALATIME_QA_DIR'];
          Future<void> capture(GlobalKey key, String name) async {
            if (qaDirectory == null) return;
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(qaDirectory).create(recursive: true);
                await File(
                  '$qaDirectory/$name-$locale-${dark ? 'dark' : 'light'}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }

          await tester.pumpWidget(
            app(IslamicCalendarScreen(now: () => DateTime(2026, 9, 12))),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await capture(captureKey, 'calendar');
          await tester.scrollUntilVisible(
            find.widgetWithText(OutlinedButton, 'calendar_hijri'.tr),
            100,
          );
          await tester.tap(
            find.widgetWithText(OutlinedButton, 'calendar_hijri'.tr),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(3));
          await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          Navigator.of(tester.element(find.byType(AlertDialog))).pop();
          await tester.pumpAndSettle();
          Navigator.of(tester.element(find.byType(AlertDialog))).pop();
          await tester.pumpAndSettle();

          final data = PrayerShareData.fromDay(
            Data(
              date: '2026-09-12',
              fajrStart: '05:30',
              sunrise: '07:00',
              zuhrStart: '13:00',
              asrStart: '16:00',
              maghribStart: '19:30',
              ishaStart: '23:50',
            ),
            city: 'Fès · فاس',
            adjustments: {'isha': 20},
          )!;
          await tester.pumpWidget(
            app(
              Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: RepaintBoundary(
                      key: cardKey,
                      child: PrayerTimesShareCard(
                        data: data,
                        hijriDate: '1 ${'hijri_month_4'.tr} 1448',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.textContaining('00:10'), findsOneWidget);
          await capture(cardKey, 'prayer-card');
        },
      );
    }
  }
}
