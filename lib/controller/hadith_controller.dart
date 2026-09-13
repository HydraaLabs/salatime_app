// ignore_for_file: avoid_print, strict_top_level_inference

import 'dart:convert';

import 'package:get/get.dart';
import 'package:salatime/helper/debug_http_client.dart';

import 'package:salatime/data/model/response/hadis_book_model.dart';
import 'package:salatime/data/model/response/hadith_chapter_model.dart';
import 'package:salatime/data/model/response/hadith_model.dart';
import 'package:salatime/view/base/custom_snackbar.dart';

/// Hadith data provider: fawazahmed0/hadith-api (static JSON on jsDelivr CDN,
/// no API key required). Replaces the defunct hadithapi.com integration.
class HadithController extends GetxController {
  // local variable
  RxBool isLoadingHadithChapter = false.obs;
  RxBool isLoadingHadith = false.obs;

  static const String _cdnBase =
      'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions';

  /// Fixed list of the 6 main books (UI displays exactly 6 items).
  /// [hasFrench]: false when the CDN has no `fra-*` edition for the book.
  static const List<Map<String, dynamic>> _bookList = [
    {
      'slug': 'bukhari',
      'name': 'Sahih al Bukhari',
      'writer': 'Imam Bukhari',
      'death': '256 AH',
      'count': '7589',
      'hasFrench': true,
    },
    {
      'slug': 'muslim',
      'name': 'Sahih Muslim',
      'writer': 'Imam Muslim',
      'death': '261 AH',
      'count': '7563',
      'hasFrench': true,
    },
    {
      'slug': 'tirmidhi',
      'name': 'Jami At Tirmidhi',
      'writer': 'Imam Tirmidhi',
      'death': '279 AH',
      'count': '3998',
      'hasFrench': false,
    },
    {
      'slug': 'abudawud',
      'name': 'Sunan Abu Dawud',
      'writer': 'Imam Abu Dawud',
      'death': '275 AH',
      'count': '5274',
      'hasFrench': true,
    },
    {
      'slug': 'nasai',
      'name': "Sunan an Nasai",
      'writer': "Imam an-Nasa'i",
      'death': '303 AH',
      'count': '5765',
      'hasFrench': true,
    },
    {
      'slug': 'ibnmajah',
      'name': 'Sunan Ibn Majah',
      'writer': 'Imam Ibn Majah',
      'death': '273 AH',
      'count': '4343',
      'hasFrench': true,
    },
  ];

  @override
  void onInit() {
    getHadishBookNameData();

    super.onInit();
  }

  HadisBookModel? hadisBookModel;
  HadithChapterModel? hadithChapterModel;
  HadithModel? hadithModel;

  // In-memory cache: slug -> {'translation': decodedJson, 'arabic': decodedJson}
  final Map<String, Map<String, dynamic>> _bookCache = {};

  Map<String, dynamic>? _bookInfo(String slug) {
    for (final book in _bookList) {
      if (book['slug'] == slug) return book;
    }
    return null;
  }

  // edition language prefix based on app locale (ara / fra / eng fallback)
  String _editionPrefix(Map<String, dynamic> bookInfo) {
    final lang = Get.locale?.languageCode ?? 'en';
    if (lang == 'ar') return 'ara';
    if (lang == 'fr' && bookInfo['hasFrench'] == true) return 'fra';
    return 'eng';
  }

