import 'package:get/get.dart';
import 'package:salatime/data/repository/splash_repo.dart';
import 'package:salatime/helper/route_helper.dart';
import 'package:salatime/view/screens/location/background_location_screen.dart';

class SplashController extends GetxController implements GetxService {
  final SplashRepo splashRepo;
  SplashController({required this.splashRepo});
  // navigate splash to navbar screen function
  Future<void> navigator() async {
    Future.delayed(const Duration(seconds: 3), () async {
      // Show the one-time background location prompt if needed,
      // otherwise go straight to the navbar screen.
      if (await BackgroundLocationScreen.shouldShow()) {
        Get.offAll(() => const BackgroundLocationScreen());
      } else {
        Get.offAllNamed(RouteHelper.bottomNavbar);
      }
    });
  }
}
