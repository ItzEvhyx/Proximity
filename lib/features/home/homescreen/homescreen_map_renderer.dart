import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import 'tabs/maps_tab/maps_controller.dart';
import 'tabs/maps_tab/place_result.dart';
import 'tabs/maps_tab/search_pin_marker.dart'
    show RadarPulse, MapPinGraphic;

/// Renders the interactive map, locked to the Philippines.
///
/// On load it requests location permission and centers the camera on the user
/// at street level (so buildings and roads are the focus), showing their
/// location puck. If permission is denied or the location can't be read, it
/// falls back to framing the whole country. Panning stays within the
/// Philippines and users can zoom out to the full nation but no further.
///
/// It also owns the searched-location marker: when the [MapsController] reports
/// a selection, the camera flies there and a green pin with an animated radar
/// pulse is overlaid, kept anchored to the geographic point as the camera moves.
class HomescreenMapRenderer extends StatefulWidget {
  const HomescreenMapRenderer({super.key, this.onReady, this.controller});

  /// Fired once the map style has loaded and the camera has been centered on
  /// the user's location (or the country fallback). Called at most once.
  final VoidCallback? onReady;

  /// Shared maps state. When null the map is purely presentational.
  final MapsController? controller;

  @override
  State<HomescreenMapRenderer> createState() => _HomescreenMapRendererState();
}

