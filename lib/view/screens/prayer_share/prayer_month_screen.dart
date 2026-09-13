import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/controller/prayer_time_adjustment.dart';
import 'package:salatime/helper/prayer_share_data.dart';

class PrayerMonthScreen extends StatefulWidget {
  final DateTime? initialDate;
  const PrayerMonthScreen({super.key, this.initialDate});

  @override
  State<PrayerMonthScreen> createState() => _PrayerMonthScreenState();
}

class _PrayerMonthScreenState extends State<PrayerMonthScreen> {
  late DateTime _month = DateTime(
    (widget.initialDate ?? DateTime.now()).year,
    (widget.initialDate ?? DateTime.now()).month,
  );
  List<PrayerShareData?> _days = [];
  bool _loading = true;
  bool _sharing = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final month = _month;
    setState(() {
      _loading = true;
      _days = [];
    });
    final count = DateTime(month.year, month.month + 1, 0).day;
    final result = List<PrayerShareData?>.filled(count, null);
    if (Get.isRegistered<PrayerTimeController>()) {
      final controller = Get.find<PrayerTimeController>();
      final chosenCity = controller.isManualPrayerTime.value
          ? controller.saveAddress.value
          : controller.currentAddress.value;
      final city = chosenCity.trim() == '--' ? '' : chosenCity.trim();
      final adjustments = PrayerTimeAdjustmentController.displayOffsets;
      // Bounded batches also keep cached/local calculations inexpensive.
      for (int start = 0; start < count; start += 3) {
        if (!mounted || generation != _generation) return;
        await Future.wait([
          for (int index = start; index < count && index < start + 3; index++)
            () async {
              try {
                final date = DateTime(month.year, month.month, index + 1);
                final model = await controller.getPrayerTimeForDate(date);
                final snapshot = PrayerShareData.fromDay(
                  model?.data,
                  city: city,
                  adjustments: adjustments,
                );
                if (snapshot != null &&
                    DateUtils.isSameDay(snapshot.date, date)) {
                  result[index] = snapshot;
                }
              } catch (_) {
                // Keep an explicit unavailable cell for this day.
              }
            }(),
        ]);
      }
    }
    if (mounted && generation == _generation) {
      setState(() {
        _days = result;
        _loading = false;
      });
    }
  }

  Future<void> _share(BuildContext buttonContext) async {
    if (_loading || _sharing || _days.every((day) => day == null)) return;
    final material = MaterialLocalizations.of(context);
    final city = _days.whereType<PrayerShareData>().first.city;
    final text = [
      'SalaTime · ${'prayer_month_title'.tr}',
      if (city.isNotEmpty) city,
      material.formatMonthYear(_month),
      '',
      for (int index = 0; index < _days.length; index++) ...[
        material.formatFullDate(DateTime(_month.year, _month.month, index + 1)),
        if (_days[index] == null)
          'prayer_month_missing'.tr
        else
          for (final prayer in _days[index]!.prayers)
            '${prayer.labelKey.tr} : ${_days[index]!.timeText(prayer, material.formatCompactDate)}',
        '',
      ],
      'salatime.net',
    ].join('\n');
    final box = buttonContext.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('prayer_share_error'.tr)));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() => _month = DateTime(_month.year, _month.month + offset));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final hasDays = _days.any((day) => day != null);
    return Scaffold(
      appBar: AppBar(title: Text('prayer_month_title'.tr)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: _sharing ? null : () => _changeMonth(-1),
                  tooltip: 'calendar_previous_month'.tr,
                  icon: const BackButtonIcon(),
                ),
                Expanded(
                  child: Text(
                    material.formatMonthYear(_month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: _sharing ? null : () => _changeMonth(1),
                  tooltip: 'calendar_next_month'.tr,
                  icon: Transform.flip(
                    flipX: true,
                    child: const BackButtonIcon(),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: hasDays
                  ? SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 64,
                          dataRowMinHeight: 64,
                          dataRowMaxHeight: 140,
                          columns: [
                            DataColumn(label: Text('calendar_day'.tr)),
                            for (final label in [
                              'fajr',
                              'sunrise',
                              'dhuhr',
                              'asr',
                              'magrib',
                              'isha',
                            ])
                              DataColumn(label: Text(label.tr)),
                          ],
                          rows: [
                            for (int index = 0; index < _days.length; index++)
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      material.formatCompactDate(
                                        DateTime(
                                          _month.year,
                                          _month.month,
                                          index + 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  for (
                                    int prayerIndex = 0;
                                    prayerIndex < 6;
                                    prayerIndex++
                                  )
                                    DataCell(
                                      Text(
                                        _days[index] == null
                                            ? '—'
                                            : _days[index]!.timeText(
                                                _days[index]!
                                                    .prayers[prayerIndex],
                                                material.formatCompactDate,
                                              ),
                                        textDirection: TextDirection.ltr,
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'prayer_share_unavailable'.tr,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
          if (!_loading)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_days.any((day) => day == null))
                      Text(
                        'prayer_month_missing'.tr,
                        textAlign: TextAlign.center,
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _sharing ? null : _load,
                          icon: const Icon(Icons.refresh),
                          label: Text('prayer_share_retry'.tr),
                        ),
                        Builder(
                          builder: (buttonContext) => FilledButton.icon(
                            onPressed: !hasDays || _sharing
                                ? null
                                : () => _share(buttonContext),
                            icon: const Icon(Icons.share_outlined),
                            label: Text('prayer_share_text'.tr),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
