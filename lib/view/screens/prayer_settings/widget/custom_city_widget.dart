// ignore_for_file: deprecated_member_use, unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/package_prayer_time_controller.dart';
import 'package:salatime/helper/salat_waqt_service.dart';
import 'package:salatime/util/app_constants.dart';
import 'package:salatime/util/dimensions.dart';
import 'package:salatime/util/images.dart';
import 'package:salatime/util/styles.dart';
import 'package:salatime/view/base/loading_indicator.dart';

class CustomCityDialog extends StatelessWidget {
  const CustomCityDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final prayerTimeController = Get.find<PrayerTimeController>();
    prayerTimeController.loadPrayerTimeSettings();

    return Center(
      child: AlertDialog(
        backgroundColor: Get.isDarkMode ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.RADIUS_DEFAULT),
        ),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: Get.width / 1.3,
          height: Get.height * 0.75,
          child: Column(
            children: [
              // Search Box
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(Dimensions.RADIUS_SMALL),
                  ),
                  child: TextField(
                    controller: prayerTimeController.citySearchController,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'search'.tr,
                      hintStyle: robotoRegular.copyWith(fontSize: 14),
                    ),
                    onChanged: (value) =>
                        prayerTimeController.onCitySearchChanged(value),
                  ),
                ),
              ),

              // My Location Option
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(AppConstants.isPrayerTme, false);
                    await prefs.setString(
                      AppConstants.saveCityName,
                      prayerTimeController.currentAddress.toString(),
                    );
                    // Back to GPS mode: drop any saved manual city coords.
                    await prefs.remove(AppConstants.manualCityLat);
                    await prefs.remove(AppConstants.manualCityLng);

                    prayerTimeController.fetchPrayerTime(
                      isManualPrayerTme: false,
                      manualCity: prayerTimeController.currentAddress.value,
                    );
                    prayerTimeController.getLocation();
                    Get.back();
                    SalatWaqtService.initializeSalatWaqt();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          Images.Icon_Location,
                          height: 20,
                          color: Theme.of(context).hintColor,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'my_location'.tr,
                                style: robotoMedium.copyWith(
                                  fontSize: Dimensions.FONT_SIZE_LARGE,
                                  color: Get.isDarkMode
                                      ? Colors.white
                                      : Colors.grey.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(thickness: 1.2),

              // City List
              Expanded(
                child: Obx(() {
                  if (prayerTimeController.isCityListLoading.value) {
                    return const Center(child: LoadingIndicator());
                  }

                  // While typing, show online search results (Nominatim).
                  if (prayerTimeController.search.value.trim().isNotEmpty) {
                    final suggestions = prayerTimeController.citySuggestions;

                    if (suggestions.isEmpty) {
                      return Center(
                        child: Text(
                          'no_data_found'.tr,
                          style: robotoMedium.copyWith(
                              fontSize: Dimensions.FONT_SIZE_LARGE),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(thickness: 0.7),
                      itemBuilder: (context, index) {
                        final city = suggestions[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool(
                                  AppConstants.isPrayerTme, true);
                              await prefs.setString(
                                  AppConstants.saveCityName, city.displayName);
                              await prefs.setDouble(
                                  AppConstants.manualCityLat, city.lat);
                              await prefs.setDouble(
                                  AppConstants.manualCityLng, city.lng);

                              prayerTimeController.fetchPrayerTime(
                                isManualPrayerTme: true,
                                manualCity: city.displayName,
                              );
                              prayerTimeController.getLocation();
                              Get.back();
                              SalatWaqtService.initializeSalatWaqt();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    Images.Icon_Location,
                                    height: 20,
                                    color: Theme.of(context).hintColor,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      city.displayName,
                                      style: robotoMedium.copyWith(
                                        fontSize: Dimensions.FONT_SIZE_LARGE,
                                        color: Get.isDarkMode
                                            ? Colors.white
                                            : Colors.grey.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }

                  // No search text: show the backend city list (legacy manual
                  // mode, e.g. "Makkah").
                  final cityList =
                      prayerTimeController.cityModelData?.data ?? [];

                  if (cityList.isEmpty) {
                    return Center(
                      child: Text(
                        'no_data_found'.tr,
                        style: robotoMedium.copyWith(
                            fontSize: Dimensions.FONT_SIZE_LARGE),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: cityList.length,
                    separatorBuilder: (_, __) => const Divider(thickness: 0.7),
                    itemBuilder: (context, index) {
                      final cityName = cityList[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(AppConstants.isPrayerTme, true);
                            await prefs.setString(
                                AppConstants.saveCityName, cityName);
                            // Legacy manual mode: no coordinates for this city.
                            await prefs.remove(AppConstants.manualCityLat);
                            await prefs.remove(AppConstants.manualCityLng);

                            prayerTimeController.fetchPrayerTime(
                              isManualPrayerTme: true,
                              manualCity: cityName,
                            );
                            prayerTimeController.getLocation();
                            Get.back();
                            SalatWaqtService.initializeSalatWaqt();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  Images.Icon_Location,
                                  height: 20,
                                  color: Theme.of(context).hintColor,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    cityName,
                                    style: robotoMedium.copyWith(
                                      fontSize: Dimensions.FONT_SIZE_LARGE,
                                      color: Get.isDarkMode
                                          ? Colors.white
                                          : Colors.grey.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
