import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/service/personal_notification_sounds.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final key = 'custom_${List.filled(64, 'a').join()}';
  late Map<String, String> item;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    PersonalNotificationSounds.sounds.clear();
    item = {
      'key': key,
      'name': 'Mon adhan.mp3',
      'path': 'content://net.salatime.app.personal-sounds/sounds/$key.mp3',
    };
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PersonalNotificationSounds.channel, null);
  });
  test(
    'import survives a cold reload and importing the same file deduplicates',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            PersonalNotificationSounds.channel,
            (_) async => item,
          );
      await PersonalNotificationSounds.importSound();
      await PersonalNotificationSounds.importSound();
      PersonalNotificationSounds.sounds.clear();
      await PersonalNotificationSounds.load();
      expect(PersonalNotificationSounds.sounds, [item]);
      expect(PersonalNotificationSounds.find(key)?['path'], item['path']);
    },
  );
  test('cancelling leaves the saved library intact', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PersonalNotificationSounds.storageKey,
      jsonEncode([item]),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          PersonalNotificationSounds.channel,
          (_) async => null,
        );
    expect(await PersonalNotificationSounds.importSound(), isNull);
    await PersonalNotificationSounds.load();
    expect(PersonalNotificationSounds.sounds, [item]);
  });
  test(
    'foreign providers and mismatched files are rejected without persistence',
    () async {
      for (final path in [
        'content://other.app/sounds/$key.mp3',
        'file:///tmp/audio.mp3',
        'content://net.salatime.app.personal-sounds/sounds/another.mp3',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              PersonalNotificationSounds.channel,
              (_) async => {...item, 'path': path},
            );
        await expectLater(
          PersonalNotificationSounds.importSound(),
          throwsA(isA<PlatformException>()),
        );
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PersonalNotificationSounds.storageKey), isNull);
    },
  );
}
