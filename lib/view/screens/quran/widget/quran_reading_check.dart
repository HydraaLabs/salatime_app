import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/service/reading/reading_progress_service.dart';

/// A deliberate reading confirmation, independent from bookmarks and scrolling.
class QuranReadingCheck extends StatelessWidget {
  const QuranReadingCheck({
    super.key,
    required this.verseKeys,
    required this.label,
    this.service,
  });

  final List<String> verseKeys;
  final String label;
  final ReadingProgressService? service;

  Future<void> _change(
    BuildContext context,
    ReadingProgressService progress,
    List<String> keys,
    bool completed,
  ) async {
    try {
      await progress.setMany(ReadingProgressKind.quran, {
        for (final key in keys) key: completed ? 0 : 1,
      });
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('reading_progress_save_error'.tr)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = service ?? ReadingProgressService.instance;
    final keys = verseKeys.toSet().toList(growable: false);
    if (keys.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final read = keys
            .where(
              (key) => progress.todayCount(ReadingProgressKind.quran, key) > 0,
            )
            .length;
        final completed = read == keys.length;
        return CheckboxListTile(
          key: ValueKey('quran-read-${keys.first}-${keys.last}'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          tristate: true,
          value: completed ? true : (read == 0 ? false : null),
          onChanged: progress.initialized
              ? (_) => _change(context, progress, keys, completed)
              : null,
          title: Text(label),
          subtitle: Text(
            'reading_quran_check_progress'.trParams({
              'read': '$read',
              'total': '${keys.length}',
            }),
          ),
          activeColor: Theme.of(context).primaryColor,
        );
      },
    );
  }
}
