import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zabi/service/reading/reading_progress_service.dart';
import 'package:zabi/view/screens/quran/widget/quran_navigation_button.dart';
import 'package:zabi/view/screens/quran/widget/quran_reading_check.dart';

class _Progress extends ChangeNotifier implements ReadingProgressService {
  final checked = <String, int>{};
  final calls = <Map<String, int>>[];
  @override
  bool initialized = true;
  @override
  int todayCount(ReadingProgressKind kind, String key) => checked[key] ?? 0;
  @override
  Future<void> setMany(
    ReadingProgressKind kind,
    Map<String, int> counts, {
    String? day,
  }) async {
    calls.add(Map.of(counts));
    checked.addAll(counts);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Strings extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'fr': {
      'reading_quran_check_progress':
          '@read / @total versets cochés aujourd’hui',
    },
  };
}

void main() {
  tearDown(() => Get.reset());

  Future<void> render(
    WidgetTester tester,
    Widget child, {
    double width = 320,
    double scale = 1,
    bool dark = false,
  }) async {
    tester.view.physicalSize = Size(width, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('fr'),
        translations: _Strings(),
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 720),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'only an explicit check records a reading; checking a page is one batch',
    (tester) async {
      final service = _Progress();
      await render(
        tester,
        QuranReadingCheck(
          verseKeys: const ['1:1', '1:2', '1:2'],
          label: 'Versets de cette page lus',
          service: service,
        ),
      );
      expect(service.calls, isEmpty);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(service.calls.single, {'1:1': 1, '1:2': 1});
      expect(find.text('2 / 2 versets cochés aujourd’hui'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(service.calls.last, {'1:1': 0, '1:2': 0});
    },
  );

  testWidgets(
    'partial pages finish on check and react to restored cloud state',
    (tester) async {
      final service = _Progress()..checked['1:1'] = 1;
      await render(
        tester,
        QuranReadingCheck(
          verseKeys: const ['1:1', '1:2'],
          label: 'Versets de cette page lus',
          service: service,
        ),
      );
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isNull);
      service.checked['1:2'] = 1;
      service.notifyListeners();
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(service.calls, isEmpty);
    },
  );

  testWidgets(
    'reading checks stay disabled before the local account copy is ready',
    (tester) async {
      final service = _Progress()..initialized = false;
      await render(
        tester,
        QuranReadingCheck(
          verseKeys: const ['1:1'],
          label: 'Verset lu',
          service: service,
        ),
      );
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'long French page and navigation labels fit 320px at text 2x dark=$dark',
      (tester) async {
        var next = 0;
        var previous = 0;
        await render(
          tester,
          Column(
            children: [
              QuranReadingCheck(
                verseKeys: const ['1:1', '1:2'],
                label: 'Versets de cette page lus',
                service: _Progress(),
              ),
              Row(
                children: [
                  QuranNavigationButton(
                    label: 'Sourate précédente',
                    icon: Icons.chevron_left,
                    isEnabled: false,
                    onPressed: () => previous++,
                  ),
                  const SizedBox(width: 16),
                  QuranNavigationButton(
                    label: 'Sourate suivante',
                    icon: Icons.chevron_right,
                    isLeftIcon: false,
                    isEnabled: true,
                    onPressed: () => next++,
                  ),
                ],
              ),
            ],
          ),
          scale: 2,
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Sourate précédente'));
        await tester.tap(find.text('Sourate suivante'));
        expect(previous, 0);
        expect(next, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
