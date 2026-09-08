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

  static const List<Map<String, String>> availableSounds = [
    {
      'key': 'azan_1',
      'name': 'Adhan 1',
      'labelKey': 'adhan_1',
      'path': 'assets/audio/azan_1.mp3',
    },
    {
      'key': 'azan_2',
      'name': 'Adhan 2',
      'labelKey': 'adhan_2',
      'path': 'assets/audio/azan_2.mp3',
    },
    {
      'key': 'azan_3',
      'name': 'Adhan 3',
      'labelKey': 'adhan_3',
      'path': 'assets/audio/azan_3.mp3',
    },
    {
      'key': 'noti_beep',
      'name': 'Short Beep',
      'labelKey': 'short_beep',
      'path': 'assets/audio/noti_beep.mp3',
    },
    {
      'key': 'noti_beep_beep',
      'name': 'Long Beep',
      'labelKey': 'long_beep',
      'path': 'assets/audio/noti_beep_beep.mp3',
    },
    {
      'key': 'noti_1',
      'name': 'Other Sound',
      'labelKey': 'other_sound',
      'path': 'assets/audio/noti_1.mp3',
    },
  ];

  final List<Map<String, String>> sounds = availableSounds;

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

  Future<void> selectSound(String? path) async {
    if (path == null || !sounds.any((sound) => sound['path'] == path)) return;

    selectedSound.value = path;
    final prefs = await SharedPreferences.getInstance();
    final fileName = extractFileName(path);

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
    try {
      if (_soundPreview != null) {
        await _soundPreview(path);
        return;
      }
      audioPlayer ??= AudioPlayer();
      await audioPlayer?.stop();
      await audioPlayer?.setAsset(path);
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
