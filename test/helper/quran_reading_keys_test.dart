import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/data/model/response/sura_detile_model.dart';
import 'package:zabi/service/reading/reading_progress_service.dart';
import 'package:zabi/view/screens/quran/widget/quran_reading_keys.dart';

void main() {
  test(
    'reading identity uses canonical verse numbers and ignores duplicate rows',
    () {
      final verses = [
        PageVerses(id: 999, chapterId: 87, versesNumber: 1),
        PageVerses(id: 1000, chapterId: 87, versesNumber: 2),
        PageVerses(id: 1001, chapterId: 87, versesNumber: 2),
      ];
      expect(quranReadingKeys(87, verses), ['87:1', '87:2']);
    },
  );

  test(
    'invalid, incomplete or mismatched identities cannot be marked read',
    () {
      expect(
        quranReadingKeys(87, [
          PageVerses(chapterId: 86, versesNumber: 1),
          PageVerses(chapterId: 87, versesNumber: 20),
          PageVerses(chapterId: 87),
          PageVerses(chapterId: 87, versesNumber: 0),
        ]),
        isEmpty,
      );
      expect(quranReadingKeys(null, null), isEmpty);
      expect(
        quranReadingKeys(null, [PageVerses(chapterId: 1, versesNumber: 7)]),
        ['1:7'],
      );
    },
  );

  for (final locale in ['ar', 'en', 'bn', 'sp']) {
    test(
      '$locale offline chapters match their files and all 6236 reading keys',
      () {
        var total = 0;
        for (var number = 1; number <= 114; number++) {
          final decoded = jsonDecode(
            File('assets/quran/$locale/s00$number.json').readAsStringSync(),
          );
          final raw = decoded is List ? decoded.single : decoded;
          final chapter = SuraDetaileModel.fromJson(
            Map<String, dynamic>.from(raw as Map),
          ).data!;
          expect(
            chapter.chapter!.id,
            number,
            reason: '$locale chapter $number',
          );
          final verses = chapter.chapterInfo!.expand(
            (page) => page.pageVerses!,
          );
          final keys = quranReadingKeys(number, verses);
          expect(
            keys,
            QuranReadingKeys.keysForSurah(number),
            reason: '$locale chapter $number',
          );
          expect(
            verses.length,
            keys.length,
            reason: 'No duplicates in $locale chapter $number',
          );
          total += keys.length;
        }
        expect(total, 6236);
      },
    );
  }
}
