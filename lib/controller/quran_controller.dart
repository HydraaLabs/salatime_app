import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/data/model/response/juz_list_model.dart';
import 'package:zabi/data/model/response/sifat_name_details_model.dart';
import 'package:zabi/data/model/response/sifat_name_list_model.dart';
import 'package:zabi/data/model/response/sura_detile_model.dart';
import 'package:zabi/data/model/response/sura_list_model.dart';
import 'package:zabi/data/repository/sifatname_list_repo.dart';
import 'package:zabi/service/quran/quran_translation_repository.dart';

class QuranController extends GetxController implements GetxService {
  final QuranRepo quranRepo;
  QuranController({
    required this.quranRepo,
    QuranTranslationRepository? translations,
    String Function()? languageCode,
  }) : _translations = translations ?? QuranTranslationRepository.instance,
       _languageCode = languageCode ?? (() => Get.locale?.languageCode ?? 'en');
  final QuranTranslationRepository _translations;
  final String Function() _languageCode;
  final translationError = RxnString();
  int _translationGeneration = 0;
  String? _requestedLanguage;
  @override
  void onInit() {
    // fetchSifatNameListData();
    super.onInit();
  }

  // local variable
  RxBool isSifatNameListLoading = false.obs;
  SifatNameListModel? sifatNameApiData;

  // get dua list form here
  Future<void> fetchSifatNameListData() async {
    try {
      isSifatNameListLoading(true);

      final response = await quranRepo.getSifatNameRepo();

      if (response.statusCode == 200) {
        sifatNameApiData = SifatNameListModel.fromJson(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching data: $e");
      }
    } finally {
      isSifatNameListLoading(false);
      update();
    }
  }

  RxBool isSifatNameDetailsLoading = false.obs;
  SifatNameDetailsModel? sifatnameDetailsApidata;

  // get dua details function
  Future<void> fetchSifatNameDetailsData({String? sifatNameId}) async {
    try {
      isSifatNameDetailsLoading(true);

      final response = await quranRepo.getSifatNameDetailsRepo(
        sifatNameId.toString(),
      );

      if (response.statusCode == 200) {
        sifatnameDetailsApidata = SifatNameDetailsModel.fromJson(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching data: $e");
      }
    } finally {
      isSifatNameDetailsLoading(false);
      update();
    }
  }

  // local variable
  SuraListModel? suraListApiData;
  SuraDetaileModel? suraDetaileApiData;
  JuzListModel? juzListApiData;

  RxBool isJuzListLoading = false.obs;
  RxBool isSuraListLoading = false.obs;
  RxBool isSuraDetaileLoading = false.obs;
  int? suraNumber;

  // get sura list function
  Future<void> fetchSuraListData({String? translatorId}) async {
    try {
      isSuraListLoading(true);
      final prefs = await SharedPreferences.getInstance();
      var selectedTranslatorId =
          translatorId ?? prefs.getString('selectedTranslatorId') ?? 1;

      final response = await quranRepo.getSuraListRepo(
        selectedTranslatorId.toString(),
      );

      if (response.statusCode == 200) {
        suraListApiData = SuraListModel.fromJson(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching data: $e");
      }
    } finally {
      isSuraListLoading(false);
      update();
    }
  }

  // Legacy translatorId remains accepted for callers; app language owns the text.
  Future<void> fetchSuraDetaileData({String? suraId, String? translatorId}) =>
      _loadTranslation(
        int.tryParse(suraId ?? '') ?? suraNumber,
        _languageCode(),
      );

  Future<void> refreshTranslation({String? languageCode}) async {
    if (suraNumber != null) {
      await _loadTranslation(suraNumber, languageCode ?? _languageCode());
    }
  }

  Future<void> _loadTranslation(int? number, String language) async {
    final generation = ++_translationGeneration;
    _requestedLanguage = language;
    translationError.value = null;
    suraDetaileApiData = null;
    isSuraDetaileLoading(true);
    if (number != null && number >= 1 && number <= 114) suraNumber = number;
    update();
    try {
      if (number == null || number < 1 || number > 114) {
        throw ArgumentError('Invalid Quran chapter');
      }
      final result = await _translations.loadSurah(
        number,
        languageCode: language,
      );
      if (isClosed ||
          generation != _translationGeneration ||
          _requestedLanguage != language) {
        return;
      }
      suraDetaileApiData = result;
    } catch (_) {
      if (!isClosed && generation == _translationGeneration) {
        translationError.value = 'quran_translation_unavailable';
      }
    } finally {
      if (!isClosed && generation == _translationGeneration) {
        isSuraDetaileLoading(false);
        update();
      }
    }
  }

  @override
  void onClose() {
    _translationGeneration++;
    super.onClose();
  }

  // get juz list form here
  Future<void> fetchJuzListData({String? translatorId}) async {
    try {
      isJuzListLoading(true);
      final prefs = await SharedPreferences.getInstance();
      var selectedTranslatorId =
          translatorId ?? prefs.getString('selectedTranslatorId') ?? 1;

      final response = await quranRepo.getJuzListRepo(
        selectedTranslatorId.toString(),
      );

      if (response.statusCode == 200) {
        juzListApiData = JuzListModel.fromJson(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching data: $e");
      }
    } finally {
      isJuzListLoading(false);
      update();
    }
  }
}
