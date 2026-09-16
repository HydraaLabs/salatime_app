import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/helper/salat_waqt_service.dart';
import 'package:salatime/view/screens/notification/upcoming_prayer_alarms_screen.dart';

class _Translations extends Translations {
  _Translations(this.values);
  final Map<String, String> values;
  @override
  Map<String, Map<String, String>> get keys => {'fr_FR': values};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('net.salatime.app/prayer_schedule');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          native,
          (call) async => call.method == 'status'
              ? {
                  'notifications': true,
                  'exact': true,
                  'batteryExempt': true,
                  'armedWindowDays': 3,
                }
              : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, null);
  });

  Future<void> showAlarms(
    WidgetTester tester, {
    required List<Map<String, dynamic>> alarms,
    List<String> skipped = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      SalatWaqtService.scheduleKey: jsonEncode(alarms),
      SalatWaqtService.skippedKey: skipped,
    });
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pendingNotificationRequests') {
        return [
          for (final alarm in alarms)
            {'id': alarm['id'], 'title': '', 'body': '', 'payload': ''},
        ];
      }
      return null;
    });
    Get.put(
      HomeLayoutController(
        sharedPreferences: await SharedPreferences.getInstance(),
      ),
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      Get.reset();
    });
    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('fr', 'FR'),
        translations: _Translations({
          'fajr': 'Fajr',
          'sunrise': 'Lever du soleil',
          'dhuhr': 'Dohr',
          'jumuah': 'Joumoua',
          'before_adhan': 'Avant',
          'iqama_reminder_title': 'Iqama',
        }),
        home: const UpcomingPrayerAlarmsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sunrise and Friday names match scheduled and skipped prayers', (
    tester,
  ) async {
    final at = DateTime.now()
        .add(const Duration(hours: 2))
        .millisecondsSinceEpoch;
    await showAlarms(
      tester,
      alarms: [
        {
          'id': 12000006,
          'prayerId': 6,
          'date': '2030-01-04',
          'at': at,
          'kind': 'before',
          'key': '2030-01-04:6',
        },
        {
          'id': 12000002,
          'prayerId': 2,
          'date': '2030-01-04',
          'at': at + 1000,
          'kind': 'adhan',
          'key': '2030-01-04:2',
        },
        {
          'id': 12000102,
          'prayerId': 2,
          'date': '2030-01-05',
          'at': at + 2000,
          'kind': 'after',
          'key': '2030-01-05:2',
        },
      ],
      skipped: ['2030-01-11:6', '2030-01-11:2'],
    );
    expect(find.text('Lever du soleil · Avant'), findsOneWidget);
    expect(find.text('Joumoua'), findsOneWidget);
    expect(find.text('Dohr · Iqama'), findsOneWidget);
    expect(find.text('Lever du soleil · 2030-01-11'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Joumoua · 2030-01-11'), 150);
    expect(find.text('Joumoua · 2030-01-11'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'malformed cached alarms and skipped keys cannot crash the list',
    (tester) async {
      final valid = <String, dynamic>{
        'id': 12000001,
        'prayerId': 1,
        'date': '2030-01-04',
        'at': DateTime.now()
            .add(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        'kind': 'adhan',
        'key': '2030-01-04:1',
      };
      await showAlarms(
        tester,
        alarms: [
          valid,
          {...valid, 'id': 12000007, 'prayerId': 7},
          {...valid, 'id': 12000008, 'at': 'invalid'},
          {...valid, 'id': 12000009, 'date': '2030-02-31'},
          {...valid, 'id': 12000010, 'key': null},
          {...valid, 'id': 12000011, 'kind': 'unknown'},
        ],
        skipped: ['broken', '2030-01-04:x', '2030-01-04:7', '2030-02-31:1'],
      );
      expect(find.text('Fajr'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
      expect(find.text('restore_alarm'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  setUpAll(() async {
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/font/Roboto-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
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
    Get.put(
      HomeLayoutController(
        sharedPreferences: await SharedPreferences.getInstance(),
      ),
    );
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
        theme: ThemeData(
          fontFamily: 'Roboto',
          colorSchemeSeed: const Color(0xff174D39),
        ),
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
    await tester.scrollUntilVisible(find.text(values['dhuhr']!), 200);
    expect(find.byTooltip(values['skip_this_prayer']!), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    if (Platform.environment['SALATIME_CAPTURE_UI'] == '1') {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '/tmp/salatime-upcoming-alarms.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
