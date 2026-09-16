import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Device-local permission: it is never included in account cloud preferences.
/// Increment the version if the recipient or the disclosed data use changes.
class AiDataConsent {
  static final instance = AiDataConsent();
  static const storageKey = 'ai_data_sharing_consent_version';
  static const version = 1;

  Future<bool>? _pending;

  Future<bool> request(BuildContext? context) =>
      _pending ??= _request(context).whenComplete(() => _pending = null);

  Future<bool> _request(BuildContext? context) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getInt(storageKey) == version) return true;
      if (context == null || !context.mounted) return false;
      final granted = await _prompt(context);
      if (granted != true || !context.mounted) return false;
      return await preferences.setInt(storageKey, version);
    } catch (_) {
      // A storage/dialog failure must never silently authorize a transfer.
      return false;
    }
  }

  Future<void> manage(BuildContext context) async {
    final preferences = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    final granted = await _prompt(
      context,
      canRevoke: preferences.getInt(storageKey) == version,
    );
    if (granted == true) {
      await preferences.setInt(storageKey, version);
    } else if (granted == false) {
      await preferences.remove(storageKey);
    }
  }

  Future<bool?> _prompt(BuildContext context, {bool canRevoke = false}) =>
      showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text('ai_data_consent_title'.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ai_data_consent_body'.tr),
                const SizedBox(height: 12),
                Text('ai_data_consent_remember'.tr),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse('https://1min.ai/privacy'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text('ai_data_consent_privacy'.tr),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('ai_data_consent_cancel'.tr),
            ),
            if (canRevoke)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('ai_data_consent_revoke'.tr),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('ai_data_consent_allow'.tr),
            ),
          ],
        ),
      );
}
