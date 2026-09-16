import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatime/service/mobile_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(
    'com.aboutyou.dart_packages.sign_in_with_apple',
  );
  final challenge = {
    'challenge_id': 'd682b988-cdb3-4a3a-9b96-2856127c9ba3',
    'nonce': 'a' * 64,
    'state': 'single-use-server-state',
  };
  late Map<String, Object?> credential;
  late List<MethodCall> calls;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls = [];
    credential = {
      'type': 'appleid',
      'identityToken': 'test-identity-token',
      'authorizationCode': 'test-authorization-code',
      'state': challenge['state'],
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'isAvailable' ? true : credential;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'native Apple hashes nonce and accepts returning user without a name',
    () async {
      final proof = await NativeMobileIdentityProvider().apple(
        const MobileAuthConfiguration(apple: true),
        challenge,
      );
      final request = (calls.last.arguments as List).single as Map;
      expect(
        request['nonce'],
        sha256.convert(utf8.encode(challenge['nonce']!)).toString(),
      );
      expect(request['state'], challenge['state']);
      expect(proof['nonce'], challenge['nonce']);
      expect(proof['challenge_id'], challenge['challenge_id']);
      expect(proof['authorization_code'], 'test-authorization-code');
      expect(proof.containsKey('name'), isFalse);
    },
  );

  test('first Apple authorization sends the normalized name', () async {
    credential.addAll({'givenName': ' Amina ', 'familyName': ' Test '});
    final proof = await NativeMobileIdentityProvider().apple(
      const MobileAuthConfiguration(apple: true),
      challenge,
    );
    expect(proof['name'], 'Amina Test');
  });

  for (final invalid in [
    {'state': null},
    {'state': 'another-state'},
    {'identityToken': ''},
    {'authorizationCode': ''},
  ]) {
    test(
      'native Apple rejects incomplete or mismatched ${invalid.keys.single}',
      () async {
        credential.addAll(invalid);
        await expectLater(
          NativeMobileIdentityProvider().apple(
            const MobileAuthConfiguration(apple: true),
            challenge,
          ),
          throwsA(isA<MobileAuthException>()),
        );
      },
    );
  }

  test('iOS requires its native audience to be enabled by the backend', () {
    for (final enabled in [null, false, true]) {
      final config = MobileAuthConfiguration.fromJson({
        'enabled': true,
        'apple': {'enabled': true, 'ios_enabled': enabled},
      });
      expect(
        config.apple,
        enabled == true &&
            const bool.fromEnvironment('SALATIME_APPLE_IOS_ENABLED'),
      );
    }
  });

  test('Android remains hidden when only native Apple login is configured', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final config = MobileAuthConfiguration.fromJson({
      'enabled': true,
      'apple': {
        'enabled': true,
        'ios_enabled': true,
        'android_enabled': false,
        'client_id': 'service.id',
        'redirect_uri': 'https://accounts.example.test/callback',
      },
    });
    expect(config.apple, isFalse);
  });
}
