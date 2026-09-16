import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/ai_assistant_controller.dart';
import 'package:salatime/controller/islamic_name_controller.dart';
import 'package:salatime/data/model/response/islamic_name_model.dart';
import 'package:salatime/data/repository/ai_assistant_repo.dart';
import 'package:salatime/data/repository/islamic_name_repo.dart';
import 'package:salatime/helper/ai_data_consent.dart';
import 'package:salatime/util/app_constants.dart';

class _Translations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    for (final locale in ['en', 'fr', 'ar'])
      locale: Map<String, String>.from(
        jsonDecode(File('assets/language/$locale.json').readAsStringSync())
            as Map,
      ),
  };
}

class _AiRepo extends AiAssistantRepo {
  final questions = <String>[];
  @override
  Future<String> askAI({
    required String question,
    required dynamic apiKey,
  }) async {
    questions.add(question);
    return 'Test reply';
  }
}

class _NamesRepo extends IslamicNameRepo {
  int calls = 0;
  @override
  Future<List<IslamicName>> generateNames({
    required String gender,
    required String origin,
    String? meaningTheme,
    String? startsWithLetter,
    int count = 15,
    required dynamic islamicNameApiKey,
  }) async {
    calls++;
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BuildContext context;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Get.reset);
  Future<void> mount(
    WidgetTester tester, {
    String locale = 'en',
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: _Translations(),
        locale: Locale(locale),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (value) {
              context = value;
              return const Text('AI');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AiAssistantController chat(_AiRepo repo, AiDataConsent consent) {
    final controller = AiAssistantController(
      assistantRepo: repo,
      consent: consent,
    );
    addTearDown(controller.questionCtrl.dispose);
    addTearDown(controller.scrollCtrl.dispose);
    return controller;
  }

  testWidgets('cancelled consent sends no question and preserves the draft', (
    tester,
  ) async {
    await mount(tester);
    final repo = _AiRepo();
    final controller = chat(repo, AiDataConsent())
      ..questionCtrl.text = 'My private draft';
    final request = controller.askQuestion(context);
    await tester.pumpAndSettle();
    expect(find.textContaining('1min.ai'), findsWidgets);
    expect(repo.questions, isEmpty);
    expect(controller.messages, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await request;
    expect(repo.questions, isEmpty);
    expect(controller.questionCtrl.text, 'My private draft');
    expect(controller.isLoading.value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AiDataConsent.storageKey), isNull);
    expect(prefs.getString('ai_islamic_chat'), isNull);
  });

  testWidgets(
    'approval persists the version and repeat sends do not re-prompt',
    (tester) async {
      await mount(tester);
      final repo = _AiRepo();
      final controller = chat(repo, AiDataConsent())
        ..questionCtrl.text = 'First question';
      final first = controller.askQuestion(context);
      final duplicate = controller.askQuestion(context);
      await tester.pumpAndSettle();
      expect(repo.questions, isEmpty);
      await tester.tap(find.text('Allow and continue'));
      await tester.pumpAndSettle();
      await first;
      await duplicate;
      expect(repo.questions, ['First question']);
      expect(
        (await SharedPreferences.getInstance()).getInt(
          AiDataConsent.storageKey,
        ),
        AiDataConsent.version,
      );
      controller.questionCtrl.text = 'Second question';
      await controller.askQuestion(context);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.questions, ['First question', 'Second question']);
    },
  );

  testWidgets(
    'revoking permission makes the next attempt ask again without sending',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        AiDataConsent.storageKey: AiDataConsent.version,
      });
      await mount(tester);
      final consent = AiDataConsent();
      final manage = consent.manage(context);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop sharing'));
      await tester.pumpAndSettle();
      await manage;
      expect(
        (await SharedPreferences.getInstance()).getInt(
          AiDataConsent.storageKey,
        ),
        isNull,
      );
      final repo = _AiRepo();
      final controller = chat(repo, consent)..questionCtrl.text = 'Do not send';
      final request = controller.askQuestion(context);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repo.questions, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await request;
      expect(repo.questions, isEmpty);
    },
  );

  testWidgets('old consent version requires a new explicit decision', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AiDataConsent.storageKey: AiDataConsent.version - 1,
    });
    await mount(tester);
    final request = AiDataConsent().request(context);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await request, isFalse);
  });

  testWidgets(
    'name generator sends no choices until permission and reuses approval',
    (tester) async {
      await mount(tester);
      final repo = _NamesRepo();
      final controller = Get.put(
        IslamicNameController(service: repo, consent: AiDataConsent()),
      );
      controller.themeCtrl.text = 'My theme';
      final cancelled = controller.generate(context);
      await tester.pumpAndSettle();
      expect(repo.calls, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await cancelled;
      expect(repo.calls, 0);
      expect(controller.themeCtrl.text, 'My theme');
      final approved = controller.generate(context);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow and continue'));
      await tester.pumpAndSettle();
      await approved;
      expect(repo.calls, 1);
      await controller.generate(context);
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  for (final locale in ['fr', 'ar']) {
    testWidgets('consent disclosure fits 320px $locale at 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, locale: locale, scale: 2);
      final request = AiDataConsent().request(context);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final cancel = find.text('ai_data_consent_cancel'.tr);
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(await request, isFalse);
    });
  }

  test('every supported app language has translated AI permission strings', () {
    final english =
        jsonDecode(File('assets/language/en.json').readAsStringSync()) as Map;
    final keys = english.keys.where(
      (key) => (key as String).startsWith('ai_data_consent_'),
    );
    for (final locale in AppConstants.languages) {
      final translations =
          jsonDecode(
                File(
                  'assets/language/${locale.languageCode}.json',
                ).readAsStringSync(),
              )
              as Map;
      for (final key in keys) {
        expect(
          translations[key],
          isA<String>(),
          reason: '${locale.languageCode}: $key',
        );
        expect((translations[key] as String).trim(), isNotEmpty);
      }
    }
  });
}
