import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/service/analytics/app_analytics_service.dart';

/// Shared, keyboard-friendly search for the Quran and reciter catalogues.
class CatalogSearchField extends StatefulWidget {
  const CatalogSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
    this.fieldKey,
    this.analyticsAction,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final Key? fieldKey;

  /// Reported once per field instance, when the first query is typed. The
  /// query itself never leaves the device.
  final AppAnalyticsAction? analyticsAction;

  @override
  State<CatalogSearchField> createState() => _CatalogSearchFieldState();
}

class _CatalogSearchFieldState extends State<CatalogSearchField> {
  bool _reported = false;

  void _changed(String query) {
    final action = widget.analyticsAction;
    if (!_reported && action != null && query.trim().isNotEmpty) {
      _reported = true;
      unawaited(AppAnalyticsService.instance.appAction(action));
    }
    widget.onChanged(query);
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) => TextField(
          key: widget.fieldKey,
          controller: widget.controller,
          onChanged: _changed,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'catalog_search_clear'.tr,
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}
