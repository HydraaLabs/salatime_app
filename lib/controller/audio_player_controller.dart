import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:http/http.dart' as http;
import 'package:salatime/helper/quran_chapter_catalog.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/mp3quran_model.dart';
import 'package:salatime/data/model/response/reciters_model.dart';
import 'package:salatime/helper/audio_handler.dart';
import 'package:salatime/helper/audio_service_helper.dart';
import 'package:salatime/helper/debug_http_client.dart';
import 'package:salatime/util/app_constants.dart';

class AudioPlayerController extends GetxController {
  final ApiClient apiClient;

  AudioPlayerController({
    required this.apiClient,
    AudioHandler? audioHandler,
    http.Client? recitersHttpClient,
  }) : _audioHandler = audioHandler ?? AudioServiceHelper.audioHandler,
       _recitersHttpClient = recitersHttpClient ?? appHttpClient;

  final http.Client _recitersHttpClient;

  // Reciter API call
  RxBool isRecitersLoading = false.obs;
  RecitersModel? recitersListApiData;

  // mp3quran.net cache (raw data, keeps the moshaf/recitation lists)
  List<Mp3QuranReciter> recitersMp3 = [];
  // Récitation choisie dans le sélecteur (null = première disponible)
  Moshaf? selectedMoshaf;

  bool hasReciterLoadError = false;
  bool arabicReciterNamesUnavailable = false;
  final Map<String, List<Mp3QuranReciter>> _reciterCatalogs = {};
  final Map<String, Future<List<Mp3QuranReciter>?>> _reciterRequests = {};
  String? _displayedRecitersLanguage;
  int _recitersRequestGeneration = 0;

  // MP3Quran uses eng/cn rather than Flutter's en/zh locale codes.
  // https://www.mp3quran.net/ar/api
  String _reciterApiLanguage(String locale) => switch (locale) {
    // Malay is not offered by MP3Quran: retain a Latin transliteration
    // instead of the provider's silent Arabic-only fallback.
    'en' || 'ms' => 'eng',
    'zh' => 'cn',
    _ => locale,
  };

  Future<List<Mp3QuranReciter>?> _loadReciterCatalog(
    String language, {
    required bool forceRefresh,
  }) {
    final pending = _reciterRequests[language];
    if (pending != null) return pending;
    if (!forceRefresh && _reciterCatalogs.containsKey(language)) {
      return Future.value(_reciterCatalogs[language]);
    }
    final request = _requestReciterCatalog(language);
    _reciterRequests[language] = request;
    return request.whenComplete(() => _reciterRequests.remove(language));
  }

