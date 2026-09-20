// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:salatime/controller/home_layout_controller.dart';
import 'package:salatime/controller/internet_check_controller.dart';
import 'package:salatime/theme/modern_light_theme.dart';
import 'package:salatime/util/dimensions.dart';
import 'package:salatime/util/images.dart';
import 'package:salatime/util/styles.dart';
import 'package:salatime/view/screens/category/category_screen.dart';
import 'package:salatime/view/screens/compass/compass_screen.dart';
import 'package:salatime/view/screens/dhikr/dhikr_screen.dart';
import 'package:salatime/view/screens/home/home_screen.dart';
import 'package:salatime/view/screens/nearby_mosque/nearby_mosque_screen.dart';

import 'np_internet_widgets.dart';
import 'play_store_review_host.dart';

class BottomNavbarScreen extends StatefulWidget {
  const BottomNavbarScreen({super.key, this.pageBuilder});

  /// Allows the shell to host alternate page content without changing navigation.
  final Widget Function(
    BuildContext context,
    int index,
    bool isActive,
    VoidCallback returnHome,
  )?
  pageBuilder;

  @override
  State<BottomNavbarScreen> createState() => _BottomNavbarScreenState();
}

class _BottomNavbarScreenState extends State<BottomNavbarScreen> {
  final Map<int, Widget> _pages = {};
  final GlobalKey _pagesKey = GlobalKey();
  static const int _pageCount = 5;
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
    if ((index == 3 || index == 4) && !internetController.hasInternet.value) {
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

  void _returnHome() {
    if (_selectedPageIndex == 0) return;
    setState(() => _selectedPageIndex = 0);
  }

  Widget _page(BuildContext context, int index) {
    final active = index == _selectedPageIndex;
    if (widget.pageBuilder != null) {
      return widget.pageBuilder!(context, index, active, _returnHome);
    }
    // Only the compass needs a new activation flag. Retaining the other widget
    // instances avoids restarting their work when returning to the home page.
    if (index == 1) {
      return CompassScreen(
        appBackButton: true,
        isActive: active,
        onBackPressed: _returnHome,
      );
    }
    return _pages.putIfAbsent(
      index,
      () => switch (index) {
        0 => const HomeScreen(),
        2 => DhikrScreen(appBackButton: true, onBackPressed: _returnHome),
        3 => NearbyMosque(appBackButton: true, onBackPressed: _returnHome),
        4 => CategoryScreen(appBackButton: true, onBackPressed: _returnHome),
        _ => throw RangeError.index(index, List.filled(_pageCount, null)),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return PlayStoreReviewHost(
      isHome: _selectedPageIndex == 0,
      child: PopScope<Object?>(
        canPop: _selectedPageIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _returnHome();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 600 && constraints.maxHeight >= 480;
            final pages = IndexedStack(
              key: _pagesKey,
              index: _selectedPageIndex,
              children: [
                for (int i = 0; i < _pageCount; i++)
                  _visitedPages.contains(i)
                      ? _page(context, i)
                      : const SizedBox.shrink(),
              ],
            );
            return Scaffold(
              body: wide
                  ? Row(
                      children: [
                        SafeArea(
                          child: NavigationRail(
                            selectedIndex: _selectedPageIndex,
                            onDestinationSelected: _selectPage,
                            labelType: NavigationRailLabelType.all,
                            destinations: [
                              NavigationRailDestination(
                                icon: const Icon(Icons.home_outlined),
                                label: Text('nav_today'.tr),
                              ),
                              NavigationRailDestination(
                                icon: SvgPicture.asset(
                                  Images.Icon_Qibla,
                                  width: 26,
                                  height: 26,
                                  colorFilter: ColorFilter.mode(
                                    Theme.of(context).colorScheme.onSurface,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                label: Text('nav_qibla'.tr),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.auto_awesome_outlined),
                                label: Text('nav_dhikr'.tr),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.location_on_outlined),
                                label: Text('nav_mosques'.tr),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.menu),
                                label: Text('nav_more'.tr),
                              ),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: pages),
                      ],
                    )
                  : pages,
              bottomNavigationBar: wide
                  ? null
                  : Obx(() {
                      final isModern =
                          Get.find<HomeLayoutController>()
                              .currentLayout
                              .value ==
                          HomeLayoutController.modern;
                      return isModern
                          ? _buildModernNavBar(context)
                          : _buildClassicNavBar(context, isIOS);
                    }),
            );
          },
        ),
      ),
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
                index: 1,
                icon: Images.Icon_Qibla,
                label: 'nav_qibla'.tr,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                index: 2,
                icon: Images.Icon_Dikir,
                label: 'nav_dhikr'.tr,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                index: 3,
                icon: Images.Icon_near_mosque,
                label: 'nav_mosques'.tr,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                index: 4,
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
              index: 1,
              icon: Images.Icon_Qibla,
              label: 'nav_qibla'.tr,
            ),
          ),
          Expanded(
            child: _buildModernNavItem(
              index: 2,
              icon: Images.ModernIcon_Dhikr,
              label: 'nav_dhikr'.tr,
            ),
          ),
          Expanded(
            child: _buildModernNavItem(
              index: 3,
              icon: Images.Icon_near_mosque,
              label: 'nav_mosques'.tr,
            ),
          ),
          Expanded(
            child: _buildModernNavItem(
              index: 4,
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
    return Semantics(
      key: ValueKey('bottom-nav-item-$index'),
      button: true,
      selected: _selectedPageIndex == index,
      child: GestureDetector(
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
    return Semantics(
      key: ValueKey('bottom-nav-item-$index'),
      button: true,
      selected: _selectedPageIndex == index,
      child: GestureDetector(
        onTap: () => _selectPage(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.black.withOpacity(0.12)
                : Colors.transparent,
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
      ),
    );
  }
}
