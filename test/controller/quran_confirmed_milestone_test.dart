import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/quran_milestone_controller.dart';
import 'package:zabi/service/reading/reading_progress_service.dart';
import 'package:zabi/util/app_constants.dart';

class _Reading extends ChangeNotifier implements ReadingProgressService {
  int surahs = 0;
  @override
  ReadingProgressStats get stats => ReadingProgressStats(
    todayAthkarCompleted: 0,
    todayQuranVerses: 0,
    todayQuranSurahs: surahs,
    quranUniqueVerses: 0,
    lifetimeAthkarCompleted: 0,
    currentStreak: 0,
    activeDays: 0,
    last7Days: const [],
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'old opened-surah counters never become confirmed reading history',
    () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.QURAN_MILESTONE_PROGRESS_KEY: ['1', '2'],
        '${AppConstants.QURAN_MILESTONE_PROGRESS_KEY}_date': '2026-09-13',
        AppConstants.QURAN_MILESTONE_GOAL_KEY: 5,
      });
      final reading = _Reading();
      final controller = QuranMilestoneController(
        sharedPreferences: await SharedPreferences.getInstance(),
        progress: reading,
      );
      expect(controller.surahsReadToday.value, 0);
      expect(controller.dailyGoal.value, 5);
      controller.onClose();
    },
  );

  test(
    'confirmed reading, unchecking and a new day update the home milestone',
    () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.QURAN_MILESTONE_GOAL_KEY: 2,
      });
      final reading = _Reading();
      final controller = QuranMilestoneController(
        sharedPreferences: await SharedPreferences.getInstance(),
        progress: reading,
      );
      reading.surahs = 2;
      reading.notifyListeners();
      expect(controller.progressRatio, 1);
      reading.surahs = 1;
      reading.notifyListeners();
      expect(controller.progressRatio, .5);
      reading.surahs = 0;
      reading.notifyListeners();
      expect(controller.surahsReadToday.value, 0);
      controller.onClose();
      reading.surahs = 7;
      reading.notifyListeners();
      expect(controller.surahsReadToday.value, 0);
    },
  );
}
