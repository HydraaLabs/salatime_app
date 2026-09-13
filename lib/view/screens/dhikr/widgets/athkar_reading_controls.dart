import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A reading check is available even when the source does not prescribe a count.
/// In that case it records one completed reading without inventing repetitions.
class AthkarReadingControls extends StatelessWidget {
  const AthkarReadingControls({
    super.key,
    required this.itemKey,
    required this.current,
    required this.repetitions,
    required this.onChanged,
    required this.onIncrement,
    this.enabled = true,
  });

  final String itemKey;
  final int current;
  final int? repetitions;
  final ValueChanged<int> onChanged;
  final VoidCallback onIncrement;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final target = repetitions ?? 1;
    final completed = current >= target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: ValueKey('athkar-read-$itemKey'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: completed,
          onChanged: enabled
              ? (value) => onChanged(value == true ? target : 0)
              : null,
          title: Text('athkar_read'.tr),
          checkboxSemanticLabel:
              (completed ? 'athkar_mark_unread' : 'athkar_mark_read').tr,
        ),
        if (repetitions != null)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: ValueKey('athkar-count-$itemKey'),
                onPressed: enabled && !completed ? onIncrement : null,
                icon: Icon(
                  completed
                      ? Icons.check_circle_outline
                      : Icons.touch_app_outlined,
                ),
                label: Text(
                  completed
                      ? 'athkar_completed'.tr
                      : 'athkar_counter_progress'.trParams({
                          'current': '$current',
                          'total': '$target',
                        }),
                  textAlign: TextAlign.center,
                ),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
              if (current > 0)
                IconButton(
                  key: ValueKey('athkar-reset-$itemKey'),
                  tooltip: 'athkar_reset_counter'.tr,
                  onPressed: enabled ? () => onChanged(0) : null,
                  icon: const Icon(Icons.restart_alt),
                ),
            ],
          ),
      ],
    );
  }
}
