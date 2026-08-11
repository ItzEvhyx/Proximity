import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../../../core/theme/app_colors.dart';

/// Displays the full route on a Mapbox map with a green polyline,
/// origin/destination pins, ETA + distance info card, and a back button.
class PathScreen extends StatefulWidget {
  const PathScreen({
    super.key,
    required this.geometry,
    required this.totalEta,
    required this.totalDistance,
    required this.travelMode,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
  });

  /// Route coordinates as [[lng, lat], ...].
  final List<List<double>> geometry;
  final String totalEta;
  final String totalDistance;

  /// "drive", "transit", or "walk".
  final String travelMode;

  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;

  @override
  State<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends State<PathScreen> {
  MapboxMap? _map;
  bool _mapReady = false;

  static const String _routeSourceId = 'route-line-source';
  static const String _routeLayerId = 'route-line-layer';

  void _onMapCreated(MapboxMap map) {
    _map = map;
    // Disable default compass and scale bar controls.
    map.compass.updateSettings(CompassSettings(enabled: false));
    map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
  }

  void _onStyleLoaded(StyleLoadedEventData _) async {
    setState(() => _mapReady = true);
    await _addRouteLine();
    await _fitCameraToBounds();
  }

  Future<void> _addRouteLine() async {
    final map = _map;
    if (map == null || widget.geometry.isEmpty) return;

    // Build GeoJSON LineString from geometry coordinates.
    final geojson = jsonEncode({
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': widget.geometry,
      },
      'properties': {},
    });

    // Choose line style based on travel mode.
    final dashArray = widget.travelMode == 'walk'
        ? [2.0, 2.0]
        : <double>[]; // solid for drive/transit

    await map.style.addSource(
      GeoJsonSource(id: _routeSourceId, data: geojson),
    );

    await map.style.addLayer(
      LineLayer(
        id: _routeLayerId,
        sourceId: _routeSourceId,
        lineColor: AppColors.primary.value,
        lineWidth: 5.0,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineDasharray: dashArray.isNotEmpty ? dashArray : null,
      ),
    );
  }

  Future<void> _fitCameraToBounds() async {
    final map = _map;
    if (map == null) return;

    // Compute bounds from origin + destination.
    final minLng = widget.originLng < widget.destLng
        ? widget.originLng
        : widget.destLng;
    final maxLng = widget.originLng > widget.destLng
        ? widget.originLng
        : widget.destLng;
    final minLat =
        widget.originLat < widget.destLat ? widget.originLat : widget.destLat;
    final maxLat =
        widget.originLat > widget.destLat ? widget.originLat : widget.destLat;

    final bounds = CoordinateBounds(
      southwest: Point(coordinates: Position(minLng, minLat)),
      northeast: Point(coordinates: Position(maxLng, maxLat)), infiniteBounds: false,
    );

    final camera = await map.cameraForCoordinateBounds(
      bounds,
      MbxEdgeInsets(top: 120, left: 60, bottom: 160, right: 60),
      null,
      null,
      null,
      null,
    );

    await map.flyTo(camera,
        MapAnimationOptions(duration: 800, startDelay: 200));
  }

  @override
  Widget build(BuildContext context) {
    final modeLabel = switch (widget.travelMode) {
      'drive' => 'Driving',
      'transit' => 'Transit',
      'walk' => 'Walking',
      _ => 'Route',
    };

    final modeIcon = switch (widget.travelMode) {
      'drive' => Icons.directions_car_rounded,
      'transit' => Icons.directions_bus_rounded,
      'walk' => Icons.directions_walk_rounded,
      _ => Icons.route_rounded,
    };

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey('path-map'),
              styleUri: MapboxStyles.STANDARD,
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded,
            ),
          ),

          // ── Back button (upper left) ───────────────────────────────────
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 26,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),

          // ── ETA / Distance card (bottom) ───────────────────────────────
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Mode icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(modeIcon, size: 22, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // ETA + distance
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          modeLabel,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.totalEta,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Distance badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.totalDistance,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
