import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/helper/adhan_notification_service_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
