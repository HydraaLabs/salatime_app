import 'dart:async';
import 'package:salatime/view/screens/notification/widgets/sound_selection_field.dart';
import 'package:salatime/view/screens/notification/widgets/notification_series_switch.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/helper/additional_reminder_plan.dart';
import 'package:salatime/service/cloud/preference_device.dart';
import 'package:salatime/helper/local_prayer_calculator.dart';
import 'package:salatime/theme/modern_dark_theme.dart';
import 'package:salatime/theme/modern_light_theme.dart';
import 'package:salatime/view/screens/reminders/additional_reminders_screen.dart';
import 'package:salatime/view/screens/reminders/daily_prayer_markers_screen.dart';

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
    LocalPrayerCalculator.initializeTimeZones();
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/font/Roboto-Regular.ttf'))).load();
    await (FontLoader('NotoSansArabic')
          ..addFont(rootBundle.load('assets/font/NotoSansArabic-Regular.ttf')))
        .load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('net.salatime.app/prayer_schedule'),
          (_) async => <String, dynamic>{},
        );
  });
  tearDown(Get.reset);
  Widget app(Widget page, String locale, {bool dark = false}) => GetMaterialApp(
    translations: _Translations(),
    locale: Locale(locale),
    theme: (dark ? modernDark : modernLight).copyWith(
      textTheme: (dark ? modernDark : modernLight).textTheme.apply(
        fontFamilyFallback: ['NotoSansArabic'],
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(2)),
      child: Directionality(
        textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
    ),
    home: page,
  );

  testWidgets(
    'sound and timing controls appear only when their reminder is enabled',
    (tester) async {
      await tester.pumpWidget(
        app(AdditionalRemindersScreen(refreshSchedule: () async {}), 'fr'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SoundSelectionField), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('extra_duha')));
      await tester.tap(find.byKey(const ValueKey('extra_duha')));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(find.byType(SoundSelectionField), findsOneWidget);
      expect(
        (await AdditionalReminderPreferences.load()).first.enabled,
        isTrue,
      );
      expect((await AdditionalReminderPreferences.load())[1].enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'series switch persists all reminders without waiting for scheduling',
    (tester) async {
      await AdditionalReminderPreferences.save([
        for (final type in AdditionalReminderType.values)
          AdditionalReminderSetting.defaults(type).copyWith(
            enabled:
                type == AdditionalReminderType.fajrAlarm ||
                type == AdditionalReminderType.mondayThursday,
            sound: type == AdditionalReminderType.fajrAlarm ? 'silent' : null,
            minutes: type == AdditionalReminderType.fajrAlarm ? 47 : null,
            anchor: type == AdditionalReminderType.fajrAlarm
                ? 'afterFajr'
                : null,
          ),
      ]);
      final before = await AdditionalReminderPreferences.load();
      final refresh = Completer<void>();
      var requests = 0;
      await tester.pumpWidget(
        app(
          AdditionalRemindersScreen(
            refreshSchedule: () {
              requests++;
              return refresh.future;
            },
          ),
          'fr',
        ),
      );
      await tester.pumpAndSettle();
      final series = find.byKey(const ValueKey('notification_series_other'));
      expect(tester.widget<NotificationSeriesSwitch>(series).value, true);

      await tester.tap(series);
      await tester.pumpAndSettle();
      expect(tester.widget<NotificationSeriesSwitch>(series).value, false);
      expect(
        tester.widget<NotificationSeriesSwitch>(series).onChanged,
        isNotNull,
      );
      expect(refresh.isCompleted, false);
      expect(requests, 1);
      final disabled = await AdditionalReminderPreferences.load();
      expect(disabled.any((item) => item.enabled), false);
      for (final setting in before) {
        expect(
          disabled.singleWhere((item) => item.type == setting.type).toJson(),
          setting.copyWith(enabled: false).toJson(),
        );
      }

      await tester.tap(series);
      await tester.pumpAndSettle();
      expect(tester.widget<NotificationSeriesSwitch>(series).value, true);
      expect(
        tester.widget<NotificationSeriesSwitch>(series).onChanged,
        isNotNull,
      );
      expect(refresh.isCompleted, false);
      expect(requests, 2);
      final enabled = await AdditionalReminderPreferences.load();
      expect(
        enabled.where((item) => item.enabled).map((item) => item.type),
        unorderedEquals(AdditionalReminderPreferences.visibleTypes),
      );
      final fajr = enabled.singleWhere(
        (item) => item.type == AdditionalReminderType.fajrAlarm,
      );
      expect(fajr.sound, 'silent');
      expect(fajr.minutes, 47);
      expect(fajr.anchor, 'afterFajr');

      final individual = find.byKey(const ValueKey('extra_fajrAlarm'));
      await tester.ensureVisible(individual);
      await tester.tap(individual);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(individual).value, false);
      // The header can be disposed when the lazy list scrolls to a reminder.
      tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(0);
      await tester.pumpAndSettle();
      // Other reminders are still enabled, so the series remains on.
      expect(tester.widget<NotificationSeriesSwitch>(series).value, true);
      expect(requests, 3);
      await tester.tap(series);
      await tester.pumpAndSettle();
      expect(tester.widget<NotificationSeriesSwitch>(series).value, false);
      expect(requests, 4);
      expect(refresh.isCompleted, false);

      await tester.pumpWidget(const SizedBox.shrink());
      refresh.completeError(StateError('late background failure'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['fr', 'ar']) {
    testWidgets(
      'all reminder settings scroll on 320px $locale with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await AdditionalReminderPreferences.save([
          for (final type in AdditionalReminderType.values)
            AdditionalReminderSetting.defaults(type).copyWith(enabled: true),
        ]);
        await tester.pumpWidget(
          app(
            AdditionalRemindersScreen(refreshSchedule: () async {}),
            locale,
            dark: locale == 'ar',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final type in AdditionalReminderPreferences.visibleTypes) {
          final target = find.byKey(ValueKey('extra_${type.name}'));
          await tester.scrollUntilVisible(target, 240, maxScrolls: 80);
          await tester.pumpAndSettle();
          expect(target.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        expect(
          find.byKey(const ValueKey('extra_friday')).hitTestable(),
          findsOneWidget,
        );
      },
    );
  }

  for (final locale in ['fr', 'ar']) {
    testWidgets(
      'Fajr timing view saves independent anchor and minutes on 320px $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await AdditionalReminderPreferences.save([
          for (final type in AdditionalReminderType.values)
            AdditionalReminderSetting.defaults(
              type,
            ).copyWith(enabled: type == AdditionalReminderType.fajrAlarm),
        ]);
        await tester.pumpWidget(
          app(
            AdditionalRemindersScreen(refreshSchedule: () async {}),
            locale,
            dark: locale == 'ar',
          ),
        );
        await tester.pumpAndSettle();
        final timing = find.byKey(const ValueKey('extra_time_fajrAlarm'));
        await tester.ensureVisible(timing);
        await tester.pumpAndSettle();
        await tester.tap(timing);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final after = find.byKey(const ValueKey('extra_anchor_afterFajr'));
        await tester.ensureVisible(after);
        await tester.pumpAndSettle();
        await tester.tap(after);
        await tester.pumpAndSettle();
        final minutes = find.byType(DropdownButtonFormField<int>);
        tester.widget<DropdownButtonFormField<int>>(minutes).onChanged!(45);
        await tester.pumpAndSettle();
        final save = find.widgetWithText(
          FilledButton,
          'extra_reminder_save_time'.tr,
        );
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        // A cloud restore completes while this timing screen is still open.
        final restored = await AdditionalReminderPreferences.load();
        await AdditionalReminderPreferences.save([
          for (final item in restored)
            if (item.type == AdditionalReminderType.fajrAlarm)
              item.copyWith(enabled: false, sound: 'silent')
            else if (item.type == AdditionalReminderType.morning)
              item.copyWith(enabled: true, minutes: 87)
            else
              item,
        ]);
        await tester.tap(save);
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
        final settings = await AdditionalReminderPreferences.load();
        final fajr = settings.singleWhere(
          (s) => s.type == AdditionalReminderType.fajrAlarm,
        );
        expect(fajr.effectiveAnchor, 'afterFajr');
        expect(fajr.minutes, 45);
        expect(fajr.sound, 'silent');
        expect(fajr.enabled, false);
        expect(
          settings
              .singleWhere((s) => s.type == AdditionalReminderType.morning)
              .enabled,
          true,
        );
        expect(
          settings
              .singleWhere((s) => s.type == AdditionalReminderType.morning)
              .minutes,
          87,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'daily guide displays night midpoint and last third with missing data gracefully',
    (tester) async {
      final zone = tz.getLocation('UTC');
      Data day(String date) => Data(
        date: date,
        fajrStart: '06:00',
        sunrise: '07:10',
        zuhrStart: '13:00',
        asrStart: '16:00',
        maghribStart: '18:00',
        ishaStart: '20:00',
      );
      final data = DailyPrayerMarkers.calculate(
        day: day('2026-09-11'),
        previous: day('2026-09-10'),
        zone: zone,
        settings: await AdditionalReminderPreferences.load(),
      );
      expect(
        data.entries
            .singleWhere((entry) => entry.label == 'daily_markers_middle_night')
            .time,
        tz.TZDateTime(zone, 2026, 9, 11),
      );
      expect(
        data.entries
            .singleWhere((entry) => entry.label == 'extra_reminder_lastThird')
            .time,
        tz.TZDateTime(zone, 2026, 9, 11, 2),
      );
      expect(
        data.entries.where(
          (entry) => entry.label == 'extra_reminder_middleNight',
        ),
        isEmpty,
      );
      expect(
        data.entries.where(
          (entry) => entry.label == 'extra_reminder_fajrAlarm',
        ),
        isEmpty,
      );
      expect(
        data.entries.where((entry) => entry.label == 'extra_reminder_friday'),
        hasLength(1),
      );
      await tester.pumpWidget(
        app(DailyPrayerMarkersScreen(loadMarkers: () async => data), 'fr'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Milieu de la nuit'), findsOneWidget);
      Get.locale = const Locale('ar');
      await tester.pumpWidget(
        app(
          DailyPrayerMarkersScreen(
            key: UniqueKey(),
            loadMarkers: () async => null,
          ),
          'ar',
          dark: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('حدد موقعك لحساب هذه الأوقات.'), findsOneWidget);
    },
  );
  testWidgets('extra reminder edits do not wait for background scheduling', (
    tester,
  ) async {
    final refresh = Completer<void>();
    var requests = 0;
    await tester.pumpWidget(
      app(
        AdditionalRemindersScreen(
          refreshSchedule: () {
            requests++;
            return refresh.future;
          },
        ),
        'fr',
      ),
    );
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('extra_fajrAlarm'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(refresh.isCompleted, isFalse);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNotNull);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(
      (await AdditionalReminderPreferences.load())
          .firstWhere((s) => s.type == AdditionalReminderType.fajrAlarm)
          .enabled,
      isFalse,
    );
    expect(requests, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    refresh.completeError(StateError('late background failure'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an open extras screen follows cloud restores and stops listening after disposal',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final device = AppPreferenceDevice(
        prefs,
        scope: 'extras-ui',
        reloadControllers: false,
      );
      await tester.pumpWidget(
        app(AdditionalRemindersScreen(refreshSchedule: () async {}), 'fr'),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('extra_fajrAlarm'));
      final series = find.byKey(const ValueKey('notification_series_other'));
      expect(tester.widget<SwitchListTile>(toggle).value, false);
      expect(tester.widget<NotificationSeriesSwitch>(series).value, false);
      await tester.runAsync(
        () => device.apply({
          'additionalReminders': {
            'fajrAlarm': {
              'enabled': true,
              'sound': 'silent',
              'minutes': 47,
              'anchor': 'afterFajr',
              'useDefaultSound': false,
            },
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, true);
      expect(tester.widget<NotificationSeriesSwitch>(series).value, true);
      final sound = tester.widget<SoundSelectionField>(
        find.byType(SoundSelectionField),
      );
      expect(sound.selectedKey, 'silent');
      expect(find.textContaining('47'), findsOneWidget);
      expect(find.textContaining('Après Fajr'), findsOneWidget);
      await tester.runAsync(
        () => device.apply({
          'additionalReminders': {
            'fajrAlarm': {
              'enabled': false,
              'sound': 'silent',
              'minutes': 47,
              'anchor': 'afterFajr',
              'useDefaultSound': false,
            },
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, false);
      expect(tester.widget<NotificationSeriesSwitch>(series).value, false);
      expect(find.byType(SoundSelectionField), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => device.apply({
          'additionalReminders': {
            'fajrAlarm': {'enabled': true},
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
