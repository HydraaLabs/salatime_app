import 'package:salatime/data/model/response/sura_detile_model.dart';
import 'package:salatime/service/reading/reading_progress_service.dart';

/// Both readers use canonical chapter/verse numbers, never database row IDs.
List<String> quranReadingKeys(int? surahNumber, Iterable<PageVerses>? verses) {
  final keys = <String>{};
  for (final verse in verses ?? <PageVerses>[]) {
    final surah = surahNumber ?? verse.chapterId;
    final number = verse.versesNumber;
    if (verse.chapterId != null && surah != verse.chapterId) continue;
    if (surah != null &&
        number != null &&
        QuranReadingKeys.valid(surah, number)) {
      keys.add('$surah:$number');
    }
  }
  return keys.toList(growable: false);
}
