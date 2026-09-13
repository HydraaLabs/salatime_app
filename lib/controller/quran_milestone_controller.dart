import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/service/reading/reading_progress_service.dart';
import 'package:zabi/util/app_constants.dart';

/// Counts fully confirmed surahs for today; opening a reader is not a reading.
class QuranMilestoneController extends GetxController implements GetxService {
  QuranMilestoneController({
    required this.sharedPreferences,
    ReadingProgressService? progress,
  }) : _progress = progress ?? ReadingProgressService.instance {
    dailyGoal.value =
        sharedPreferences.getInt(AppConstants.QURAN_MILESTONE_GOAL_KEY) ??
        defaultDailyGoal;
    _progress.addListener(_refresh);
    _refresh();
  }

  final SharedPreferences sharedPreferences;
  final ReadingProgressService _progress;
  static const int defaultDailyGoal = 20;
  final RxInt dailyGoal = defaultDailyGoal.obs;
  final RxInt surahsReadToday = 0.obs;

  void _refresh() {
    surahsReadToday.value = _progress.stats.todayQuranSurahs;
  }

  double get progressRatio => dailyGoal.value <= 0
      ? 0
      : (surahsReadToday.value / dailyGoal.value).clamp(0, 1);

  @override
  void onClose() {
    _progress.removeListener(_refresh);
    super.onClose();
  }
}
