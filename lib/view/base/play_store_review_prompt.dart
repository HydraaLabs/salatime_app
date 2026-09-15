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

class PlayStoreReviewPrompt extends StatefulWidget {
  const PlayStoreReviewPrompt({super.key});

  @override
  State<PlayStoreReviewPrompt> createState() => _PlayStoreReviewPromptState();
}

class _PlayStoreReviewPromptState extends State<PlayStoreReviewPrompt> {
  bool _likesApp = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        (_likesApp ? 'play_store_review_title' : 'play_store_review_question')
            .tr,
      ),
      content: _likesApp ? Text('play_store_review_message'.tr) : null,
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actionsOverflowButtonSpacing: 8,
      actions: [
        if (!_likesApp) ...[
          TextButton(
            key: const ValueKey('play-store-review-yes'),
            onPressed: () => setState(() => _likesApp = true),
            child: Text('play_store_review_yes'.tr),
          ),
          TextButton(
            key: const ValueKey('play-store-review-no'),
            onPressed: () =>
                Navigator.of(context).pop(PlayStoreReviewChoice.never),
            child: Text('play_store_review_no'.tr),
          ),
          TextButton(
            key: const ValueKey('play-store-review-later'),
            onPressed: () =>
                Navigator.of(context).pop(PlayStoreReviewChoice.later),
            child: Text('play_store_review_later'.tr),
          ),
        ] else
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
