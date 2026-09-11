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
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/view/screens/notification/upcoming_prayer_alarms_screen.dart';

class _Translations extends Translations {
  _Translations(this.values);
  final Map<String, String> values;
  @override
  Map<String, Map<String, String>> get keys => {'fr_FR': values};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Roboto')..addFont(rootBundle.load('assets/font/Roboto-Regular.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('upcoming alarms fit a narrow French screen at large text size', (
    tester,
  ) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      SalatWaqtService.scheduleKey: jsonEncode([
        {
          'id': 12000001,
          'prayerId': 1,
          'date': '2026-09-12',
          'at': now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
          'kind': 'adhan',
          'key': '2026-09-12:1',
        },
        {
          'id': 12000002,
          'prayerId': 2,
          'date': '2026-09-12',
          'at': now.add(const Duration(hours: 6)).millisecondsSinceEpoch,
          'kind': 'adhan',
          'key': '2026-09-12:2',
        },
      ]),
    });
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'pendingNotificationRequests') {
            return [
              {'id': 12000001, 'title': 'Fajr', 'body': '', 'payload': ''},
              {'id': 12000002, 'title': 'Dhuhr', 'body': '', 'payload': ''},
            ];
          }
          return null;
        });
    final values = Map<String, String>.from(
      jsonDecode(File('assets/language/fr.json').readAsStringSync()) as Map,
    );
      Get.put(HomeLayoutController(sharedPreferences: await SharedPreferences.getInstance()));
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      Get.reset();
    });
    final boundary = GlobalKey();
    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(fontFamily: 'Roboto', colorSchemeSeed: const Color(0xff174D39)),
        locale: const Locale('fr', 'FR'),
        translations: _Translations(values),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: boundary,
          child: const UpcomingPrayerAlarmsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip(values['skip_this_prayer']!), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    if (Platform.environment['SALATIME_CAPTURE_UI'] == '1') {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/salatime-upcoming-alarms.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
