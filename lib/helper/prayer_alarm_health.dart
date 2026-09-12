import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PrayerAlarmHealth {
  static const channel = MethodChannel('net.salatime.app/prayer_schedule');

  static Future<Map<String, dynamic>?> route(int id) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await channel.invokeMapMethod<String, dynamic>('route', {
        'id': id,
      });
    } on MissingPluginException {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> status() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await channel.invokeMapMethod<String, dynamic>('status');
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('Prayer alarm status unavailable: $error');
      return null;
    }
  }

  static Future<void> cancel({int? id}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await channel.invokeMethod<void>(
        id == null ? 'cancelAll' : 'cancel',
        id == null ? null : {'id': id},
      );
    } on MissingPluginException {
      // Older Android releases only have the notification plugin's alarms.
    } on PlatformException catch (error) {
      // The plugin must still remove the cache entry. The native receiver checks
      // that entry at delivery and ignores cancelled prayers even after an error.
      debugPrint('Native prayer alarm cancellation failed: $error');
    }
  }
}
