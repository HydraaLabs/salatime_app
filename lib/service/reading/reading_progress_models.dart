enum ReadingProgressKind { athkar, quran }

class ReadingProgressEntry {
  const ReadingProgressEntry({
    required this.kind,
    required this.itemKey,
    required this.day,
    required this.count,
    this.revision = 0,
  });
  final ReadingProgressKind kind;
  final String itemKey;
  final String day;
  final int count;
  final int revision;
  String get key => '${kind.name}|$day|$itemKey';
  Map<String, Object> toJson() => {
    'kind': kind.name,
    'itemKey': itemKey,
    'day': day,
    'count': count,
    'revision': revision,
  };
}

class ReadingProgressOperation {
  const ReadingProgressOperation({
    required this.id,
    required this.entry,
    this.merge = false,
  });
  final String id;
  final ReadingProgressEntry entry;

  /// Guest imports preserve the greater count; ordinary edits can still uncheck.
  final bool merge;
  Map<String, Object> toJson() => {
    'id': id,
    'kind': entry.kind.name,
    'itemKey': entry.itemKey,
    'day': entry.day,
    'count': entry.count,
    if (merge) 'merge': true,
  };
}

class ReadingDailyStats {
  const ReadingDailyStats({
    required this.day,
    this.athkarCompleted = 0,
    this.athkarRepetitions = 0,
    this.quranVerses = 0,
    this.quranSurahs = 0,
  });
  final String day;
  final int athkarCompleted;
  final int athkarRepetitions;
  final int quranVerses;
  final int quranSurahs;
  bool get active => athkarRepetitions > 0 || quranVerses > 0;
}

class ReadingProgressStats {
  const ReadingProgressStats({
    required this.todayAthkarCompleted,
    required this.todayQuranVerses,
    required this.todayQuranSurahs,
    required this.quranUniqueVerses,
    required this.lifetimeAthkarCompleted,
    required this.currentStreak,
    required this.activeDays,
    required this.last7Days,
  });
  final int todayAthkarCompleted;
  final int todayQuranVerses;
  final int todayQuranSurahs;
  final int quranUniqueVerses;
  final int lifetimeAthkarCompleted;
  final int currentStreak;
  final int activeDays;
  final List<ReadingDailyStats> last7Days;
  int get totalQuranVerses => QuranReadingKeys.totalVerses;
}

/// The canonical counts match the bundled Quran's 114-surah index.
class QuranReadingKeys {
  static const totalVerses = 6236;
  static const List<int> verseCounts = [
    7,
    286,
    200,
    176,
    120,
    165,
    206,
    75,
    129,
    109,
    123,
    111,
    43,
    52,
    99,
    128,
    111,
    110,
    98,
    135,
    112,
    78,
    118,
    64,
    77,
    227,
    93,
    88,
    69,
    60,
    34,
    30,
    73,
    54,
    45,
    83,
    182,
    88,
    75,
    85,
    54,
    53,
    89,
    59,
    37,
    35,
    38,
    29,
    18,
    45,
    60,
    49,
    62,
    55,
    78,
    96,
    29,
    22,
    24,
    13,
    14,
    11,
    11,
    18,
    12,
    12,
    30,
    52,
    52,
    44,
    28,
    28,
    20,
    56,
    40,
    31,
    50,
    40,
    46,
    42,
    29,
    19,
    36,
    25,
    22,
    17,
    19,
    26,
    30,
    20,
    15,
    21,
    11,
    8,
    8,
    19,
    5,
    8,
    8,
    11,
    11,
    8,
    3,
    9,
    5,
    4,
    7,
    3,
    6,
    3,
    5,
    4,
    5,
    6,
  ];
  static bool valid(int surah, int verse) =>
      surah >= 1 &&
      surah <= verseCounts.length &&
      verse >= 1 &&
      verse <= verseCounts[surah - 1];
  static bool contains(String key) {
    if (!RegExp(r'^[1-9][0-9]{0,2}:[1-9][0-9]{0,2}$').hasMatch(key)) {
      return false;
    }
    final parts = key.split(':');
    return valid(int.parse(parts[0]), int.parse(parts[1]));
  }

  static List<String> keysForSurah(int surah) {
    if (surah < 1 || surah > verseCounts.length) {
      throw RangeError.range(surah, 1, verseCounts.length, 'surah');
    }
    return List<String>.unmodifiable(
      List.generate(verseCounts[surah - 1], (index) => '$surah:${index + 1}'),
    );
  }
}
