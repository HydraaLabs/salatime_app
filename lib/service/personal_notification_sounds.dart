import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalNotificationSounds {
  static const _applicationId = String.fromEnvironment(
    'SALATIME_APPLICATION_ID',
    defaultValue: 'net.salatime.app',
  );
  static const storageKey = 'personal_notification_sounds_v1';
  static const channel = MethodChannel('net.salatime.app/personal_sounds');
  static final sounds = <Map<String, String>>[].obs;
  static bool get supported =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform);
  static bool valid(Map<String, dynamic> row) {
    final key = row['key'];
    final path = row['path'];
    final name = row['name'];
    if (key is! String ||
        path is! String ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 100) {
      return false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return RegExp(r'^custom_[a-f0-9]{64}$').hasMatch(key) &&
          path == '$key.caf';
    }
    final uri = Uri.tryParse(path);
    return RegExp(r'^custom_[a-f0-9]{64}$').hasMatch(key) &&
        uri != null &&
        uri.scheme == 'content' &&
        uri.host == '$_applicationId.personal-sounds' &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'sounds' &&
        RegExp(
          '^${RegExp.escape(key)}\\.(mp3|m4a|aac|ogg|flac|wav|3gp)\$',
        ).hasMatch(uri.pathSegments.last);
  }

  static Future<String> playbackPath(String path) async {
    if (defaultTargetPlatform != TargetPlatform.iOS ||
        !RegExp(r'^custom_[a-f0-9]{64}\.caf$').hasMatch(path)) {
      return path;
    }
    final url = await channel.invokeMethod<String>('resolve', {
      'key': path.substring(0, path.length - 4),
    });
    if (url == null || Uri.tryParse(url)?.scheme != 'file') {
      throw PlatformException(code: 'sound_missing');
    }
    return url;
  }

  static Future<void> load([SharedPreferences? prefs]) async {
    final preferences = prefs ?? await SharedPreferences.getInstance();
    final rows = <Map<String, String>>[];
    try {
      final decoded = jsonDecode(preferences.getString(storageKey) ?? '[]');
      if (decoded is List) {
        for (final item in decoded.take(30)) {
          if (item is Map &&
              valid(Map<String, dynamic>.from(item)) &&
              !rows.any((row) => row['key'] == item['key'])) {
            rows.add({
              'key': item['key'] as String,
              'name': item['name'] as String,
              'path': item['path'] as String,
            });
          }
        }
      }
    } catch (_) {
      /* Ignore invalid restored settings. */
    }
    if (!listEquals(
      sounds.map(jsonEncode).toList(),
      rows.map(jsonEncode).toList(),
    )) {
      sounds.assignAll(rows);
    }
  }

  static Map<String, String>? find(String? key) {
    for (final item in sounds) {
      if (item['key'] == key) return item;
    }
    return null;
  }

  static Future<Map<String, String>?> importSound() async {
    if (!supported) return null;
    final row = await channel.invokeMapMethod<String, dynamic>('import');
    if (row == null) return null;
    if (!valid(row)) throw PlatformException(code: 'sound_invalid');
    final prefs = await SharedPreferences.getInstance();
    await load(prefs);
    final item = {
      'key': row['key'] as String,
      'name': row['name'] as String,
      'path': row['path'] as String,
    };
    final next = [...sounds.where((old) => old['key'] != item['key']), item];
    if (!await prefs.setString(storageKey, jsonEncode(next))) {
      throw PlatformException(code: 'sound_import_failed');
    }
    sounds.assignAll(next);
    return item;
  }
}
