import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/controller/offline_quran_controller.dart';
import 'package:zabi/controller/quran_controller.dart';
import 'package:zabi/controller/quran_settings_controller.dart';
import 'package:zabi/data/api/api_client.dart';
import 'package:zabi/data/model/response/sura_detile_model.dart';
import 'package:zabi/data/repository/quran_setting_repo.dart';
import 'package:zabi/data/repository/sifatname_list_repo.dart';
import 'package:zabi/service/quran/quran_translation_repository.dart';
import 'package:zabi/service/reading/reading_progress_service.dart';
import 'package:zabi/theme/modern_dark_theme.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/view/screens/offline_quran/widgets/offline_ayah_translation_screen.dart';
import 'package:zabi/view/screens/quran/quran_settings_screen.dart';
import 'package:zabi/view/screens/quran/widget/ayah_translation_widget.dart';
import 'package:zabi/view/screens/quran/widget/quran_reading_check.dart';
import 'package:zabi/view/screens/quran/widget/quran_translation_source_card.dart';
import 'package:zabi/view/screens/quran/widget/quran_translation_text.dart';

class _Strings extends Translations {
  _Strings(this.keys);
  @override
  final Map<String, Map<String, String>> keys;
}

class _Settings extends SettingsController {
  _Settings(QuranSettingsRepo repo) : super(quranSettingRepo: repo);
  @override
  // Only local reader preferences are needed; never fetch an old translator API.
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final strings = <String, Map<String, String>>{};
  final fatiha = <String, SuraDetaileModel>{};
  late SharedPreferences prefs;
  late ApiClient api;

