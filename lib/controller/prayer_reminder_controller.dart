import 'package:zabi/service/personal_notification_sounds.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/noti_sound_controller.dart';
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/util/app_constants.dart';

enum PrayerReminderType { before, after }

class PrayerReminderController extends GetxController {
  PrayerReminderController({Future<void> Function(String path)? soundPreview})
    : _soundPreview = soundPreview;

  static final List<int> minuteOptions = List<int>.unmodifiable(
    List<int>.generate(60, (index) => index + 1),
  );

  final beforeEnabled = false.obs;
  final afterEnabled = false.obs;
  final beforeMinutes = AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES.obs;
  final afterMinutes = AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES.obs;
  final beforeSound = AppConstants.DEFAULT_PRAYER_REMINDER_SOUND.obs;
  final afterSound = AppConstants.DEFAULT_PRAYER_REMINDER_SOUND.obs;

  AudioPlayer? _audioPlayer;
  final Future<void> Function(String path)? _soundPreview;

  List<Map<String, String>> get sounds => NotiSoundController.availableSounds;

  @override
  void onInit() {
    super.onInit();
    _audioPlayer = AudioPlayer();
    loadPreferences();
  }

  @override
  void onClose() {
    _audioPlayer?.dispose();
    super.onClose();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await PersonalNotificationSounds.load(prefs);
    beforeEnabled.value =
        prefs.getBool(AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY) ?? false;
    afterEnabled.value =
        prefs.getBool(AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY) ?? false;
    beforeMinutes.value = _validMinutes(
      prefs.getInt(AppConstants.BEFORE_ADHAN_REMINDER_MINUTES_KEY),
    );
    afterMinutes.value = _validMinutes(
      prefs.getInt(AppConstants.AFTER_ADHAN_REMINDER_MINUTES_KEY),
    );
    beforeSound.value = _validSound(
      prefs.getString(AppConstants.BEFORE_ADHAN_REMINDER_SOUND_KEY),
    );
    afterSound.value = _validSound(
      prefs.getString(AppConstants.AFTER_ADHAN_REMINDER_SOUND_KEY),
    );
  }

  Future<void> setEnabled(PrayerReminderType type, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (type == PrayerReminderType.before) {
      beforeEnabled.value = enabled;
      await prefs.setBool(
        AppConstants.BEFORE_ADHAN_REMINDER_ENABLED_KEY,
        enabled,
      );
    } else {
      afterEnabled.value = enabled;
      await prefs.setBool(
        AppConstants.AFTER_ADHAN_REMINDER_ENABLED_KEY,
        enabled,
      );
    }
    await _rescheduleNotifications();
  }

  Future<void> setMinutes(PrayerReminderType type, int minutes) async {
    final validMinutes = _validMinutes(minutes);
    final prefs = await SharedPreferences.getInstance();
    if (type == PrayerReminderType.before) {
      beforeMinutes.value = validMinutes;
      await prefs.setInt(
        AppConstants.BEFORE_ADHAN_REMINDER_MINUTES_KEY,
        validMinutes,
      );
    } else {
      afterMinutes.value = validMinutes;
      await prefs.setInt(
        AppConstants.AFTER_ADHAN_REMINDER_MINUTES_KEY,
        validMinutes,
      );
    }
    await _rescheduleNotifications();
  }

  Future<void> setSound(PrayerReminderType type, String sound) async {
    final validSound = _validSound(sound);
    final prefs = await SharedPreferences.getInstance();
    if (type == PrayerReminderType.before) {
      beforeSound.value = validSound;
      await prefs.setString(
        AppConstants.BEFORE_ADHAN_REMINDER_SOUND_KEY,
        validSound,
      );
    } else {
      afterSound.value = validSound;
      await prefs.setString(
        AppConstants.AFTER_ADHAN_REMINDER_SOUND_KEY,
        validSound,
      );
    }
    await _previewSound(validSound);
    await _rescheduleNotifications();
  }

  int _validMinutes(int? minutes) {
    return minuteOptions.contains(minutes)
        ? minutes!
        : AppConstants.DEFAULT_PRAYER_REMINDER_MINUTES;
  }

  String _validSound(String? sound) {
    return sounds.any((option) => option['key'] == sound)
        ? sound!
        : AppConstants.DEFAULT_PRAYER_REMINDER_SOUND;
  }

  Future<void> previewSound(String sound) => _previewSound(sound);

  Future<void> stopPreview() async {
    try {
      await _audioPlayer?.stop();
    } catch (_) {
      // Navigation remains available if the audio backend is unavailable.
    }
  }

  Future<void> _previewSound(String sound) async {
    try {
      await _audioPlayer?.stop();
      if (sound == 'silent') return;
      final option = sounds.firstWhere((item) => item['key'] == sound);
      if (_soundPreview != null) {
        await _soundPreview(option['path']!);
        return;
      }
      if (sound.startsWith('custom_')) {
        await _audioPlayer?.setUrl(option['path']!);
      } else {
        await _audioPlayer?.setAsset(option['path']!);
      }
      unawaited(_audioPlayer?.play());
    } catch (_) {
      // A preview failure must not prevent saving or scheduling the reminder.
    }
  }

  Future<void> _rescheduleNotifications() async {
    try {
      await SalatWaqtService.initializeSalatWaqt();
    } catch (error) {
      Get.log('Failed to reschedule prayer reminders: $error');
    }
  }
}
