import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:salatime/view/screens/settings/widgets/analytics_settings_tile.dart';

void main() {
  tearDown(Get.reset);

  Future<void> show(
    WidgetTester tester,
    ValueNotifier<bool> choice,
    Future<void> Function(bool) save, {
    String language = 'en',
    double textScale = 1,
  }) async {
    final labels = Map<String, String>.from(
      jsonDecode(File('assets/language/$language.json').readAsStringSync())
          as Map,
    );
    Get.addTranslations({language: labels});
    await tester.pumpWidget(
      GetMaterialApp(
        locale: Locale(language),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnalyticsSettingsTile(
              collectionPreference: choice,
              onCollectionChanged: save,
            ),
          ),
        ),
      ),
    );
  }

  Finder toggle() => find.byKey(const ValueKey('analytics_collection_toggle'));

  testWidgets('reflects saved choice and disables duplicate updates', (
    tester,
  ) async {
    final choice = ValueNotifier(true);
    addTearDown(choice.dispose);
    final pending = Completer<void>();
    final changes = <bool>[];
    await show(tester, choice, (value) async {
      changes.add(value);
      await pending.future;
      choice.value = value;
    });
    expect(tester.widget<SwitchListTile>(toggle()).value, isTrue);
    await tester.tap(toggle());
    await tester.pump();
    expect(changes, [false]);
    expect(tester.widget<SwitchListTile>(toggle()).onChanged, isNull);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle()).value, isFalse);
    expect(tester.widget<SwitchListTile>(toggle()).onChanged, isNotNull);
    // A change outside the tile (for example bootstrap restoration) is shown.
    choice.value = true;
    await tester.pump();
    expect(tester.widget<SwitchListTile>(toggle()).value, isTrue);
  });

  testWidgets('failed update keeps current choice and allows retry', (
    tester,
  ) async {
    final choice = ValueNotifier(false);
    addTearDown(choice.dispose);
    var failed = true;
    await show(tester, choice, (value) async {
      if (failed) throw StateError('Storage unavailable');
      choice.value = value;
    });
    await tester.tap(toggle());
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle()).value, isFalse);
    expect(
      find.text('Unable to save this choice. Please try again.'),
      findsOneWidget,
    );
    failed = false;
    await tester.tap(toggle());
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle()).value, isTrue);
    expect(
      find.text('Unable to save this choice. Please try again.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final language in ['fr', 'ar']) {
    testWidgets('readable at 320px and 200% text in $language', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final choice = ValueNotifier(true);
      addTearDown(choice.dispose);
      await show(
        tester,
        choice,
        (value) async => choice.value = value,
        language: language,
        textScale: 2,
      );
      await tester.ensureVisible(toggle());
      await tester.tap(toggle());
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle()).value, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
