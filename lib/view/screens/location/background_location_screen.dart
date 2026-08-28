import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabi/helper/route_helper.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/styles.dart';

class BackgroundLocationScreen extends StatelessWidget {
  const BackgroundLocationScreen({super.key});

  static bool get _isPermissionHandlerSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Whether the one-time background location prompt should be shown.
  static Future<bool> shouldShow() async {
    if (!_isPermissionHandlerSupported) return false;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool shown = prefs.getBool('bg_location_prompt_shown') ?? false;
    if (shown) return false;
    PermissionStatus status = await Permission.locationAlways.status;
    return !status.isGranted;
  }

  Future<void> _continueToHome() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bg_location_prompt_shown', true);
    Get.offAllNamed(RouteHelper.bottomNavbar);
  }

  Future<void> _onActivate() async {
    // Foreground location must be granted before asking for "always".
    PermissionStatus foreground = await Permission.location.status;
    if (!foreground.isGranted) {
      foreground = await Permission.location.request();
    }

    PermissionStatus always = PermissionStatus.denied;
    if (foreground.isGranted) {
      always = await Permission.locationAlways.request();
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (always.isGranted) {
      await prefs.setBool('auto_location_update', true);
      await _continueToHome();
    } else if (always.isPermanentlyDenied || always.isDenied) {
      // Android 11+ cannot prompt for background location directly:
      // the user must pick "Allow all the time" in system settings.
      _showSettingsDialog();
    } else {
      await _continueToHome();
    }
  }

  void _showSettingsDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Get.theme.cardColor,
        title: Text(
          'background_location_dialog_title'.tr,
          style: robotoMedium.copyWith(
            fontSize: Dimensions.FONT_SIZE_LARGE,
            color: Get.theme.primaryColor,
          ),
        ),
        content: Text(
          'background_location_dialog_message'.tr,
          style: robotoRegular.copyWith(
            fontSize: Dimensions.FONT_SIZE_DEFAULT,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              _continueToHome();
            },
            child: Text('no_thanks'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Get.theme.primaryColor,
            ),
            onPressed: () async {
              Get.back();
              await openAppSettings();
              await _continueToHome();
            },
            child: Text('open_settings'.tr),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.PADDING_SIZE_LARGE),
          child: Column(
            children: [
              const Spacer(),

              // location icon
              Container(
                height: 110,
                width: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                ),
                child: Icon(
                  Icons.location_on,
                  size: 60,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: Dimensions.PADDING_SIZE_LARGE),

              // title
              Text(
                'background_location_title'.tr,
                textAlign: TextAlign.center,
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.FONT_SIZE_OVER_LARGE,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: Dimensions.PADDING_SIZE_DEFAULT),

              // description
              Text(
                'background_location_description'.tr,
                textAlign: TextAlign.center,
                style: robotoRegular.copyWith(
                  fontSize: Dimensions.FONT_SIZE_DEFAULT,
                ),
              ),
              const Spacer(),

              // activate button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(
                      vertical: Dimensions.PADDING_SIZE_DEFAULT,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        Dimensions.RADIUS_SMALL,
                      ),
                    ),
                  ),
                  onPressed: _onActivate,
                  child: Text(
                    'activate'.tr,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.FONT_SIZE_LARGE,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Dimensions.PADDING_SIZE_SMALL),

              // no thanks button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _continueToHome,
                  child: Text(
                    'no_thanks'.tr,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.FONT_SIZE_LARGE,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
