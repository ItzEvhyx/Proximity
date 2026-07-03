import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Renders the interactive map, locked to the Philippines.
///
/// On load it requests location permission and centers the camera on the user
/// at street level (so buildings and roads are the focus), showing their
/// location puck. If permission is denied or the location can't be read, it
/// falls back to framing the whole country. Panning stays within the
/// Philippines and users can zoom out to the full nation but no further.
class HomescreenMapRenderer extends StatefulWidget {
  const HomescreenMapRenderer({super.key, this.onReady});

  /// Fired once the map style has loaded and the camera has been centered on
  /// the user's location (or the country fallback). Called at most once.
  final VoidCallback? onReady;

  @override
  State<HomescreenMapRenderer> createState() => _HomescreenMapRendererState();
}

class _HomescreenMapRendererState extends State<HomescreenMapRenderer> {
  // Philippines extents (with margin for Batanes in the north and Tawi-Tawi in
  // the south). Position is (longitude, latitude).
  static final Position _southwest = Position(116.0, 4.2);
  static final Position _northeast = Position(127.0, 21.5);

  // Used only when the user's location is unavailable.
  static final Position _fallbackCenter = Position(121.774, 12.8797);

  // Street-level zoom so buildings and roads are the focus on first load.
  static const double _streetZoom = 16.0;
  static const double _maxZoom = 19.0;

  bool _styleLoaded = false;
  bool _cameraReady = false;
  bool _readyFired = false;

  /// Notifies the parent once the map is both styled and centered.
  void _maybeFireReady() {
    if (!_readyFired && _styleLoaded && _cameraReady && mounted) {
      _readyFired = true;
      widget.onReady?.call();
    }
  }

  CoordinateBounds get _phBounds => CoordinateBounds(
        southwest: Point(coordinates: _southwest),
        northeast: Point(coordinates: _northeast),
        infiniteBounds: false,
      );

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    // Hide the default ornaments the app doesn't need (compass + scale bar).
    // Logo and attribution stay visible as required by Mapbox's terms.
    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // Ask for permission and read the current location up front so it becomes
    // the basis for the initial camera.
    final userPosition = await _requestUserLocation();

    // Show the user's location puck on the map.
    await mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    // Keep panning within the country; the country-fit zoom is the floor so
    // users can zoom out to the whole nation but never past it.
    final fitted = await mapboxMap.cameraForCoordinateBounds(
      _phBounds,
      MbxEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
      null,
      null,
      null,
      null,
    );
    await mapboxMap.setBounds(
      CameraBoundsOptions(
        bounds: _phBounds,
        minZoom: fitted.zoom,
        maxZoom: _maxZoom,
      ),
    );

    // Center on the user at street level, or fall back to the country view.
    if (userPosition != null) {
      await mapboxMap.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(
              userPosition.longitude,
              userPosition.latitude,
            ),
          ),
          zoom: _streetZoom,
        ),
      );
    } else {
      await mapboxMap.setCamera(
        CameraOptions(
          center: Point(coordinates: _fallbackCenter),
          zoom: fitted.zoom,
        ),
      );
    }

    _cameraReady = true;
    _maybeFireReady();
  }

  /// Requests location permission (if needed) and returns the current position,
  /// or null if the service is off or permission was denied.
  Future<geo.Position?> _requestUserLocation() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) return null;

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await geo.Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('ph-map'),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: (_) {
        _styleLoaded = true;
        _maybeFireReady();
      },
    );
  }
}
