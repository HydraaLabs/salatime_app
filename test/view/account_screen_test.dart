import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zabi/service/mobile_auth_service.dart';
import 'package:zabi/theme/modern_dark_theme.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/view/screens/account/account_screen.dart';

class _Store implements AuthSessionStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _Translations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    for (final locale in ['fr', 'ar'])
      locale: Map<String, String>.from(
        jsonDecode(File('assets/language/$locale.json').readAsStringSync())
            as Map,
      ),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/font/Roboto-Regular.ttf'))).load();
    await (FontLoader('NotoSansArabic')
          ..addFont(rootBundle.load('assets/font/NotoSansArabic-Regular.ttf')))
        .load();
  });
  tearDown(Get.reset);
  final calls = <String>[];
  MobileAuthService service({bool mail = true, bool enabled = true}) =>
      MobileAuthService(
        apiBaseUrl: 'https://test.example.test',
        storage: _Store(),
        client: MockClient((request) async {
          calls.add(request.url.path);
          final Map<String, Object> result;
          if (request.url.path.endsWith('/config')) {
            result = {
              'enabled': enabled,
              'email': {
                'enabled': enabled,
                'verification_enabled': mail,
                'password_reset_enabled': mail,
              },
              'google': {'enabled': false},
              'apple': {'enabled': false},
            };
          } else {
            result = {
              'user': {
                'id': 1,
                'name': 'Test',
                'email': 'test@example.test',
                'email_verified': request.url.path.endsWith('/me'),
                'has_password': true,
              },
              'token': '1|mock-session',
            };
          }
          return http.Response(jsonEncode({'data': result}), 200);
        }),
      );
  Widget app(MobileAuthService auth, String locale) => GetMaterialApp(
    locale: Locale(locale),
    translations: _Translations(),
    theme: (locale == 'ar' ? modernDark : modernLight).copyWith(
      textTheme: (locale == 'ar' ? modernDark : modernLight).textTheme.apply(
        fontFamilyFallback: ['NotoSansArabic'],
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(2)),
      child: Directionality(
        textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
    ),
    home: AccountScreen(service: auth),
  );

  for (final locale in ['fr', 'ar']) {
    testWidgets(
      'account registration and verification fit 320px $locale at 2x text',
      (tester) async {
        calls.clear();
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = service();
        await tester.pumpWidget(app(auth, locale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('auth_google'.tr), findsNothing);
        expect(find.text('auth_apple'.tr), findsNothing);
        final signup = find.widgetWithText(
          TextButton,
          'auth_create_account'.tr,
        );
        await tester.ensureVisible(signup);
        await tester.pumpAndSettle();
        await tester.tap(signup);
        await tester.pumpAndSettle();
        for (final input in [
          ('auth_name', 'Test'),
          ('auth_email', 'test@example.test'),
          ('auth_password', 'Alphabet2026!'),
          ('auth_confirm', 'Alphabet2026!'),
        ]) {
          final field = find.byKey(ValueKey(input.$1));
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, input.$2);
        }
        final submit = find.widgetWithText(FilledButton, 'auth_register'.tr);
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(auth.user.value?.id, '1');
        final code = find.byKey(const ValueKey('auth_code'));
        await tester.ensureVisible(code);
        await tester.pumpAndSettle();
        await tester.enterText(code, locale == 'ar' ? '١٢٣٤٥٦' : '123456');
        final verify = find.widgetWithText(
          FilledButton,
          'auth_verify_action'.tr,
        );
        await tester.ensureVisible(verify);
        await tester.pumpAndSettle();
        await tester.tap(verify);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(auth.user.value?.emailVerified, isTrue);
        expect(calls.where((p) => p.endsWith('/register')), hasLength(1));
      },
    );
  }
  testWidgets(
    'disabled email recovery is not offered and invalid email never leaves device',
    (tester) async {
      calls.clear();
      await tester.pumpWidget(app(service(mail: false), 'fr'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextButton, 'Mot de passe oublié ?'),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth_email')),
        'invalid',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth_password')),
        'Alphabet2026!',
      );
      final login = find.widgetWithText(FilledButton, 'Se connecter');
      await tester.ensureVisible(login);
      await tester.pumpAndSettle();
      await tester.tap(login);
      await tester.pumpAndSettle();
      expect(calls.where((p) => p.endsWith('/login')), isEmpty);
      expect(find.text('Saisissez une adresse email valide.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unavailable account service leaves clear guest continuation', (
    tester,
  ) async {
    await tester.pumpWidget(app(service(enabled: false), 'fr'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(
      find.text('Vous pouvez continuer à utiliser SalaTime sans compte.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
