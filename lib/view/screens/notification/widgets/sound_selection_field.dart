import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/noti_sound_controller.dart';
import 'import_sound_button.dart';

/// A compact, shared entry point to the full sound library. The library stays
/// lazy and bounded even when the user adds many personal recordings.
class SoundSelectionField extends StatelessWidget {
  const SoundSelectionField({
    super.key,
    required this.selectedKey,
    required this.label,
    required this.onChanged,
    this.sounds,
    this.onPreview,
    this.onStopPreview,
    this.previewKey,
    this.compact = false,
    this.allowImport = false,
  });

  final String selectedKey;
  final String label;
  final ValueChanged<String>? onChanged;
  final List<Map<String, String>>? sounds;
  final Future<void> Function(String key)? onPreview;
  final Future<void> Function()? onStopPreview;
  final Key? previewKey;
  final bool compact;
  final bool allowImport;

  Future<void> _open(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => _SoundLibraryDialog(
        sounds: sounds ?? NotiSoundController.availableSounds,
        selectedKey: selectedKey,
        onPreview: onPreview,
        allowImport: allowImport,
      ),
    );
    try {
      await onStopPreview?.call();
    } catch (_) {
      // A failed preview must not discard the chosen sound.
    }
    if (context.mounted && selected != null) onChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final options = sounds ?? NotiSoundController.availableSounds;
    final current = options.where((sound) => sound['key'] == selectedKey);
    final selectedLabel = current.isEmpty
        ? 'sound_unavailable'.tr
        : NotiSoundController.label(current.first);
    if (compact) {
      return Semantics(
        button: true,
        enabled: onChanged != null,
        child: InkWell(
          onTap: onChanged == null ? null : () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * .5,
                    ),
                    child: Text(label),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      selectedLabel,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            enabled: onChanged != null,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onChanged == null ? null : () => _open(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: label,
                  enabled: onChanged != null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (onPreview != null)
          IconButton(
            key: previewKey,
            tooltip: 'preview_sound'.tr,
            onPressed: onChanged == null ? null : () => onPreview!(selectedKey),
            icon: const Icon(Icons.play_circle_outline),
          ),
      ],
    );
  }
}

class _SoundLibraryDialog extends StatefulWidget {
  const _SoundLibraryDialog({
    required this.sounds,
    required this.selectedKey,
    this.onPreview,
    this.allowImport = false,
  });
  final List<Map<String, String>> sounds;
  final String selectedKey;
  final Future<void> Function(String key)? onPreview;
  final bool allowImport;

  @override
  State<_SoundLibraryDialog> createState() => _SoundLibraryDialogState();
}

class _SoundLibraryDialogState extends State<_SoundLibraryDialog> {
  String _query = '';

  String _searchable(String text) {
    var value = text.toLowerCase().replaceAll(
      RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'),
      '',
    );
    const letters = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'á': 'a',
      'ã': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'í': 'i',
      'ı': 'i',
      'ô': 'o',
      'ö': 'o',
      'ó': 'o',
      'õ': 'o',
      'û': 'u',
      'ü': 'u',
      'ù': 'u',
      'ú': 'u',
      'ç': 'c',
      'ñ': 'n',
      'أ': 'ا',
      'إ': 'ا',
      'آ': 'ا',
    };
    for (final entry in letters.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final terms = _searchable(_query.trim()).split(RegExp(r'\s+'));
    final matches = widget.sounds.where((sound) {
      final text = _searchable(
        '${NotiSoundController.label(sound)} ${sound['name']} ${sound['key']}',
      );
      return terms.every(text.contains);
    }).toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'choose_sound_for_notification'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'close'.tr,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  key: const ValueKey('sound_library_search'),
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'search'.tr,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const Divider(height: 1),
              if (widget.allowImport)
                ImportSoundButton(
                  onImported: (sound) async {
                    if (context.mounted) Navigator.pop(context, sound['key']);
                  },
                ),
              Expanded(
                child: matches.isEmpty
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Text('sound_no_results'.tr),
                      )
                    : ListView.separated(
                        key: const ValueKey('sound_library_results'),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: matches.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final sound = matches[index];
                          final selected = sound['key'] == widget.selectedKey;
                          return ListTile(
                            key: ValueKey('sound_choice_${sound['key']}'),
                            selected: selected,
                            contentPadding: const EdgeInsetsDirectional.only(
                              start: 16,
                              end: 8,
                            ),
                            title: Text(
                              NotiSoundController.label(sound),
                              style: selected
                                  ? const TextStyle(fontWeight: FontWeight.w600)
                                  : null,
                            ),
                            subtitle: selected
                                ? Text('sound_selected'.tr)
                                : null,
                            trailing: widget.onPreview == null
                                ? (selected ? const Icon(Icons.check) : null)
                                : IconButton(
                                    tooltip: 'preview_sound'.tr,
                                    onPressed: () =>
                                        widget.onPreview!(sound['key']!),
                                    icon: const Icon(Icons.play_circle_outline),
                                  ),
                            onTap: () => Navigator.pop(context, sound['key']),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
