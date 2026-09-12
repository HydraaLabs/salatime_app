import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryListController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    getBoolLocally();
  }

// local variable
  RxBool isCategoryChange = true.obs;
  // Method to save boolean value locally
  Future<void> saveBoolLocally(bool value) async {
    isCategoryChange.value = value;
    update();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isCategoryChangeKey', value);
  }

  // Method to retrieve boolean value locally
  void getBoolLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool newValue = prefs.getBool('isCategoryChangeKey') ?? true;
    isCategoryChange.value = newValue;
    update();
  }
}