class _HomescreenMapRendererState extends State<HomescreenMapRenderer>
    with SingleTickerProviderStateMixin {
  // Philippines extents (with margin for Batanes in the north and Tawi-Tawi in
  // the south). Position is (longitude, latitude).
  static final Position _southwest = Position(116.0, 4.2);
  static final Position _northeast = Position(127.0, 21.5);

  // Used only when the user's location is unavailable.
  static final Position _fallbackCenter = Position(121.774, 12.8797);

  // Street-level zoom so buildings and roads are the focus on first load.
  static const double _streetZoom = 16.0;
  static const double _maxZoom = 19.0;

  // Zoom the camera settles at when flying to a searched location.
  static const double _pinZoom = 16.5;

  bool _styleLoaded = false;
  bool _cameraReady = false;
  bool _readyFired = false;

  MapboxMap? _map;

  /// The currently pinned place and its projected screen position (logical
  /// pixels). Both null when nothing is pinned.
  PlaceResult? _pinned;
  ScreenCoordinate? _pinScreen;

  /// While the pin is being dragged, this holds its live screen position and
  /// [_pinScreen] is ignored so the marker follows the finger.
  bool _dragging = false;
  ScreenCoordinate? _dragScreen;

  /// Mirrors the controller's locked state. While editing, the pin is a
  /// screen-anchored Flutter overlay (stays put on screen, draggable). Once
  /// locked (confirmed), it is replaced by NATIVE Mapbox annotations — a pin
  /// plus animated radar circles — which the SDK keeps perfectly glued to the
  /// coordinate during pan/zoom (no reprojection, so no wobble), at the same
  /// size and with the radar still pulsing.
  bool _locked = false;

  // Native locked-pin rendering.
  PointAnnotationManager? _pinManager;
  PointAnnotation? _lockedAnnotation;
  Uint8List? _greenPinBytes;
  CircleAnnotationManager? _radarManager;
  final List<CircleAnnotation> _radarRings = [];
  AnimationController? _radarController;
  bool _radarUpdating = false;

  static const double _radarMaxRadius = 90;

  /// Set before a programmatic camera move (e.g. fly-to a search result) so the
  /// idle that follows doesn't overwrite the precise, freshly-selected place.
  bool _suppressIdleResolve = false;

  /// Latest laid-out size of the map (logical px), used to place the pin at the
  /// viewport center when flying to a searched location. Stored as plain
  /// doubles because `Size` is ambiguous (Mapbox also exports a `Size`).
  double _viewportWidth = 0;
  double _viewportHeight = 0;

  @override
  void initState() {
    super.initState();
    widget.controller
      ?..attachMap(onFlyToPin: _flyToPin, onClearPin: _clearPin)
      ..addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _radarController?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final locked = widget.controller?.locked ?? false;
    if (locked == _locked || !mounted) return;
    if (locked) {
      _lockPin();
    } else {
      _unlockPin();
    }
  }

  /// Confirm → plant NATIVE annotations (pin + radar) at the pinned coordinate.
  /// Native annotations move with the map itself, so they stay glued with no
  /// reprojection lag (no wobble). The Flutter overlay is hidden while locked.
  Future<void> _lockPin() async {
    final map = _map;
    final place = _pinned;
    setState(() => _locked = true);
    if (map == null || place == null) return;

    // Capture before any async gap (context must not cross awaits).
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final geometry =
        Point(coordinates: Position(place.longitude, place.latitude));
    try {
      // Create the radar manager first so its circles draw beneath the pin.
      _radarManager ??= await map.annotations.createCircleAnnotationManager();
      _pinManager ??= await map.annotations.createPointAnnotationManager();

      // Clear anything left over from a previous lock.
      await _radarManager!.deleteAll();
      _radarRings.clear();
      if (_lockedAnnotation != null) {
        await _pinManager!.delete(_lockedAnnotation!);
        _lockedAnnotation = null;
      }

      final color = AppColors.primary.toARGB32();
      for (var i = 0; i < 3; i++) {
        final ring = await _radarManager!.create(
          CircleAnnotationOptions(
            geometry: geometry,
            circleRadius: 0,
            circleColor: color,
            circleOpacity: 0,
            circleBlur: 0.4,
          ),
        );
        _radarRings.add(ring);
      }

      _greenPinBytes ??= await _renderPinBytes(dpr);
      _lockedAnnotation = await _pinManager!.create(
        PointAnnotationOptions(
          geometry: geometry,
          image: _greenPinBytes!,
          iconSize: 1.0,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );

      _startRadar();
    } catch (e) {
      debugPrint('lockPin failed: $e');
    }
  }

  /// Edit → remove the native annotations and restore the draggable Flutter
  /// overlay at the pin's current on-screen position.
  Future<void> _unlockPin() async {
    final map = _map;
    final place = _pinned;
    _radarController?.stop();
    if (_radarManager != null) {
      try {
        await _radarManager!.deleteAll();
      } catch (_) {}
    }
    _radarRings.clear();
    if (_lockedAnnotation != null && _pinManager != null) {
      try {
        await _pinManager!.delete(_lockedAnnotation!);
      } catch (_) {}
      _lockedAnnotation = null;
    }
    if (map != null && place != null) {
      try {
        final sc = await map.pixelForCoordinate(
          Point(coordinates: Position(place.longitude, place.latitude)),
        );
        if (mounted) _pinScreen = sc;
      } catch (_) {}
    }
    if (mounted) setState(() => _locked = false);
  }

  void _startRadar() {
    _radarController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..addListener(_tickRadar);
    _radarController!
      ..reset()
      ..repeat();
  }

  /// Drives the native radar circles' radius + opacity each frame. Position is
  /// fixed by the source geometry, so the rings never drift — only the pulse
  /// animates. Self-throttles to the annotation channel's throughput.
  Future<void> _tickRadar() async {
    final manager = _radarManager;
    final controller = _radarController;
    if (manager == null ||
        controller == null ||
        _radarRings.isEmpty ||
        _radarUpdating) {
      return;
    }
    _radarUpdating = true;
    final base = controller.value;
    for (var i = 0; i < _radarRings.length; i++) {
      final t = (base + i / _radarRings.length) % 1.0;
      _radarRings[i].circleRadius = _radarMaxRadius * t;
      _radarRings[i].circleOpacity = (1 - t) * 0.35;
    }
    try {
      await Future.wait(_radarRings.map(manager.update));
    } catch (_) {}
    _radarUpdating = false;
  }

  /// Rasterizes the green teardrop marker (with a white core) to PNG bytes at
  /// the device pixel ratio so the native pin matches the Flutter pin's size.
  Future<Uint8List> _renderPinBytes(double dpr) async {
    final side = _pinHeight * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // White core behind the glyph so the pin's hole reads as a white dot.
    canvas.drawCircle(
      Offset(side / 2, side * 0.38),
      side * 0.14,
      Paint()..color = AppColors.white,
    );

    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: String.fromCharCode(Icons.location_on.codePoint),
      style: TextStyle(
        fontSize: side,
        fontFamily: Icons.location_on.fontFamily,
        package: Icons.location_on.fontPackage,
        color: AppColors.primary,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset((side - tp.width) / 2, 0));

    final image =
        await recorder.endRecording().toImage(side.ceil(), side.ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

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
    _map = mapboxMap;

    // Hide the default ornaments the app doesn't need (compass + scale bar).
    // Logo and attribution stay visible as required by Mapbox's terms.
    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // Ask for permission and read the current location up front so it becomes
    // the basis for the initial camera.
    final userPosition = await _requestUserLocation();
    if (userPosition != null) {
      widget.controller?.setUserLocation(
        longitude: userPosition.longitude,
        latitude: userPosition.latitude,
      );
    }

    // Show the user's location as a red map pin instead of the default blue
    // puck. The pin PNG is loaded from assets and handed to the 2D puck as its
    // top image; pulsing is disabled so it reads as a clean marker.
    final pinBytes = await rootBundle.load(
      'public/assets/icons/pin_red_icon.png',
    );
    await mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: false,
        puckBearingEnabled: false,
        locationPuck: LocationPuck(
          locationPuck2D: LocationPuck2D(
            topImage: pinBytes.buffer.asUint8List(),
            // The source PNG is high-res, so scale it down to a compact,
            // Google Maps-sized marker. scaleExpression takes a Mapbox style
            // expression as a JSON string; a bare number is ignored, so it
            // must be wrapped as a ["literal", n] expression. Like Google
            // Maps' marker, this keeps a constant on-screen size across zoom.
            scaleExpression: '["literal", 0.25]',
          ),
        ),
      ),
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

  /// Flies the camera to [place] and drops the green pin at the viewport
  /// center. The pin is screen-anchored: once placed it stays put on screen
  /// while the user pans/zooms; only dragging it moves it.
  Future<void> _flyToPin(PlaceResult place) async {
    final map = _map;
    setState(() {
      _pinned = place;
      _pinScreen = _viewportCenter;
      _dragScreen = null;
    });

    if (map == null) return;
    // The searched place is precise; don't let the post-fly idle relabel it.
    _suppressIdleResolve = true;
    await map.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(place.longitude, place.latitude),
        ),
        zoom: _pinZoom,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  void _clearPin() {
    if (!mounted) return;
    _radarController?.stop();
    if (_radarManager != null) {
      _radarManager!.deleteAll().catchError((_) {});
    }
    _radarRings.clear();
    if (_lockedAnnotation != null && _pinManager != null) {
      _pinManager!.delete(_lockedAnnotation!).catchError((_) {});
      _lockedAnnotation = null;
    }
    setState(() {
      _pinned = null;
      _pinScreen = null;
      _dragScreen = null;
      _dragging = false;
      _locked = false;
    });
  }

  // ── Pin dragging ─────────────────────────────────────────────────────────
  void _onPinPanStart(DragStartDetails _) {
    if (_locked) return;
    setState(() {
      _dragging = true;
      _dragScreen = _pinScreen;
    });
  }

  void _onPinPanUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final current = _dragScreen ?? _pinScreen;
    if (current == null) return;
    setState(() {
      _dragScreen = ScreenCoordinate(
        x: current.x + details.delta.dx,
        y: current.y + details.delta.dy,
      );
    });
  }

  /// On release, convert the marker's screen position back to a coordinate,
  /// snap it to the nearest address/road via reverse geocoding, and move the
  /// pin onto that snapped point. The camera is left untouched so nothing else
  /// on screen shifts.
  Future<void> _onPinPanEnd(DragEndDetails _) async {
    final map = _map;
    final controller = widget.controller;
    final drop = _dragScreen;
    setState(() => _dragging = false);
    if (map == null || controller == null || drop == null) {
      setState(() => _dragScreen = null);
      return;
    }

    try {
      final point = await map.coordinateForPixel(drop);
      final coords = point.coordinates;
      final resolved = await controller.resolveDroppedPin(
        longitude: coords.lng.toDouble(),
        latitude: coords.lat.toDouble(),
      );
      if (!mounted) return;

      // Project the snapped coordinate back to the screen so the pin visually
      // lands on the corrected (road/address) spot without moving the map.
      ScreenCoordinate? snapped;
      try {
        snapped = await map.pixelForCoordinate(
          Point(
            coordinates: Position(resolved.longitude, resolved.latitude),
          ),
        );
      } catch (_) {
        snapped = null;
      }
      if (!mounted) return;
      setState(() {
        _pinned = resolved;
        _dragScreen = null;
        if (snapped != null) _pinScreen = snapped;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _dragScreen = null);
    }
  }

  /// Once the map settles after a user pan/zoom, refresh the pin's label to the
  /// place now under it — without moving the pin. Skipped for programmatic
  /// camera moves (search fly-to) and while dragging or locked.
  Future<void> _handleMapIdle() async {
    if (_suppressIdleResolve) {
      _suppressIdleResolve = false;
      return;
    }
    final map = _map;
    final controller = widget.controller;
    final screen = _pinScreen;
    if (map == null ||
        controller == null ||
        _pinned == null ||
        screen == null ||
        _dragging ||
        _locked) {
      return;
    }
    try {
      final point = await map.coordinateForPixel(screen);
      final coords = point.coordinates;
      final resolved = await controller.resolveDroppedPin(
        longitude: coords.lng.toDouble(),
        latitude: coords.lat.toDouble(),
      );
      if (!mounted) return;
      // Keep the pin's screen position; only its label/coordinate updated.
      setState(() => _pinned = resolved);
    } catch (_) {
      // Ignore transient projection / network errors.
    }
  }

  /// The viewport center in logical pixels (falls back to the screen size
  /// before the first layout pass).
  ScreenCoordinate get _viewportCenter {
    var width = _viewportWidth;
    var height = _viewportHeight;
    if (width <= 0 || height <= 0) {
      final media = MediaQuery.sizeOf(context);
      width = media.width;
      height = media.height;
    }
    return ScreenCoordinate(x: width / 2, y: height / 2);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportWidth = constraints.maxWidth;
        _viewportHeight = constraints.maxHeight;
        return Stack(
          children: [
            MapWidget(
              key: const ValueKey('ph-map'),
              // Standard style shows POIs, place labels and 3D landmarks
              // (Google Maps-like) rather than just streets.
              styleUri: MapboxStyles.STANDARD,
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: (_) {
                _styleLoaded = true;
                _maybeFireReady();
              },
              // While editing, the pin is screen-anchored and must NOT move on
              // pan/zoom; we only relabel it once the map settles (idle). Once
              // locked, the pin is a native annotation, so nothing to do here.
              onMapIdleListener: (_) => _handleMapIdle(),
            ),

            // Draggable Flutter pin + radar pulse while EDITING only. Once
            // locked, native annotations take over (glued to the map).
            if (_pinned != null && _markerPos != null && !_locked)
              Positioned(
                left: _markerPos!.x - _markerSize / 2,
                top: _markerPos!.y - _markerSize / 2,
                child: _buildMarker(),
              ),
          ],
        );
      },
    );
  }

  /// The screen position to draw the marker at: the live drag position while
  /// dragging, otherwise the projected pin position.
  ScreenCoordinate? get _markerPos => _dragScreen ?? _pinScreen;

  Widget _buildMarker() {
    return SizedBox(
      width: _markerSize,
      height: _markerSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Radar rings keep pulsing in every state (including once locked).
          IgnorePointer(
            child: RadarPulse(size: _markerSize),
          ),
          // Only the pin itself is draggable; its tip rests on the anchor.
          // Dragging is disabled once locked, but the pin keeps its size.
          Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: const Offset(0, -_pinHeight / 2),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _locked ? null : _onPinPanStart,
                onPanUpdate: _locked ? null : _onPinPanUpdate,
                onPanEnd: _locked ? null : _onPinPanEnd,
                child: MapPinGraphic(
                  height: _pinHeight,
                  dragging: _dragging,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _markerSize = 200;
  static const double _pinHeight = 52;
}
