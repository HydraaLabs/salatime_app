// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/data/model/response/juz_list_model.dart';
import 'package:zabi/data/model/response/offline_sura_model.dart';
import 'package:zabi/data/model/response/sura_detile_model.dart';
import 'package:zabi/helper/offline_quran_loader.dart';
import 'package:zabi/view/screens/offline_quran/offline_surah_detail_screen.dart';

class OfflineQuranController extends GetxController {
  OfflineQuranController({QuranLoader? loader})
    : _loader = loader ?? QuranLoader.instance;

  final QuranLoader _loader;
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

  Future<void> loadSurahDetails({
    required int surahNumber,
    String? translatorId,
  }) async {
    try {
      // suraDetailsApiData = null;
      isSurahDetailsLoading.value = true;

      final prefs = await SharedPreferences.getInstance();
      var selectedTranslatorId =
          translatorId ?? prefs.getString('selectedTranslatorId') ?? '1';
      print(
        'Loading offline surah details for Surah $surahNumber with translator ID $selectedTranslatorId',
      );

      //folder path
      String folderPath = selectedTranslatorId == '2'
          ? 'assets/quran/bn/s00'
          : selectedTranslatorId == '3'
          ? 'assets/quran/sp/s00'
          : selectedTranslatorId == '4'
          ? 'assets/quran/ar/s00'
          : 'assets/quran/en/s00';
      update();

      // Load local JSON file
      final String response = await rootBundle.loadString(
        '$folderPath$surahNumber.json',
      );
      final data = json.decode(response);
      if (data is List) {
        suraDetailsApiData = SuraDetaileModel.fromJson(data.first);
      } else if (data is Map<String, dynamic>) {
        suraDetailsApiData = SuraDetaileModel.fromJson(data);
      } else {
        throw Exception('Unexpected JSON format');
      }
    } catch (e) {
      print('Error loading surah details: $e');
    } finally {
      isSurahDetailsLoading.value = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        update(); // notify listeners after frame build
      });
    }
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
  String _query = '';
  Timer? _searchDebounce;

  // Load the search index only when search is opened, not when reading a surah.
  Future<void> initLoader() {
    if (verses.isNotEmpty) return Future.value();
    return _loadingVerses ??= _loadSearchIndex();
  }

  Future<void> _loadSearchIndex() async {
    isQuranSearching.value = true;
    try {
      await _loader.loadAllVerses();
      if (isClosed) return;
      verses.assignAll(_loader.allVerses);
      _runSearch();
    } catch (error) {
      debugPrint('Unable to load offline search: $error');
    } finally {
      _loadingVerses = null;
      if (!isClosed) isQuranSearching.value = false;
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
    _searchDebounce?.cancel();
    super.onClose();
  }
}