  Future<Map<String, dynamic>> _fetchEdition(String editionName) async {
    final response = await appHttpClient.get(
      Uri.parse('$_cdnBase/$editionName.min.json'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load edition $editionName '
          '(status ${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // Downloads (once per session) the translation + arabic editions of a book.
  Future<Map<String, dynamic>> _loadBook(String slug) async {
    if (_bookCache.containsKey(slug)) return _bookCache[slug]!;
    final info = _bookInfo(slug);
    if (info == null) throw Exception('Unknown hadith book: $slug');
    final results = await Future.wait([
      _fetchEdition('${_editionPrefix(info)}-$slug'),
      _fetchEdition('ara-$slug'),
    ]);
    final cached = {'translation': results[0], 'arabic': results[1]};
    _bookCache[slug] = cached;
    return cached;
  }

  // get hadith book list api call here
  getHadishBookNameData() async {
    isLoadingHadithChapter(true);
    try {
      hadisBookModel = HadisBookModel(
        status: 200,
        message: 'success',
        books: [
          for (var i = 0; i < _bookList.length; i++)
            Books(
              id: i + 1,
              bookName: _bookList[i]['name'] as String,
              writerName: _bookList[i]['writer'] as String,
              writerDeath: _bookList[i]['death'] as String,
              bookSlug: _bookList[i]['slug'] as String,
              hadithsCount: _bookList[i]['count'] as String,
            ),
        ],
      );
      update();
    } catch (error) {
      print("Error fetching data: $error");
      showCustomSnackBar("please_try_again".tr, isError: true);
    } finally {
      isLoadingHadithChapter(false);
    }

    update();
  }

  // get hadith chaptar here
  getHadithBookChaptersData(arguments) async {
    isLoadingHadithChapter(true);
    try {
      final String slug = arguments.toString();
      final book = await _loadBook(slug);
      final sections =
          (book['translation']['metadata']?['sections'] as Map?) ?? {};
      final arabicSections =
          (book['arabic']['metadata']?['sections'] as Map?) ?? {};

      final chapters = <Chapters>[];
      sections.forEach((key, value) {
        final title = value?.toString() ?? '';
        if (key == '0' || title.isEmpty) return;
        chapters.add(
          Chapters(
            id: num.tryParse(key.toString()),
            chapterNumber: key.toString(),
            chapterEnglish: title,
            chapterArabic: arabicSections[key]?.toString() ?? title,
            bookSlug: slug,
          ),
        );
      });

      hadithChapterModel = HadithChapterModel(
        status: 200,
        message: 'success',
        chapters: chapters,
      );
      update();
    } catch (error) {
      print("Error fetching data: $error");
      hadithChapterModel = HadithChapterModel(
        status: 500,
        message: 'error',
        chapters: const [],
      );
      showCustomSnackBar("please_try_again".tr, isError: true);
    } finally {
      isLoadingHadithChapter(false);
    }
  }

  // get hadith data here
  getAllHadithData(bookName, chapter) async {
    isLoadingHadith(true);
    try {
      final String slug = bookName.toString();
      final String chapterNumber = chapter.toString();
      final book = await _loadBook(slug);
      final info = _bookInfo(slug)!;

      final translationHadiths =
          (book['translation']['hadiths'] as List?) ?? [];
      final arabicHadiths = (book['arabic']['hadiths'] as List?) ?? [];

      // hadithnumber -> arabic text
      final arabicTextByNumber = <String, String>{
        for (final h in arabicHadiths)
          if (h is Map)
            h['hadithnumber'].toString(): h['text']?.toString() ?? '',
      };

      final sectionTitle =
          (book['translation']['metadata']?['sections'] as Map?)?[chapterNumber]
              ?.toString() ??
          '';
      final sectionTitleArabic =
          (book['arabic']['metadata']?['sections'] as Map?)?[chapterNumber]
              ?.toString() ??
          sectionTitle;

      final data = <Data>[];
      for (final h in translationHadiths) {
        if (h is! Map) continue;
        final reference = h['reference'];
        if (reference is! Map) continue;
        if (reference['book']?.toString() != chapterNumber) continue;
        final number = h['hadithnumber']?.toString() ?? '';
        data.add(
          Data(
            id: num.tryParse(number),
            hadithNumber: number,
            englishNarrator: '',
            hadithEnglish: h['text']?.toString() ?? '',
            hadithArabic: arabicTextByNumber[number] ?? '',
            chapterId: chapterNumber,
            bookSlug: slug,
            book: Book(
              bookName: info['name'] as String,
              writerName: info['writer'] as String,
              writerDeath: info['death'] as String,
              bookSlug: slug,
            ),
            chapter: Chapter(
              chapterNumber: chapterNumber,
              chapterEnglish: sectionTitle,
              chapterArabic: sectionTitleArabic,
              bookSlug: slug,
            ),
          ),
        );
      }

      if (data.isEmpty) {
        showCustomSnackBar("no_hadith_found_in_this_chapter".tr, isError: true);
      }
      hadithModel = HadithModel(
        status: 200,
        message: 'success',
        hadiths: Hadiths(data: data, total: data.length),
      );
      update();
    } catch (error) {
      print("Error fetching data: $error");
      hadithModel = HadithModel(
        status: 500,
        message: 'error',
        hadiths: Hadiths(data: const [], total: 0),
      );
      showCustomSnackBar("please_try_again".tr, isError: true);
    } finally {
      isLoadingHadith(false);
    }
  }
}
