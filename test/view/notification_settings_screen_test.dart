import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/helper/prayer_notification_preferences.dart';
import 'package:zabi/theme/modern_dark_theme.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/view/screens/notification/notification_dw_widget.dart';
import 'package:zabi/view/screens/notification/notification_phase_screen.dart';
import 'package:zabi/view/screens/notification/notification_settings_screen.dart';
import 'package:zabi/view/screens/notification/widgets/sound_selection_field.dart';

class _Strings extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    for (final lang in ['fr', 'ar'])
      lang: Map<String, String>.from(
        jsonDecode(File('assets/language/$lang.json').readAsStringSync())
            as Map,
      ),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'Roboto': 'assets/font/Roboto-Regular.ttf',
      'NotoSansArabic': 'assets/font/NotoSansArabic-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Get.reset);

  Widget app(
    Widget page, {
    String locale = 'fr',
    bool dark = false,
    double scale = 1,
    Key? capture,
  }) {
    final theme = dark ? modernDark : modernLight;
    return RepaintBoundary(
      key: capture,
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        translations: _Strings(),
        locale: Locale(locale),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('fr'), Locale('ar')],
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(
            fontFamilyFallback: ['NotoSansArabic'],
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page,
      ),
    );
  }

  testWidgets('settings entry opens a dedicated hub with four categories', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Scaffold(body: NofificationDWWidget())));
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
    await tester.tap(find.byKey(const ValueKey('open_notification_settings')));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
    for (final category in ['before', 'adhan', 'after', 'other']) {
      expect(
        find.byKey(ValueKey('notification_category_$category')),
        findsOneWidget,
      );
    }
  });

  testWidgets('each prayer has an independent phase, sound and delay', (
    tester,
  ) async {
    await PrayerNotificationPreferences.setPhaseEnabled(
      PrayerNotificationPhase.after,
      false,
    );
    var schedules = 0;
    await tester.pumpWidget(
      app(
        NotificationPhaseScreen(
          phase: PrayerNotificationPhase.after,
          requestPermissions: false,
          reschedule: () async {
            schedules++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SoundSelectionField), findsNothing);
    await tester.tap(find.byKey(const ValueKey('notification_after_fajr')));
    await tester.pumpAndSettle();
    final soundField = find.byKey(
      const ValueKey('notification_sound_after_fajr'),
    );
    expect(
      tester.widget<SoundSelectionField>(soundField).selectedKey,
      'moatheni_after_prayer_fajr',
    );
    await tester.tap(
      find.byKey(const ValueKey('notification_time_after_fajr')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('notification_minutes_22')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('notification_minutes_22')));
    await tester.pumpAndSettle();
    await tester.tap(soundField);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sound_library_search')),
      'Tonalite 3',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('sound_choice_moatheni_short3')),
    );
    await tester.pumpAndSettle();
    final settings = await PrayerNotificationPreferences.load();
    final selected = settings.firstWhere(
      (s) =>
          s.prayer == PrayerNotificationPrayer.fajr &&
          s.phase == PrayerNotificationPhase.after,
    );
    expect(selected.sound, 'moatheni_short3');
    expect(selected.minutes, 22);
    expect(selected.enabled, isTrue);
    expect(
      settings
          .where(
            (s) =>
                s.phase == PrayerNotificationPhase.after &&
                s.prayer != PrayerNotificationPrayer.fajr,
          )
          .every((s) => !s.enabled),
      isTrue,
    );
    expect(schedules, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local edits stay responsive while alarm refresh is pending', (
    tester,
  ) async {
    final refresh = Completer<void>();
    var requests = 0;
    await tester.pumpWidget(
      app(
        NotificationPhaseScreen(
          phase: PrayerNotificationPhase.after,
          requestPermissions: false,
          reschedule: () {
            requests++;
            return refresh.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fajr = find.byKey(const ValueKey('notification_after_fajr'));
    final sunrise = find.byKey(const ValueKey('notification_after_sunrise'));
    await tester.tap(fajr);
    await tester.pumpAndSettle();
    expect(refresh.isCompleted, isFalse);
    expect(tester.widget<SwitchListTile>(fajr).value, isFalse);
    expect(tester.widget<SwitchListTile>(sunrise).onChanged, isNotNull);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(sunrise);
    await tester.pumpAndSettle();
    final persisted = await PrayerNotificationPreferences.load();
    expect(
      persisted
          .firstWhere(
            (s) =>
                s.phase == PrayerNotificationPhase.after &&
                s.prayer == PrayerNotificationPrayer.fajr,
          )
          .enabled,
      isFalse,
    );
    expect(
      persisted
          .firstWhere(
            (s) =>
                s.phase == PrayerNotificationPhase.after &&
                s.prayer == PrayerNotificationPrayer.sunrise,
          )
          .enabled,
      isTrue,
    );
    expect(requests, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    refresh.completeError(StateError('background scheduler unavailable'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final phase in PrayerNotificationPhase.values) {
    testWidgets(
      '${phase.name} series can be disabled, reopened and edited while refresh is pending',
      (tester) async {
        await PrayerNotificationPreferences.update(
          PrayerNotificationPrayer.fajr,
          phase,
          sound: 'moatheni_short3',
          minutes: 22,
        );
        await PrayerNotificationPreferences.update(
          PrayerNotificationPrayer.sunrise,
          phase,
          enabled: true,
        );
        final original = await PrayerNotificationPreferences.load();
        final refresh = Completer<void>();
        var requests = 0;
        Widget page() => app(
          NotificationPhaseScreen(
            phase: phase,
            requestPermissions: false,
            reschedule: () {
              requests++;
              return refresh.future;
            },
          ),
        );
        final series = find.descendant(
          of: find.byKey(ValueKey('notification_series_${phase.name}')),
          matching: find.byType(SwitchListTile),
        );
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        await tester.tap(series);
        await tester.pumpAndSettle();
        expect(requests, 1);
        expect(refresh.isCompleted, isFalse);
        expect(tester.widget<SwitchListTile>(series).value, isFalse);
        expect(tester.widget<SwitchListTile>(series).onChanged, isNotNull);
        expect(find.byType(SoundSelectionField), findsNothing);
        final disabled = await PrayerNotificationPreferences.load();
        for (var index = 0; index < original.length; index++) {
          expect(
            disabled[index].toJson(),
            original[index]
                .copyWith(
                  enabled: original[index].phase == phase ? false : null,
                )
                .toJson(),
          );
        }

        // Closing and reopening must keep the entire category disabled.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(series).value, isFalse);
        await tester.tap(
          find.byKey(ValueKey('notification_${phase.name}_fajr')),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(series).value, isTrue);
        expect(requests, 2);

        await tester.tap(series); // Disable that one prayer again.
        await tester.pumpAndSettle();
        await tester.tap(
          series,
        ); // Re-enable the category; sunrise stays opt-in.
        await tester.pumpAndSettle();
        final restored = (await PrayerNotificationPreferences.load()).where(
          (setting) => setting.phase == phase,
        );
        for (final setting in restored) {
          expect(
            setting.enabled,
            setting.prayer != PrayerNotificationPrayer.sunrise,
          );
        }
        expect(
          restored
              .firstWhere((s) => s.prayer == PrayerNotificationPrayer.fajr)
              .sound,
          'moatheni_short3',
        );
        expect(requests, 4);
        await tester.pumpWidget(const SizedBox.shrink());
        refresh.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('late background errors do not override the newest edit', (
    tester,
  ) async {
    final requests = <Completer<void>>[];
    await tester.pumpWidget(
      app(
        NotificationPhaseScreen(
          phase: PrayerNotificationPhase.after,
          requestPermissions: false,
          reschedule: () {
            final c = Completer<void>();
            requests.add(c);
            return c.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fajr = find.byKey(const ValueKey('notification_after_fajr'));
    await tester.tap(fajr);
    await tester.pumpAndSettle();
    await tester.tap(fajr);
    await tester.pumpAndSettle();
    requests.first.completeError(StateError('superseded'));
    requests.last.complete();
    await tester.pumpAndSettle();
    expect(find.text('extra_reminders_save_error'.tr), findsNothing);
    expect(tester.widget<SwitchListTile>(fajr).value, isTrue);
    await tester.tap(fajr);
    await tester.pumpAndSettle();
    requests.last.completeError(StateError('latest failed'));
    await tester.pumpAndSettle();
    expect(find.text('extra_reminders_save_error'.tr), findsOneWidget);
    expect(tester.widget<SwitchListTile>(fajr).onChanged, isNotNull);
  });

  for (final locale in ['fr', 'ar']) {
    for (final phase in PrayerNotificationPhase.values) {
      testWidgets(
        '$locale ${phase.name} fits 320px at large text and keeps all seven entries reachable',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          for (final setting in await PrayerNotificationPreferences.load()) {
            if (setting.phase == phase) {
              await PrayerNotificationPreferences.save(
                setting.copyWith(enabled: true),
              );
            }
          }
          final capture = GlobalKey();
          await tester.pumpWidget(
            app(
              NotificationPhaseScreen(
                phase: phase,
                requestPermissions: false,
                reschedule: () async {},
              ),
              locale: locale,
              dark: locale == 'ar',
              scale: 2,
              capture: capture,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final prayer in PrayerNotificationPrayer.values) {
            final target = find.byKey(
              ValueKey('notification_${phase.name}_${prayer.name}'),
            );
            await tester.scrollUntilVisible(target, 220, maxScrolls: 60);
            await tester.pumpAndSettle();
            expect(target.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          final qa = Platform.environment['SALATIME_QA_DIR'];
          if (qa != null) {
            await tester.runAsync(() async {
              final image =
                  await (capture.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(qa).create(recursive: true);
                await File(
                  '$qa/notifications-${phase.name}-$locale.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }
        },
      );
    }
  }
}
