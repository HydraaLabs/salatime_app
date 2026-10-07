import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/controller/quran_settings_controller.dart';
import 'package:salatime/controller/zakat_calculator_controller.dart';
import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/data/model/response/mosque_settings_model.dart';
import 'package:salatime/data/repository/quran_setting_repo.dart';
import 'package:salatime/view/screens/haram_ingredients_food/haram_food_detaile_info.dart';
import 'package:salatime/view/screens/zakat/zakat_calculator.dart';
import 'package:salatime/view/screens/zakat/zakat_detaile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends QuranSettingsRepo {
  _Repository(SharedPreferences prefs)
    : super(
        sharedPreferences: prefs,
        apiClient: ApiClient(
          appBaseUrl: 'https://example.test',
          sharedPreferences: prefs,
        ),
      );

  int requests = 0;
  late Future<Response> Function() respond;

  @override
  Future<Response> getMosqueSettingsRepo() {
    requests++;
    return respond();
  }
}

class _Settings extends SettingsController {
  _Settings(_Repository repository) : super(quranSettingRepo: repository);

  // These tests exercise the real settings fetch, without unrelated Quran init.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Strings extends Translations {
  @override
  final keys = {
    'en': {
      'todays_nisab': 'Nisab',
      'click_for_result': 'Calculate',
      'enter_your_Current_Nisab': 'Enter a positive Nisab',
      'enter_amount': 'Enter an amount',
      'amount': 'Amount',
      'please_try_again': 'Unable to load settings',
      'no_data_found': 'No information available',
      'try_again': 'Retry',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repository;
  late _Settings settings;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(HomeLayoutController(sharedPreferences: prefs));
    repository = _Repository(prefs);
    settings = Get.put<SettingsController>(_Settings(repository)) as _Settings;
  });
  tearDown(Get.reset);

