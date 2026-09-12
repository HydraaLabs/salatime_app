import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:zabi/helper/islamic_calendar.dart';
import 'package:zabi/helper/salat_waqt_service.dart';
import 'package:zabi/view/screens/prayer_share/prayer_month_screen.dart';

class IslamicCalendarScreen extends StatefulWidget {
  final DateTime Function() now;
  const IslamicCalendarScreen({super.key, this.now = DateTime.now});

  @override
  State<IslamicCalendarScreen> createState() => _IslamicCalendarScreenState();
}

class _IslamicCalendarScreenState extends State<IslamicCalendarScreen> {
  late DateTime _selected = widget.now();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await IslamicCalendarPreferences.initialize();
    } catch (_) {
      if (mounted) _error();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _error() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('calendar_save_error'.tr)));

  String _hijri(HijriCalendar date) =>
      '${date.hDay} ${'hijri_month_${date.hMonth}'.tr} ${date.hYear}';

  Future<void> _correct(int value) async {
    setState(() => _saving = true);
    try {
      await IslamicCalendarPreferences.setOffset(value);
      await SalatWaqtService.initializeSalatWaqt();
    } catch (_) {
      if (mounted) _error();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickGregorian() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: IslamicCalendarPreferences.gregorian(1357, 1, 1),
      lastDate: IslamicCalendarPreferences.gregorian(1499, 12, 29),
      helpText: 'calendar_gregorian'.tr,
    );
    if (selected != null && mounted) setState(() => _selected = selected);
  }

  Future<void> _pickHijri() async {
    final current = IslamicCalendarPreferences.date(_selected);
    int year = current.hYear;
    int month = current.hMonth;
    int day = current.hDay;
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('calendar_hijri'.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: year,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(labelText: 'calendar_year'.tr),
                  items: [
                    for (int y = 1357; y <= 1499; y++)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (value) => update(() {
                    year = value!;
                    day = day.clamp(
                      1,
                      HijriCalendar().getDaysInMonth(year, month),
                    );
                  }),
                ),
                DropdownButtonFormField<int>(
                  initialValue: month,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(labelText: 'calendar_month'.tr),
                  items: [
                    for (int m = 1; m <= 12; m++)
                      DropdownMenuItem(
                        value: m,
                        child: Text('hijri_month_$m'.tr),
                      ),
                  ],
                  onChanged: (value) => update(() {
                    month = value!;
                    day = day.clamp(
                      1,
                      HijriCalendar().getDaysInMonth(year, month),
                    );
                  }),
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey('hijri-day-$year-$month-$day'),
                  initialValue: day,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(labelText: 'calendar_day'.tr),
                  items: [
                    for (
                      int d = 1;
                      d <= HijriCalendar().getDaysInMonth(year, month);
                      d++
                    )
                      DropdownMenuItem(value: d, child: Text('$d')),
                  ],
                  onChanged: (value) => update(() => day = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                IslamicCalendarPreferences.gregorian(year, month, day),
              ),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _selected = selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('islamic_calendar_title'.tr)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<int>(
              valueListenable: IslamicCalendarPreferences.offset,
              builder: (context, correction, _) {
                final hijri = IslamicCalendarPreferences.date(_selected);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              color: theme.colorScheme.primary,
                              size: 36,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _hijri(hijri),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              material.formatFullDate(_selected),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: _pickGregorian,
                                  child: Text('calendar_gregorian'.tr),
                                ),
                                OutlinedButton(
                                  onPressed: _pickHijri,
                                  child: Text('calendar_hijri'.tr),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _selected = widget.now()),
                                  child: Text('calendar_today'.tr),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'calendar_correction'.tr,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'calendar_moon_note'.tr,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: _saving || correction <= -2
                                      ? null
                                      : () => _correct(correction - 1),
                                  tooltip: 'calendar_previous_day'.tr,
                                  icon: const Icon(Icons.remove),
                                ),
                                Flexible(
                                  child: Text(
                                    '${correction > 0 ? '+' : ''}$correction ${'calendar_days'.tr}',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _saving || correction >= 2
                                      ? null
                                      : () => _correct(correction + 1),
                                  tooltip: 'calendar_next_day'.tr,
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PrayerMonthScreen(initialDate: _selected),
                        ),
                      ),
                      icon: const Icon(Icons.table_chart_outlined),
                      label: Text('prayer_month_title'.tr),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        IconButton(
                          onPressed: hijri.hYear <= 1358
                              ? null
                              : () => setState(
                                  () => _selected =
                                      IslamicCalendarPreferences.gregorian(
                                        hijri.hYear - 1,
                                        1,
                                        1,
                                      ),
                                ),
                          tooltip: 'calendar_previous_year'.tr,
                          icon: const BackButtonIcon(),
                        ),
                        Expanded(
                          child: Text(
                            '${'calendar_events'.tr} · ${hijri.hYear}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: hijri.hYear >= 1498
                              ? null
                              : () => setState(
                                  () => _selected =
                                      IslamicCalendarPreferences.gregorian(
                                        hijri.hYear + 1,
                                        1,
                                        1,
                                      ),
                                ),
                          tooltip: 'calendar_next_year'.tr,
                          icon: Transform.flip(
                            flipX: true,
                            child: const BackButtonIcon(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final event in IslamicEvent.all)
                      _eventTile(event, hijri.hYear),
                  ],
                );
              },
            ),
    );
  }

  Widget _eventTile(IslamicEvent event, int year) {
    final theme = Theme.of(context);
    final date = event.dateInYear(year);
    final remaining = IslamicEvent.civilDaysBetween(widget.now(), date);
    final isPast = remaining < 0;
    final mutedColor = theme.brightness == Brightness.dark
        ? Colors.grey.shade500
        : Colors.grey.shade600;
    final dateStyle = isPast ? TextStyle(color: mutedColor) : null;
    final delta = remaining == 0
        ? 'calendar_today'.tr
        : (remaining > 0 ? 'calendar_in_days' : 'calendar_days_ago').trParams({
            'days': '${remaining.abs()}',
          });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.key.tr,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isPast ? mutedColor : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${event.day} ${'hijri_month_${event.month}'.tr} $year',
              style: dateStyle,
            ),
            Text(
              MaterialLocalizations.of(context).formatFullDate(date),
              style: dateStyle,
            ),
            const SizedBox(height: 8),
            Text(
              delta,
              style: TextStyle(
                color: isPast ? mutedColor : theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
