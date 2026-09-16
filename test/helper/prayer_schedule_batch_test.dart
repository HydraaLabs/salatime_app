import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/helper/adhan_notification_service_helper.dart';
import 'package:salatime/helper/prayer_alarm_health.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const plugin = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('flutter_timezone');
  final pluginCalls = <MethodCall>[];
  final nativeCalls = <MethodCall>[];
  var available = true;
  var fail = false;
  var failedRegistrations = 0;
  var inexact = false;
  int? failedPluginId;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    pluginCalls.clear();
    nativeCalls.clear();
    available = true;
    fail = false;
    failedRegistrations = 0;
    inexact = false;
    failedPluginId = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(plugin, (call) async {
      pluginCalls.add(call);
      if (call.method == 'canScheduleExactNotifications') return true;
      if (call.method == 'zonedSchedule' &&
          call.arguments['id'] == failedPluginId) {
        throw PlatformException(code: 'individual_schedule_failed');
      }
      return null;
    });
    messenger.setMockMethodCallHandler(timezone, (_) async => 'UTC');
    messenger.setMockMethodCallHandler(PrayerAlarmHealth.channel, (call) async {
      nativeCalls.add(call);
      if (call.method == 'applyScheduleChanges') {
        if (!available) throw MissingPluginException();
        if (fail) throw PlatformException(code: 'reserve_write_failed');
      }
      return {'routed': 0, 'failed': failedRegistrations, 'inexact': inexact};
    });
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [plugin, timezone, PrayerAlarmHealth.channel]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  Future<bool> schedule(AdhanNotificationServiceImpl service, int id) {
    final at = DateTime.now().add(const Duration(hours: 1));
    return service.scheduleNotification(
      id: id,
      title: 'Fajr',
      body: 'Prayer',
      dateTime: at,
      sound: 'silent',
      payload: jsonEncode({
        'id': id,
        'prayerId': 1,
        'kind': 'adhan',
        'at': at.millisecondsSinceEpoch,
        'prayerAt': at.millisecondsSinceEpoch,
      }),
    );
  }

  test(
    '450 reserve updates use one native transaction and no plugin schedules',
    () async {
      final service = AdhanNotificationServiceImpl(
        batchAndroidScheduling: true,
      );
      expect(service.nativeScheduleApplied, isFalse);
      for (var id = 10000001; id <= 10000450; id++) {
        expect(await schedule(service, id), isTrue);
      }
      expect(service.nativeScheduleApplied, isFalse);
      expect(nativeCalls, isEmpty);
      expect(
        pluginCalls.where((call) => call.method == 'zonedSchedule'),
        isEmpty,
      );
      await service.flushPendingAndroidSchedule();
      expect(service.nativeScheduleApplied, isTrue);
      final call = nativeCalls.single;
      expect(call.method, 'applyScheduleChanges');
      expect(call.arguments['notifications'], hasLength(450));
      expect(call.arguments['cancelIds'], isEmpty);
      final row = call.arguments['notifications'].first as Map;
      expect(row['platformSpecifics']['channelShowBadge'], isFalse);
      expect(row['platformSpecifics']['playSound'], isFalse);
      expect(row['platformSpecifics']['priority'], 2);
      expect(row['scheduledDateTime'], isA<String>());
      expect(row['timeZoneName'], 'UTC');
      await service.flushPendingAndroidSchedule();
      expect(nativeCalls, hasLength(1));
    },
  );

  test(
    'last edit wins within a batch and legacy cancellations stay immediate',
    () async {
      final service = AdhanNotificationServiceImpl(
        batchAndroidScheduling: true,
      );
      await schedule(service, 10000001);
      await service.cancelNotification(10000001);
      await service.cancelNotification(10000002);
      await schedule(service, 10000002);
      await service.cancelNotification(1);
      expect(
        pluginCalls.where((call) => call.method == 'cancel'),
        hasLength(1),
      );
      await service.flushPendingAndroidSchedule();
      final call = nativeCalls.singleWhere(
        (call) => call.method == 'applyScheduleChanges',
      );
      expect(call.arguments['cancelIds'], [10000001]);
      expect((call.arguments['notifications'] as List).single['id'], 10000002);
    },
  );

  test(
    'standalone test registration and cancellation share native transaction locking',
    () async {
      final service = AdhanNotificationServiceImpl();
      expect(await schedule(service, 1999000001), isTrue);
      await service.cancelNotification(1999000001);
      expect(nativeCalls.map((call) => call.method), [
        'applyScheduleChanges',
        'applyScheduleChanges',
      ]);
      expect(nativeCalls.last.arguments['cancelIds'], [1999000001]);
      expect(
        pluginCalls.where(
          (call) => ['zonedSchedule', 'cancel'].contains(call.method),
        ),
        isEmpty,
      );
    },
  );

  test(
    'old binaries fall back once to plugin scheduling and individual routing',
    () async {
      available = false;
      final service = AdhanNotificationServiceImpl(
        batchAndroidScheduling: true,
      );
      await schedule(service, 10000001);
      await schedule(service, 10000002);
      await service.flushPendingAndroidSchedule();
      await schedule(service, 10000003);
      expect(
        nativeCalls.where((call) => call.method == 'applyScheduleChanges'),
        hasLength(1),
      );
      expect(
        pluginCalls.where((call) => call.method == 'zonedSchedule'),
        hasLength(3),
      );
      expect(nativeCalls.where((call) => call.method == 'route'), hasLength(3));
      expect(service.schedulingFailed, isFalse);
      expect(service.nativeScheduleApplied, isFalse);
    },
  );

  test(
    'a failed reserve write is surfaced before its manifest can be saved',
    () async {
      fail = true;
      final service = AdhanNotificationServiceImpl(
        batchAndroidScheduling: true,
      );
      await schedule(service, 10000001);
      await expectLater(
        service.flushPendingAndroidSchedule(),
        throwsA(isA<PlatformException>()),
      );
      expect(service.schedulingFailed, isTrue);
      expect(service.nativeScheduleApplied, isFalse);
      expect(
        pluginCalls.where((call) => call.method == 'zonedSchedule'),
        isEmpty,
      );
    },
  );

  test(
    'partial legacy fallback keeps a checkpoint for successful writes',
    () async {
      available = false;
      failedPluginId = 10000002;
      final service = AdhanNotificationServiceImpl(
        batchAndroidScheduling: true,
      );
      await schedule(service, 10000001);
      await schedule(service, 10000002);
      await service.flushPendingAndroidSchedule();
      expect(service.schedulingFailed, isTrue);
      expect(
        pluginCalls.where((call) => call.method == 'zonedSchedule'),
        hasLength(2),
      );
      expect(nativeCalls.where((call) => call.method == 'route'), hasLength(1));
      await service.flushPendingAndroidSchedule();
      expect(
        pluginCalls.where((call) => call.method == 'zonedSchedule'),
        hasLength(2),
      );
    },
  );

  test(
    'native registration failures and inexact delivery update health flags',
    () async {
      failedRegistrations = 1;
      inexact = true;
      final service = AdhanNotificationServiceImpl(
        batchAndroidScheduling: true,
      );
      await schedule(service, 10000001);
      await service.flushPendingAndroidSchedule();
      expect(service.schedulingFailed, isTrue);
      expect(service.usedInexactAlarms, isTrue);
      expect(service.nativeScheduleApplied, isFalse);
    },
  );

  test('staged edits invalidate the completed native batch handoff', () async {
    final service = AdhanNotificationServiceImpl(batchAndroidScheduling: true);
    await schedule(service, 10000001);
    await service.flushPendingAndroidSchedule();
    expect(service.nativeScheduleApplied, isTrue);
    await service.cancelNotification(10000001);
    expect(service.nativeScheduleApplied, isFalse);
    await service.flushPendingAndroidSchedule();
    expect(service.nativeScheduleApplied, isTrue);
    await schedule(service, 10000002);
    expect(service.nativeScheduleApplied, isFalse);
    fail = true;
    await expectLater(
      service.flushPendingAndroidSchedule(),
      throwsA(isA<PlatformException>()),
    );
    expect(service.nativeScheduleApplied, isFalse);
  });
}
