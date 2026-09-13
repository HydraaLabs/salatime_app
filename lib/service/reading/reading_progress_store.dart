import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

abstract class ReadingProgressStore {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> document);
}

/// One JSON write commits a day's edits and their outbox together.
class SharedPreferencesReadingProgressStore implements ReadingProgressStore {
  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid reading cache');
    }
    return decoded;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> document) async {
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getString(key);
    try {
      if (!await prefs.setString(key, jsonEncode(document))) {
        throw StateError('Reading progress could not be saved');
      }
    } catch (_) {
      try {
        if (before == null) {
          await prefs.remove(key);
        } else {
          await prefs.setString(key, before);
        }
      } catch (_) {
        /* Preserve the original storage failure. */
      }
      rethrow;
    }
  }
}
