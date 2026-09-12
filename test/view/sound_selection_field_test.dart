import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/noti_sound_controller.dart';
import 'package:zabi/theme/modern_dark_theme.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/view/screens/notification/widgets/sound_selection_field.dart';

class _Translations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    for (final locale in ['fr', 'ar'])
      locale: Map<String, String>.from(
        jsonDecode(File('assets/language/$locale.json').readAsStringSync())
            as Map,
      ),
  };
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
  });
  tearDown(Get.reset);
  for (final locale in ['fr', 'ar']) {
    testWidgets(
      'search, preview and choose a last-library sound on 320px $locale at 2x text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? selected;
        String? preview;
        var stops = 0;
        final theme = locale == 'ar' ? modernDark : modernLight;
        await tester.pumpWidget(
          GetMaterialApp(
            locale: Locale(locale),
            translations: _Translations(),
            theme: theme.copyWith(
              textTheme: theme.textTheme.apply(
                fontFamilyFallback: ['NotoSansArabic'],
              ),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: Directionality(
                textDirection: locale == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: child!,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SoundSelectionField(
                    selectedKey: 'azan_2',
                    label: 'reminder_sound'.tr,
                    onChanged: (value) => selected = value,
                    onPreview: (key) async {
                      preview = key;
                    },
                    onStopPreview: () async {
                      stops++;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(InputDecorator));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byType(ListTile).evaluate().length,
          lessThan(NotiSoundController.availableSounds.length),
        );
        final target = NotiSoundController.bundledSounds.last;
        await tester.enterText(
          find.byKey(const ValueKey('sound_library_search')),
          target['name']!,
        );
        await tester.pumpAndSettle();
        final choice = find.byKey(ValueKey('sound_choice_${target['key']}'));
        expect(choice, findsOneWidget);
        await tester.tap(
          find.descendant(of: choice, matching: find.byType(IconButton)),
        );
        await tester.pumpAndSettle();
        expect(preview, target['key']);
        expect(selected, isNull);
        // Keep the result reachable even with the keyboard occupying most of a
        // small display and an accessibility font size.
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(selected, target['key']);
        expect(stops, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
