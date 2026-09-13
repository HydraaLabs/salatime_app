import 'package:flutter/material.dart';
import 'package:salatime/util/styles.dart';

class QuranNavigationButton extends StatelessWidget {
  const QuranNavigationButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isEnabled,
    required this.onPressed,
    this.isLeftIcon = true,
  });

  final String label;
  final IconData icon;
  final bool isEnabled;
  final VoidCallback onPressed;
  final bool isLeftIcon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.95),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          children: [
            if (isLeftIcon) Icon(icon, size: 20),
            if (isLeftIcon) const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: robotoMedium.copyWith(fontSize: 15),
              ),
            ),
            if (!isLeftIcon) const SizedBox(width: 4),
            if (!isLeftIcon) Icon(icon, size: 20),
          ],
        ),
      ),
    );
  }
}
