import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:salatime/helper/app_translations.dart';
import 'package:salatime/util/app_constants.dart';

import '../support/memory_translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    AppTranslations.resetForTest();
    Get.reset();
  });

  test('every supported language ships a bundled translation file', () async {
    AppTranslations.resetForTest();
    for (final language in AppConstants.languages) {
      final strings = await AppTranslations.load(language.languageCode!);
      expect(strings, isNotEmpty, reason: language.languageCode);
      expect(strings['about'], isNotEmpty, reason: language.languageCode);
      expect(
        AppTranslations.keyFor(language.languageCode!),
        '${language.languageCode}_${language.countryCode}',
      );
    }
  });

  test('a language file is read once and shared by concurrent callers', () async {
    final bundle = useMemoryTranslations({
      'fr': {'about': 'À propos'},
    });
    final results = await Future.wait([
      AppTranslations.load('fr'),
      AppTranslations.load('fr'),
    ]);
    expect(bundle.requested, ['assets/language/fr.json']);
    expect(identical(results[0], results[1]), isTrue);
    expect(await AppTranslations.load('fr'), {'about': 'À propos'});
    expect(bundle.requested, hasLength(1));
  });

  test('an unsupported code falls back to the first language', () async {
    final bundle = useMemoryTranslations();
    expect(AppTranslations.keyFor('xx'), 'en_US');
    await AppTranslations.load('xx');
    expect(bundle.requested, ['assets/language/en.json']);
  });

  test('ensureRegistered adds the strings to GetX only once', () async {
    final bundle = useMemoryTranslations({
      'ar': {'about': 'حول'},
    });
    await AppTranslations.ensureRegistered('ar');
    await AppTranslations.ensureRegistered('ar');
    expect(bundle.requested, hasLength(1));
    expect(Get.translations['ar_SA'], {'about': 'حول'});
  });

  test('ensureRegistered skips languages already supplied at startup', () async {
    final bundle = useMemoryTranslations();
    Get.addTranslations({
      'tr_TR': {'about': 'Hakkında'},
    });
    await AppTranslations.ensureRegistered('tr');
    expect(bundle.requested, isEmpty);
    expect(Get.translations['tr_TR'], {'about': 'Hakkında'});
  });

  test('a failed read is retried on the next request', () async {
    var fail = true;
    AppTranslations.resetForTest(bundle: _FlakyBundle(() => fail));
    await expectLater(AppTranslations.load('fr'), throwsA(isA<StateError>()));
    fail = false;
    expect(await AppTranslations.load('fr'), {'about': 'ok'});
  });
}

class _FlakyBundle extends MemoryTranslationBundle {
  _FlakyBundle(this.shouldFail)
    : super({
        'fr': {'about': 'ok'},
      });
  final bool Function() shouldFail;
  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (shouldFail()) throw StateError('asset unavailable');
    return super.loadString(key, cache: cache);
  }
}
