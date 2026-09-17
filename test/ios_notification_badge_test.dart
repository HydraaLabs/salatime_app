import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/helper/adhan_notification_service_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all prayer phases share one iOS thread without replacing pending IDs',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({});
      tz_data.initializeTimeZones();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      const timezone = MethodChannel('flutter_timezone');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'initialize' ? true : null;
      });
      messenger.setMockMethodCallHandler(timezone, (_) async => 'UTC');
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(timezone, null);
      });
      final service = AdhanNotificationServiceImpl();
      await service.initializeNotification(requestPermissions: false);
      final kinds = ['before', 'adhan', 'after', 'extra_reminder'];
      for (var index = 0; index < kinds.length; index++) {
        final id = 10000000 + index;
        expect(
          await service.scheduleNotification(
            id: id,
            title: 'Prayer',
            body: kinds[index],
            dateTime: DateTime.now().add(Duration(hours: index + 1)),
            payload: jsonEncode({'id': id, 'kind': kinds[index]}),
          ),
          isTrue,
        );
      }
      final scheduled = calls
          .where((c) => c.method == 'zonedSchedule')
          .toList();
      expect(scheduled.map((c) => c.arguments['id']).toSet().length, 4);
      for (final call in scheduled) {
        expect(
          call.arguments['platformSpecifics']['threadIdentifier'],
          'salatime.prayer-reminders',
        );
      }
      await service.sendNotification(title: 'Sound preview', body: 'Preview');
      expect(
        calls
            .lastWhere((c) => c.method == 'show')
            .arguments['platformSpecifics']['threadIdentifier'],
        isNull,
      );
      expect(calls.where((c) => c.method.startsWith('cancel')), isEmpty);
    },
  );
  test(
    'cloud restore initializes iOS without any permission request',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'initialize' ? true : null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await AdhanNotificationServiceImpl().initializeNotification(
        requestPermissions: false,
      );
      final initialization = calls
          .singleWhere((call) => call.method == 'initialize')
          .arguments;
      expect(initialization['requestAlertPermission'], false);
      expect(initialization['requestSoundPermission'], false);
      expect(initialization['requestBadgePermission'], false);
      expect(
        calls.where((call) => call.method == 'requestPermissions'),
        isEmpty,
      );
    },
  );
  test(
    'iOS notifications keep alerts and sound without incrementing the badge',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'initialize' ? true : null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final service = AdhanNotificationServiceImpl();
      await service.initializeNotification();
      final initialization = calls
          .firstWhere((c) => c.method == 'initialize')
          .arguments;
      expect(initialization['requestBadgePermission'], isFalse);
      expect(initialization['defaultPresentBadge'], isFalse);
      expect(initialization['defaultPresentSound'], isTrue);
      await service.sendNotification(title: 'Prayer', body: 'Time');
      final details = calls
          .lastWhere((c) => c.method == 'show')
          .arguments['platformSpecifics'];
      expect(details['presentBadge'], isFalse);
      expect(details['badgeNumber'], 0);
      expect(details['presentAlert'], isTrue);
      expect(details['presentSound'], isTrue);
    },
  );
}