  Future<void> show(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('en'),
        translations: _Strings(),
        home: screen,
      ),
    );
    await tester.pump();
  }

  Response response(Map<String, dynamic>? data) =>
      Response(statusCode: 200, body: {'status': true, 'data': data});

  Finder nisabField() => find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        (widget.decoration?.labelText ?? '').startsWith('Nisab'),
  );

  Future<void> calculate(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Calculate'));
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();
  }

  test(
    'concurrent settings requests share a fetch and failures can retry',
    () async {
      final pending = Completer<Response>();
      repository.respond = () => pending.future;
      final first = settings.fetchMosqueSettingsData();
      final second = settings.fetchMosqueSettingsData();
      expect(identical(first, second), isTrue);
      expect(repository.requests, 1);
      expect(settings.isMosqueSettingsLoading.value, isTrue);
      pending.complete(const Response(statusCode: 503));
      await first;
      expect(settings.isMosqueSettingsLoading.value, isFalse);
      expect(settings.mosqueSettingsLoadFailed, isTrue);
      repository.respond = () async =>
          response({'haram_description': 'Loaded'});
      await settings.fetchMosqueSettingsData();
      expect(repository.requests, 2);
      expect(settings.mosqueSettingsLoadFailed, isFalse);
      expect(settings.mosqueSettingsApiData?.data?.haramDescription, 'Loaded');
    },
  );

  test('Nisab never defaults to zero and rejects invalid financial input', () {
    final calculator = ZakatCalculatorController();
    addTearDown(calculator.onClose);
    expect(calculator.totalNisab.text, isEmpty);
    calculator.equalResult = 10000;
    for (final input in ['', '0', '-1', 'NaN', 'Infinity', 'text']) {
      calculator.totalNisab.text = input;
      expect(calculator.validateTotalNisab(input), isNotNull);
      expect(calculator.getZakat(), isFalse);
      expect(calculator.totalZakat.text, isEmpty);
    }
    calculator.totalNisab.text = '1000,50';
    calculator.own_cash.text = '5000,50';
    calculator.owe_personal_loans.text = '1000,50';
    expect(calculator.getTotalOwn(), isTrue);
    expect(calculator.getTotalOwe(), isTrue);
    calculator.getEqual();
    expect(calculator.getZakat(), isTrue);
    expect(calculator.total_zakat, 100);
    expect(calculator.totalZakat.text, '100.0');
    calculator.own_cash.text = 'not a number';
    expect(ZakatCalculatorController.validateAmount('not a number'), isNotNull);
    expect(calculator.getTotalOwn(), isFalse);
  });

  test(
    'settings omit invalid Nisab, preserve manual entries and avoid null currency',
    () {
      final calculator = ZakatCalculatorController(
        settings: Data(zakatNisab: 0),
      );
      addTearDown(calculator.onClose);
      expect(calculator.hasConfiguredNisab, isFalse);
      expect(calculator.totalNisab.text, isEmpty);
      calculator.totalNisab.text = '1500';
      calculator.applySettings(Data(zakatNisab: 2000, currencySymbol: null));
      expect(calculator.totalNisab.text, '1500');
      expect(calculator.hasConfiguredNisab, isFalse);
      calculator.equalResult = 3000;
      expect(calculator.getZakat(), isTrue);
      expect(calculator.totalZakat.text, '75.0');
    },
  );

  test(
    'automatic settings and invalid configured thresholds require manual Nisab',
    () {
      for (final config in [
        Data(automaticPayerTime: true, zakatNisab: 1000, currencySymbol: '€'),
        Data(zakatNisab: 'NaN'),
        Data(zakatNisab: -100),
        Data(zakatNisab: ''),
      ]) {
        final calculator = ZakatCalculatorController(settings: config);
        expect(calculator.hasConfiguredNisab, isFalse);
        expect(calculator.totalNisab.text, isEmpty);
        calculator.onClose();
      }
    },
  );

  test(
    'a refreshed threshold invalidates a result computed with the old Nisab',
    () {
      final calculator = ZakatCalculatorController(
        settings: Data(zakatNisab: 1000),
      );
      addTearDown(calculator.onClose);
      calculator.equalResult = 2000;
      expect(calculator.getZakat(), isTrue);
      expect(calculator.totalZakat.text, '50.0');
      calculator.applySettings(Data(zakatNisab: 3000));
      expect(calculator.totalNisab.text, '3000.0');
      expect(calculator.totalZakat.text, isEmpty);
      expect(calculator.getZakat(), isTrue);
      expect(calculator.total_zakat, 0);
    },
  );

  testWidgets(
    'Zakat waits for delayed settings once, then uses configured Nisab',
    (tester) async {
      final pending = Completer<Response>();
      repository.respond = () => pending.future;
      await show(tester, const ZakatCalculator(appBackButton: false));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      settings.update();
      await tester.pump();
      expect(repository.requests, 1);
      pending.complete(
        response({
          'automatic_payer_time': false,
          'zakat_nisab': 1000,
          'currency_symbol': '€',
        }),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(nisabField());
      expect(field.readOnly, isTrue);
      expect(field.controller?.text, '1000.0');
      final cash = find
          .byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.hintText == 'Amount',
          )
          .first;
      await tester.enterText(cash, '10000');
      await calculate(tester);
      final result = tester.widget<TextField>(find.byType(TextField).last);
      expect(result.controller?.text, '€ 250.0');
      expect(repository.requests, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed settings allow manual Nisab and validate before calculating',
    (tester) async {
      repository.respond = () async => throw StateError('offline');
      await show(tester, const ZakatCalculator(appBackButton: false));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(nisabField());
      expect(field.readOnly, isFalse);
      expect(field.controller?.text, isEmpty);
      expect(find.text('Unable to load settings'), findsOneWidget);
      await calculate(tester);
      expect(find.text('Enter a positive Nisab'), findsOneWidget);
      final result = tester.widget<TextField>(find.byType(TextField).last);
      expect(result.controller?.text, isEmpty);
      await tester.ensureVisible(nisabField());
      await tester.enterText(nisabField(), '1000');
      final cash = find
          .byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.hintText == 'Amount',
          )
          .first;
      await tester.ensureVisible(cash);
      await tester.enterText(cash, '5000');
      await calculate(tester);
      expect(result.controller?.text, '125.0');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty settings leave a manual, empty Nisab', (tester) async {
    repository.respond = () async => response(null);
    await show(tester, const ZakatCalculator(appBackButton: false));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(nisabField());
    expect(field.readOnly, isFalse);
    expect(field.controller?.text, isEmpty);
    expect(find.text('No information available'), findsOneWidget);
    await calculate(tester);
    expect(find.text('Enter a positive Nisab'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final screen in ['haram', 'zakat']) {
    Widget descriptionScreen() => screen == 'haram'
        ? const HaramFoodDetaileInfoScreen(appBackButton: false)
        : const ZakatDetaile(appBackButton: false);
    testWidgets(
      '$screen description waits and survives a rebuild without another fetch',
      (tester) async {
        final pending = Completer<Response>();
        repository.respond = () => pending.future;
        await show(tester, descriptionScreen());
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pumpWidget(
          GetMaterialApp(
            locale: const Locale('en'),
            translations: _Strings(),
            home: descriptionScreen(),
          ),
        );
        await tester.pump();
        expect(repository.requests, 1);
        pending.complete(
          response({
            'haram_description': 'Haram explanation',
            'zakat_description': 'Zakat explanation',
          }),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            screen == 'haram' ? 'Haram explanation' : 'Zakat explanation',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$screen description handles failure, empty content and retry',
      (tester) async {
        repository.respond = () async => throw StateError('offline');
        await show(tester, descriptionScreen());
        await tester.pumpAndSettle();
        expect(find.text('Unable to load settings'), findsOneWidget);
        repository.respond = () async =>
            response({'haram_description': '', 'zakat_description': null});
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('No information available'), findsOneWidget);
        expect(find.text('null'), findsNothing);
        repository.respond = () async => response({
          'haram_description': 'Available now',
          'zakat_description': 'Available now',
        });
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('Available now'), findsOneWidget);
        expect(repository.requests, 3);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('retrying settings does not overwrite a manually entered Nisab', (
    tester,
  ) async {
    repository.respond = () async => response(null);
    await show(tester, const ZakatCalculator(appBackButton: false));
    await tester.pumpAndSettle();
    await tester.ensureVisible(nisabField());
    await tester.enterText(nisabField(), '1500');
    final pending = Completer<Response>();
    repository.respond = () => pending.future;
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(response({'zakat_nisab': 2000}));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(nisabField());
    expect(field.controller?.text, '1500');
    expect(field.readOnly, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving a loading calculator does not access disposed fields', (
    tester,
  ) async {
    final pending = Completer<Response>();
    repository.respond = () => pending.future;
    await show(tester, const ZakatCalculator(appBackButton: false));
    await tester.pumpWidget(const SizedBox());
    pending.complete(response({'zakat_nisab': 2000}));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'leaving while a description is loading does not update disposed state',
    (tester) async {
      final pending = Completer<Response>();
      repository.respond = () => pending.future;
      await show(
        tester,
        const HaramFoodDetaileInfoScreen(appBackButton: false),
      );
      await tester.pumpWidget(const SizedBox());
      pending.complete(response({'haram_description': 'Late result'}));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
