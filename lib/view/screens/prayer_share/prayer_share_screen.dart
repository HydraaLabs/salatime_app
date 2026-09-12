import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zabi/controller/package_prayer_time_controller.dart';
import 'package:zabi/controller/prayer_time_adjustment.dart';
import 'package:zabi/data/model/response/todays_prayer_time_model.dart';
import 'package:zabi/helper/islamic_calendar.dart';
import 'package:zabi/helper/prayer_share_data.dart';
import 'package:zabi/theme/brand_colors.dart';

class PrayerShareScreen extends StatefulWidget {
  final DateTime? initialDate;
  const PrayerShareScreen({super.key, this.initialDate});

  @override
  State<PrayerShareScreen> createState() => _PrayerShareScreenState();
}

class _PrayerShareScreenState extends State<PrayerShareScreen> {
  final _cardKey = GlobalKey();
  late DateTime _date = widget.initialDate ?? DateTime.now();
  PrayerShareData? _data;
  bool _loading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _data = null;
    });
    try {
      await IslamicCalendarPreferences.initialize();
      if (!Get.isRegistered<PrayerTimeController>()) return;
      final controller = Get.find<PrayerTimeController>();
      final key =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
      Data? day = controller.prayerTimeModel?.data;
      if (day?.date != key) {
        day = (await controller.getPrayerTimeForDate(_date))?.data;
      }
      if (day?.date != key) return;
      final chosenCity = controller.isManualPrayerTime.value
          ? controller.saveAddress.value
          : controller.currentAddress.value;
      final city = chosenCity.trim();
      final snapshot = PrayerShareData.fromDay(
        day,
        city: city == '--' ? '' : city,
        adjustments: PrayerTimeAdjustmentController.displayOffsets,
      );
      if (mounted) setState(() => _data = snapshot);
    } catch (_) {
      // An incomplete schedule must never be exported as a valid prayer card.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _hijri(DateTime date) {
    final h = IslamicCalendarPreferences.date(date);
    return '${h.hDay} ${'hijri_month_${h.hMonth}'.tr} ${h.hYear}';
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 2, 12, 31),
    );
    if (chosen == null || !mounted) return;
    setState(() => _date = chosen);
    await _load();
  }

  Future<void> _share(BuildContext buttonContext, {required bool image}) async {
    final snapshot = _data;
    if (snapshot == null || _sharing) return;
    final material = MaterialLocalizations.of(context);
    final text = snapshot.text(
      translate: (key) => key.tr,
      formatDate: material.formatFullDate,
      hijriDate: _hijri(snapshot.date),
    );
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    setState(() => _sharing = true);
    try {
      List<XFile>? files;
      if (image) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        final boundary =
            _cardKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
        if (boundary == null) throw StateError('Prayer card unavailable');
        final picture = await boundary.toImage(pixelRatio: 2);
        try {
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (bytes == null) throw StateError('Prayer card capture failed');
          files = [
            XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png'),
          ];
        } finally {
          picture.dispose();
        }
      }
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: files,
          fileNameOverrides: image
              ? [
                  'salatime-${snapshot.date.toIso8601String().split('T').first}.png',
                ]
              : null,
          sharePositionOrigin: origin,
        ),
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('prayer_share_title'.tr)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: _loading || _sharing ? null : _pickDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(MaterialLocalizations.of(context).formatFullDate(_date)),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_data == null) ...[
          Text('prayer_share_unavailable'.tr, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text('prayer_share_retry'.tr),
          ),
        ] else ...[
          RepaintBoundary(
            key: _cardKey,
            child: PrayerTimesShareCard(
              data: _data!,
              hijriDate: _hijri(_data!.date),
            ),
          ),
          const SizedBox(height: 20),
          Builder(
            builder: (buttonContext) => FilledButton.icon(
              onPressed: _sharing
                  ? null
                  : () => _share(buttonContext, image: true),
              icon: const Icon(Icons.image_outlined),
              label: Text('prayer_share_image'.tr),
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (buttonContext) => OutlinedButton.icon(
              onPressed: _sharing
                  ? null
                  : () => _share(buttonContext, image: false),
              icon: const Icon(Icons.notes_outlined),
              label: Text('prayer_share_text'.tr),
            ),
          ),
          if (_sharing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ],
    ),
  );
}

/// A self-contained surface: image exports stay legible in either app theme.
class PrayerTimesShareCard extends StatelessWidget {
  final PrayerShareData data;
  final String hijriDate;
  const PrayerTimesShareCard({
    super.key,
    required this.data,
    required this.hijriDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: BrandColors.primary,
              child: DefaultTextStyle(
                style: theme.textTheme.titleMedium!.copyWith(
                  color: Colors.white,
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.mosque_outlined,
                      size: 36,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SalaTime',
                      style: theme.textTheme.headlineSmall!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (data.city.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(data.city, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 12),
                    Text(hijriDate, textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(
                      material.formatFullDate(data.date),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  for (final prayer in data.prayers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final time = Text(
                            data.timeText(prayer, material.formatCompactDate),
                            textDirection: TextDirection.ltr,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          );
                          final label = Text(
                            prayer.labelKey.tr,
                            style: theme.textTheme.titleMedium,
                          );
                          if (MediaQuery.textScalerOf(context).scale(16) > 24 ||
                              constraints.maxWidth < 250) {
                            return Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  label,
                                  const SizedBox(height: 4),
                                  time,
                                ],
                              ),
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: label),
                              const SizedBox(width: 12),
                              Flexible(child: time),
                            ],
                          );
                        },
                      ),
                    ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'salatime.net',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
