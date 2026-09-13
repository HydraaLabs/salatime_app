import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/adhan_notification_service_helper.dart';
import 'package:salatime/service/cloud/preference_device.dart';
import 'package:salatime/service/personal_notification_sounds.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timezone = MethodChannel('flutter_timezone');
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    PersonalNotificationSounds.sounds.clear();
    for (final channel in [
      notifications,
      timezone,
      AppPreferenceDevice.widgetChannel,
      AppPreferenceDevice.silenceChannel,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  test(
    'iOS schedules bundled and imported audio without a badge and preserves silence',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(notifications, (call) async {
        calls.add(call);
        return call.method == 'initialize' ? true : null;
      });
      messenger.setMockMethodCallHandler(timezone, (_) async => 'UTC');
      final key = 'custom_${'a' * 64}';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        PersonalNotificationSounds.storageKey,
        jsonEncode([
          {'key': key, 'name': 'My audio', 'path': '$key.caf'},
        ]),
      );
      final service = AdhanNotificationServiceImpl();
      for (final sound in ['azan_2', key, 'silent']) {
        expect(
          await service.scheduleNotification(
            id: 42,
            title: 'Fajr',
            body: 'Time',
            sound: sound,
            dateTime: DateTime.now().add(const Duration(hours: 1)),
          ),
          isTrue,
        );
        final details = calls
            .lastWhere((call) => call.method == 'zonedSchedule')
            .arguments['platformSpecifics'];
        expect(details['presentBadge'], isFalse);
        expect(details['badgeNumber'], 0);
        expect(details['presentSound'], sound != 'silent');
        expect(
          details['sound'],
          sound == 'silent'
              ? null
              : sound == key
              ? '$key.caf'
              : 'azan_2.aiff',
        );
      }
      expect(
        calls.any((call) => call.method == 'canScheduleExactNotifications'),
        isFalse,
      );
    },
  );

  test(
    'iOS cloud restore updates widget options without calling Android DND',
    () async {
      var options = <String, dynamic>{'city': true, 'opacity': 100};
      final widgetCalls = <MethodCall>[];
      final silenceCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(AppPreferenceDevice.widgetChannel, (
        call,
      ) async {
        widgetCalls.add(call);
        if (call.method == 'get') return options;
        if (call.method == 'set') {
          options = Map<String, dynamic>.from(call.arguments);
        }
        return null;
      });
      messenger.setMockMethodCallHandler(AppPreferenceDevice.silenceChannel, (
        call,
      ) async {
        silenceCalls.add(call);
        return {};
      });
      final adapter = AppPreferenceDevice(
        await SharedPreferences.getInstance(),
        scope: 'ios',
        reloadControllers: false,
      );
      final before = await adapter.capture();
      await adapter.apply({
        ...before,
        'widgets': {...before['widgets'] as Map, 'city': false, 'opacity': 60},
      });
      expect(widgetCalls.any((call) => call.method == 'set'), isTrue);
      final after = await adapter.capture();
      expect(after['widgets']['city'], isFalse);
      expect(after['widgets']['opacity'], 60);
      expect(silenceCalls, isEmpty);
    },
  );
}
