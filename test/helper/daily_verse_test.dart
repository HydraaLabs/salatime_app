import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/helper/daily_verse.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'daily verse keeps one reference across translations and offline tafsir',
    () async {
      final day = DateTime(2024, 1, 1);
      final english = await DailyVerse.load(day, '1');
      final arabic = await DailyVerse.load(day, '4');
      expect(english.chapter, 1);
      expect(english.number, '1');
      expect(arabic.arabic, english.arabic);
      expect(arabic.translation, english.tafsir);
      expect(english.source, 'Ahmed Ali');
      expect(arabic.source, 'تفسير الجلالين');
      expect(english.arabic, isNotEmpty);
      expect(english.tafsir, isNotEmpty);
    },
  );
  test(
    'missing offline tafsir keeps the same verse across reader languages',
    () async {
      final day = DateTime(2029, 7, 17);
      final english = await DailyVerse.load(day, '1');
      final arabic = await DailyVerse.load(day, '4');
      expect(arabic.chapter, english.chapter);
      expect(arabic.number, english.number);
      expect(arabic.arabic, isNotEmpty);
      expect(english.tafsir, isEmpty);
    },
  );
  test('day choice is independent of time and increments across midnight', () {
    expect(
      DailyVerse.dayIndex(DateTime(2026, 9, 12, 23, 59)),
      DailyVerse.dayIndex(DateTime(2026, 9, 12)),
    );
    expect(
      DailyVerse.dayIndex(DateTime(2026, 9, 13)) -
          DailyVerse.dayIndex(DateTime(2026, 9, 12)),
      1,
    );
  });
}
