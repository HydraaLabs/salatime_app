import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/service/mobile_auth_service.dart';

class MemoryAuthStore implements AuthSessionStore {
  final values = <String, String>{};
  bool failWrite = false;
  bool failRead = false;
  int reads = 0;
  Completer<void>? readGate;
  final readStarted = Completer<void>();
  Completer<void>? writeGate;
  final writeStarted = Completer<void>();
  @override
  Future<String?> read(String key) async {
    reads++;
    final value = values[key];
    if (!readStarted.isCompleted) readStarted.complete();
    if (readGate != null) await readGate!.future;
    if (failRead) throw StateError('Storage temporarily unavailable');
    return value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    if (writeGate != null) await writeGate!.future;
    if (failWrite) throw StateError('Storage unavailable');
    values[key] = value;
  }
}

class FakeIdentityProvider implements MobileIdentityProvider {
  int calls = 0;
  Completer<void>? gate;
  final started = Completer<void>();
  @override
  Future<Map<String, String>> google(MobileAuthConfiguration config) async {
    calls++;
    if (!started.isCompleted) started.complete();
    if (gate != null) await gate!.future;
    return {'id_token': 'mock-provider-token'};
  }

  @override
  Future<Map<String, String>> apple(
    MobileAuthConfiguration config,
    Map<String, dynamic> challenge,
  ) async {
    calls++;
    if (!started.isCompleted) started.complete();
    if (gate != null) await gate!.future;
    return {'identity_token': 'mock-apple-token'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final profile = {
    'id': 7,
    'name': 'Test',
    'email': 'test@example.test',
    'email_verified': false,
    'has_password': true,
  };
  Map<String, Object> session() => {
    'user': profile,
    'token': '7|test-session-token',
  };
  http.Response data(Object body, [int status = 200]) => http.Response(
    jsonEncode({'data': body}),
    status,
    headers: {'content-type': 'application/json'},
  );
  late MemoryAuthStore store;
  late List<http.Request> requests;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    store = MemoryAuthStore();
    requests = [];
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  MobileAuthService service(
    FutureOr<http.Response> Function(http.Request) respond, {
    MobileIdentityProvider? identity,
  }) => MobileAuthService(
    storage: store,
    identityProvider: identity,
    apiBaseUrl: 'https://accounts.example.test',
    client: MockClient((request) async {
      requests.add(request);
      return respond(request);
    }),
  );

  test(
    'local validation matches password letters/numbers and bcrypt byte limit without sending requests',
    () async {
      final auth = service((_) => data(session()));
      expect(MobileAuthService.validPassword('abcdefghijkl'), isFalse);
      expect(MobileAuthService.validPassword('123456789012'), isFalse);
      expect(MobileAuthService.validPassword('Alphabet2026!'), isTrue);
      expect(MobileAuthService.validPassword('ا' * 36 + '12'), isFalse);
      await expectLater(
        auth.register(name: 'Test', email: 'wrong', password: 'Alphabet2026!'),
        throwsA(isA<MobileAuthException>()),
      );
      await expectLater(
        auth.register(
          name: 'Test',
          email: 'test@example.test',
          password: 'abcdefghijkl',
        ),
        throwsA(isA<MobileAuthException>()),
      );
      await expectLater(
        auth.register(
          name: 'a' * 101,
          email: 'test@example.test',
          password: 'Alphabet2026!',
        ),
        throwsA(isA<MobileAuthException>()),
      );
      expect(requests, isEmpty);
    },
  );
  test(
    'register stores token only in secure session, sends confirmation and publishes profile after save',
    () async {
      final auth = service((_) => data(session(), 201));
      await auth.register(
        name: ' Test ',
        email: ' test@example.test ',
        password: 'Alphabet2026!',
      );
      final body = jsonDecode(requests.single.body);
      expect(body['password_confirmation'], body['password']);
      expect(body['email'], 'test@example.test');
      expect(auth.user.value!.id, '7');
      expect(await auth.accessToken(), '7|test-session-token');
      expect(
        jsonDecode(store.values[auth.storageKey]!)['token'],
        '7|test-session-token',
      );
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );
  for (final replacementId in [7, 8]) {
    test(
      'an obsolete guarded clear preserves replacement session $replacementId and secure storage',
      () async {
        var current = session();
        final auth = service((_) => data(current));
        await auth.login(email: 'test@example.test', password: 'Alphabet2026!');
        final oldToken = await auth.accessToken();
        current = {
          'user': {...profile, 'id': replacementId},
          'token': '$replacementId|replacement-session',
        };
        await auth.login(email: 'test@example.test', password: 'Alphabet2026!');
        final saved = store.values[auth.storageKey];

        await auth.clearSession(expectedToken: oldToken);

        expect(auth.user.value!.id, replacementId.toString());
        expect(await auth.accessToken(), '$replacementId|replacement-session');
        expect(store.values[auth.storageKey], saved);
        expect(
          requests.length,
          2,
          reason: 'No network request from a local guard',
        );
      },
    );
  }
  test(
    'a mismatched clear does not invalidate a pending login generation',
    () async {
      final started = Completer<void>();
      final reply = Completer<http.Response>();
      final auth = service((_) {
        started.complete();
        return reply.future;
      });
      final login = auth.login(
        email: 'test@example.test',
        password: 'Alphabet2026!',
      );
      await started.future;

      await auth.clearSession(expectedToken: 'obsolete-session');
      reply.complete(data(session()));
      await login;

      expect(auth.user.value!.id, '7');
      expect(await auth.accessToken(), '7|test-session-token');
      expect(store.values.containsKey(auth.storageKey), isTrue);
    },
  );
  test(
    'a matching guarded clear invalidates synchronously and removes the stored session',
    () async {
      final auth = service((_) => data(session()));
      await auth.login(email: 'test@example.test', password: 'Alphabet2026!');
      final token = await auth.accessToken();

      final clearing = auth.clearSession(expectedToken: token);
      expect(auth.user.value, isNull);
      await clearing;

      expect(await auth.accessToken(), isNull);
      expect(store.values, isEmpty);
    },
  );
  test('secure keys bind sessions to the exact API origin', () {
    final a = service((_) => data({}));
    final b = MobileAuthService(
      storage: store,
      apiBaseUrl: 'https://other.example.test',
    );
    expect(a.storageKey, isNot(b.storageKey));
    expect(
      () => MobileAuthService(apiBaseUrl: 'http://outside.example.test'),
      throwsArgumentError,
    );
  });
  test(
    'restored profile survives offline fetch and is cleared on an expired session',
    () async {
      var offline = true;
      final auth = service((_) {
        if (offline) throw const SocketException('offline');
        return http.Response('{}', 401);
      });
      store.values[auth.storageKey] = jsonEncode(session());
      await auth.initialize();
      expect(auth.user.value!.email, 'test@example.test');
      expect(
        requests.single.headers['authorization'],
        'Bearer 7|test-session-token',
      );
      offline = false;
      await expectLater(
        auth.refreshUser(),
        throwsA(isA<MobileAuthException>()),
      );
      expect(auth.user.value, isNull);
      expect(await auth.accessToken(), isNull);
      expect(store.values, isEmpty);
    },
  );
  test(
    'retry after a transient secure read failure restores the saved session',
    () async {
      final auth = service((_) => data({'user': profile}));
      store.values[auth.storageKey] = jsonEncode(session());
      store.failRead = true;
      await auth.initialize();
      expect(auth.user.value, isNull);
      expect(auth.initializationError.value, 'auth_secure_storage_error');
      store.failRead = false;
      await auth.initialize();
      expect(store.reads, 2);
      expect(auth.user.value?.id, '7');
      expect(auth.initializationError.value, isNull);
      await auth.initialize();
      expect(
        store.reads,
        2,
        reason: 'Successful initialization remains cached',
      );
    },
  );

  test('concurrent initialization shares one secure read', () async {
    final auth = service((_) => data({'user': profile}));
    store.values[auth.storageKey] = jsonEncode(session());
    store.readGate = Completer<void>();
    final first = auth.initialize();
    final second = auth.initialize();
    expect(identical(first, second), true);
    expect(store.reads, 1);
    store.readGate!.complete();
    await Future.wait([first, second]);
    expect(auth.user.value?.id, '7');
  });

  test(
    'a delayed startup read cannot restore a session after logout',
    () async {
      final auth = service((_) => data({'user': profile}));
      store.values[auth.storageKey] = jsonEncode(session());
      store.readGate = Completer<void>();
      final initialize = auth.initialize();
      await store.readStarted.future;
      await auth.clearSession();
      store.readGate!.complete();
      await initialize;
      expect(auth.user.value, isNull);
      expect(await auth.accessToken(), isNull);
      expect(store.values, isEmpty);
      expect(
        requests,
        isEmpty,
        reason: 'Do not validate an obsolete restored token',
      );
    },
  );

  test('a late startup read failure cannot clear a newer login', () async {
    final auth = service(
      (_) => data({
        'user': {...profile, 'id': 8},
        'token': '8|replacement-session',
      }),
    );
    store.values[auth.storageKey] = jsonEncode(session());
    store.readGate = Completer<void>();
    final initialize = auth.initialize();
    await store.readStarted.future;
    await auth.login(email: 'test@example.test', password: 'Alphabet2026!');
    store.failRead = true;
    store.readGate!.complete();
    await initialize;
    expect(auth.user.value?.id, '8');
    expect(await auth.accessToken(), '8|replacement-session');
    expect(auth.initializationError.value, isNull);
    expect(jsonDecode(store.values[auth.storageKey]!)['user']['id'], '8');
  });

  test(
    'failed secure write never authenticates and revokes the unstored candidate token',
    () async {
      store.failWrite = true;
      final auth = service(
        (request) => data(
          request.url.path.endsWith('/logout')
              ? {'logged_out': true}
              : session(),
        ),
      );
      await expectLater(
        auth.login(email: 'test@example.test', password: 'Alphabet2026!'),
        throwsA(isA<MobileAuthException>()),
      );
      expect(auth.user.value, isNull);
      expect(store.values, isEmpty);
      expect(requests.last.url.path, endsWith('/logout'));
      expect(
        requests.last.headers['authorization'],
        'Bearer 7|test-session-token',
      );
    },
  );
  test('a late login response cannot restore a session after logout', () async {
    final reply = Completer<http.Response>();
    final auth = service(
      (request) => request.url.path.endsWith('/login')
          ? reply.future
          : data({'logged_out': true}),
    );
    final login = auth.login(
      email: 'test@example.test',
      password: 'Alphabet2026!',
    );
    final rejected = expectLater(login, throwsA(isA<MobileAuthException>()));
    await auth.clearSession();
    reply.complete(data(session()));
    await rejected;
    expect(auth.user.value, isNull);
    expect(store.values, isEmpty);
  });
  test(
    'logout waits for in-flight secure write and cannot leave a restorable token',
    () async {
      store.writeGate = Completer<void>();
      final auth = service((_) => data(session()));
      final login = auth.login(
        email: 'test@example.test',
        password: 'Alphabet2026!',
      );
      await store.writeStarted.future;
      final logout = auth.clearSession();
      store.writeGate!.complete();
      await Future.wait([login, logout]);
      expect(auth.user.value, isNull);
      expect(store.values, isEmpty);
    },
  );
  test(
    'verification and reset validate codes and use the correct authenticated boundary',
    () async {
      final auth = service(
        (request) => data(
          request.url.path.endsWith('/me')
              ? {
                  'user': {...profile, 'email_verified': true},
                }
              : session(),
        ),
      );
      await auth.login(email: 'test@example.test', password: 'Alphabet2026!');
      await expectLater(
        auth.verifyEmail('bad'),
        throwsA(isA<MobileAuthException>()),
      );
      await auth.verifyEmail('123456');
      expect(auth.user.value!.emailVerified, isTrue);
      final verify = requests.firstWhere(
        (r) => r.url.path.endsWith('/verify-email'),
      );
      expect(jsonDecode(verify.body), {'token': '123456'});
      expect(verify.headers['authorization'], isNotNull);
      await auth.resetPassword(
        email: 'test@example.test',
        code: '654321',
        password: 'FreshPassword2026',
      );
      expect(requests.last.headers.containsKey('authorization'), isFalse);
    },
  );
  test('unconfigured providers remain hidden and no SDK is called', () async {
    final identity = FakeIdentityProvider();
    final auth = service(
      (_) => data({
        'enabled': true,
        'email': {
          'enabled': true,
          'verification_enabled': false,
          'password_reset_enabled': false,
        },
        'google': {'enabled': true},
        'apple': {
          'enabled': true,
          'client_id': 'service',
          'redirect_uri': 'http://untrusted.example.test',
        },
      }),
      identity: identity,
    );
    await auth.loadConfiguration();
    expect(auth.configuration.value.google, isFalse);
    expect(auth.configuration.value.apple, isFalse);
    expect(auth.configuration.value.verification, isFalse);
    await expectLater(
      auth.signInWithGoogle(),
      throwsA(isA<MobileAuthException>()),
    );
    expect(identity.calls, 0);
  });
  test(
    'provider proof goes to backend before a session can be published',
    () async {
      final identity = FakeIdentityProvider();
      final auth = service(
        (request) => request.url.path.endsWith('/config')
            ? data({
                'enabled': true,
                'email': {'enabled': true},
                'google': {
                  'enabled': true,
                  'server_client_id': 'configured.apps.googleusercontent.com',
                },
              })
            : data(session()),
        identity: identity,
      );
      await auth.loadConfiguration();
      await auth.signInWithGoogle();
      expect(identity.calls, 1);
      expect(requests.last.url.path, endsWith('/google'));
      expect(jsonDecode(requests.last.body)['id_token'], 'mock-provider-token');
      expect(auth.user.value!.id, '7');
    },
  );
  for (final provider in ['google', 'apple']) {
    test('late $provider proof cannot link a different account', () async {
      final identity = FakeIdentityProvider()..gate = Completer<void>();
      var current = session();
      final auth = service((request) {
        if (request.url.path.endsWith('/config')) {
          return data({
            'enabled': true,
            'email': {'enabled': true},
            'google': {
              'enabled': true,
              'server_client_id': 'configured.apps.googleusercontent.com',
            },
            'apple': {
              'enabled': true,
              'client_id': 'service.id',
              'redirect_uri':
                  'https://accounts.example.test/api/mobile/auth/apple/callback',
            },
          });
        }
        if (request.url.path.endsWith('/challenge')) {
          return data({'nonce': 'test'});
        }
        return data(current);
      }, identity: identity);
      await auth.loadConfiguration();
      await auth.login(email: 'test@example.test', password: 'Alphabet2026!');
      final linking = provider == 'google'
          ? auth.signInWithGoogle(link: true)
          : auth.signInWithApple(link: true);
      final rejected = expectLater(
        linking,
        throwsA(
          isA<MobileAuthException>().having(
            (e) => e.messageKey,
            'message',
            'auth_cancelled',
          ),
        ),
      );
      await identity.started.future;
      await auth.clearSession();
      current = {
        'user': {...profile, 'id': 8},
        'token': '8|other-session',
      };
      await auth.login(email: 'other@example.test', password: 'Alphabet2026!');
      identity.gate!.complete();
      await rejected;
      expect(requests.where((r) => r.url.path.contains('/link/')), isEmpty);
      expect(auth.user.value!.id, '8');
      expect(await auth.accessToken(), '8|other-session');
    });
  }
  test('late verification cannot refresh a replacement account', () async {
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    var current = session();
    final auth = service((request) {
      if (request.url.path.endsWith('/verify-email')) {
        started.complete();
        return gate.future;
      }
      return data(current);
    });
    await auth.login(email: 'test@example.test', password: 'Alphabet2026!');
    final verifying = auth.verifyEmail('١٢٣٤٥٦');
    final rejected = expectLater(
      verifying,
      throwsA(isA<MobileAuthException>()),
    );
    await started.future;
    expect(jsonDecode(requests.last.body)['token'], '123456');
    await auth.clearSession();
    current = {
      'user': {...profile, 'id': 8},
      'token': '8|other-session',
    };
    await auth.login(email: 'other@example.test', password: 'Alphabet2026!');
    gate.complete(data({'verified': true}));
    await rejected;
    expect(requests.where((r) => r.url.path.endsWith('/me')), isEmpty);
    expect(auth.user.value!.id, '8');
  });
  test('error messages never expose server payloads or passwords', () async {
    final auth = service(
      (_) => http.Response(
        jsonEncode({'message': 'secret server payload Password123'}),
        422,
      ),
    );
    try {
      await auth.login(email: 'test@example.test', password: 'Alphabet2026!');
      fail('Expected rejection');
    } on MobileAuthException catch (error) {
      expect(error.messageKey, 'auth_invalid_credentials');
      expect(error.toString(), isNot(contains('secret')));
      expect(error.toString(), isNot(contains('Password123')));
    }
  });
}
