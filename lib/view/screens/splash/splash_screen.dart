import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/splash_controller.dart';
import 'package:salatime/util/app_constants.dart';
import 'package:salatime/util/dimensions.dart';
import 'package:salatime/util/images.dart';
import 'package:salatime/util/styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Get.find<SplashController>().navigator();
    // _checkNotificationPermission();
  }

  // Future<void> _checkNotificationPermission() async {
  //   if (Platform.isAndroid || Platform.isIOS) {
  //     var status = await Permission.notification.status;
  //     if (!status.isGranted) {
  //       await Permission.notification.request();
  //     }
  //   }

  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // logo image
            Image.asset(Images.Dark_APP_LOGO, height: 100, fit: BoxFit.contain),
            const SizedBox(height: Dimensions.PADDING_SIZE_EXTRA_SMALL),

            // app name
            Text(
              AppConstants.APP_NAME,
              style: robotoMedium.copyWith(
                fontSize: Dimensions.FONT_SIZE_OVER_LARGE,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
