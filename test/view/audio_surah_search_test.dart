import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/audio_player_controller.dart';
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/helper/quran_chapter_catalog.dart';
import 'package:salatime/view/screens/audio/audio_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Audio extends AudioPlayerController {
  _Audio(ApiClient client)
    : super(apiClient: client, audioHandler: BaseAudioHandler());
  final originalQueue = const [
    MediaItem(id: 'one', title: 'Al-Fatihah', extras: {'chapterId': 1}),
    MediaItem(id: 'two', title: 'Al-Baqarah', extras: {'chapterId': 2}),
    MediaItem(id: 'eighteen', title: 'Al-Kahf', extras: {'chapterId': 18}),
  ];
  MediaItem? played;
  int loads = 0;
  @override
  Future<void> loadAudioList(String id) async {
    loads++;
    audioData = [
      for (final item in originalQueue) {'path': item.id},
    ];
    audioList.assignAll(originalQueue);
    isLoading.value = false;
  }

  @override
  Future<void> playMediaItem(MediaItem item) async => played = item;
}

class _Strings extends Translations {
  @override
  final keys = {
    'fr': {
      'surah_search_hint': 'Rechercher une sourate',
      'surah_search_empty': 'Aucune sourate trouvée.',
      'catalog_search_clear': 'Effacer la recherche',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Audio audio;
  setUpAll(QuranChapterCatalog.load);
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(HomeLayoutController(sharedPreferences: prefs));
    audio = _Audio(
      ApiClient(appBaseUrl: 'https://example.com', sharedPreferences: prefs),
    );
    Get.put<AudioPlayerController>(audio);
  });
  tearDown(Get.reset);

  testWidgets(
    'searches selected language, Arabic and number without altering playback queue',
    (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr'), Locale('en')],
          translations: _Strings(),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(),
          getPages: [GetPage(name: '/audio', page: () => AudioPlayerView())],
        ),
      );
      Get.toNamed('/audio', arguments: 1);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('audio_surah_search'));
      expect(find.text('La vache'), findsOneWidget);
      await tester.enterText(field, 'vache');
      await tester.pumpAndSettle();
      expect(find.text('La vache'), findsOneWidget);
      expect(find.text('La caverne'), findsNothing);
      await tester.enterText(field, 'الْبَقَرَة');
      await tester.pumpAndSettle();
      expect(find.text('La vache'), findsOneWidget);
      await tester.tap(find.text('La vache'));
      await tester.pump();
      expect(audio.played, same(audio.originalQueue[1]));
      expect(audio.audioList, audio.originalQueue);
      expect(audio.loads, 1);
      await tester.enterText(field, '١٨');
      await tester.pumpAndSettle();
      expect(find.text('La caverne'), findsOneWidget);
      await tester.enterText(field, 'absent');
      await tester.pumpAndSettle();
      expect(find.text('Aucune sourate trouvée.'), findsOneWidget);
      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pumpAndSettle();
      expect(find.text('La vache'), findsOneWidget);
      expect(find.text('La caverne'), findsOneWidget);
      expect(audio.audioList, audio.originalQueue);
      expect(audio.loads, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
