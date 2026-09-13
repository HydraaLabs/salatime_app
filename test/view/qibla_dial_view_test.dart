import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:salatime/theme/modern_light_theme.dart';
import 'package:salatime/theme/modern_dark_theme.dart';
import 'package:salatime/view/screens/compass/widget/qibla_dial_view.dart';

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
    for (final size in [
      const Size(320, 568),
      const Size(640, 360),
      const Size(800, 1024),
    ]) {
      testWidgets('compass fits $locale $size with large text', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final strings = Map<String, String>.from(
          jsonDecode(
            (await tester.runAsync(
              () => rootBundle.loadString('assets/language/$locale.json'),
            ))!,
          ),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          GetMaterialApp(
            locale: Locale(locale),
            translations: _Strings({locale: strings}),
            theme:
                (Platform.environment['SALATIME_QA_DARK'] == '1'
                        ? modernDark
                        : modernLight)
                    .copyWith(
                      textTheme: modernLight.textTheme.apply(
                        fontFamilyFallback: ['NotoSansArabic'],
                      ),
                    ),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(
                  double.parse(
                    Platform.environment['SALATIME_QA_TEXT_SCALE'] ?? '2',
                  ),
                ),
              ),
              child: Scaffold(
                body: RepaintBoundary(
                  key: key,
                  child: const QiblaDialView(
                    heading: 147,
                    bearing: 95,
                    deviceAngle: 147,
                    needleAngle: -52,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.text('95°'), findsOneWidget);
        if (Platform.environment['SALATIME_QA_DIR'] case final String dir) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(dir).create(recursive: true);
            await File(
              '$dir/qibla-$locale-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
