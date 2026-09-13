import 'package:flutter/foundation.dart';
import 'package:salatime/service/reading/reading_progress_service.dart';

/// UI-only fixture: no storage, auth, timers or network.
class FakeReadingProgress extends ChangeNotifier
    implements ReadingProgressService {
  @override
  bool initialized = false;
  @override
  String status = 'cloud_signed_out';
  @override
  String today = '2026-09-13';
  final targets = <String, int>{};
  final values = <String, ReadingProgressEntry>{};
  int writes = 0;
  int syncCalls = 0;
  int historyCalls = 0;
  bool failWrite = false;

  @override
  Future<void> initialize() async {
    if (initialized) return;
    initialized = true;
    notifyListeners();
  }

  @override
  List<ReadingProgressEntry> get entries => values.values.toList();

  @override
  int target(ReadingProgressKind kind, String key) =>
      kind == ReadingProgressKind.athkar ? targets[key] ?? 1 : 1;

  @override
  int count(ReadingProgressKind kind, String key, {String? day}) =>
      values['${kind.name}|${day ?? today}|$key']?.count ?? 0;

  @override
  int todayCount(ReadingProgressKind kind, String key) => count(kind, key);

  @override
  bool isComplete(ReadingProgressKind kind, String key, {String? day}) =>
      count(kind, key, day: day) >= target(kind, key);

  @override
  Future<void> setCount(
    ReadingProgressKind kind,
    String key,
    int count, {
    String? day,
  }) async {
    if (failWrite) throw StateError('Fixture storage failure');
    final entry = ReadingProgressEntry(
      kind: kind,
      itemKey: key,
      day: day ?? today,
      count: count.clamp(0, target(kind, key)),
    );
    values[entry.key] = entry;
    writes++;
    notifyListeners();
  }

  @override
  Future<void> increment(ReadingProgressKind kind, String key, {String? day}) =>
      setCount(kind, key, count(kind, key, day: day) + 1, day: day);

  @override
  Future<void> setMany(
    ReadingProgressKind kind,
    Map<String, int> counts, {
    String? day,
  }) async {
    for (final item in counts.entries) {
      await setCount(kind, item.key, item.value, day: day);
    }
  }

  @override
  Future<void> syncNow() async {
    syncCalls++;
    status = 'cloud_synced';
    notifyListeners();
  }

  @override
  Future<void> loadHistory() async {
    historyCalls++;
  }

  @override
  ReadingDailyStats statsForDay(String day) {
    final records = entries.where(
      (entry) => entry.day == day && entry.count > 0,
    );
    final athkar = records.where(
      (entry) => entry.kind == ReadingProgressKind.athkar,
    );
    final quran = records
        .where((entry) => entry.kind == ReadingProgressKind.quran)
        .map((entry) => entry.itemKey)
        .toSet();
    return ReadingDailyStats(
      day: day,
      athkarCompleted: athkar
          .where((entry) => entry.count >= target(entry.kind, entry.itemKey))
          .length,
      athkarRepetitions: athkar.fold(0, (sum, entry) => sum + entry.count),
      quranVerses: quran.length,
      quranSurahs: Iterable<int>.generate(114, (index) => index + 1)
          .where(
            (surah) =>
                QuranReadingKeys.keysForSurah(surah).every(quran.contains),
          )
          .length,
    );
  }

  @override
  List<ReadingDailyStats> lastDays([int days = 7]) => [
    for (var offset = days - 1; offset >= 0; offset--)
      statsForDay(
        DateTime.parse(
          today,
        ).subtract(Duration(days: offset)).toIso8601String().substring(0, 10),
      ),
  ];

  @override
  ReadingProgressStats get stats {
    final days = entries
        .map((entry) => entry.day)
        .toSet()
        .map(statsForDay)
        .toList();
    final current = statsForDay(today);
    return ReadingProgressStats(
      todayAthkarCompleted: current.athkarCompleted,
      todayQuranVerses: current.quranVerses,
      todayQuranSurahs: current.quranSurahs,
      quranUniqueVerses: entries
          .where(
            (entry) =>
                entry.kind == ReadingProgressKind.quran && entry.count > 0,
          )
          .map((entry) => entry.itemKey)
          .toSet()
          .length,
      lifetimeAthkarCompleted: days.fold(
        0,
        (sum, day) => sum + day.athkarCompleted,
      ),
      currentStreak: current.active ? 1 : 0,
      activeDays: days.where((day) => day.active).length,
      last7Days: lastDays(),
    );
  }

  void refresh() => notifyListeners();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
