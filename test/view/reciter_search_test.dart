import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/testing.dart';
import 'package:salatime/controller/audio_player_controller.dart';
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/helper/route_helper.dart';
import 'package:salatime/view/screens/audio/reciters_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controller/reciter_catalog_test.dart' show catalog, reciter;

class _Strings extends Translations {
  @override
  final keys = {
    'fr': {
      'reciter_search_hint': 'Rechercher un récitateur',
      'reciter_search_empty': 'Aucun récitateur trouvé.',
      'catalog_search_clear': 'Effacer la recherche',
      'all_reciters_key': 'Récitateurs',
      'auth_retry': 'Réessayer',
      'reciter_load_error': 'Impossible de charger les récitateurs.',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AudioPlayerController audio;
  late int requests;
  late bool failing;
  late int extraReciters;
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(HomeLayoutController(sharedPreferences: prefs));
    requests = 0;
    failing = false;
    extraReciters = 0;
    audio = Get.put(
      AudioPlayerController(
        apiClient: ApiClient(
          appBaseUrl: 'https://example.com',
          sharedPreferences: prefs,
        ),
        audioHandler: BaseAudioHandler(),
        recitersHttpClient: MockClient((request) async {
          requests++;
          if (failing) throw StateError('offline');
          final arabic = request.url.queryParameters['language'] == 'ar';
          return catalog([
            reciter(1, arabic ? 'إبراهيم الأخضر' : 'Ibrahime Al Akhdar'),
            {
              ...reciter(2, arabic ? 'عبد الباسط' : 'Abdel Basit'),
              'moshaf': [
                {
                  'id': 20,
                  'name': 'Hafs',
                  'surah_list': '1,2',
                  'server': 'https://example.com/hafs/',
                },
                {
                  'id': 21,
                  'name': 'Warsh',
                  'surah_list': '1,2',
                  'server': 'https://example.com/warsh/',
                },
              ],
            },
            for (var id = 3; id < extraReciters + 3; id++)
              reciter(id, arabic ? 'قارئ $id' : 'Reciter $id'),
          ]);
        }),
      ),
    );
  });
  tearDown(Get.reset);

  Future<void> show(
    WidgetTester tester, {
    Locale locale = const Locale('fr'),
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        locale: locale,
        supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
        translations: _Strings(),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ReciterScreen(),
        getPages: [
          GetPage(
            name: RouteHelper.audioList,
            page: () => Scaffold(body: Text('selected ${Get.arguments}')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'searches either language locally, handles empty result and clear',
    (tester) async {
      await show(tester);
      expect(find.text('Ibrahime Al Akhdar'), findsOneWidget);
      expect(find.text('إبراهيم الأخضر'), findsOneWidget);
      expect(requests, 2);
      final field = find.byKey(const ValueKey('reciter_search'));
      await tester.enterText(field, 'إِبْرَاهِيم');
      await tester.pumpAndSettle();
      expect(find.text('Ibrahime Al Akhdar'), findsOneWidget);
      expect(find.text('Abdel Basit'), findsNothing);
      await tester.enterText(field, 'BASIT');
      await tester.pumpAndSettle();
      expect(find.text('Abdel Basit'), findsOneWidget);
      expect(find.text('Ibrahime Al Akhdar'), findsNothing);
      await tester.enterText(field, 'absent');
      await tester.pumpAndSettle();
      expect(find.text('Aucun récitateur trouvé.'), findsOneWidget);
      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pumpAndSettle();
      expect(find.text('Ibrahime Al Akhdar'), findsOneWidget);
      expect(find.text('Abdel Basit'), findsOneWidget);
      expect(requests, 2);
    },
  );

  testWidgets('filtered selection keeps stable reciter and chosen moshaf IDs', (
    tester,
  ) async {
    await show(tester);
    await tester.enterText(
      find.byKey(const ValueKey('reciter_search')),
      'باسط',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abdel Basit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Warsh'));
    await tester.pumpAndSettle();
    expect(audio.selectedMoshaf!.id, 21);
    expect(find.text('selected 2'), findsOneWidget);
    expect(requests, 2);
  });

  testWidgets('network error offers retry instead of a permanent shimmer', (
    tester,
  ) async {
    failing = true;
    await show(tester);
    expect(find.text('Impossible de charger les récitateurs.'), findsOneWidget);
    failing = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Ibrahime Al Akhdar'), findsOneWidget);
    expect(audio.isRecitersLoading.value, isFalse);
  });
  testWidgets(
    'visible screen reloads selected language and reuses Arabic catalogue',
    (tester) async {
      await show(tester);
      expect(find.text('Ibrahime Al Akhdar'), findsOneWidget);
      Get.updateLocale(const Locale('ar'));
      await tester.pumpAndSettle();
      expect(find.text('Ibrahime Al Akhdar'), findsNothing);
      expect(find.text('إبراهيم الأخضر'), findsOneWidget);
      expect(requests, 2);
      Get.updateLocale(const Locale('fr'));
      await tester.pumpAndSettle();
      expect(find.text('Ibrahime Al Akhdar'), findsOneWidget);
      expect(requests, 2);
    },
  );
  testWidgets(
    'search resets a scrolled list and closing keeps the shared player',
    (tester) async {
      extraReciters = 40;
      await show(tester);
      final list = find.byType(ListView).first;
      await tester.drag(list, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('Ibrahime Al Akhdar'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('reciter_search')),
        'Akhdar',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ibrahime Al Akhdar'), findsOneWidget);
      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pumpAndSettle();
      expect(find.text('Ibrahime Al Akhdar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(Get.isRegistered<AudioPlayerController>(), isTrue);
      expect(audio.isClosed, isFalse);
    },
  );

  for (final locale in ['fr', 'ar']) {
    testWidgets('reciter search fits $locale at 320px and 200 percent text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, locale: Locale(locale), textScale: 2);
      await tester.enterText(
        find.byKey(const ValueKey('reciter_search')),
        'ابراهيم',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reciter_1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
