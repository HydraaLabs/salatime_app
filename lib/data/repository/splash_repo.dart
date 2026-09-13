import 'package:salatime/data/api/api_client.dart';
import 'package:salatime/util/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashRepo {
  ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  SplashRepo({required this.sharedPreferences, required this.apiClient});

  Future<bool> initSharedData() {
    if (!sharedPreferences.containsKey(AppConstants.THEME)) {
      sharedPreferences.setBool(AppConstants.THEME, false);
    }
    if (!sharedPreferences.containsKey(AppConstants.THEME_MODE_KEY)) {
      return sharedPreferences.setString(
        AppConstants.THEME_MODE_KEY,
        'daylight',
      );
    }
    return Future.value(true);
  }

  Future<bool> removeSharedData() {
    return sharedPreferences.clear();
  }
}
