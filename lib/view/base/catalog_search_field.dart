import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shared, keyboard-friendly search for the Quran and reciter catalogues.
class CatalogSearchField extends StatelessWidget {
  const CatalogSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
    this.fieldKey,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          key: fieldKey,
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'catalog_search_clear'.tr,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
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
