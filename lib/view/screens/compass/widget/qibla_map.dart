import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:salatime/helper/qiblah_helper.dart';
import 'package:salatime/util/app_constants.dart';

class QiblaMap extends StatefulWidget {
  const QiblaMap({super.key});

  @override
  State<QiblaMap> createState() => _QiblaMapState();
}

class _QiblaMapState extends State<QiblaMap> {
  final _map = MapController();
  LatLng? _position;
  bool _loading = true;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _restorePosition();
  }

  Future<void> _restorePosition() async {
    final prefs = await SharedPreferences.getInstance();
    final manual = prefs.getBool(AppConstants.isPrayerTme) ?? false;
    final lat = prefs.getDouble(
      manual ? AppConstants.manualCityLat : 'prayer_time_automatic_latitude',
    );
    final lng = prefs.getDouble(
      manual ? AppConstants.manualCityLng : 'prayer_time_automatic_longitude',
    );
    if (!mounted) return;
    setState(() {
      if (lat != null &&
          lng != null &&
          lat.isFinite &&
          lng.isFinite &&
          lat.abs() <= 90 &&
          lng.abs() <= 180) {
        _position = LatLng(lat, lng);
      }
      _loading = false;
    });
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw StateError('Location unavailable');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      setState(() => _position = LatLng(position.latitude, position.longitude));
      _map.move(_position!, 16);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('qibla_map_pick_location'.tr)));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final position = _position;
    final bearing = position == null
        ? null
        : QiblahHelper.bearingFromTrueNorth(
            position.latitude,
            position.longitude,
          );
    // A short local segment follows the initial great-circle bearing. A straight
    // line all the way to Mecca on a Mercator map would give a wrong direction.
    final end = position == null
        ? null
        : const Distance().offset(position, 20000, bearing!);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text('qibla_map_pick_location'.tr, textAlign: TextAlign.center),
              if (bearing != null)
                Text(
                  '${'qibla_compass'.tr} · ${bearing.toStringAsFixed(1)}°',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: position ?? const LatLng(20, 0),
                  initialZoom: position == null ? 3 : 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, point) => setState(() => _position = point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'net.salatime.app',
                  ),
                  if (position != null && end != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [position, end],
                          color: Theme.of(context).colorScheme.primary,
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                  if (position != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: position,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 12,
                right: 12,
                child: FloatingActionButton.small(
                  heroTag: 'qibla_map_location',
                  onPressed: _locating ? null : _locate,
                  tooltip: 'current_location'.tr,
                  child: _locating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text('qibla_map_north_up'.tr, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
