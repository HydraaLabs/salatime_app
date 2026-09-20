import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:salatime/helper/adhan_notification_service_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'iOS receives an absolute UTC instant even if its named zone rules lag',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({});
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'initialize' ? true : null;
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
      });
      final service = AdhanNotificationServiceImpl();
      await service.initializeNotification(requestPermissions: false);
      final zone = tz.Location('Device/RulesUnknownToPlugin', [], [], [
        const tz.TimeZone(3600000, isDst: false, abbreviation: '+01'),
      ]);
      final when = tz.TZDateTime(zone, 2035, 9, 20, 12, 14);
      expect(
        await service.scheduleNotification(
          id: 10000001,
          title: 'Dohr',
          body: 'Test',
          dateTime: when,
        ),
        isTrue,
      );
      final args =
          calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
              as Map;
      expect(args['timeZoneName'], 'UTC');
      expect(args['scheduledDateTime'], startsWith('2035-09-20T11:14:00'));
    },
  );
}
