import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/service/athkar_reader_preferences.dart';

class AthkarTextSizeSheet extends StatefulWidget {
  const AthkarTextSizeSheet({
    super.key,
    required this.size,
    required this.preferences,
    required this.onChanged,
  });

  final double size;
  final AthkarReaderPreferences preferences;
  final ValueChanged<double> onChanged;

  @override
  State<AthkarTextSizeSheet> createState() => _AthkarTextSizeSheetState();
}

class _AthkarTextSizeSheetState extends State<AthkarTextSizeSheet> {
  late double _size = widget.size;
  bool _saving = false;
  bool _error = false;

  Future<void> _change(double size) async {
    if (_saving || _size == size) return;
    final previous = _size;
    setState(() {
      _saving = true;
      _error = false;
      _size = size;
    });
    try {
      await widget.preferences.save(size);
      widget.onChanged(size);
    } catch (_) {
      if (mounted) {
        setState(() {
          _size = previous;
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'athkar_text_size'.tr,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('athkar-size-decrease'),
                  tooltip: 'athkar_text_smaller'.tr,
                  onPressed:
                      _saving || _size <= AthkarReaderPreferences.minimumSize
                      ? null
                      : () => _change(
                          (_size - 2).clamp(
                            AthkarReaderPreferences.minimumSize,
                            AthkarReaderPreferences.maximumSize,
                          ),
                        ),
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  _size.toStringAsFixed(0),
                  key: const ValueKey('athkar-size-value'),
                  style: theme.textTheme.headlineSmall,
                ),
                IconButton.filledTonal(
                  key: const ValueKey('athkar-size-increase'),
                  tooltip: 'athkar_text_larger'.tr,
                  onPressed:
                      _saving || _size >= AthkarReaderPreferences.maximumSize
                      ? null
                      : () => _change(
                          (_size + 2).clamp(
                            AthkarReaderPreferences.minimumSize,
                            AthkarReaderPreferences.maximumSize,
                          ),
                        ),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('athkar_text_preview'.tr, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoSansArabic',
                fontSize: _size,
                height: 1.8,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (_error)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'athkar_save_error'.tr,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
