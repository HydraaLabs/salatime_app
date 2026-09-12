import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/helper/mosque_directions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() => calls = []);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<bool> open() =>
      openMosqueDirections(latitude: 34.0331, longitude: -5.0003);

  test(
    'opens a route even when Android cannot query installed handlers',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'canLaunch') return false;
        if (call.method == 'launch') return true;
        throw PlatformException(code: 'UNEXPECTED_METHOD');
      });

      expect(await open(), isTrue);
      expect(calls.map((call) => call.method), ['launch']);
      final arguments = calls.single.arguments as Map;
      expect(arguments['useWebView'], isFalse);
      final uri = Uri.parse(arguments['url'] as String);
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '34.0331,-5.0003');
      expect(uri.queryParameters['dir_action'], 'navigate');
      // Let Maps use its current location and the user's transport preference.
      expect(uri.queryParameters.containsKey('origin'), isFalse);
      expect(uri.queryParameters.containsKey('travelmode'), isFalse);
    },
  );

  test(
    'opens the same route in a browser when the external launch fails',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return (call.arguments as Map)['useWebView'] == true;
      });

      expect(await open(), isTrue);
      expect(calls, hasLength(2));
      expect(calls[0].arguments['useWebView'], isFalse);
      expect(calls[1].arguments['useWebView'], isTrue);
      expect(calls[1].arguments['url'], calls[0].arguments['url']);
    },
  );

  test(
    'handles Android ACTIVITY_NOT_FOUND and still tries the browser',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (calls.length == 1) {
          throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
        }
        return true;
      });

      expect(await open(), isTrue);
      expect(calls, hasLength(2));
      expect(calls.last.arguments['useWebView'], isTrue);
    },
  );

  test('reports failure when neither launch succeeds', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return false;
    });
    expect(await open(), isFalse);
    expect(calls, hasLength(2));
  });

  test('does not leak platform exceptions to the tap handler', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
    });
    expect(await open(), isFalse);
    expect(calls, hasLength(2));
  });

  test('unsupported hosts fail gracefully', () async {
    expect(await open(), isFalse);
  });

  test('invalid coordinates never open an application', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    for (final point in [
      (double.nan, 0.0),
      (0.0, double.infinity),
      (91.0, 0.0),
      (0.0, -181.0),
    ]) {
      expect(
        await openMosqueDirections(latitude: point.$1, longitude: point.$2),
        isFalse,
      );
    }
    expect(calls, isEmpty);
  });
}
