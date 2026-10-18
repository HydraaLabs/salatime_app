import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/service/app_update_service.dart';

/// Non-modal and height-flexible on phones, tablets and enlarged text.
class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({
    super.key,
    required this.onUpdate,
    required this.onLater,
    this.version,
    this.busy = false,
    this.openFailed = false,
    this.progress = AppUpdateProgress.idle,
  });

  final VoidCallback onUpdate;
  final VoidCallback onLater;
  final String? version;
  final bool busy;
  final bool openFailed;
  final AppUpdateProgress progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        key: const ValueKey('app-update-banner'),
        color: colors.primaryContainer,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.system_update_alt,
                      color: colors.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        switch (progress) {
                          AppUpdateProgress.downloading =>
                            'app_update_downloading'.tr,
                          AppUpdateProgress.downloaded => 'app_update_ready'.tr,
                          AppUpdateProgress.idle =>
                            version == null
                                ? 'app_update_available'.tr
                                : 'app_update_version_available'.trParams({
                                    'version': version!,
                                  }),
                        },
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (progress == AppUpdateProgress.downloading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    key: const ValueKey('app-update-progress'),
                    color: colors.primary,
                    backgroundColor: colors.onPrimaryContainer.withValues(
                      alpha: 0.15,
                    ),
                  ),
                ],
                if (openFailed) ...[
                  const SizedBox(height: 6),
                  Text(
                    'app_update_open_failed'.tr,
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                ],
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        key: const ValueKey('app-update-later'),
                        onPressed: busy ? null : onLater,
                        style: TextButton.styleFrom(
                          foregroundColor: colors.onPrimaryContainer,
                        ),
                        child: Text('app_update_later'.tr),
                      ),
                      if (progress != AppUpdateProgress.downloading)
                        FilledButton(
                          key: const ValueKey('app-update-now'),
                          onPressed: busy ? null : onUpdate,
                          child: busy
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.onPrimary,
                                    semanticsLabel: 'app_update_now'.tr,
                                  ),
                                )
                              : Text(
                                  progress == AppUpdateProgress.downloaded
                                      ? 'app_update_restart'.tr
                                      : 'app_update_now'.tr,
                                ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
