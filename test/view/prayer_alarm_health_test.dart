import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/salat_waqt_service.dart';
import 'package:salatime/view/screens/notification/widgets/prayer_alarm_health_card.dart';

class _Translations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'fr_FR': Map<String, String>.from(
      jsonDecode(File('assets/language/fr.json').readAsStringSync()) as Map,
    ),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('net.salatime.app/prayer_schedule');
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timezone = MethodChannel('flutter_timezone');
  final calls = <MethodCall>[];
  final nativeCalls = <MethodCall>[];
  final pending = <Map<String, dynamic>>[];
  var alarmVolume = 7;
  var outcome = 'late_silent';
  final boundary = GlobalKey();

  setUpAll(() async {
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/font/Roboto-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    nativeCalls.clear();
    pending.clear();
    alarmVolume = 7;
    outcome = 'late_silent';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (call) async {
          nativeCalls.add(call);
          return switch (call.method) {
            'status' => {
              'exact': true,
              'notifications': true,
              'batteryExempt': true,
              'alarmVolume': alarmVolume,
              'alarmVolumeMax': 10,
              'manufacturer': 'Samsung',
              'delayMs': 26 * 60000,
              'outcome': outcome,
            },
            'route' => {'routed': 1, 'failed': 0, 'inexact': false},
            _ => null,
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'initialize':
              return true;
            case 'canScheduleExactNotifications':
              return true;
            case 'getNotificationChannels':
              return [];
            case 'pendingNotificationRequests':
              return List.of(pending);
            case 'zonedSchedule':
              final args = Map<String, dynamic>.from(call.arguments as Map);
              pending.add({
                'id': args['id'],
                'title': args['title'],
                'body': args['body'],
                'payload': args['payload'],
              });
            case 'cancel':
              pending.removeWhere((p) => p['id'] == call.arguments['id']);
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, (_) async => 'UTC');
  });

  tearDown(() {
    for (final channel in [native, notifications, timezone]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
    Get.reset();
  });

  Future<void> showCard(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(
          fontFamily: 'Roboto',
          colorSchemeSeed: const Color(0xff174D39),
        ),
        locale: const Locale('fr', 'FR'),
        translations: _Translations(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: boundary,
          child: const Scaffold(
            body: SingleChildScrollView(child: PrayerAlarmHealthCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'test schedules the selected Adhan one minute ahead and can cancel both alarm paths',
    (tester) async {
      await showCard(tester);
      if (Platform.environment['SALATIME_CAPTURE_UI'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '/tmp/salatime-adhan-test-card.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(find.textContaining('26 minutes de retard'), findsOneWidget);
      expect(find.text('Volume des alarmes : 70 %'), findsOneWidget);
      final start = find.text('Tester dans une minute');
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      final schedule =
          calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
              as Map;
      final payload = jsonDecode(schedule['payload'] as String) as Map;
      final seconds =
          (payload['at'] as int) - DateTime.now().millisecondsSinceEpoch;
      expect(seconds, inInclusiveRange(55000, 61000));
      expect(schedule['id'], SalatWaqtService.testAlarmId);
      expect(schedule['platformSpecifics']['sound'], 'azan_2');
      expect(payload['stopLabel'], 'Arrêter');
      expect(nativeCalls.where((c) => c.method == 'route'), hasLength(1));
      expect(
        nativeCalls.singleWhere((c) => c.method == 'route').arguments['id'],
        SalatWaqtService.testAlarmId,
      );
      expect(calls.where((c) => c.method == 'show'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Annuler le test'));
      await tester.tap(find.text('Annuler le test'));
      await tester.pumpAndSettle();
      expect(pending, isEmpty);
      expect(
        nativeCalls.where((c) => c.method == 'cancel').last.arguments['id'],
        SalatWaqtService.testAlarmId,
      );
      expect(find.text('Tester dans une minute'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'muted audio replaces the failure message with the phone settings explanation',
    (tester) async {
      outcome = 'audio_error';
      await showCard(tester);
      expect(find.text('alarm_audio_failed'.tr), findsOneWidget);
      expect(find.text('alarm_audio_muted'.tr), findsNothing);

      outcome = 'audio_muted';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Le dernier adhan est resté silencieux selon les réglages audio du téléphone.',
        ),
        findsOneWidget,
      );
      expect(find.text('alarm_audio_failed'.tr), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'alarm volume is refreshed after returning from Android settings',
    (tester) async {
      await showCard(tester);
      alarmVolume = 0;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Volume des alarmes : 0 %'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
