// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/category_controller.dart';
import 'package:zabi/helper/route_helper.dart';
import 'package:zabi/util/images.dart';
import 'package:zabi/view/base/custom_app_bar.dart';
import 'package:zabi/view/screens/category/widget/grid_view_item_widget.dart';
import 'package:zabi/view/screens/category/widget/list_view_item_widget.dart';

import '../../../util/dimensions.dart';

class CategoryScreen extends StatelessWidget {
  final bool appBackButton;
  CategoryScreen({super.key, required this.appBackButton});
  final CategoryListController categoryListController = Get.put(
    CategoryListController(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Appbar start ===>
      appBar: CustomAppBar(
        title: 'all_category'.tr,
        isBackButtonExist: appBackButton == true ? true : false,
        actions: [
          GetBuilder<CategoryListController>(
            builder: (categoryListController) {
              return Obx(
                () => IconButton(
                  onPressed: () {
                    categoryListController.saveBoolLocally(
                      !categoryListController.isCategoryChange.value,
                    );
                  },
                  icon: categoryListController.isCategoryChange.value == true
                      ? SvgPicture.asset(
                          Images.Icon_Line,
                          color: Get.isDarkMode
                              ? Theme.of(context).textTheme.bodyMedium!.color
                              : Theme.of(context).cardColor,
                          height: 25,
                        )
                      : SvgPicture.asset(
                          Images.Icon_Grid,
                          color: Get.isDarkMode
                              ? Theme.of(context).textTheme.bodyMedium!.color
                              : Theme.of(context).cardColor,
                          height: 25,
                        ),
                ),
              );
            },
          ),
        ],
      ),

      // body start ===>
      body: SingleChildScrollView(
        child: GetBuilder<CategoryListController>(
          builder: (categoryListController) {
            return Obx(
              () => Column(
                children: [
                  categoryListController.isCategoryChange.value == false
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.PADDING_SIZE_EXTRA_SMALL,
                          ),
                          child: Column(
                            children: [
                              // audio ===>
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.recters);
                                },
                                itemName: "audio_quran".tr,
                                itemImage: Images.Iocn_Audio,
                                iconHeight: 40,
                              ),

                              // quibla item ===>
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.compass);
                                },
                                itemName: "compass".tr,
                                itemImage: Images.Icon_Qibla,
                              ),

                              // near by mosque item ===>
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.nearByMosque);
                                },
                                itemName: "nearby".tr,
                                itemImage: Images.Icon_near_mosque,
                              ),

                              // quran  item ===>
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.suraList);
                                },
                                itemName: "quran".tr,
                                itemImage: Images.Icon_Quran,
                              ),

                              // dikir  item ===>
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.dhikr);
                                },
                                itemName: "dikir".tr,
                                itemImage: Images.Icon_Dikir,
                              ),

                              // dua item ===>
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.dua);
                                },
                                itemName: "dua".tr,
                                itemImage: Images.Icon_Dua,
                              ),

                              // hadith item ===>
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.hadithBookName);
                                },
                                itemName: "hadith".tr,
                                itemImage: Images.Icon_Hadith,
                              ),

                              // allah name item ===>
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.sifatName);
                                },
                                itemName: "allah_name".tr,
                                itemImage: Images.Icon_Allah_99_name,
                              ),

                              // zakat calculator item ===>
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.zakatCalculator);
                                },
                                itemName: "zakat_calculator".tr,
                                itemImage: Images.Icon_Zakat,
                              ),

                              // haram  item ===>
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.haramIngredientsFood);
                                },
                                itemName: "haram_codes".tr,
                                itemImage: Images.Icon_Haram,
                              ),

                              // Wallpaper Section
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.wallpaperScreens);
                                },
                                itemName: "wallpapers_key".tr,
                                itemImage: Images.wallpaper,
                                iconHeight: 45,
                              ),
                              // Alphabet Section
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.alphabetScreens);
                                },
                                itemName: "alphabet_key".tr,
                                itemImage: Images.Icon_Alif,
                                iconHeight: 45,
                              ),
                              // AI Name Generator Section
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.aiNameGenerator);
                                },
                                itemName: "ai_name_key".tr,
                                itemImage: Images.nameGenerator,
                                iconHeight: 45,
                              ),
                              // more  item ===>
                              ListViewItemWidget(
                                onPressed: () {
                                  Get.toNamed(RouteHelper.settings);
                                },
                                itemName: "settings".tr,
                                itemImage: Images.Icon_app_setting,
                                iconHeight: 40,
                              ),
                            ],
                          ),
                        )
                      : GridView.count(
                          primary: false,
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.PADDING_SIZE_DEFAULT,
                            vertical: Dimensions.PADDING_SIZE_DEFAULT,
                          ),
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 10,
                          crossAxisCount: 3,
                          children: [
                            // audio  ===>
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.recters);
                              },
                              itemName: "audio_quran".tr,
                              itemImage: Images.Iocn_Audio,
                              iconHeight: 40,
                            ),
                            // quibla item ===>
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.compass);
                              },
                              itemName: "compass".tr,
                              itemImage: Images.Icon_Qibla,
                            ),

                            // near by mosque item ===>
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.nearByMosque);
                              },
                              itemName: "nearby".tr,
                              itemImage: Images.Icon_near_mosque,
                            ),

                            // quran  item ===>
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.suraList);
                              },
                              itemName: "quran".tr,
                              itemImage: Images.Icon_Quran,
                            ),

                            // dikir item ===>
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.dhikr);
                              },
                              itemName: "dikir".tr,
                              itemImage: Images.Icon_Dikir,
                            ),

                            // dua item ===>
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.dua);
                              },
                              itemName: "dua".tr,
                              itemImage: Images.Icon_Dua,
                            ),

                            // hadith item ===>
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.hadithBookName);
                              },
                              itemName: "hadith".tr,
                              itemImage: Images.Icon_Hadith,
                            ),

                            // allah name  item ===>
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.sifatName);
                              },
                              itemName: "allah_name".tr,
                              itemImage: Images.Icon_Allah_99_name,
                            ),

                            // zakat calculator item ===>
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.zakatCalculator);
                              },
                              itemName: "zakat_calculator".tr,
                              itemImage: Images.Icon_Zakat,
                            ),

                            // haram  item ===>
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.haramIngredientsFood);
                              },
                              itemName: "haram_codes".tr,
                              itemImage: Images.Icon_Haram,
                            ),

                            // Wallpaper Section
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.wallpaperScreens);
                              },
                              itemName: "wallpapers_key".tr,
                              itemImage: Images.wallpaper,
                            ),
                            // Alphabet Section
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.alphabetScreens);
                              },
                              itemName: "alphabet_key".tr,
                              itemImage: Images.Icon_Alif,
                            ),

                            // AI Name Section
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.aiNameGenerator);
                              },
                              itemName: "ai_name_key".tr,
                              itemImage: Images.nameGenerator,
                            ),

                            // Settings  ===>
                            GridViewItemWidget(
                              onPressed: () {
                                Get.toNamed(RouteHelper.settings);
                              },
                              itemName: "settings".tr,
                              itemImage: Images.Icon_app_setting,
                              iconHeight: 40,
                            ),
                          ],
                        ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
