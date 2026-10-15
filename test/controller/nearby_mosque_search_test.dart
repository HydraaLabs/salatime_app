import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/nearby_mosque_controller.dart';

class _Strings extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'fr': {
      'nearby_mosque_unnamed': 'Mosquée',
      'nearby_mosques_saved_results': 'Résultats enregistrés',
      'nearby_mosques_unavailable': 'Recherche indisponible',
    },
  };
}

void main() {
  late List<http.Request> requests;
  late List<String> notices;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests = [];
    notices = [];
  });
  tearDown(() {
    // Snackbars are queued globally by GetX across tests.
    SnackbarController.cancelAllSnackbars();
    Get.reset();
  });

  Future<NearbyMosqueController> search(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler, {
    int radiusKm = 2,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: _Strings(),
        locale: const Locale('fr'),
        home: const SizedBox(),
      ),
    );
    final controller = NearbyMosqueController(
      client: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
      notify: (message, {isError = false}) =>
          notices.add('${isError ? 'error' : 'info'}: $message'),
    );
    controller.kmToRadious = radiusKm;
    controller.userLocation.value = '33.995,-5.03';
    await tester.runAsync(controller.searchNearbyPlaces);
    await tester.pump();
    return controller;
  }

  final proxyBody = jsonEncode({
    'status': true,
    'source': 'cache',
    'mosques': [
      {
        'name': 'Masjid Nour',
        'address': null,
        'lat': 33.996,
        'lng': -5.0265,
        'distance': 330,
      },
      {
        'name': null,
        'address': 'Rue 1 Fès',
        'lat': 34.005,
        'lng': -5.03,
        'distance': 1110,
      },
    ],
  });
  final overpassBody = jsonEncode({
    'elements': [
      {
        'type': 'node',
        'lat': 33.996,
        'lon': -5.0265,
        'tags': {'name': 'Masjid Nour'},
      },
    ],
  });

  testWidgets('the SalaTime proxy is used first and its results are saved', (
    tester,
  ) async {
    final controller = await search(
      tester,
      (_) async => http.Response(proxyBody, 200),
    );
    expect(requests, hasLength(1));
    final url = requests.single.url;
    expect(url.path, '/api/mosques/nearby');
    expect(url.queryParameters, {
      'lat': '33.99500',
      'lng': '-5.03000',
      'radius': '2',
      'lang': 'fr',
    });
    expect(requests.single.headers['Accept'], 'application/json');
    expect(controller.places.map((p) => p['name']), ['Masjid Nour', 'Mosquée']);
    expect(controller.places.map((p) => p['vicinity']), ['--', 'Rue 1 Fès']);
    expect(controller.places.first['geometry'], {
      'location': {'lat': 33.996, 'lng': -5.0265},
    });
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('nearby_mosques_last_v1'), contains('Masjid Nour'));
    expect(controller.isLoading.value, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('OpenStreetMap is queried directly when the proxy fails', (
    tester,
  ) async {
    final controller = await search(tester, (request) async {
      if (request.url.host == 'salatime.net') return http.Response('', 503);
      return http.Response(overpassBody, 200);
    });
    expect(requests.map((r) => r.url.host), [
      'salatime.net',
      'overpass-api.de',
    ]);
    expect(controller.places.map((p) => p['name']), ['Masjid Nour']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('saved results are shown when every source fails', (
    tester,
  ) async {
    await search(tester, (_) async => http.Response(proxyBody, 200));
    requests.clear();
    final controller = await search(
      tester,
      (_) async => http.Response('busy', 502),
    );
    expect(requests, hasLength(4)); // proxy + three OpenStreetMap servers
    expect(controller.places.map((p) => p['name']), ['Masjid Nour', 'Mosquée']);
    expect(notices, ['info: Résultats enregistrés']);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a wider search than the saved one is not answered from it', (
    tester,
  ) async {
    await search(tester, (_) async => http.Response(proxyBody, 200));
    final controller = await search(
      tester,
      (_) async => http.Response('busy', 502),
      radiusKm: 5,
    );
    expect(controller.places, isEmpty);
    expect(notices, ['error: Recherche indisponible']);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
