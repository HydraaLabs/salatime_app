import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/controller/noti_sound_controller.dart';
import 'package:zabi/helper/notification_sound_catalog.dart';

void main() {
  test(
    'every imported sound is selectable and packaged without altering its audio',
    () async {
      final manifest = jsonDecode(
        await File('assets/audio/catalog.json').readAsString(),
      );
      final rows = (manifest['sounds'] as List).cast<Map<String, dynamic>>();
      expect(rows, hasLength(68));
      expect(rows.map((row) => row['key']).toSet(), hasLength(68));
      final project = await File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsString();
      for (final row in rows) {
        final key = row['key'] as String;
        expect(NotificationSoundCatalog.contains(key), isTrue, reason: key);
        expect(NotiSoundController.isAdhan(key), isTrue, reason: key);
        for (final folder in ['assets/audio', 'android/app/src/main/res/raw']) {
          final bytes = await File('$folder/$key.mp3').readAsBytes();
          expect(
            sha256.convert(bytes).toString(),
            row['sha256'],
            reason: '$folder/$key',
          );
        }
        expect(
          File('ios/Runner/Resources/$key.aiff').existsSync(),
          isTrue,
          reason: key,
        );
        expect(project, contains('$key.aiff in Resources'), reason: key);
      }
      for (final key in [
        'azan_1',
        'azan_2',
        'azan_3',
        'noti_1',
        'noti_beep',
        'noti_beep_beep',
      ]) {
        expect(
          NotificationSoundCatalog.contains(key),
          isTrue,
          reason: 'existing preference $key',
        );
      }
    },
  );
}