  Future<List<Mp3QuranReciter>?> _requestReciterCatalog(String language) async {
    try {
      final response = await _recitersHttpClient
          .get(
            Uri.parse(
              '${AppConstants.MP3QURAN_API_URL}/reciters',
            ).replace(queryParameters: {'language': language}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw StateError('Reciter catalog HTTP ${response.statusCode}');
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic> || json['reciters'] is! List) {
        throw const FormatException('Invalid reciter catalog');
      }
      final reciters = Mp3QuranResponse.fromJson(json).reciters!;
      _reciterCatalogs[language] = reciters;
      return reciters;
    } catch (error) {
      if (kDebugMode) debugPrint('Reciter catalog unavailable: $error');
      return null;
    }
  }

  // Search never fetches data: localized names and their Arabic aliases are
  // loaded together, joined by the provider's stable reciter ID and cached.
  Future<void> fetchReciterData({bool forceRefresh = false}) async {
    final language = _reciterApiLanguage(Get.locale?.languageCode ?? 'en');
    final generation = ++_recitersRequestGeneration;
    if (_displayedRecitersLanguage != language) {
      recitersListApiData = null;
      recitersMp3 = [];
    }
    isRecitersLoading(true);
    hasReciterLoadError = false;
    arabicReciterNamesUnavailable = false;
    update();

    final catalogs = await Future.wait([
      _loadReciterCatalog(language, forceRefresh: forceRefresh),
      if (language != 'ar')
        _loadReciterCatalog('ar', forceRefresh: forceRefresh),
    ]);
    // A slow request for a previous language must not replace the current list.
    if (generation != _recitersRequestGeneration || isClosed) return;
    final localized = catalogs.first ?? _reciterCatalogs[language];
    final arabic = language == 'ar'
        ? localized
        : catalogs.last ?? _reciterCatalogs['ar'];
    hasReciterLoadError = catalogs.first == null;
    arabicReciterNamesUnavailable = language != 'ar' && arabic == null;
    if (localized != null) {
      recitersMp3 = localized;
      final arabicNames = {
        for (final reciter in arabic ?? <Mp3QuranReciter>[])
          if (reciter.id != null) reciter.id!: reciter.name,
      };
      recitersListApiData = RecitersModel(
        result: true,
        data: [
          for (final reciter in localized)
            if (reciter.id != null)
              Data(
                id: reciter.id,
                name: reciter.name,
                arabicName: arabicNames[reciter.id],
              ),
        ],
      );
      _displayedRecitersLanguage = language;
    }
    isRecitersLoading(false);
    update();
  }

  // Récitations (moshaf) disponibles pour un récitateur
  List<Moshaf> moshafListFor(int reciterId) {
    final reciter = recitersMp3.firstWhereOrNull((r) => r.id == reciterId);
    return reciter?.moshaf ?? [];
  }

  // Reciter audio list (built from the selected mp3quran moshaf)
  RxBool isAudioLoading = false.obs;
  List<dynamic> audioData = [];

  Future<void> fetchAudio(String id) async {
    try {
      audioData.clear();
      isAudioLoading(true);

      final reciterId = int.tryParse(id);
      final reciter = recitersMp3.firstWhereOrNull((r) => r.id == reciterId);
      final moshaf =
          selectedMoshaf ??
          (reciter?.moshaf?.isNotEmpty == true ? reciter!.moshaf!.first : null);

      if (reciter == null || moshaf == null) {
        if (kDebugMode) {
          print("Reciter or moshaf not found for id $id");
        }
        return;
      }

      // Localized sura names from the bundled catalogue, fallback "Sura N"
      final suraNames = await _loadSuraNames();

      audioData = moshaf.surahList
          .map(
            (suraNumber) => {
              'path': moshaf.suraUrl(suraNumber),
              'sura_name': suraNames[suraNumber] ?? 'Sura $suraNumber',
              'chapter_id': suraNumber,
              'reciter_name': reciter.name,
              'duration': null,
              'reciter_avatar': '',
            },
          )
          .toList();

      if (kDebugMode) {
        print("Audio List: ${audioData.length} suras — ${moshaf.name}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching data 4444: $e");
      }
    } finally {
      isAudioLoading(false);
      update();
    }
  }

  // The bundled chapter catalogue keeps names localized without waiting for
  // another network request before showing a reciter's available recordings.
  Future<Map<int, String>> _loadSuraNames() async {
    try {
      final catalog = await QuranChapterCatalog.load();
      final language = Get.locale?.languageCode ?? 'en';
      return {
        for (var id = 1; id <= 114; id++)
          if (catalog.localizedName(id, language) case final String name)
            id: name,
      };
    } catch (error) {
      if (kDebugMode) debugPrint('Sura names unavailable: $error');
      return {};
    }
  }

  // Audio player controller starts
  final AudioHandler _audioHandler;
  StreamSubscription<MediaItem?>? _mediaItemSubscription;
  StreamSubscription<PlaybackState>? _playbackSubscription;

  @override
  void onInit() {
    super.onInit();
    // Subscribe once, even when the user changes reciter repeatedly.
    _mediaItemSubscription = _audioHandler.mediaItem.listen((item) {
      currentMediaItem.value = item;
      duration.value = item?.duration ?? Duration.zero;
      // Refresh the UI
      update();
    });

    // Listen to playback state changes
    _playbackSubscription = _audioHandler.playbackState.listen((state) async {
      isPlaying.value = state.playing;

      // Update position and handle buffering or paused states
      position.value = state.updatePosition;
      update();

      if (state.processingState == AudioProcessingState.ready) {
        duration.value = currentMediaItem.value?.duration ?? Duration.zero;
      }

      // Automatically play the first audio if the last one is finished
      if (state.processingState == AudioProcessingState.completed &&
          audioList.isNotEmpty) {
        // Loop modes are handled natively by just_audio; here only the
        // "no repeat" case needs a decision at the end of the queue.
        if (loopMode.value == LoopMode.off &&
            currentMediaItem.value == audioList.last) {
          await _audioHandler.pause();
          Get.back();
        } else {
          // Skip to next if not the last audio
          await _audioHandler.skipToNext();
        }
      }

      update();
    });
  }

  @override
  void onClose() {
    unawaited(_mediaItemSubscription?.cancel());
    unawaited(_playbackSubscription?.cancel());
    super.onClose();
  }

  final RxList<MediaItem> audioList = <MediaItem>[].obs;
  final Rx<MediaItem?> currentMediaItem = Rx<MediaItem?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isPlaying = false.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;

  // Playback modes: repeat cycles off -> all -> one, shuffle is on/off
  final Rx<LoopMode> loopMode = LoopMode.off.obs;
  final RxBool shuffleEnabled = false.obs;

  Future<void> toggleRepeat() async {
    final next = loopMode.value == LoopMode.off
        ? LoopMode.all
        : loopMode.value == LoopMode.all
        ? LoopMode.one
        : LoopMode.off;
    loopMode.value = next;
    if (_audioHandler is AudioPlayerHandler) {
      await _audioHandler.setLoopMode(next);
    }
    update();
  }

  Future<void> toggleShuffle() async {
    shuffleEnabled.value = !shuffleEnabled.value;
    if (_audioHandler is AudioPlayerHandler) {
      await _audioHandler.setShuffleEnabled(shuffleEnabled.value);
    }
    update();
  }

  // Future<void> ensureAudioHandlerRunning() async {
  //   if (!_audioHandler.playbackState.value.playing &&
  //       _audioHandler.queue.value.isEmpty) {
  //     // Reinitialize the AudioHandler
  //     AudioService.init(
  //       builder: () => AudioPlayerHandler(),
  //       config: const AudioServiceConfig(
  //         androidNotificationChannelId: 'com.muslimPath.muslimPath ',
  //         androidNotificationChannelName: 'Audio playback',
  //         androidNotificationIcon: 'mipmap/launcher_icon',
  //         androidNotificationOngoing: true,
  //       ),
  //     );
  //   }
  // }

  Future<void> loadAudioList(String id) async {
    await fetchAudio(id);

    // Cast the AudioHandler to AudioPlayerHandler to access loadAudioFromApi
    if (_audioHandler is AudioPlayerHandler) {
      await (_audioHandler).loadAudioFromApi(audioData);
    } else {
      throw Exception('AudioHandler is not an instance of AudioPlayerHandler');
    }

    try {
      isLoading(true);
      update();
      audioList.clear();

      // Loop through the fetched API audio data
      for (var audio in audioData) {
        // Handle duration safely
        final int? audioDuration = audio['duration'] != null
            ? audio['duration'] is int
                  ? audio['duration']
                  : int.tryParse(audio['duration'].toString())
            : 0;

        final mediaItem = MediaItem(
          id: audio['path'],
          album: audio['sura_name'] ?? 'Unknown Album',
          title: audio['sura_name'] ?? 'Unknown Title',
          artist: audio['reciter_name'] ?? 'Unknown Artist',
          duration: Duration(
            milliseconds: audioDuration ?? 0,
          ), // Ensure this is a Duration
          artUri: Uri.tryParse(audio['reciter_avatar'] ?? ''),
          extras: {'chapterId': audio['chapter_id']},
        );
        audioList.add(mediaItem);
      }

      // Inside the loadAudioList method, after setting currentMediaItem
      if (audioList.isNotEmpty) {
        currentMediaItem.value = audioList[0];
        await _audioHandler.updateQueue(audioList.toList());
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading audio list: $e');
      }
    } finally {
      isLoading(false);
      update();
    }
  }

  Future<void> playMediaItem(MediaItem mediaItem) async {
    // if (_audioHandler.playbackState.value.processingState ==
    //     AudioProcessingState.idle) {
    //   await ensureAudioHandlerRunning();
    // }
    await _audioHandler.playMediaItem(mediaItem);
    update();
  }

  void togglePlayPause() async {
    if (isPlaying.value) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> skipToNext() async => await _audioHandler.skipToNext();

  Future<void> skipToPrevious() async => await _audioHandler.skipToPrevious();

  Future<void> seekToPosition(double value) async {
    if (value >= 0 && value <= duration.value.inMilliseconds) {
      await _audioHandler.seek(Duration(milliseconds: value.toInt()));
    }
  }
}
