import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/view/screens/onboarding/widget_prompt.dart';
import 'package:salatime/view/screens/onboarding/prayer_widget_preview.dart';

void main() {
  for (final size in [null, 'small', 'medium', 'large']) {
    testWidgets('widget prompt is optional and pins the chosen size ($size)', (
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
      expect(find.byType(PrayerWidgetPreview), findsNWidgets(3));
      for (final name in ['small', 'medium', 'large']) {
        expect(find.text('widget_size_$name'), findsOneWidget);
      }
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'medium',
      );
      // Confirming without touching a radio must add the medium widget.
      if (size != 'medium') {
        final choice = find.byKey(ValueKey('widget_option_${size ?? 'small'}'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
      }
      expect(calls.where((call) => call.method == 'pin'), isEmpty);
      final action = find.text(size == null ? 'widget_later' : 'widget_add');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(prefs.getBool(WidgetPrompt.seenKey), isTrue);
      expect(
        calls.where((call) => call.method == 'pin').length,
        size == null ? 0 : 1,
      );
      if (size != null) expect(calls.last.arguments, {'size': size});
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('widget_prompt_title'), findsNothing);
    });
  }

  for (final language in ['fr', 'ar']) {
    testWidgets(
      'all sizes remain reachable at 320px and 200% text ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
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
        final labels = Map<String, String>.from(
          jsonDecode(File('assets/language/$language.json').readAsStringSync())
              as Map,
        );
        Get.addTranslations({language: labels});
        await tester.pumpWidget(
          GetMaterialApp(
            locale: Locale(language),
            theme: language == 'ar' ? ThemeData.dark() : ThemeData.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
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
        for (final name in ['small', 'medium', 'large']) {
          final option = find.byKey(ValueKey('widget_option_$name'));
          await tester.ensureVisible(option);
          await tester.pumpAndSettle();
          expect(option.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byKey(const ValueKey('widget_option_large')));
        await tester.pumpAndSettle();
        expect(calls.where((call) => call.method == 'pin'), isEmpty);
        expect(
          tester
              .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
              .groupValue,
          'large',
        );
        final add = find.text(labels['widget_add']!);
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(calls.last.arguments, {'size': 'large'});
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('unsupported launchers skip the prompt without marking it seen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      WidgetPrompt.channel,
      (call) async {
        calls.add(call);
        return false;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        WidgetPrompt.channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => WidgetPrompt.showOnce(context, prefs),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(prefs.getBool(WidgetPrompt.seenKey), isNull);
    expect(calls.map((call) => call.method), ['canPin']);
    expect(find.text('widget_prompt_title'), findsNothing);
  });
  testWidgets(
    'iOS offers three sizes and explains manual addition without pinning',
    (tester) async {
      addTearDown(Get.reset);
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
      expect(find.byType(PrayerWidgetPreview), findsNWidgets(3));
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'medium',
      );
      final add = find.text('widget_ios_add');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('widget_size_medium'), findsOneWidget);
      expect(find.text('widget_ios_steps'), findsOneWidget);
      expect(calls.map((call) => call.method), ['isSupported']);
      expect(prefs.getBool(WidgetPrompt.seenKey), isTrue);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
