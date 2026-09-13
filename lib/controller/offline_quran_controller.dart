// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:salatime/data/model/response/juz_list_model.dart';
import 'package:salatime/data/model/response/offline_sura_model.dart';
import 'package:salatime/data/model/response/sura_detile_model.dart';
import 'package:salatime/helper/offline_quran_loader.dart';
import 'package:salatime/service/quran/quran_translation_repository.dart';
import 'package:salatime/view/screens/offline_quran/offline_surah_detail_screen.dart';

class OfflineQuranController extends GetxController {
  OfflineQuranController({
    QuranLoader? loader,
    QuranTranslationRepository? translations,
    String Function()? languageCode,
  }) : _loader =
           loader ??
           (translations == null
               ? QuranLoader.instance
               : QuranLoader(translations: translations)),
       _translations = translations ?? QuranTranslationRepository.instance,
       _languageCode = languageCode ?? (() => Get.locale?.languageCode ?? 'en');

  final QuranLoader _loader;
  final QuranTranslationRepository _translations;
  final String Function() _languageCode;
  final translationError = RxnString();
  final searchError = RxnString();
  int _translationGeneration = 0;
  String? _requestedLanguage;
  RxBool isLoading = true.obs;
  RxList<OfflineSurahListModel> surahList = <OfflineSurahListModel>[].obs;

  Future<void> loadSurahList() async {
    print('Loading offline surah list...');
    try {
      final String response = await rootBundle.loadString(
        'assets/quran/surah_list.json',
      );
      final data = json.decode(response);
      final List surahData = data['data'];
      surahList.value = surahData
          .map((e) => OfflineSurahListModel.fromJson(e))
          .toList();
    } catch (e) {
      print('Error loading surah list: $e');
    } finally {
      isLoading.value = false;
      update();
    }
  }

  // Add other methods to load surah details, ayahs, etc. as needed

  RxBool isSurahDetailsLoading = true.obs;

  SuraDetaileModel? suraDetailsApiData;

  // translatorId is retained only for compatibility with older routes.
  Future<void> loadSurahDetails({
    required int surahNumber,
    String? translatorId,
  }) => _loadTranslation(surahNumber, _languageCode());

  Future<void> _loadTranslation(int number, String language) async {
    final generation = ++_translationGeneration;
    _requestedLanguage = language;
    translationError.value = null;
    suraDetailsApiData = null;
    isSurahDetailsLoading.value = true;
    if (number >= 1 && number <= 114) lastSurahNumber = number;
    update();
    try {
      final result = await _translations.loadSurah(
        number,
        languageCode: language,
      );
      if (isClosed ||
          generation != _translationGeneration ||
          _requestedLanguage != language) {
        return;
      }
      suraDetailsApiData = result;
    } catch (_) {
      if (!isClosed && generation == _translationGeneration) {
        translationError.value = 'quran_translation_unavailable';
      }
    } finally {
      if (!isClosed && generation == _translationGeneration) {
        isSurahDetailsLoading.value = false;
        update();
      }
    }
  }

  Future<void> refreshTranslation({String? languageCode}) async {
    final language = languageCode ?? _languageCode();
    await Future.wait<void>([
      if (lastSurahNumber != null) _loadTranslation(lastSurahNumber!, language),
      if (_indexRequested) _ensureSearchIndex(language),
    ]);
  }

  // change surah detail ayah font size

  int? lastSurahNumber;

  void changeSurah(int surahNumber) {
    lastSurahNumber = surahNumber;
    loadSurahDetails(surahNumber: surahNumber);
    update(); // refresh the GetBuilder UI

    // Navigate after updating state (prevents setState/build conflicts)
    Future.microtask(() {
      Get.to(
        () => OfflineSuraDetaileScreen(
          appBackButton: true,
          surahNumber: surahNumber.toString(),
        ),
        arguments: 0,
      );
    });
  }

  // juzz data
  RxBool isJuzzLoading = true.obs;
  JuzListModel? juzListApiData;
  Future<void> loadJuzzList() async {
    print('Loading offline juzz list...');
    try {
      final String response = await rootBundle.loadString(
        'assets/quran/juzz_list.json',
      );
      final data = json.decode(response);
      juzListApiData = JuzListModel.fromJson(data);
    } catch (e) {
      print('Error loading juzz list: $e');
    } finally {
      isJuzzLoading.value = false;
    }
  }

  final verses = <Map<String, dynamic>>[].obs; // cached verses
  final results = <Map<String, dynamic>>[].obs; // search results
  final isQuranSearching = false.obs;

  Future<void>? _loadingVerses;
  String? _searchLanguage;
  int _searchGeneration = 0;
  bool _indexRequested = false;
  String _query = '';
  Timer? _searchDebounce;

  // Build the index only after search is opened, in the current app language.
  Future<void> initLoader() {
    _indexRequested = true;
    return _ensureSearchIndex(_languageCode());
  }

  Future<void> _ensureSearchIndex(String language) {
    if (_searchLanguage == language) {
      if (verses.isNotEmpty) return Future.value();
      if (_loadingVerses != null) return _loadingVerses!;
    }
    final generation = ++_searchGeneration;
    _searchLanguage = language;
    verses.clear();
    results.clear();
    searchError.value = null;
    return _loadingVerses = _loadSearchIndex(language, generation);
  }

  Future<void> _loadSearchIndex(String language, int generation) async {
    isQuranSearching.value = true;
    try {
      await _loader.loadAllVerses(languageCode: language);
      if (isClosed || generation != _searchGeneration) return;
      verses.assignAll(_loader.allVerses);
      _runSearch();
    } catch (_) {
      if (!isClosed && generation == _searchGeneration) {
        searchError.value = 'quran_translation_unavailable';
      }
    } finally {
      if (!isClosed && generation == _searchGeneration) {
        _loadingVerses = null;
        isQuranSearching.value = false;
      }
    }
  }

  void search(String query) {
    _query = normalizeQuranSearch(query);
    _searchDebounce?.cancel();
    if (_query.isEmpty) {
      results.clear();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 180), _runSearch);
  }

  void _runSearch() {
    if (isClosed) return;
    results.assignAll(
      _query.isEmpty
          ? <Map<String, dynamic>>[]
          : verses.where(
              (verse) => (verse['_searchText'] as String).contains(_query),
            ),
    );
  }

  void clearSearch() {
    _query = '';
    _searchDebounce?.cancel();
    results.clear();
  }

  @override
  void onClose() {
    _translationGeneration++;
    _searchGeneration++;
    _searchDebounce?.cancel();
    super.onClose();
  }
}
