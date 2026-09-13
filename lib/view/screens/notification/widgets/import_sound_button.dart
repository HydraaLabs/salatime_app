import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:salatime/service/personal_notification_sounds.dart';

class ImportSoundButton extends StatefulWidget {
  const ImportSoundButton({super.key, required this.onImported});
  final Future<void> Function(Map<String, String>) onImported;
  @override
  State<ImportSoundButton> createState() => _ImportSoundButtonState();
}

class _ImportSoundButtonState extends State<ImportSoundButton> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    if (!PersonalNotificationSounds.supported) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.audio_file_outlined),
          label: Text('import_personal_sound'.tr),
          onPressed: busy
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    final imported =
                        await PersonalNotificationSounds.importSound();
                    if (!mounted) return;
                    if (imported != null) await widget.onImported(imported);
                  } on PlatformException catch (e) {
                    if (mounted && e.code != 'sound_import_cancelled') {
                      setState(
                        () => error =
                            [
                              'sound_too_large',
                              'sound_duration_invalid',
                              'sound_invalid',
                              'sound_library_full',
                            ].contains(e.code)
                            ? e.code.tr
                            : 'sound_import_failed'.tr,
                      );
                    }
                  } catch (_) {
                    if (mounted) {
                      setState(() => error = 'sound_import_failed'.tr);
                    }
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
