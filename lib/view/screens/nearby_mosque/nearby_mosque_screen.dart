// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:salatime/controller/nearby_mosque_controller.dart';
import 'package:salatime/helper/mosque_directions.dart';
import 'package:salatime/helper/translator_helper.dart';
import 'package:salatime/shimmer/all_shimmer_loder.dart';
import 'package:salatime/view/base/custom_app_bar.dart';
import 'package:salatime/view/base/custom_snackbar.dart';
import 'package:salatime/view/base/location_error_widget.dart';
import '../../../util/dimensions.dart';
import '../../../util/images.dart';
import '../../../util/styles.dart';

class NearbyMosque extends StatefulWidget {
  final bool appBackButton;
  final VoidCallback? onBackPressed;
  const NearbyMosque({
    super.key,
    required this.appBackButton,
    this.onBackPressed,
  });

  @override
  State<NearbyMosque> createState() => _NearbyMosqueState();
}

class _NearbyMosqueState extends State<NearbyMosque> {
  final MapController _mapController = MapController();

  // Parse "lat,lng" stored by NearbyMosqueController.getLocation().
  LatLng? _userLatLng(String userLocation) {
    final parts = userLocation.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  List<Marker> _buildMarkers(BuildContext context, List places) {
    final markers = <Marker>[];
    for (var i = 0; i < places.length; i++) {
      final location = places[i]["geometry"]?["location"];
      if (location == null) continue;
      markers.add(
        Marker(
          point: LatLng(location["lat"], location["lng"]),
          width: 40,
          height: 40,
          child: Icon(
            Icons.mosque,
            color: Theme.of(context).primaryColor,
            size: 32,
          ),
        ),
      );
    }
    return markers;
  }

  void _centerOnPlace(Map place) {
    final location = place["geometry"]?["location"];
    if (location == null) return;
    _mapController.move(LatLng(location["lat"], location["lng"]), 15);
  }

  Future<void> _openDirections(double latitude, double longitude) async {
    final opened = await openMosqueDirections(
      latitude: latitude,
      longitude: longitude,
    );
    if (!mounted || opened) return;
    showCustomSnackBar('unable_to_open_directions'.tr, isError: true);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Get.put(NearbyMosqueController()).getLocation();
    return Scaffold(
      // Appbar start ===>
      appBar: CustomAppBar(
        title: 'nearby_mosque'.tr,
        isBackButtonExist: widget.appBackButton,
        onBackPressed: widget.onBackPressed,
      ),

      // body start ==>
      body: SingleChildScrollView(
        child: GetBuilder<NearbyMosqueController>(
          init: NearbyMosqueController(),
          builder: (nearbyMosqueController) {
            return Obx(
              () =>
                  nearbyMosqueController.isLoading.value ||
                      nearbyMosqueController.userLocation.value == ""
                  ? SizedBox(
                      height: Get.height / 1.2,
                      child: Center(
                        child:
                            nearbyMosqueController.isLocationDenied.value ==
                                true
                            ? LocationErrorWidget(
                                error:
                                    "location_service_permission_denied_for_getting_this_service_please_enable_location"
                                        .tr,
                              )
                            : const NearbyMosqueShimmerScreen(),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.PADDING_SIZE_SMALL,
                        vertical: Dimensions.PADDING_SIZE_SMALL,
                      ),
                      child: Column(
                        children: [
                          // map ===>
                          Builder(
                            builder: (context) {
                              final userLatLng = _userLatLng(
                                nearbyMosqueController.userLocation.value,
                              );
                              if (userLatLng == null) {
                                return const SizedBox.shrink();
                              }
                              return SizedBox(
                                height: Get.height * 0.42,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.RADIUS_SMALL,
                                  ),
                                  child: FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      initialCenter: userLatLng,
                                      initialZoom: 14,
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName:
                                            'com.example.zabi',
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          ..._buildMarkers(
                                            context,
                                            nearbyMosqueController.places,
                                          ),
                                          // user position marker
                                          Marker(
                                            point: userLatLng,
                                            width: 40,
                                            height: 40,
                                            child: const Icon(
                                              Icons.my_location,
                                              color: Colors.blue,
                                              size: 28,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          Text(
                            "if_you_cant_find_the_mosque_according_to_the_predefined_area_then_search_for_the_mosque_by_selecting_area_by_kilometers_from_below"
                                .tr,
                            textAlign: TextAlign.justify,
                            style: robotoMedium.copyWith(
                              fontSize: Dimensions.FONT_SIZE_DEFAULT,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // dropdown ==>
                          Obx(
                            () => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Dimensions.PADDING_SIZE_SMALL,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  Dimensions.RADIUS_SMALL,
                                ),
                                border: Border.all(
                                  color: Theme.of(context).primaryColor,
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: Dimensions.PADDING_SIZE_EXTRA_SMALL,
                                ),
                                child: DropdownButton<String>(
                                  menuMaxHeight: 500,
                                  value: nearbyMosqueController.km.value,
                                  items:
                                      <String>[
                                        '1  KM',
                                        '2  KM',
                                        '3  KM',
                                        '4  KM',
                                        '5  KM',
                                      ].map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(translateText(value)),
                                        );
                                      }).toList(),
                                  onChanged: (String? newValue) {
                                    nearbyMosqueController.loadKmDropdownValue(
                                      newValue!,
                                    );
                                    nearbyMosqueController.searchNearbyPlaces();
                                  },
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // list view ===>
                          ListView.builder(
                            primary: false,
                            shrinkWrap: true,
                            itemCount: nearbyMosqueController.places.length,
                            itemBuilder: (BuildContext context, int index) {
                              var place = nearbyMosqueController.places[index];
                              double lat = place["geometry"]["location"]["lat"];
                              double lng = place["geometry"]["location"]["lng"];
                              return GestureDetector(
                                onTap: () => _centerOnPlace(place),
                                child: Card(
                                  clipBehavior: Clip.antiAlias,
                                  color: Theme.of(context).cardColor,
                                  shadowColor: Get.isDarkMode
                                      ? Colors.grey[800]!
                                      : Colors.grey[200]!,
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsetsDirectional.symmetric(
                                          horizontal:
                                              Dimensions.PADDING_SIZE_DEFAULT,
                                        ),
                                    title: Text(
                                      place['name'] ?? "--",
                                      style: robotoMedium.copyWith(
                                        fontSize: Dimensions.FONT_SIZE_LARGE,
                                      ),
                                    ),
                                    subtitle: Text(
                                      place['vicinity'] ?? "--",
                                      style: robotoMedium.copyWith(
                                        fontSize: Dimensions.FONT_SIZE_SMALL,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'get_directions'.tr,
                                      onPressed: () =>
                                          _openDirections(lat, lng),
                                      icon: SvgPicture.asset(
                                        Images.Icon_Right_Arrow,
                                        color: Theme.of(context).primaryColor,
                                        height: 30,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}
