import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/service/analytics/app_analytics_service.dart';

/// The collection choice is local to this installation, including guest use.
class AnalyticsSettingsTile extends StatefulWidget {
  const AnalyticsSettingsTile({
    super.key,
    this.collectionPreference,
    this.onCollectionChanged,
  });

  final ValueListenable<bool>? collectionPreference;
  final Future<void> Function(bool)? onCollectionChanged;

  @override
  State<AnalyticsSettingsTile> createState() => _AnalyticsSettingsTileState();
}

class _AnalyticsSettingsTileState extends State<AnalyticsSettingsTile> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _change(bool enabled) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await (widget.onCollectionChanged ??
          AppAnalyticsService.instance.setCollectionEnabled)(enabled);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable:
                widget.collectionPreference ??
                AppAnalyticsService.instance.collectionPreference,
            builder: (context, enabled, child) => SwitchListTile.adaptive(
              key: const ValueKey('analytics_collection_toggle'),
              secondary: Icon(
                Icons.insights_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text('analytics_usage_title'.tr),
              value: enabled,
              onChanged: _busy ? null : _change,
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
            child: Text('analytics_usage_summary'.tr),
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'analytics_usage_error'.tr,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
