import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/service/reading/reading_progress_service.dart';
import 'package:zabi/view/base/custom_app_bar.dart';
import 'package:zabi/view/screens/account/account_screen.dart';

class ReadingProgressScreen extends StatefulWidget {
  const ReadingProgressScreen({super.key, this.service});

  final ReadingProgressService? service;

  @override
  State<ReadingProgressScreen> createState() => _ReadingProgressScreenState();
}

class _ReadingProgressScreenState extends State<ReadingProgressScreen> {
  late final ReadingProgressService _progress =
      widget.service ?? ReadingProgressService.instance;
  String? _selectedDay;
  int _historyLimit = 31;
  bool _initializationFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initialize());
    });
  }

  Future<void> _initialize() async {
    try {
      await _progress.initialize();
      if (mounted) await _progress.loadHistory();
    } catch (_) {
      if (mounted) setState(() => _initializationFailed = true);
    }
  }

  Future<void> _sync() async {
    try {
      await _progress.syncNow();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('cloud_offline'.tr)));
      }
    }
  }

  String _fullDate(String day) =>
      MaterialLocalizations.of(context).formatFullDate(DateTime.parse(day));

  Future<void> _chooseDate() async {
    final today = DateTime.parse(_progress.today);
    final chosen = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedDay ?? _progress.today),
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (chosen != null && mounted) {
      setState(
        () => _selectedDay =
            '${chosen.year.toString().padLeft(4, '0')}-'
            '${chosen.month.toString().padLeft(2, '0')}-'
            '${chosen.day.toString().padLeft(2, '0')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: CustomAppBar(
      title: 'reading_progress_title'.tr,
      isBackButtonExist: true,
    ),
    body: SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          if (!_progress.initialized) {
            return Center(
              child: _initializationFailed
                  ? TextButton.icon(
                      onPressed: () {
                        setState(() => _initializationFailed = false);
                        unawaited(_initialize());
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text('athkar_retry'.tr),
                    )
                  : const CircularProgressIndicator(),
            );
          }
          final selectedDay = _selectedDay ?? _progress.today;
          final selected = _progress.statsForDay(selectedDay);
          final stats = _progress.stats;
          final week = _progress.lastDays();
          final allDays = {
            _progress.today,
            ..._progress.entries.map((entry) => entry.day),
          }.toList()..sort((a, b) => b.compareTo(a));
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                key: const PageStorageKey('reading-progress-list'),
                padding: const EdgeInsets.all(16),
                children: [
                  _cloudCard(),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        key: const ValueKey('reading-progress-today'),
                        onPressed: () => setState(() => _selectedDay = null),
                        icon: const Icon(Icons.today_outlined),
                        label: Text('reading_progress_today'.tr),
                      ),
                      IconButton(
                        key: const ValueKey('reading-progress-select-date'),
                        tooltip: 'reading_progress_select_date'.tr,
                        onPressed: _chooseDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ],
                  ),
                  Text(
                    _fullDate(selectedDay),
                    key: const ValueKey('reading-progress-selected-date'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _metrics([
                    _metric(
                      'selected-athkar',
                      'reading_progress_athkar_completed',
                      selected.athkarCompleted,
                      Icons.check_circle_outline,
                    ),
                    _metric(
                      'selected-quran',
                      'reading_progress_quran_verses',
                      selected.quranVerses,
                      Icons.menu_book_outlined,
                    ),
                    _metric(
                      'selected-surahs',
                      'reading_progress_quran_surahs',
                      selected.quranSurahs,
                      Icons.auto_stories_outlined,
                    ),
                  ]),
                  if (!selected.active)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('reading_progress_empty'.tr),
                    ),
                  _heading('reading_progress_week'),
                  _weekChart(week, selectedDay),
                  const SizedBox(height: 12),
                  _metrics([
                    _metric(
                      'week-athkar',
                      'reading_progress_athkar_completed',
                      week.fold(0, (sum, day) => sum + day.athkarCompleted),
                      Icons.check_circle_outline,
                    ),
                    _metric(
                      'week-quran',
                      'reading_progress_quran_verses',
                      week.fold(0, (sum, day) => sum + day.quranVerses),
                      Icons.menu_book_outlined,
                    ),
                    _metric(
                      'week-surahs',
                      'reading_progress_quran_surahs',
                      week.fold(0, (sum, day) => sum + day.quranSurahs),
                      Icons.auto_stories_outlined,
                    ),
                  ]),
                  _heading('reading_progress_total'),
                  _metrics([
                    _metric(
                      'total-athkar',
                      'reading_progress_athkar_completed',
                      stats.lifetimeAthkarCompleted,
                      Icons.check_circle_outline,
                    ),
                    _metric(
                      'streak',
                      'reading_progress_streak',
                      stats.currentStreak,
                      Icons.local_fire_department_outlined,
                      valueLabel: 'reading_progress_streak_days'.trParams({
                        'count': '${stats.currentStreak}',
                      }),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'reading_progress_quran_coverage'.tr,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'reading_progress_quran_fraction'.trParams({
                              'read': '${stats.quranUniqueVerses}',
                              'total': '${stats.totalQuranVerses}',
                            }),
                            key: const ValueKey(
                              'reading-progress-quran-coverage',
                            ),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value:
                                (stats.quranUniqueVerses /
                                        stats.totalQuranVerses)
                                    .clamp(0, 1),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                            semanticsLabel:
                                'reading_progress_quran_coverage'.tr,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _heading('reading_progress_history'),
                  for (final day in allDays.take(_historyLimit))
                    _historyDay(_progress.statsForDay(day), selectedDay),
                  if (allDays.length > _historyLimit)
                    TextButton(
                      onPressed: () => setState(() => _historyLimit += 31),
                      child: Text('reading_progress_load_more'.tr),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _cloudCard() {
    final signedOut = _progress.status == 'cloud_signed_out';
    return Card(
      key: const ValueKey('reading-progress-cloud'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  signedOut
                      ? Icons.phone_android_outlined
                      : Icons.cloud_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (signedOut
                            ? 'reading_progress_guest_title'
                            : _progress.status)
                        .tr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (signedOut) ...[
              const SizedBox(height: 8),
              Text('reading_progress_guest_body'.tr),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('reading-progress-account'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AccountScreen(),
                    ),
                  ),
                  child: Text('reading_progress_guest_account'.tr),
                ),
              ),
            ] else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('reading-progress-sync'),
                  onPressed: _progress.status == 'cloud_syncing' ? null : _sync,
                  icon: const Icon(Icons.sync),
                  label: Text('cloud_sync_now'.tr),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String key) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(key.tr, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _metrics(List<Widget> cards) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 500 &&
              MediaQuery.textScalerOf(context).scale(16) <= 24
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final card in cards) SizedBox(width: width, child: card),
        ],
      );
    },
  );

  Widget _metric(
    String id,
    String label,
    int value,
    IconData icon, {
    String? valueLabel,
  }) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.tr),
                const SizedBox(height: 4),
                Text(
                  valueLabel ?? '$value',
                  key: ValueKey('reading-progress-$id'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  String _summary(ReadingDailyStats day) =>
      'reading_progress_day_summary'.trParams({
        'athkar': '${day.athkarCompleted}',
        'quran': '${day.quranVerses}',
      });

  Widget _historyDay(ReadingDailyStats day, String selectedDay) => Card(
    child: ListTile(
      key: ValueKey('reading-history-${day.day}'),
      selected: day.day == selectedDay,
      title: Text(_fullDate(day.day)),
      subtitle: Text(_summary(day)),
      trailing: day.day == selectedDay
          ? Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: () => setState(() => _selectedDay = day.day),
    ),
  );

  Widget _weekChart(List<ReadingDailyStats> days, String selectedDay) {
    final largest = days.fold(
      1,
      (value, day) => math.max(value, day.athkarCompleted + day.quranVerses),
    );
    return SizedBox(
      height: 170 + MediaQuery.textScalerOf(context).scale(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Semantics(
                  button: true,
                  selected: selectedDay == day.day,
                  label: '${_fullDate(day.day)}. ${_summary(day)}',
                  child: Tooltip(
                    message: '${_fullDate(day.day)}\n${_summary(day)}',
                    child: InkWell(
                      key: ValueKey('reading-week-${day.day}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _selectedDay = day.day),
                      child: ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: selectedDay == day.day
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.10)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 18,
                                height: math.max(
                                  3,
                                  (day.athkarCompleted + day.quranVerses) /
                                      largest *
                                      110,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: day.active
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${DateTime.parse(day.day).day}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
