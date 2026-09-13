import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/helper/athkar_catalog.dart';
import 'package:salatime/service/athkar_reader_preferences.dart';
import 'package:salatime/service/reading/reading_progress_service.dart';
import 'package:salatime/view/base/custom_app_bar.dart';
import 'package:salatime/view/screens/dhikr/widgets/athkar_reading_controls.dart';
import 'package:salatime/view/screens/dhikr/widgets/athkar_text_size_sheet.dart';
import 'package:salatime/view/screens/dhikr/widgets/personal_dhikr_screen.dart';
import 'package:salatime/view/screens/reading/reading_progress_screen.dart';

class DhikrScreen extends StatefulWidget {
  const DhikrScreen({
    super.key,
    required this.appBackButton,
    this.onBackPressed,
    this.loadCatalog,
    this.readerPreferences = const AthkarReaderPreferences(),
    this.readingProgress,
  });

  final bool appBackButton;
  final VoidCallback? onBackPressed;
  final Future<AthkarCatalog> Function()? loadCatalog;
  final AthkarReaderPreferences readerPreferences;
  final ReadingProgressService? readingProgress;

  @override
  State<DhikrScreen> createState() => _DhikrScreenState();
}

class _DhikrScreenState extends State<DhikrScreen> {
  static const _mainCategories = [
    'morning',
    'evening',
    'after_prayer',
    'sleep',
  ];
  late final ReadingProgressService _progress =
      widget.readingProgress ?? ReadingProgressService.instance;
  late Future<AthkarCatalog> _catalog;
  final _arabicSize = ValueNotifier(AthkarReaderPreferences.defaultSize);
  bool _sizeReady = false;

