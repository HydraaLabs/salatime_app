import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/service/reading/reading_progress_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const entry = ReadingProgressEntry(
    kind: ReadingProgressKind.quran,
    itemKey: '1:1',
    day: '2026-09-13',
    count: 1,
  );
  const operation = ReadingProgressOperation(
    id: '00000000-0000-4000-8000-000000000001',
    entry: entry,
  );
  test(
    'transport sends scoped bearer, explicit pagination, and absolute immutable operations',
    () async {
      final requests = <http.Request>[];
      final remote = HttpReadingProgressRemote(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'data': request.method == 'GET'
                  ? {'entries': [], 'cursor': 7, 'hasMore': false}
                  : {
                      'acknowledged': [operation.id],
                      'entries': [],
                    },
            }),
            200,
          );
        }),
      );
      await remote.pull('private-token', 7);
      await remote.push('private-token', [operation]);
      expect(requests.first.url.path, '/api/mobile/reading-progress');
      expect(requests.first.url.queryParameters, {
        'after': '7',
        'limit': '500',
      });
      expect(requests.first.headers['Authorization'], 'Bearer private-token');
      expect(requests.every((r) => !r.followRedirects), isTrue);
      final body = jsonDecode(requests.last.body) as Map;
      expect((body['operations'] as List).single, operation.toJson());
      expect(requests.last.url.path, '/api/mobile/reading-progress/batch');
    },
  );
  test(
    'redirect is rejected without exposing response body or bearer in error',
    () async {
      final remote = HttpReadingProgressRemote(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => http.Response(
            'private-body',
            302,
            headers: {'Location': 'https://outside.test'},
          ),
        ),
      );
      try {
        await remote.pull('private-token', 0);
        fail('Expected redirect rejection');
      } on ReadingProgressRemoteException catch (error) {
        expect(error.statusCode, 302);
        expect(error.toString(), isNot(contains('private')));
      }
    },
  );
  test(
    'malformed cursor and missing acknowledgements reject the response',
    () async {
      final remote = HttpReadingProgressRemote(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => http.Response(
            '{"data":{"entries":[],"cursor":1.5,"hasMore":false}}',
            200,
          ),
        ),
      );
      await expectLater(remote.pull('token', 0), throwsFormatException);
      await expectLater(
        remote.push('token', [operation]),
        throwsFormatException,
      );
    },
  );
  test(
    'actual SharedPreferences cache writes one document and survives a new store',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesReadingProgressStore();
      final document = <String, dynamic>{
        'schema': 1,
        'cursor': 0,
        'entries': [entry.toJson()],
        'outbox': [operation.toJson()],
      };
      await store.write('reading-test', document);
      expect(
        await SharedPreferencesReadingProgressStore().read('reading-test'),
        document,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'reading-test'});
    },
  );
}
