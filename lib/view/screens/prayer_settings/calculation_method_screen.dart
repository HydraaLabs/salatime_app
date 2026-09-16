import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/helper/prayer_calculation_methods.dart';

String calculationMethodLabel(PrayerCalculationMethod method) {
  final translated = method.nameKey.tr;
  return translated == method.nameKey ? method.fallbackName : translated;
}

class CalculationMethodScreen extends StatefulWidget {
  const CalculationMethodScreen({super.key});

  @override
  State<CalculationMethodScreen> createState() =>
      _CalculationMethodScreenState();
}

class _CalculationMethodScreenState extends State<CalculationMethodScreen> {
  late final PrayerTimeController _controller;
  bool _loading = true;
  String? _savingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<PrayerTimeController>();
    _load();
  }

  Future<void> _load() async {
    try {
      await _controller.loadPrayerTimeSettings();
    } catch (_) {
      if (mounted) _error = 'please_try_again'.tr;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(PrayerCalculationMethod method) async {
    if (_savingId != null) return;
    if (!_controller.automaticCalculationMethod &&
        _controller.selectedCalculationMethod == method.id) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _savingId = method.id;
      _error = null;
    });
    try {
      // This future only waits for durable preferences. Recalculation and alarm
      // refresh are deferred by the controller so navigation stays responsive.
      await _controller.selectCalculationMethod(method.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'calculation_method_save_error'.tr);
      }
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  Future<void> _setAutomatic(bool enabled) async {
    if (_savingId != null) return;
    setState(() {
      _savingId = 'automatic';
      _error = null;
    });
    try {
      await _controller.selectAutomaticCalculationMethod(enabled);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'calculation_method_save_error'.tr);
      }
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  String _automaticDescription(PrayerTimeController controller) {
    final method = PrayerCalculationMethods.byId(
      controller.selectedCalculationMethod,
    );
    if (!controller.automaticCalculationMethod) {
      return 'calculation_method_auto_description'.tr;
    }
    if (controller.calculationCountry == null || method == null) {
      return 'calculation_method_auto_unavailable'.trParams({
        'method': method == null ? '' : calculationMethodLabel(method),
      });
    }
    return 'calculation_method_auto_resolved'.trParams({
      'country': controller.calculationCountry!,
      'method': calculationMethodLabel(method),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.primary,
        elevation: 0,
        toolbarHeight: math.max(
          kToolbarHeight,
          MediaQuery.textScalerOf(context).scale(20) * 2 + 16,
        ),
        title: Text(
          'calculation_method_title'.tr,
          maxLines: 2,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GetBuilder<PrayerTimeController>(
              builder: (controller) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (controller.usesManualPrayerTimetable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'calculation_method_manual_notice'.tr,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    child: SwitchListTile(
                      key: const ValueKey('calculation-method-automatic'),
                      title: Text('calculation_method_auto_title'.tr),
                      subtitle: Text(_automaticDescription(controller)),
                      value: controller.automaticCalculationMethod,
                      onChanged: _savingId == null ? _setAutomatic : null,
                    ),
                  ),
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final method in PrayerCalculationMethods.all) ...[
                          if (method != PrayerCalculationMethods.all.first)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                          Semantics(
                            checked:
                                controller.selectedCalculationMethod ==
                                method.id,
                            inMutuallyExclusiveGroup: true,
                            child: ListTile(
                              key: ValueKey('calculation-method-${method.id}'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              minVerticalPadding: 12,
                              selected:
                                  controller.selectedCalculationMethod ==
                                  method.id,
                              selectedColor: theme.colorScheme.primary,
                              title: Text(
                                calculationMethodLabel(method),
                                style: theme.textTheme.bodyLarge,
                              ),
                              trailing: SizedBox(
                                width: 24,
                                height: 24,
                                child: _savingId == method.id
                                    ? const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      )
                                    : controller.selectedCalculationMethod ==
                                          method.id
                                    ? Icon(
                                        Icons.check_rounded,
                                        color: theme.colorScheme.primary,
                                      )
                                    : null,
                              ),
                              onTap: _savingId == null
                                  ? () => _select(method)
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
