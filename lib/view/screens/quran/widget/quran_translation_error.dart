import 'package:flutter/material.dart';
import 'package:get/get.dart';

class QuranTranslationError extends StatelessWidget {
  const QuranTranslationError({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('quran_translation_unavailable'.tr, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text('quran_translation_retry'.tr),
          ),
        ],
      ),
    ),
  );
}
