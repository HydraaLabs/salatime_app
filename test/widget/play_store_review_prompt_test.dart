import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:salatime/theme/modern_dark_theme.dart';
import 'package:salatime/theme/modern_light_theme.dart';
import 'package:salatime/view/base/play_store_review_prompt.dart';

class _Strings extends Translations {
  _Strings(this.keys);

  @override
  final Map<String, Map<String, String>> keys;
}

void main() {
  final strings = <String, Map<String, String>>{
    for (final language in [
      'fr',
      'en',
      'ar',
      'es',
      'tr',
      'id',
      'ms',
      'fa',
      'ur',
      'bn',
      'hi',
    ])
      language: Map<String, String>.from(
        jsonDecode(File('assets/language/$language.json').readAsStringSync()),
      ),
  };

  tearDown(Get.reset);

  Future<void> open(
    WidgetTester tester, {
    String language = 'fr',
    bool dark = false,
    bool accept = true,
    double scale = 1,
    ValueChanged<PlayStoreReviewChoice?>? onResult,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        locale: Locale(language),
        translations: _Strings(strings),
        supportedLocales: strings.keys.map(Locale.new).toList(),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: dark ? modernDark : modernLight,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open-review'),
              onPressed: () async {
                final choice = await showPlayStoreReviewPrompt(context);
                onResult?.call(choice);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-review')));
    await tester.pumpAndSettle();
    if (accept) {
      await tester.tap(find.byKey(const ValueKey('play-store-review-yes')));
      await tester.pumpAndSettle();
    }
  }

  test('the two-step prompt and store error exist in all app languages', () {
    for (final entry in strings.entries) {
      for (final suffix in [
        'title',
        'message',
        'rate',
        'later',
        'never',
        'question',
        'yes',
        'no',
      ]) {
        expect(
          entry.value['play_store_review_$suffix']?.trim(),
          isNotEmpty,
          reason: '${entry.key}: play_store_review_$suffix',
        );
      }
      expect(
        entry.value['review_store_unavailable']?.trim(),
        isNotEmpty,
        reason: '${entry.key}: review_store_unavailable',
      );
    }
    expect(strings['fr']!['play_store_review_title'], 'Votre avis compte');
    expect(
      strings['fr']!['play_store_review_message'],
      'Partagez votre expérience de SalaTime sur Google Play.',
    );
  });

  for (final choice in PlayStoreReviewChoice.values) {
    testWidgets('${choice.name} completes with its choice', (tester) async {
      final results = <PlayStoreReviewChoice?>[];
      await open(tester, onResult: results.add);
      expect(find.byType(PlayStoreReviewPrompt), findsOneWidget);
      expect(results, isEmpty);
      await tester.tap(
        find.byKey(ValueKey('play-store-review-${choice.name}')),
      );
      await tester.pumpAndSettle();
      expect(results, [choice]);
      expect(find.byType(PlayStoreReviewPrompt), findsNothing);
    });
  }

  testWidgets('rating is offered only after answering Yes', (tester) async {
    final results = <PlayStoreReviewChoice?>[];
    await open(tester, accept: false, onResult: results.add);
    expect(find.text('Aimez-vous SalaTime ?'), findsOneWidget);
    expect(find.byKey(const ValueKey('play-store-review-rate')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('play-store-review-yes')));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(
      find.byKey(const ValueKey('play-store-review-rate')),
      findsOneWidget,
    );
    expect(find.text('Aimez-vous SalaTime ?'), findsNothing);
  });

  for (final answer in ['no', 'later']) {
    testWidgets(
      '$answer closes the initial question without requesting a rating',
      (tester) async {
        final results = <PlayStoreReviewChoice?>[];
        await open(tester, accept: false, onResult: results.add);
        await tester.tap(find.byKey(ValueKey('play-store-review-$answer')));
        await tester.pumpAndSettle();
        expect(results, [
          answer == 'no'
              ? PlayStoreReviewChoice.never
              : PlayStoreReviewChoice.later,
        ]);
        expect(find.byType(PlayStoreReviewPrompt), findsNothing);
        expect(
          find.byKey(const ValueKey('play-store-review-rate')),
          findsNothing,
        );
      },
    );
  }

  testWidgets('dismissing the first question does not offer a rating', (
    tester,
  ) async {
    final results = <PlayStoreReviewChoice?>[];
    await open(tester, accept: false, onResult: results.add);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(results, [null]);
    expect(find.byType(PlayStoreReviewPrompt), findsNothing);
  });

  testWidgets('dismissing outside the dialog returns null', (tester) async {
    final results = <PlayStoreReviewChoice?>[];
    await open(tester, onResult: results.add);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(results, [null]);
    expect(find.byType(PlayStoreReviewPrompt), findsNothing);
  });

  testWidgets('system back returns null', (tester) async {
    final results = <PlayStoreReviewChoice?>[];
    await open(tester, onResult: results.add);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(results, [null]);
    expect(find.byType(PlayStoreReviewPrompt), findsNothing);
  });

  for (final language in ['fr', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        '$language ${dark ? 'dark' : 'light'} fits 320px with double text size',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await open(
            tester,
            language: language,
            dark: dark,
            scale: 2,
            accept: false,
          );
          expect(
            find.text(strings[language]!['play_store_review_question']!),
            findsOneWidget,
          );
          for (final answer in ['yes', 'no', 'later']) {
            expect(
              find.byKey(ValueKey('play-store-review-$answer')).hitTestable(),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('play-store-review-yes')));
          await tester.pumpAndSettle();

          final context = tester.element(find.byType(PlayStoreReviewPrompt));
          expect(
            Directionality.of(context),
            language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(
            Theme.of(context).brightness,
            dark ? Brightness.dark : Brightness.light,
          );
          final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
          expect(dialog.scrollable, isTrue);
          expect(
            find.text(strings[language]!['play_store_review_title']!),
            findsOneWidget,
          );
          expect(
            find.text(strings[language]!['play_store_review_message']!),
            findsOneWidget,
          );
          for (final choice in PlayStoreReviewChoice.values) {
            final button = find.byKey(
              ValueKey('play-store-review-${choice.name}'),
            );
            expect(button.hitTestable(), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
