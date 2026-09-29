import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salatime/controller/audio_player_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/mp3quran_model.dart';
import 'package:salatime/helper/catalog_search.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> reciter(int id, String name, {int moshaf = 1}) => {
  'id': id,
  'name': name,
  'moshaf': [
    {
      'id': moshaf,
      'name': 'Hafs',
      'server': 'https://example.com/$id/',
      'surah_list': '1,18,114',
    },
  ],
};
http.Response catalog(List<Map<String, dynamic>> reciters) => http.Response(
  jsonEncode({'reciters': reciters}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient api;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = ApiClient(
      appBaseUrl: 'https://example.com',
      sharedPreferences: await SharedPreferences.getInstance(),
    );
    Get.locale = const Locale('fr');
  });
  tearDown(Get.reset);

  AudioPlayerController controller(http.Client httpClient) =>
      AudioPlayerController(
        apiClient: api,
        audioHandler: BaseAudioHandler(),
        recitersHttpClient: httpClient,
      );

  test(
    'joins real Arabic aliases by ID without replacing names or moshafs',
    () async {
      final requests = <String>[];
      final audio = controller(
        MockClient((request) async {
          final lang = request.url.queryParameters['language']!;
          requests.add(lang);
          return catalog(
            lang == 'ar'
                ? [reciter(2, 'عبد الباسط'), reciter(1, 'إبراهيم الأخضر')]
                : [
                    reciter(1, 'Ibrahime Al Akhdar', moshaf: 23),
                    reciter(2, 'Abdel Basit'),
                  ],
          );
        }),
      );
      final chosen = Moshaf(id: 45, server: 'https://existing.example.com/');
      audio.selectedMoshaf = chosen;
      await audio.fetchReciterData();
      final first = audio.recitersListApiData!.data!.first;
      expect(first.id, 1);
      expect(first.name, 'Ibrahime Al Akhdar');
      expect(first.arabicName, 'إبراهيم الأخضر');
      expect(
        matchesCatalogSearch('ابراهيم', [first.name, first.arabicName]),
        isTrue,
      );
      expect(
        matchesCatalogSearch('akhdar', [first.name, first.arabicName]),
        isTrue,
      );
      expect(audio.moshafListFor(1).single.id, 23);
      expect(audio.selectedMoshaf, same(chosen));
      await audio.fetchReciterData();
      expect(requests, unorderedEquals(['fr', 'ar']));
    },
  );

  test(
    'Arabic locale makes one request and locale switch uses localized cache',
    () async {
      final requests = <String>[];
      final audio = controller(
        MockClient((request) async {
          final lang = request.url.queryParameters['language']!;
          requests.add(lang);
          return catalog([reciter(1, lang == 'ar' ? 'إبراهيم' : 'Ibrahim')]);
        }),
      );
      Get.locale = const Locale('ar');
      await audio.fetchReciterData();
      expect(requests, ['ar']);
      Get.locale = const Locale('en');
      await audio.fetchReciterData();
      expect(requests, ['ar', 'eng']);
      expect(audio.recitersListApiData!.data!.single.name, 'Ibrahim');
      expect(audio.recitersListApiData!.data!.single.arabicName, 'إبراهيم');
      Get.locale = const Locale('ar');
      await audio.fetchReciterData();
      expect(requests, ['ar', 'eng']);
      expect(audio.recitersListApiData!.data!.single.name, 'إبراهيم');
    },
  );

  test(
    'slow previous locale cannot overwrite the newest chosen language',
    () async {
      final french = Completer<http.Response>();
      final audio = controller(
        MockClient((request) async {
          final lang = request.url.queryParameters['language'];
          if (lang == 'fr') return french.future;
          return catalog([reciter(1, lang == 'ar' ? 'إبراهيم' : 'Ibrahim')]);
        }),
      );
      final old = audio.fetchReciterData();
      Get.locale = const Locale('en');
      await audio.fetchReciterData();
      french.complete(catalog([reciter(1, 'Ibrahime')]));
      await old;
      expect(audio.recitersListApiData!.data!.single.name, 'Ibrahim');
      expect(audio.isRecitersLoading.value, isFalse);
    },
  );

  test(
    'optional Arabic failure preserves localized list and retry enriches it',
    () async {
      var failArabic = true;
      final audio = controller(
        MockClient((request) async {
          if (request.url.queryParameters['language'] == 'ar') {
            return failArabic
                ? http.Response('', 503)
                : catalog([reciter(1, 'إبراهيم')]);
          }
          return catalog([reciter(1, 'Ibrahime')]);
        }),
      );
      await audio.fetchReciterData();
      expect(audio.hasReciterLoadError, isFalse);
      expect(audio.arabicReciterNamesUnavailable, isTrue);
      expect(audio.recitersListApiData!.data!.single.name, 'Ibrahime');
      failArabic = false;
      await audio.fetchReciterData(forceRefresh: true);
      expect(audio.arabicReciterNamesUnavailable, isFalse);
      expect(audio.recitersListApiData!.data!.single.arabicName, 'إبراهيم');
    },
  );

  test('failure ends loading and explicit retry can recover', () async {
    var fail = true;
    final audio = controller(
      MockClient(
        (request) async => fail
            ? http.Response('not available', 503)
            : catalog([reciter(1, 'Ibrahim')]),
      ),
    );
    await audio.fetchReciterData();
    expect(audio.hasReciterLoadError, isTrue);
    expect(audio.isRecitersLoading.value, isFalse);
    expect(audio.recitersListApiData, isNull);
    fail = false;
    await audio.fetchReciterData(forceRefresh: true);
    expect(audio.hasReciterLoadError, isFalse);
    expect(audio.recitersListApiData!.data, hasLength(1));
  });
  test(
    'audio chapter IDs and localized names come from local catalogue',
    () async {
      final requests = <String>[];
      final audio = controller(
        MockClient((request) async {
          requests.add(request.url.toString());
          return catalog([reciter(1, 'Ibrahim')]);
        }),
      );
      await audio.fetchReciterData();
      await audio.fetchAudio('1');
      expect(audio.audioData.map((row) => row['chapter_id']), [1, 18, 114]);
      expect(audio.audioData[1]['sura_name'], 'La caverne');
      expect(audio.audioData[1]['path'], 'https://example.com/1/018.mp3');
      expect(requests, hasLength(2));
    },
  );
}
