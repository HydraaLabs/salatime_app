import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/view/screens/onboarding/widget_prompt.dart';

void main() {
  for (final add in [false, true]) {
    testWidgets('widget prompt is optional and shown once (add=$add)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        WidgetPrompt.channel,
        (call) async {
          calls.add(call);
          return true;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          WidgetPrompt.channel,
          null,
        ),
      );
      addTearDown(Get.reset);
      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => WidgetPrompt.showOnce(context, prefs),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('widget_prompt_title'), findsOneWidget);
      await tester.tap(find.text(add ? 'widget_add' : 'widget_later'));
      await tester.pumpAndSettle();
      expect(prefs.getBool(WidgetPrompt.seenKey), isTrue);
      expect(calls.where((call) => call.method == 'pin').length, add ? 1 : 0);
      if (add) expect(calls.last.arguments, {'size': 'large'});
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('widget_prompt_title'), findsNothing);
    });
  }
}
