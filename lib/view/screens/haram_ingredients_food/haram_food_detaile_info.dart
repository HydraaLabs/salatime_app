import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/view/base/mosque_settings_description.dart';
import 'package:salatime/view/base/custom_app_bar.dart';

class HaramFoodDetaileInfoScreen extends StatelessWidget {
  final bool appBackButton;
  const HaramFoodDetaileInfoScreen({super.key, required this.appBackButton});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Appbar start ===>
      appBar: CustomAppBar(
        title: 'haram_ingredients_food_details'.tr,
        isBackButtonExist: appBackButton == true ? true : false,
      ),

      // body start ==>
      body: MosqueSettingsDescription(
        description: (data) => data.haramDescription,
      ),
    );
  }
}
