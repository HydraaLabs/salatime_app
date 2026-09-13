import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/controller/noti_sound_controller.dart';
import 'package:salatime/data/model/response/todays_prayer_time_model.dart';
import 'package:salatime/util/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);
  test(
    'adjusted display includes sunrise without mutating cached schedule',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = Get.put(PrayerTimeAdjustmentController());
      await controller.init();
      await controller.updateAdjustment('sunrise', -2);
      await controller.updateAdjustment('asr', 5);
      final raw = Data(sunrise: '07:01', asrStart: '16:48');
      final result = PrayerTimeAdjustmentController.adjustedDay(raw)!;
      expect(result.sunrise, '06:59');
      expect(result.asrStart, '16:53');
      expect(raw.asrStart, '16:48');
      expect(
        PrayerTimeAdjustmentController.adjustedDay(raw)!.asrStart,
        '16:53',
      );
    },
  );
  test(
    'silent notification choice is saved without playing an asset',
    () async {
      SharedPreferences.setMockInitialValues({});
      var previews = 0;
      final controller = NotiSoundController(
        soundPreview: (_) async => previews++,
      );
      await controller.selectSound('silent');
      expect(previews, 0);
      expect(
        (await SharedPreferences.getInstance()).getString(
          AppConstants.SELECTED_NOTIFICATION_SOUND_KEY,
        ),
        'silent',
      );
      await controller.loadSelectedSound();
      expect(controller.selectedSound.value, 'silent');
    },
  );
}
