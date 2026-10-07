// ignore_for_file: non_constant_identifier_names, prefer_null_aware_operators, strict_top_level_inference

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/data/model/response/mosque_settings_model.dart';

class ZakatCalculatorController extends GetxController {
  ZakatCalculatorController({Data? settings}) {
    applySettings(settings);
  }

  final zakatCalculatorformkey = GlobalKey<FormState>();

  //------------- Global Variable forSection   ------------//
  double oweResult = 0;
  double ownResult = 0;
  double equalResult = 0;
  double total_zakat = 0;

  //------------- All result TextEditingController Section   ------------//
  final totalOwn = TextEditingController();
  final totalOwe = TextEditingController();
  final equal = TextEditingController();
  final totalNisab = TextEditingController();
  final totalZakat = TextEditingController();
  bool hasConfiguredNisab = false;
  String currencySymbol = '';
  String? _configuredNisab;

  // Missing settings always require a real, manually entered Nisab. Never use
  // zero as a substitute, or overwrite input entered while a retry completes.
  void applySettings(Data? settings) {
    final previousNisab = totalNisab.text;
    final previousCurrency = currencySymbol;
    final wasConfigured =
        hasConfiguredNisab && totalNisab.text == _configuredNisab;
    final automatic = settings?.automaticPayerTime == true;
    final configured = automatic
        ? null
        : parseAmount(settings?.zakatNisab?.toString() ?? '');
    currencySymbol = automatic ? '' : (settings?.currencySymbol?.trim() ?? '');
    hasConfiguredNisab = false;
    if (configured != null &&
        configured > 0 &&
        (totalNisab.text.trim().isEmpty || wasConfigured)) {
      _configuredNisab = configured.toString();
      totalNisab.text = _configuredNisab!;
      hasConfiguredNisab = true;
    } else if (wasConfigured) {
      totalNisab.clear();
      _configuredNisab = null;
    }
    if (previousNisab != totalNisab.text ||
        previousCurrency != currencySymbol) {
      total_zakat = 0;
      totalZakat.clear();
    }
  }

  static double? parseAmount(String value) {
    final amount = double.tryParse(value.trim().replaceAll(',', '.'));
    return amount != null && amount.isFinite && amount >= 0 ? amount : null;
  }

  static String? validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return parseAmount(value) == null ? 'enter_amount'.tr : null;
  }

  String? validateTotalNisab(String? value) {
    final amount = parseAmount(value ?? '');
    return amount == null || amount <= 0 ? 'enter_your_Current_Nisab'.tr : null;
  }

  //------------- Variable for Own section ------------//

  final own_bank_cash = TextEditingController();
  final own_cash = TextEditingController();
  final own_loan = TextEditingController();
  final own_money_expected = TextEditingController();
  final own_gold = TextEditingController();
  final own_silver = TextEditingController();
  final own_shares_bought_exclusively = TextEditingController();
  final own_shares_bought = TextEditingController();
  final own_pension = TextEditingController();
  final own_stocks = TextEditingController();
  final own_cash_isa = TextEditingController();
  final own_cryptocurrency = TextEditingController();
  final own_business_cash = TextEditingController();
  final own_business_receivables = TextEditingController();
  final own_business_stock = TextEditingController();

  //------------- Variable for Owe section ------------//
  final owe_mortgage = TextEditingController();
  final owe_utility_bills = TextEditingController();
  final owe_personal_loans = TextEditingController();
  final owe_overdraft = TextEditingController();
  final owe_credit_card = TextEditingController();
  final owe_business_libilities = TextEditingController();

  List<TextEditingController> get ownInputs => [
    own_bank_cash,
    own_cash,
    own_loan,
    own_money_expected,
    own_gold,
    own_silver,
    own_shares_bought_exclusively,
    own_shares_bought,
    own_pension,
    own_stocks,
    own_cash_isa,
    own_cryptocurrency,
    own_business_cash,
    own_business_receivables,
    own_business_stock,
  ];

  List<TextEditingController> get oweInputs => [
    owe_mortgage,
    owe_utility_bills,
    owe_personal_loans,
    owe_overdraft,
    owe_credit_card,
    owe_business_libilities,
  ];

  double? _sum(List<TextEditingController> fields) {
    var sum = 0.0;
    for (final field in fields) {
      final amount = field.text.trim().isEmpty ? 0.0 : parseAmount(field.text);
      if (amount == null) return null;
      sum += amount;
    }
    return sum.isFinite ? sum : null;
  }

  bool getTotalOwn() {
    final sum = _sum(ownInputs);
    if (sum == null) return false;
    ownResult = sum;
    totalOwn.text = sum.toString();
    return true;
  }

  bool getTotalOwe() {
    final sum = _sum(oweInputs);
    if (sum == null) return false;
    oweResult = sum;
    totalOwe.text = sum.toString();
    return true;
  }

  void getEqual() {
    equalResult = ownResult - oweResult;
    equal.text = equalResult.toString();
  }

  bool getZakat() {
    final threshold = parseAmount(totalNisab.text);
    if (threshold == null || threshold <= 0 || !equalResult.isFinite) {
      total_zakat = 0;
      totalZakat.clear();
      return false;
    }
    if (equalResult > threshold) {
      total_zakat = equalResult * 0.025;
      totalZakat.text = [
        currencySymbol,
        total_zakat.toString(),
      ].where((part) => part.isNotEmpty).join(' ');
    } else {
      total_zakat = 0;
      totalZakat.text = 'zakat_is_not_obligatory_on_you'.tr;
    }
    return true;
  }

  @override
  void onClose() {
    for (final field in [
      ...ownInputs,
      ...oweInputs,
      totalOwn,
      totalOwe,
      equal,
      totalNisab,
      totalZakat,
    ]) {
      field.dispose();
    }
    super.onClose();
  }
}
