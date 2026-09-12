import 'package:shared_preferences/shared_preferences.dart';

/// Athkar reading size is local and independent of the Quran reader settings.
class AthkarReaderPreferences {
  const AthkarReaderPreferences();

  static const storageKey = 'athkar_arabic_font_size_v1';
  static const defaultSize = 26.0;
  static const minimumSize = 20.0;
  static const maximumSize = 40.0;

  Future<double> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.get(storageKey);
    if (saved is! num ||
        !saved.isFinite ||
        saved < minimumSize ||
        saved > maximumSize) {
      return defaultSize;
    }
    return saved.toDouble();
  }

  Future<void> save(double size) async {
    if (!size.isFinite || size < minimumSize || size > maximumSize) {
      throw RangeError.value(size, 'size', 'Expected a size between 20 and 40');
    }
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.get(storageKey);
    try {
      if (!await prefs.setDouble(storageKey, size)) {
        throw StateError('Athkar reading size could not be saved');
      }
    } catch (_) {
      // SharedPreferences updates its cache before the platform write completes.
      try {
        if (previous is double) {
          await prefs.setDouble(storageKey, previous);
        } else if (previous is int) {
          await prefs.setInt(storageKey, previous);
        } else {
          await prefs.remove(storageKey);
        }
      } catch (_) {
        // Keep the first persistence error for the reading-size sheet.
      }
      rethrow;
    }
  }
}
