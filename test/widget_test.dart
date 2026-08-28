import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/util/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SalaTime application identity is configured', () {
    expect(AppConstants.APP_NAME, 'SalaTime');
    expect(Uri.parse(AppConstants.BASE_URL).host, 'salatime.net');
  });

  test('every supported language has a bundled translation file', () async {
    for (final language in AppConstants.languages) {
      final languageCode = language.languageCode;
      expect(languageCode, isNotEmpty);

      final contents = await rootBundle.loadString(
        'assets/language/$languageCode.json',
      );
      final translations = json.decode(contents);

      expect(translations, isA<Map<String, dynamic>>());
      expect(translations, isNotEmpty);
    }
  });
}
