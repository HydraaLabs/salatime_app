import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Apple-branded button for sign-in and account linking.
///
/// Follows Apple's Sign in with Apple guidelines: the Apple logo next to the
/// title, the black style on light backgrounds and the white style on dark
/// ones, and the system font on Apple platforms. The pill shape and height
/// match [GoogleSignInButton] so both providers sit together.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  static const logoAsset = 'assets/icon/apple_logo.svg';
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // White style on dark backgrounds, black style on light backgrounds.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null;
    final fill = dark ? white : black;
    final text = dark ? black : white;
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
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
          disabledForegroundColor: text.withValues(alpha: 0.6),
          overlayColor: text,
          side: BorderSide(color: fill.withValues(alpha: enabled ? 1 : 0.38)),
          shape: const StadiumBorder(),
          minimumSize: const Size(140, 48),
          padding: const EdgeInsetsDirectional.only(start: 12, end: 16),
          textStyle: TextStyle(
            // Apple asks for the system font; other platforms keep Roboto.
            fontFamily: apple ? '.SF Pro Text' : 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 16,
            height: 20 / 16,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              logoAsset,
              key: const ValueKey('apple_logo'),
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                enabled ? text : text.withValues(alpha: 0.6),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