  setUpAll(() async {
    final repository = QuranTranslationRepository();
    for (final language in ['fr', 'en', 'ar', 'fa', 'ur']) {
      strings[language] = Map<String, String>.from(
        jsonDecode(
          await rootBundle.loadString('assets/language/$language.json'),
        ),
      );
      fatiha[language] = await repository.loadSurah(1, languageCode: language);
    }
    for (final (family, asset) in [
      ('Roboto', 'assets/font/Roboto-Regular.ttf'),
      ('NotoSansArabic', 'assets/font/NotoSansArabic-Regular.ttf'),
      ('Scheherazade New', 'assets/font/ScheherazadeNew-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    api = ApiClient(
      appBaseUrl: 'https://example.invalid',
      sharedPreferences: prefs,
    );
    Get.put<SettingsController>(
      _Settings(QuranSettingsRepo(sharedPreferences: prefs, apiClient: api)),
    );
  });
  tearDown(Get.reset);

  Widget app(
    Widget child, {
    String language = 'fr',
    bool dark = false,
    double scale = 1,
    GlobalKey? capture,
  }) => GetMaterialApp(
    locale: Locale(language),
    translations: _Strings(strings),
    supportedLocales: const [
      Locale('fr'),
      Locale('en'),
      Locale('ar'),
      Locale('fa'),
      Locale('ur'),
    ],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: (dark ? modernDark : modernLight).copyWith(
      textTheme: (dark ? modernDark : modernLight).textTheme.apply(
        fontFamilyFallback: ['NotoSansArabic'],
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: RepaintBoundary(key: capture, child: child!),
    ),
    home: Scaffold(body: child),
  );
  Widget scroll(Widget child) => SingleChildScrollView(
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
  Finder keyed(String key) => find.byKey(ValueKey(key));
  void narrow(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final directory = Platform.environment['SALATIME_QURAN_PREVIEW_DIR'];
    if (directory == null) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  test(
    'presentation tags preserve wording, punctuation, markers and complete notes',
    () {
      const raw =
          'Texte exact [1].<br>\n<b>Note entière</b> &amp; &#x627; &#233;';
      expect(
        quranTranslationPlainText(raw),
        'Texte exact [1].\n\nNote entière & ا é',
      );
      expect(raw, contains('<b>Note entière</b>'));
      expect(
        quranTranslationPlainText('« Texte intact »\n  seconde ligne '),
        '« Texte intact »\n  seconde ligne ',
      );
      expect(
        quranTranslationPlainText('&#xD800; &#1114112;'),
        '&#xD800; &#1114112;',
      );
    },
  );

  testWidgets(
    'sharing includes complete published translation, notes and attribution',
    (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      final model = fatiha['fr']!;
      final verse = model.data!.chapterInfo!.first.pageVerses!.first;
      final share = quranTranslationShareText(
        reference: '1:1',
        arabic: verse.arabicName!,
        translation: verse.translatedName!,
        footnotes: verse.translationFootnotes,
        source: model.translationSource,
        appName: 'SalaTime',
      );
      for (final expected in [
        verse.arabicName!,
        verse.translatedName!,
        verse.translationFootnotes!,
        model.translationSource!.title,
        model.translationSource!.publisher,
        model.translationSource!.version,
        model.translationSource!.sourceUrl,
        'QuranEnc',
        'SalaTime',
      ]) {
        expect(share, contains(expected));
      }
      expect(share, isNot(contains('Arabic Ayah:')));
      expect(share, isNot(contains('Powered By:')));
    },
  );

  for (final language in ['fr', 'en', 'ar', 'fa', 'ur']) {
    testWidgets(
      'published $language text uses its own direction and expandable intact notes',
      (tester) async {
        narrow(tester);
        final verse =
            fatiha[language]!.data!.chapterInfo!.first.pageVerses!.first;
        final notes = verse.translationFootnotes?.isNotEmpty == true
            ? verse.translationFootnotes!
            : 'ملاحظة كاملة [1].\nDeuxième ligne intacte.';
        await tester.pumpWidget(
          app(
            scroll(
              QuranTranslationText(
                text: verse.translatedName!,
                footnotes: notes,
                languageCode: language,
                fontSize: 18,
              ),
            ),
            language: language == 'fr' ? 'ar' : 'fr',
            scale: 2,
            dark: language == 'ar',
          ),
        );
        await tester.pumpAndSettle();
        final direction = ['ar', 'fa', 'ur'].contains(language)
            ? TextDirection.rtl
            : TextDirection.ltr;
        expect(
          tester
              .widget<SelectableText>(keyed('quran-translation-body'))
              .textDirection,
          direction,
        );
        expect(
          tester.widget<SelectableText>(keyed('quran-translation-body')).data,
          quranTranslationPlainText(verse.translatedName!),
        );
        expect(keyed('quran-translation-footnotes'), findsNothing);
        await tester.ensureVisible(keyed('quran-translation-notes'));
        await tester.tap(keyed('quran-translation-notes'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SelectableText>(keyed('quran-translation-footnotes'))
              .data,
          quranTranslationPlainText(notes),
        );
        expect(
          tester
              .widget<SelectableText>(keyed('quran-translation-footnotes'))
              .textDirection,
          direction,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'source metadata includes publisher, version, QuranEnc and opens only the HTTPS source',
    (tester) async {
      Uri? opened;
      final source = fatiha['fr']!.translationSource!;
      await tester.pumpWidget(
        app(
          scroll(
            QuranTranslationSourceCard(
              source: source,
              followsAppLanguage: true,
              openSource: (uri) async {
                opened = uri;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(source.title), findsOneWidget);
      expect(find.textContaining(source.publisher), findsOneWidget);
      expect(find.textContaining('QuranEnc'), findsOneWidget);
      expect(find.textContaining(source.version), findsOneWidget);
      expect(
        find.text(strings['fr']!['quran_translation_follows_language']!),
        findsOneWidget,
      );
      await tester.tap(keyed('quran-translation-open-source'));
      expect(opened.toString(), source.sourceUrl);
      expect(opened!.scheme, 'https');
    },
  );

  testWidgets(
    'source changes wait for the current locale and ignore stale completions',
    (tester) async {
      final requests = <String, Completer<QuranTranslationSource>>{};
      Future<QuranTranslationSource> load(String language) =>
          (requests[language] = Completer<QuranTranslationSource>()).future;
      Widget render(String language) => app(
        scroll(
          QuranTranslationSourceCard(languageCode: language, loadSource: load),
        ),
      );
      await tester.pumpWidget(render('fr'));
      requests['fr']!.complete(fatiha['fr']!.translationSource);
      await tester.pumpAndSettle();
      expect(find.text(fatiha['fr']!.translationSource!.title), findsOneWidget);
      await tester.pumpWidget(render('ar'));
      await tester.pump();
      expect(keyed('quran-translation-source-title'), findsNothing);
      await tester.pumpWidget(render('ur'));
      requests['ar']!.complete(fatiha['ar']!.translationSource);
      await tester.pump();
      expect(keyed('quran-translation-source-title'), findsNothing);
      requests['ur']!.complete(fatiha['ur']!.translationSource);
      await tester.pumpAndSettle();
      expect(find.text(fatiha['ur']!.translationSource!.title), findsOneWidget);
      await tester.pumpWidget(render('ur'));
      await tester.pumpAndSettle();
      expect(requests.length, 3);
    },
  );

  testWidgets(
    'missing source can retry and an unavailable source link reports its failure',
    (tester) async {
      var loads = 0;
      Future<QuranTranslationSource> load(String _) async {
        if (++loads == 1) throw StateError('Missing local source');
        return fatiha['fr']!.translationSource!;
      }

      await tester.pumpWidget(
        app(
          scroll(
            QuranTranslationSourceCard(
              loadSource: load,
              openSource: (_) async => false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(strings['fr']!['quran_translation_unavailable']!),
        findsOneWidget,
      );
      await tester.tap(keyed('quran-translation-source-retry'));
      await tester.pumpAndSettle();
      expect(loads, 2);
      await tester.tap(keyed('quran-translation-open-source'));
      await tester.pump();
      expect(
        find.text(strings['fr']!['quran_translation_link_error']!),
        findsOneWidget,
      );
    },
  );

  for (final language in ['fr', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        'settings retain font controls with automatic $language edition at 320px text 2x dark=$dark',
        (tester) async {
          narrow(tester);
          final key = GlobalKey();
          await tester.pumpWidget(
            app(
              QuranReaderSettingsSheet(
                sourceCard: QuranTranslationSourceCard(
                  source: fatiha[language]!.translationSource,
                  followsAppLanguage: true,
                ),
              ),
              language: language,
              scale: 2,
              dark: dark,
              capture: key,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(Slider), findsNWidgets(2));
          expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
          final slider = tester.widget<Slider>(find.byType(Slider).first);
          slider.onChanged!(30);
          await tester.pump();
          expect(Get.find<SettingsController>().arabicFontSize.value, 30);
          expect(prefs.getDouble('arabic_font_size_key'), 30);
          await tester.ensureVisible(keyed('quran-translation-source-card'));
          await tester.pumpAndSettle();
          expect(
            find.text(
              strings[language]!['quran_translation_follows_language']!,
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            key,
            'settings-$language-${dark ? 'dark' : 'light'}-320-2x',
          );
        },
      );
    }
  }

  for (final offline in [false, true]) {
    testWidgets(
      '${offline ? 'offline' : 'online'} reader renders actual Hamidullah Fatiha with intact notes and reading checks',
      (tester) async {
        narrow(tester);
        final model = fatiha['fr']!;
        if (offline) {
          Get.put(
            OfflineQuranController()
              ..suraDetailsApiData = model
              ..isSurahDetailsLoading.value = false,
          );
        } else {
          Get.put(
            QuranController(
              quranRepo: QuranRepo(sharedPreferences: prefs, apiClient: api),
            )..suraDetaileApiData = model,
          );
        }
        final imageKey = GlobalKey();
        await tester.pumpWidget(
          app(
            offline
                ? const OfflineAyanTranslationWidget()
                : const AyanTranslationWidget(),
            capture: imageKey,
          ),
        );
        await tester.pumpAndSettle();
        final verse = model.data!.chapterInfo!.first.pageVerses!.first;
        expect(find.byType(QuranReadingCheck), findsNWidgets(7));
        expect(find.text(verse.translatedName!), findsOneWidget);
        expect(find.textContaining('In the Name of Allah'), findsNothing);
        expect(
          tester
              .widget<SelectableText>(keyed('quran-translation-body').first)
              .data,
          verse.translatedName,
        );
        expect(
          ReadingProgressService.instance.todayCount(
            ReadingProgressKind.quran,
            '1:1',
          ),
          0,
        );
        expect(find.text(model.translationSource!.title), findsOneWidget);
        await tester.ensureVisible(keyed('quran-translation-body').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          imageKey,
          'fatiha-fr-${offline ? 'offline' : 'online'}-320',
        );
        await tester.ensureVisible(keyed('quran-translation-notes').first);
        await tester.tap(keyed('quran-translation-notes').first);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SelectableText>(
                keyed('quran-translation-footnotes').first,
              )
              .data,
          verse.translationFootnotes,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
