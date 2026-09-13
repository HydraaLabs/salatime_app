import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum PlayStoreReviewChoice { rate, later, never }

/// Presents the choice only; the caller handles opening Google Play or deferring.
Future<PlayStoreReviewChoice?> showPlayStoreReviewPrompt(BuildContext context) {
  return showDialog<PlayStoreReviewChoice>(
    context: context,
    builder: (_) => const PlayStoreReviewPrompt(),
  );
}

class PlayStoreReviewPrompt extends StatelessWidget {
  const PlayStoreReviewPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text('play_store_review_title'.tr),
      content: Text('play_store_review_message'.tr),
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actionsOverflowButtonSpacing: 8,
      actions: [
        for (final choice in PlayStoreReviewChoice.values)
          TextButton(
            key: ValueKey('play-store-review-${choice.name}'),
            onPressed: () => Navigator.of(context).pop(choice),
            child: Text('play_store_review_${choice.name}'.tr),
          ),
      ],
    );
  }
}
