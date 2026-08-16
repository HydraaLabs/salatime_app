// ignore_for_file: deprecated_member_use

import 'package:zabi/controller/dua_controller.dart';
import 'package:zabi/controller/quran_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:zabi/data/model/response/local_dua_model.dart';
import 'package:zabi/util/images.dart';
import 'package:zabi/util/styles.dart';
import 'package:zabi/view/base/custom_app_bar.dart';
import '../../../../util/dimensions.dart';

class LocalDuasViewScreen extends StatelessWidget {
  final bool appBackButton;
  final LocalDuaModel dua;
  const LocalDuasViewScreen(
      {super.key, required this.appBackButton, required this.dua});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DuaController>(
      builder: (duaDetailsController) {
        return Scaffold(
          // Appbar start ===>
          appBar: CustomAppBar(
            title: "",
            isBackButtonExist: appBackButton == true ? true : false,
          ),

          body: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.PADDING_SIZE_DEFAULT,
              vertical: Dimensions.FONT_SIZE_SMALL,
            ),
            child: ListView(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // bismillah image ===>
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: SvgPicture.asset(
                        Images.Bismillah,
                        height: 50,
                        fit: BoxFit.fitHeight,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: Dimensions.PADDING_SIZE_SMALL),
                    const Divider(),

                    // arabic string ===>
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        dua.arabicDescription == ""
                            ? "--"
                            : dua.arabicDescription,
                        textAlign: TextAlign.right,
                        style:Get.find<SettingsController>()
                            .selectedArabicFont
                            .copyWith(
                          fontSize: Get.find<SettingsController>()
                              .arabicFontSize
                              .value,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimensions.PADDING_SIZE_LARGE),

                    // english string ===>
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        dua.englishDescription,
                        textAlign: TextAlign.justify,
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.FONT_SIZE_DEFAULT,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
