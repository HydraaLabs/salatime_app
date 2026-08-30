import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/util/app_constants.dart';

class NotiSoundController extends GetxController {
  var selectedSound = RxnString();
  AudioPlayer? audioPlayer;

  final List<Map<String, String>> sounds = [
    {'name': 'Adhan 1', 'path': 'assets/audio/azan_1.mp3'},
    {'name': 'Adhan 2', 'path': 'assets/audio/azan_2.mp3'},
    {'name': 'Adhan 3', 'path': 'assets/audio/azan_3.mp3'},
    {'name': 'Short Beep', 'path': 'assets/audio/noti_beep.mp3'},
    {'name': 'Long Beep', 'path': 'assets/audio/noti_beep_beep.mp3'},
    {'name': 'Other Sound', 'path': 'assets/audio/noti_1.mp3'},
  ];

  @override
  void onInit() async {
    super.onInit();
    audioPlayer = AudioPlayer();
    await loadSelectedSound();
  }

  @override
  void onClose() {
    audioPlayer?.dispose();
    super.onClose();
  }

  Future<void> loadSelectedSound() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSoundName = prefs.getString(
      AppConstants.SELECTED_NOTIFICATION_SOUND_KEY,
    );

    if (savedSoundName != null &&
        sounds.any((sound) => sound['path']!.contains(savedSoundName))) {
      selectedSound.value = sounds.firstWhere(
        (sound) => sound['path']!.contains(savedSoundName),
      )['path'];
    } else {
      selectedSound.value = AppConstants.DEFAULT_NOTIFICATION_SOUND_ASSET;
      await prefs.setString(
        AppConstants.SELECTED_NOTIFICATION_SOUND_KEY,
        AppConstants.DEFAULT_NOTIFICATION_SOUND,
      );
    }
  }

  void selectSound(String? path) async {
    if (path != null && path != selectedSound.value) {
      selectedSound.value = path;
      playSound(path);

      final prefs = await SharedPreferences.getInstance();
      final fileName = extractFileName(path);

      if (kDebugMode) {
        print("Selected Sound Name: $fileName");
      }

      await prefs.setString(
        AppConstants.SELECTED_NOTIFICATION_SOUND_KEY,
        fileName,
      );
    } else if (path == sounds.first['path']) {
      playSound(path!);
    }
  }

  void playSound(String path) async {
    try {
      await audioPlayer?.setAsset(path);
      await audioPlayer?.play();
    } catch (e) {
      if (kDebugMode) {
        print('Error playing sound: $e');
      }
    }
  }

  String extractFileName(String path) {
    return path.split('/').last.split('.').first;
  }
}
