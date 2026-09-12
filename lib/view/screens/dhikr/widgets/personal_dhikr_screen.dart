import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/helper/route_helper.dart';
import 'package:zabi/view/base/custom_app_bar.dart';
import 'package:zabi/view/screens/dhikr/local%20stroge%20dhikr/user_added_dikir_list_widget.dart';

/// Keeps the existing personal list and stored counters available from Athkar.
class PersonalDhikrScreen extends StatelessWidget {
  const PersonalDhikrScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: CustomAppBar(
      title: 'athkar_personal_title'.tr,
      isBackButtonExist: true,
      actions: [
        IconButton(
          key: const ValueKey('athkar-add-personal'),
          tooltip: 'add_dikir'.tr,
          onPressed: () => Get.toNamed(RouteHelper.addDhikr),
          icon: const Icon(Icons.playlist_add, color: Colors.white),
        ),
      ],
    ),
    body: SafeArea(top: false, child: UserAddedDikirWidget()),
  );
}
