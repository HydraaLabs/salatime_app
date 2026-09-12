import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/helper/adhan_notification_service_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timezone = MethodChannel('flutter_timezone');
  const native = MethodChannel('net.salatime.app/prayer_schedule');
  final calls = <MethodCall>[];
  var failScheduling = false;
  var existingReplacement = false;
  var exactAllowed = true;
  var revokeBeforeScheduling = false;
  Map<String, Object> channel(String id) => {
    'id': id,
    'name': 'Prayer',
    'showBadge': true,
    'importance': 0,
    'playSound': false,
    'enableLights': false,
    'enableVibration': false,
    'ledColor': 0,
    'audioAttributesUsage': 5,
  };
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    failScheduling = false;
    existingReplacement = false;
    exactAllowed = true;
    revokeBeforeScheduling = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'initialize':
              return true;
            case 'canScheduleExactNotifications':
              return exactAllowed;
            case 'getNotificationChannels':
              return [
                channel('adhan_azan_2'),
                channel('before_adhan_noti_beep'),
                channel('after_adhan_noti_beep'),
                channel('azan_2'),
                channel('com.muslimPath.muslimPath'),
                if (existingReplacement) channel('adhan_azan_2_no_badge_v1'),
              ];
            case 'zonedSchedule':
              if (failScheduling ||
                  (revokeBeforeScheduling &&
                      call.arguments['platformSpecifics']['scheduleMode'] ==
                          'exactAllowWhileIdle')) {
                throw PlatformException(code: 'exact_alarms_not_permitted');
              }
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, (_) async => 'UTC');
  });

  test(
    'denied exact permission and revocation both retain an inexact idle alarm',
    () async {
      for (final deniedBeforeCheck in [true, false]) {
        calls.clear();
        exactAllowed = !deniedBeforeCheck;
        revokeBeforeScheduling = !deniedBeforeCheck;
        final service = AdhanNotificationServiceImpl();
        final ok = await service.scheduleNotification(
          id: 42,
          title: 'Fajr',
          body: 'Prayer',
          dateTime: DateTime.now().add(const Duration(hours: 1)),
        );
        expect(ok, isTrue);
        expect(service.usedInexactAlarms, isTrue);
        expect(service.schedulingFailed, isFalse);
        final schedules = calls
            .where((c) => c.method == 'zonedSchedule')
            .toList();
        expect(schedules, hasLength(deniedBeforeCheck ? 1 : 2));
        expect(
          schedules.last.arguments['platformSpecifics']['scheduleMode'],
          'inexactAllowWhileIdle',
        );
      }
    },
  );

  test('a past occurrence is not silently moved to tomorrow', () async {
    final service = AdhanNotificationServiceImpl();
    expect(
      await service.scheduleNotification(
        id: 42,
        title: 'Fajr',
        body: 'Prayer',
        dateTime: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      isFalse,
    );
    expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, null);
  });

  test('refreshing 450 prayers stays below the Android alarm limit', () async {
    final armed = {for (var id = 10000001; id <= 10000450; id++) 'native:$id'};
    var peak = armed.length;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notifications, (call) async {
      if (call.method == 'canScheduleExactNotifications') return true;
      if (call.method == 'zonedSchedule') {
        armed.add('plugin:${call.arguments['id']}');
        if (armed.length > peak) peak = armed.length;
        if (armed.length > 500) {
          throw PlatformException(code: 'too_many_alarms');
        }
      }
      return null;
    });
    messenger.setMockMethodCallHandler(native, (call) async {
      if (call.method == 'route') {
        final id = call.arguments['id'];
        armed.add('native:$id');
        armed.remove('plugin:$id');
        return {'routed': 1, 'failed': 0, 'inexact': false};
      }
      return null;
    });
    final service = AdhanNotificationServiceImpl();
    for (var id = 10000001; id <= 10000450; id++) {
      expect(
        await service.scheduleNotification(
          id: id,
          title: 'Prayer',
          body: 'Time',
          dateTime: DateTime.now().add(const Duration(hours: 1)),
        ),
        isTrue,
      );
    }
    expect(service.schedulingFailed, isFalse);
    expect(peak, lessThanOrEqualTo(451));
    expect(armed.length, 450);
    expect(armed.where((alarm) => alarm.startsWith('plugin:')), isEmpty);
  });

  test(
    'native routing failure retains the plugin alarm and reports degraded scheduling',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(native, (_) async {
            throw PlatformException(code: 'alarm_operation_failed');
          });
      final service = AdhanNotificationServiceImpl();
      expect(
        await service.scheduleNotification(
          id: 10000001,
          title: 'Prayer',
          body: 'Time',
          dateTime: DateTime.now().add(const Duration(hours: 1)),
        ),
        isTrue,
      );
      expect(service.schedulingFailed, isTrue);
      expect(calls.where((c) => c.method == 'zonedSchedule'), hasLength(1));
      expect(calls.where((c) => c.method == 'cancel'), isEmpty);
    },
  );

  test(
    'migration preserves blocked channels and clears old badges after rescheduling',
    () async {
      final service = AdhanNotificationServiceImpl();
      await service.initializeNotification();
      final created = calls
          .where((c) => c.method == 'createNotificationChannel')
          .toList();
      expect(created, hasLength(4));
      for (final call in created) {
        final config = call.arguments;
        expect(config['showBadge'], isFalse);
        expect(config['importance'], 0);
        expect(config['playSound'], isFalse);
        expect(config['enableVibration'], isFalse);
      }
      expect(
        calls.where((c) => c.method == 'deleteNotificationChannel'),
        isEmpty,
      );
      for (final channelId in [
        'adhan_azan_2',
        'before_adhan_noti_beep',
        'after_adhan_noti_beep',
      ]) {
        await service.scheduleNotification(
          id: 1,
          title: 'Prayer',
          body: 'Time',
          dateTime: DateTime.now().add(const Duration(hours: 1)),
          channel: channelId,
        );
        final details = calls
            .lastWhere((c) => c.method == 'zonedSchedule')
            .arguments['platformSpecifics'];
        expect(details['channelId'], '${channelId}_no_badge_v1');
        expect(details['channelShowBadge'], isFalse);
        expect(details['number'], 0);
        expect(details['playSound'], isTrue);
      }
      await service.retireLegacyBadgeChannels();
      final deleted = calls
          .where((c) => c.method == 'deleteNotificationChannel')
          .map((c) => c.arguments);
      expect(
        deleted,
        unorderedEquals([
          'adhan_azan_2',
          'before_adhan_noti_beep',
          'after_adhan_noti_beep',
          'azan_2',
        ]),
      );
      expect(
        calls.where((c) => c.method == 'cancelAll' || c.method == 'cancel'),
        isEmpty,
      );
    },
  );

  test('failed scheduling retains legacy channels and their alarms', () async {
    final service = AdhanNotificationServiceImpl();
    await service.initializeNotification();
    failScheduling = true;
    await service.scheduleNotification(
      id: 1,
      title: 'Prayer',
      body: 'Time',
      dateTime: DateTime.now().add(const Duration(hours: 1)),
    );
    await service.retireLegacyBadgeChannels();
    expect(
      calls.where((c) => c.method == 'deleteNotificationChannel'),
      isEmpty,
    );
  });

  test(
    'existing replacement settings are not overwritten and previews have no badge',
    () async {
      existingReplacement = true;
      final service = AdhanNotificationServiceImpl();
      await service.initializeNotification();
      expect(
        calls.where(
          (c) =>
              c.method == 'createNotificationChannel' &&
              c.arguments['id'] == 'adhan_azan_2_no_badge_v1',
        ),
        isEmpty,
      );
      await service.sendNotification(title: 'Preview', body: 'Sound');
      final details = calls
          .lastWhere((c) => c.method == 'show')
          .arguments['platformSpecifics'];
      expect(details['channelId'], 'azan_2_no_badge_v1');
      expect(details['channelShowBadge'], isFalse);
      expect(details['number'], 0);
    },
  );
}
