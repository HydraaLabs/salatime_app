// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/home_layout_controller.dart';
import 'package:zabi/controller/internet_check_controller.dart';
import 'package:zabi/theme/modern_light_theme.dart';
import 'package:zabi/util/dimensions.dart';
import 'package:zabi/util/images.dart';
import 'package:zabi/util/styles.dart';
import 'package:zabi/view/screens/category/category_screen.dart';
import 'package:zabi/view/screens/compass/compass_screen.dart';
import 'package:zabi/view/screens/home/home_screen.dart';
import 'package:zabi/view/screens/nearby_mosque/nearby_mosque_screen.dart';

import 'np_internet_widgets.dart';

class BottomNavbarScreen extends StatefulWidget {
  const BottomNavbarScreen({super.key});

  @override
  State<BottomNavbarScreen> createState() => _BottomNavbarScreenState();
}

class _BottomNavbarScreenState extends State<BottomNavbarScreen> {
  late List<Widget> _pages;
  int _selectedPageIndex = 0;

  // Pages already visited are kept alive in the IndexedStack; unvisited
  // pages stay unmounted until first access.
  final Set<int> _visitedPages = {0};

  final internetController = Get.put(InternetController());

  // Reference width used as the design baseline (standard mobile width).
  // Adjust this if your designs target a different baseline (e.g. 360).
  static const double _baseWidth = 375;

  @override
  void initState() {
    internetController.checkConnection();
    super.initState();
  }

  void _selectPage(int index) {
    // Prevent access to online-only pages without internet
    if ((index == 2 || index == 3) && !internetController.hasInternet.value) {
      showNoInternetDialog();
      return;
    }
    setState(() {
      _selectedPageIndex = index;
      _visitedPages.add(index);
    });
  }

  /// Scales [baseSize] according to the current device width relative to
  /// [_baseWidth], clamped so text doesn't shrink or grow too aggressively
  /// on very small or very large screens.
  double _responsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth / _baseWidth;
    final clampedScale = scale.clamp(0.85, 1.25);
    return baseSize * clampedScale;
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    _pages = [
      const HomeScreen(),
      CompassScreen(appBackButton: false, isActive: _selectedPageIndex == 1),
      const NearbyMosque(appBackButton: false),
      CategoryScreen(appBackButton: false),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedPageIndex,
        children: [
          for (int i = 0; i < _pages.length; i++)
            _visitedPages.contains(i) ? _pages[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Obx(() {
        final isModern =
            Get.find<HomeLayoutController>().currentLayout.value ==
            HomeLayoutController.modern;
        return isModern
            ? _buildModernNavBar(context)
            : _buildClassicNavBar(context, isIOS);
      }),
    );
  }

  Widget _buildClassicNavBar(BuildContext context, bool isIOS) {
    final darkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: isIOS ? 76 : 70,
      decoration: BoxDecoration(
        color: darkMode
            ? Theme.of(context).cardColor
            : Theme.of(context).primaryColor,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: _buildNavItem(
                index: 0,
                icon: Images.Icon_Home,
                label: 'nav_today'.tr,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                index: 1,
                icon: Images.Icon_Qibla,
                label: 'nav_qibla'.tr,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                index: 2,
                icon: Images.Icon_near_mosque,
                label: 'nav_mosques'.tr,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                index: 3,
                icon: Images.Icon_Category,
                label: 'nav_more'.tr,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernNavBar(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF15261E)
            : AppColorModern.primaryGreenDark,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildModernNavItem(
              index: 0,
              icon: Images.ModernIcon_Home,
              label: 'nav_today'.tr,
            ),
          ),
          Expanded(
            child: _buildModernNavItem(
              index: 1,
              icon: Images.Icon_Qibla,
              label: 'nav_qibla'.tr,
            ),
          ),
          Expanded(
            child: _buildModernNavItem(
              index: 2,
              icon: Images.Icon_near_mosque,
              label: 'nav_mosques'.tr,
            ),
          ),
          Expanded(
            child: _buildModernNavItem(
              index: 3,
              icon: Images.ModernIcon_Menu,
              label: 'nav_more'.tr,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String icon,
    required String label,
  }) {
    return GestureDetector(
      onTap: () => _selectPage(index),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              icon,
              height: 30,
              color: _selectedPageIndex == index
                  ? Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).cardColor
                  : Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).primaryColor.withOpacity(0.6)
                  : Theme.of(context).cardColor.withOpacity(0.6),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: robotoMedium.copyWith(
                fontSize: _responsiveFontSize(
                  context,
                  Dimensions.FONT_SIZE_SMALL,
                ),
                height: 1.0,
                color: _selectedPageIndex == index
                    ? Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).cardColor
                    : Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).primaryColor.withOpacity(0.6)
                    : Theme.of(context).cardColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernNavItem({
    required int index,
    required String icon,
    required String label,
  }) {
    final isActive = _selectedPageIndex == index;
    final color = isActive ? const Color(0xFFF9A825) : Colors.white70;
    return GestureDetector(
      onTap: () => _selectPage(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? Colors.black.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(icon, height: 25, color: color),
            const SizedBox(height: 4),
            Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: robotoMedium.copyWith(
                  fontSize: _responsiveFontSize(
                    context,
                    Dimensions.FONT_SIZE_SMALL,
                  ),
                  height: 1.0,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
