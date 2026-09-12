import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/service/automatic_silence_service.dart';
import 'package:zabi/view/screens/settings/widgets/automatic_silence_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  var access = false;
  var enabled = false;
  var supported = true;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    calls.clear();
    access = false;
    enabled = false;
    supported = true;
    messenger.setMockMethodCallHandler(AutomaticSilenceService.channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'requestAccess' || call.method == 'requestExact') {
        return null;
      }
      if (call.method == 'set' &&
          (call.arguments as Map).containsKey('enabled')) {
        enabled = (call.arguments as Map)['enabled'] == true;
      }
      return {
        'supported': supported,
        'enabled': enabled,
        'access': access,
        'exact': true,
        'hasSchedule': true,
        'prayers': [1, 2, 3, 4, 5],
      };
    });
  });

  tearDown(
    () => messenger.setMockMethodCallHandler(
      AutomaticSilenceService.channel,
      null,
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AutomaticSilenceSettings()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
  }

  testWidgets('opening settings never enables silence or requests permission', (
    tester,
  ) async {
    await open(tester);
    expect(calls.map((e) => e.method).toList(), ['get']);
    expect(find.byType(SwitchListTile).first, findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
      false,
    );
  });

  testWidgets(
    'permission is requested only after activation and denial stays off',
    (tester) async {
      await open(tester);
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      expect(calls.where((e) => e.method == 'requestAccess').length, 1);
      expect(calls.where((e) => e.method == 'set'), isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(enabled, false);
      expect(calls.where((e) => e.method == 'set'), isEmpty);
    },
  );

  testWidgets(
    'returning from granted permission completes explicit activation',
    (tester) async {
      await open(tester);
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      access = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(enabled, true);
      expect(calls.where((e) => e.method == 'set').single.arguments, {
        'enabled': true,
      });
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      expect(enabled, false);
    },
  );

  testWidgets(
    'unsupported Android displays explanation and leaves other settings alone',
    (tester) async {
      supported = false;
      await open(tester);
      expect(find.text('silence_unsupported'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(calls.map((e) => e.method).toList(), ['get']);
    },
  );

  test(
    'restoring native settings clamps malformed ranges and filters prayer identifiers',
    () {
      final state = AutomaticSilenceStatus.fromMap({
        'delay': -5,
        'duration': 500,
        'fridayDuration': 0,
        'prayers': [1, 2, 2, 6, -1, 'bad'],
      });
      expect(state.enabled, false);
      expect(state.delay, 0);
      expect(state.duration, 120);
      expect(state.fridayDuration, 5);
      expect(state.prayers, [1, 2]);
    },
  );
}
