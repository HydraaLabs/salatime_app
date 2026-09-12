import 'package:zabi/service/personal_notification_sounds.dart';
import 'package:zabi/helper/notification_sound_catalog.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/util/app_constants.dart';

class NotiSoundController extends GetxController {
  NotiSoundController({Future<void> Function(String path)? soundPreview})
    : _soundPreview = soundPreview;

  final Future<void> Function(String path)? _soundPreview;
  var selectedSound = RxnString();
  AudioPlayer? audioPlayer;

  static const bundledSounds = NotificationSoundCatalog.sounds;

  static List<Map<String, String>> get availableSounds => [
    ...bundledSounds,
    if (PersonalNotificationSounds.supported)
      ...PersonalNotificationSounds.sounds.map(
        (item) => {...item, 'labelKey': item['name']!},
      ),
  ];
  List<Map<String, String>> get sounds => availableSounds;
  static String label(Map<String, String> sound) =>
      sound['key']!.startsWith('custom_')
      ? sound['name']!
      : sound['labelKey']!.tr;
  static bool isAdhan(String key) =>
      NotificationSoundCatalog.contains(key) || key.startsWith('custom_');

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
    await PersonalNotificationSounds.load(prefs);
    final savedSoundName = prefs.getString(
      AppConstants.SELECTED_NOTIFICATION_SOUND_KEY,
    );

    if (savedSoundName != null &&
        sounds.any((sound) => sound['key'] == savedSoundName)) {
      selectedSound.value = sounds.firstWhere(
        (sound) => sound['key'] == savedSoundName,
      )['path'];
    } else {
      selectedSound.value = AppConstants.DEFAULT_NOTIFICATION_SOUND_ASSET;
      // An imported Android sound is preserved when opening the app elsewhere.
      if (savedSoundName == null || !savedSoundName.startsWith('custom_')) {
        await prefs.setString(
          AppConstants.SELECTED_NOTIFICATION_SOUND_KEY,
          AppConstants.DEFAULT_NOTIFICATION_SOUND,
        );
      }
    }
    update();
  }

  Future<void> selectSound(String? path) async {
    if (path == null || !sounds.any((sound) => sound['path'] == path)) return;

    selectedSound.value = path;
    final prefs = await SharedPreferences.getInstance();
    final fileName = sounds.firstWhere(
      (sound) => sound['path'] == path,
    )['key']!;

    if (kDebugMode) {
      print("Selected Sound Name: $fileName");
    }

    await prefs.setString(
      AppConstants.SELECTED_NOTIFICATION_SOUND_KEY,
      fileName,
    );
    await playSound(path);
  }

  Future<void> playSound(String path) async {
    if (path == 'silent') {
      await stopSound();
      return;
    }
    try {
      if (_soundPreview != null) {
        await _soundPreview(path);
        return;
      }
      audioPlayer ??= AudioPlayer();
      await audioPlayer?.stop();
      if (path.startsWith('content://')) {
        await audioPlayer?.setUrl(path);
      } else {
        await audioPlayer?.setAsset(path);
      }
      unawaited(audioPlayer?.play());
    } catch (e) {
      if (kDebugMode) {
        print('Error playing sound: $e');
      }
    }
  }

  Future<void> stopSound() async {
    try {
      await audioPlayer?.stop();
    } catch (_) {
      // Leaving the screen must not fail if the audio backend is unavailable.
    }
  }

  String extractFileName(String path) {
    return path.split('/').last.split('.').first;
  }
}