  @override
  void initState() {
    super.initState();
    _catalog = _loadCatalog();
    unawaited(_loadSize());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initializeReading());
    });
  }

  Future<AthkarCatalog> _loadCatalog() =>
      widget.loadCatalog?.call() ?? AthkarCatalog.load();

  Future<void> _initializeReading() async {
    try {
      await _progress.initialize();
    } catch (_) {
      _readingError();
    }
  }

  void _readingError() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('reading_progress_save_error'.tr)));
  }

  Future<void> _saveReading(AthkarEntry entry, int count) async {
    try {
      await _progress.setCount(ReadingProgressKind.athkar, entry.id, count);
    } catch (_) {
      _readingError();
    }
  }

  Future<void> _incrementReading(AthkarEntry entry) async {
    try {
      await _progress.increment(ReadingProgressKind.athkar, entry.id);
    } catch (_) {
      _readingError();
    }
  }

  void _openProgress() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReadingProgressScreen(service: _progress),
    ),
  );

  Future<void> _loadSize() async {
    try {
      final size = await widget.readerPreferences.load();
      if (mounted) _arabicSize.value = size;
    } catch (_) {
      // Offline text remains readable if the saved reading preference is absent.
    } finally {
      if (mounted) setState(() => _sizeReady = true);
    }
  }

  Future<void> _changeTextSize() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => AthkarTextSizeSheet(
      size: _arabicSize.value,
      preferences: widget.readerPreferences,
      onChanged: (size) {
        if (mounted) _arabicSize.value = size;
      },
    ),
  );

  @override
  void dispose() {
    _arabicSize.dispose();
    super.dispose();
  }

  String _categoryLabel(AthkarCategory category) {
    final label = category.nameKey.tr;
    return label == category.nameKey ? category.titleArabic : label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'athkar_title'.tr,
        isBackButtonExist: widget.appBackButton,
        onBackPressed: widget.onBackPressed,
        actions: [
          IconButton(
            key: const ValueKey('athkar-reading-progress'),
            tooltip: 'reading_progress_title'.tr,
            onPressed: _openProgress,
            icon: const Icon(Icons.bar_chart_outlined, color: Colors.white),
          ),
          IconButton(
            key: const ValueKey('athkar-text-size'),
            tooltip: 'athkar_text_size'.tr,
            onPressed: _sizeReady ? _changeTextSize : null,
            icon: const Text(
              'AA',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<AthkarCatalog>(
          future: _catalog,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('athkar_load_error'.tr, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          final next = _loadCatalog();
                          setState(() {
                            _catalog = next;
                          });
                        },
                        child: Text('athkar_retry'.tr),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final catalog = snapshot.requireData;
            final categories = [
              for (final id in _mainCategories) ?catalog.category(id),
            ];
            final theme = Theme.of(context);
            return DefaultTabController(
              length: categories.length + 1,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    indicatorColor: theme.colorScheme.primary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: [
                      for (final category in categories)
                        _tab(category.id, _categoryLabel(category)),
                      _tab('more', 'athkar_more'.tr),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final category in categories) _entries(category),
                        _more(catalog),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tab(String id, String label) => Tab(
    key: ValueKey('athkar-tab-$id'),
    height: math.max(52, MediaQuery.textScalerOf(context).scale(16) * 1.4 + 16),
    child: Text(label),
  );

  Widget _entries(AthkarCategory category, {bool showTitle = false}) =>
      AnimatedBuilder(
        animation: _progress,
        builder: (context, _) => ValueListenableBuilder<double>(
          valueListenable: _arabicSize,
          builder: (context, size, child) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView.builder(
                key: PageStorageKey('athkar-list-${category.id}'),
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                itemCount: category.entries.length + (showTitle ? 1 : 0),
                itemBuilder: (context, index) {
                  if (showTitle && index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      child: Text(
                        _categoryLabel(category),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    );
                  }
                  final entry = category.entries[index - (showTitle ? 1 : 0)];
                  return _card(entry, size);
                },
              ),
            ),
          ),
        ),
      );

  Widget _card(AthkarEntry entry, double size) {
    final theme = Theme.of(context);
    final current = _progress.todayCount(ReadingProgressKind.athkar, entry.id);
    final arabicStyle = TextStyle(
      fontFamily: 'NotoSansArabic',
      fontSize: size,
      height: 1.8,
      color: theme.colorScheme.onSurface,
    );
    return Card(
      key: ValueKey('athkar-card-${entry.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (entry.title.trim().isNotEmpty) ...[
              Text(
                entry.title,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: arabicStyle.copyWith(
                  color: theme.colorScheme.primary,
                  fontSize: math.max(20, size - 4),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
            ],
            SelectableText(
              entry.arabic,
              key: ValueKey('athkar-arabic-${entry.id}'),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: arabicStyle,
            ),
            if (entry.reason.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                entry.reason,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: arabicStyle.copyWith(fontSize: 16),
              ),
            ],
            if (entry.reference.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                entry.reference,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: arabicStyle.copyWith(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (entry.repetition.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                entry.repetition,
                key: ValueKey('athkar-repetition-${entry.id}'),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: arabicStyle.copyWith(
                  fontSize: 16,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            AthkarReadingControls(
              itemKey: entry.id,
              current: current,
              repetitions: entry.repetitions,
              enabled: _progress.initialized,
              onChanged: (count) => unawaited(_saveReading(entry, count)),
              onIncrement: () => unawaited(_incrementReading(entry)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _more(AthkarCatalog catalog) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: ListView(
        key: const PageStorageKey('athkar-more-list'),
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              key: const ValueKey('athkar-personal-entry'),
              leading: Icon(
                Icons.bookmark_border,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text('athkar_personal_title'.tr),
              subtitle: Text('athkar_personal_description'.tr),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PersonalDhikrScreen(),
                ),
              ),
            ),
          ),
          for (final category in catalog.categories)
            if (!_mainCategories.contains(category.id))
              Card(
                child: ListTile(
                  key: ValueKey('athkar-category-${category.id}'),
                  title: Text(_categoryLabel(category)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: CustomAppBar(
                          title: 'athkar_title'.tr,
                          isBackButtonExist: true,
                          actions: [
                            IconButton(
                              tooltip: 'reading_progress_title'.tr,
                              onPressed: _openProgress,
                              icon: const Icon(
                                Icons.bar_chart_outlined,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              tooltip: 'athkar_text_size'.tr,
                              onPressed: _changeTextSize,
                              icon: const Text(
                                'AA',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        body: SafeArea(top: false, child: _entries(category)),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}
