import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:salatime/helper/app_translations.dart';

/// Serves `assets/language/<code>.json` from memory so widget tests never wait
/// for a real asset read.
class MemoryTranslationBundle extends AssetBundle {
  MemoryTranslationBundle([this.strings = const {}]);

  /// Strings per language code; a missing language resolves to an empty map.
  final Map<String, Map<String, String>> strings;
  final requested = <String>[];

  @override
  Future<ByteData> load(String key) async {
    final data = utf8.encode(await loadString(key));
    return ByteData.sublistView(Uint8List.fromList(data));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    requested.add(key);
    final code = RegExp(r'assets/language/([a-z]+)\.json$').firstMatch(key);
    if (code == null) throw StateError('Unknown test asset: $key');
    return jsonEncode(strings[code.group(1)] ?? const <String, String>{});
  }
}

/// Points [AppTranslations] at an in-memory bundle for the current test.
MemoryTranslationBundle useMemoryTranslations([
  Map<String, Map<String, String>> strings = const {},
]) {
  final bundle = MemoryTranslationBundle(strings);
  AppTranslations.resetForTest(bundle: bundle);
  return bundle;
}
