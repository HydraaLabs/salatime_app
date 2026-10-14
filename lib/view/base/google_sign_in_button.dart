import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Google-branded button for sign-in and account linking.
///
/// Follows Google's Sign in with Google branding: the four-colour "G" logo on
/// the leading side, Roboto Medium, and the light or dark palette matching the
/// current theme. Only the label is app-specific.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  static const logoAsset = 'assets/icon/google_g.svg';

  // Colours from Google's branding guidelines (light and dark themes).
  static const lightFill = Color(0xFFFFFFFF);
  static const lightStroke = Color(0xFF747775);
  static const lightText = Color(0xFF1F1F1F);
  static const darkFill = Color(0xFF131314);
  static const darkStroke = Color(0xFF8E918F);
  static const darkText = Color(0xFFE3E3E3);

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null;
    final fill = dark ? darkFill : lightFill;
    final stroke = dark ? darkStroke : lightStroke;
    final text = dark ? darkText : lightText;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: enabled ? fill : fill.withValues(alpha: 0.38),
          foregroundColor: text,
          disabledForegroundColor: text.withValues(alpha: 0.38),
          overlayColor: text,
          side: BorderSide(
            color: enabled ? stroke : stroke.withValues(alpha: 0.12),
          ),
          shape: const StadiumBorder(),
          minimumSize: const Size(140, 48),
          padding: const EdgeInsetsDirectional.only(start: 12, end: 16),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: 0.25,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: enabled ? 1 : 0.38,
              child: SvgPicture.asset(
                logoAsset,
                key: const ValueKey('google_logo'),
                width: 20,
                height: 20,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
