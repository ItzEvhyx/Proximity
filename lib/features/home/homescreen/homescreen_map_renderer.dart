import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import 'tabs/maps_tab/building_highlight_service.dart';
import 'tabs/maps_tab/maps_controller.dart';
import 'tabs/maps_tab/place_result.dart';

/// Renders the interactive map, locked to the Philippines.
///
/// The searched / current-location marker is drawn with NATIVE Mapbox
/// annotations (a pin image + animated radar rings). Because native annotations
/// are anchored to the geographic coordinate by the SDK itself, the pin stays
/// perfectly glued to its spot during pan/zoom with no reprojection wobble —
/// and it looks identical whether the location is being edited or confirmed
/// (confirming only disables dragging). A small invisible Flutter hit-area over
/// the pin lets the user drag it (when unlocked); dragging moves the native
/// annotation live and reverse-geocodes the spot.
class HomescreenMapRenderer extends StatefulWidget {
  const HomescreenMapRenderer({super.key, this.onReady, this.controller});

  final VoidCallback? onReady;
  final MapsController? controller;

  @override
  State<HomescreenMapRenderer> createState() => _HomescreenMapRendererState();
}

class _HomescreenMapRendererState extends State<HomescreenMapRenderer>
    with SingleTickerProviderStateMixin {
  // Philippines extents. Position is (longitude, latitude).
  static final Position _southwest = Position(116.0, 4.2);
  static final Position _northeast = Position(127.0, 21.5);
  static final Position _fallbackCenter = Position(121.774, 12.8797);

  static const double _streetZoom = 16.0;
  static const double _maxZoom = 19.0;
  static const double _pinZoom = 16.5;

  bool _styleLoaded = false;
  bool _cameraReady = false;
  bool _readyFired = false;

  MapboxMap? _map;

  /// The place currently marked, or null when nothing is pinned.
  PlaceResult? _pinned;

  /// Reprojected screen position of the pin, used only to place the invisible
  /// drag hit-area. Recomputed when the pin changes and when the camera goes
  /// idle (so it's accurate whenever the user might grab the pin).
  ScreenCoordinate? _pinScreen;

  bool _dragging = false;
  ScreenCoordinate? _dragScreen;
  bool _dragMoveBusy = false;

  bool _locked = false;

  Timer? _liveResolveTimer;
  static const Duration _liveResolveDebounce = Duration(milliseconds: 600);

  bool _reprojecting = false;

  // ── Native marker (pin + radar) ────────────────────────────────────────
  PointAnnotationManager? _pinManager;
  CircleAnnotationManager? _radarManager;
  PointAnnotation? _pinAnnotation;
  final List<CircleAnnotation> _radarRings = [];
  CircleAnnotation? _radarDot;
  AnimationController? _radarController;
  bool _radarUpdating = false;
  bool _radarActive = false;

  static const int _radarRingCount = 3;
  static const double _radarMaxRadius = 90;
  static const double _pinHeight = 52;

  /// Cache of rendered pin PNGs keyed by ARGB color, so we don't re-rasterize.
  final Map<int, Uint8List> _pinBytesCache = {};
  double _pinDpr = 1;

  // ── Building highlight (OSM polygon, yellow border) ─────────────────────
  final BuildingHighlightService _buildingService = BuildingHighlightService();
  static const String _highlightSourceId = 'building-highlight-source';
  static const String _highlightFillLayerId = 'building-highlight-fill';
  static const String _highlightLineLayerId = 'building-highlight-line';
  bool _highlightLayersAdded = false;
  static const String _emptyFeatureCollection =
      '{"type":"FeatureCollection","features":[]}';

  @override
  void initState() {
    super.initState();
    widget.controller
      ?..attachMap(onShowPin: _showPin, onClearPin: _clearPin)
      ..addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _liveResolveTimer?.cancel();
    _radarController?.dispose();
    _buildingService.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final locked = widget.controller?.locked ?? false;
    if (locked != _locked && mounted) {
      setState(() => _locked = locked);
    }
  }

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
    _pinDpr = MediaQuery.devicePixelRatioOf(context);

    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // Our own red pin represents the user's location, so hide the puck.
    await mapboxMap.location
        .updateSettings(LocationComponentSettings(enabled: false));

    final userPosition = await _requestUserLocation();

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

    if (userPosition != null) {
      await mapboxMap.setCamera(
        CameraOptions(
          center: Point(
            coordinates:
                Position(userPosition.longitude, userPosition.latitude),
          ),
          zoom: _streetZoom,
        ),
      );
    } else {
      await mapboxMap.setCamera(
        CameraOptions(center: Point(coordinates: _fallbackCenter), zoom: fitted.zoom),
      );
    }

    // Create the annotation managers up front (radar under the pin).
    _radarManager ??= await mapboxMap.annotations.createCircleAnnotationManager();
    _pinManager ??= await mapboxMap.annotations.createPointAnnotationManager();

    _cameraReady = true;
    _maybeFireReady();

    if (userPosition != null) {
      widget.controller?.setUserLocation(
        longitude: userPosition.longitude,
        latitude: userPosition.latitude,
      );
    }
  }

  // ── Pin colors ─────────────────────────────────────────────────────────
  Color get _pinColor => (_pinned?.isCurrentLocation ?? false)
      ? AppColors.currentLocation
      : AppColors.primary;

  /// Rasterizes (once, cached) the teardrop pin PNG in [color] at the device
  /// pixel ratio so the native image matches the intended on-screen size.
  Future<Uint8List> _pinBytesFor(Color color) async {
    final key = color.toARGB32();
    final cached = _pinBytesCache[key];
    if (cached != null) return cached;

    final side = _pinHeight * _pinDpr;
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
        color: color,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset((side - tp.width) / 2, 0));

    final image =
        await recorder.endRecording().toImage(side.ceil(), side.ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();
    _pinBytesCache[key] = bytes;
    return bytes;
  }

  // ── Show / move / clear the native marker ──────────────────────────────

  /// Shows a marker for [place]. Searched destinations animate the camera; the
  /// current-location pin is placed without moving the camera.
  Future<void> _showPin(PlaceResult place, {bool animateCamera = true}) async {
    final map = _map;
    // Don't yank the pin out from under an in-progress drag.
    if (_dragging) {
      _pinned = place;
      return;
    }
    setState(() => _pinned = place);

    if (map != null && animateCamera) {
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(place.longitude, place.latitude)),
          zoom: _pinZoom,
        ),
        MapAnimationOptions(duration: 1200),
      );
    }

    await _placeNativeMarker(place);
    await _reprojectHitArea();

    if (animateCamera) {
      // Highlight the searched building's footprint (OSM yellow outline).
      unawaited(_showBuildingHighlight(place));
    }
  }

  /// Creates or moves the native pin + radar rings to [place]'s coordinate.
  Future<void> _placeNativeMarker(PlaceResult place) async {
    final map = _map;
    if (map == null) return;
    _pinManager ??= await map.annotations.createPointAnnotationManager();
    _radarManager ??= await map.annotations.createCircleAnnotationManager();

    final geometry =
        Point(coordinates: Position(place.longitude, place.latitude));
    final colorInt = _pinColor.toARGB32();

    try {
      // Radar rings (created once, then repositioned).
      if (_radarRings.isEmpty) {
        for (var i = 0; i < _radarRingCount; i++) {
          final ring = await _radarManager!.create(
            CircleAnnotationOptions(
              geometry: geometry,
              circleRadius: 0,
              circleColor: colorInt,
              circleOpacity: 0,
              circleStrokeColor: colorInt,
              circleStrokeWidth: 2,
              circleStrokeOpacity: 0,
            ),
          );
          _radarRings.add(ring);
        }
        _radarDot = await _radarManager!.create(
          CircleAnnotationOptions(
            geometry: geometry,
            circleRadius: 5,
            circleColor: colorInt,
            circleOpacity: 0.9,
          ),
        );
      } else {
        for (final ring in _radarRings) {
          ring.geometry = geometry;
          ring.circleColor = colorInt;
          ring.circleStrokeColor = colorInt;
          await _radarManager!.update(ring);
        }
        final dot = _radarDot;
        if (dot != null) {
          dot.geometry = geometry;
          dot.circleColor = colorInt;
          await _radarManager!.update(dot);
        }
      }

      // Pin image.
      final bytes = await _pinBytesFor(_pinColor);
      final existing = _pinAnnotation;
      if (existing == null) {
        _pinAnnotation = await _pinManager!.create(
          PointAnnotationOptions(
            geometry: geometry,
            image: bytes,
            iconSize: 1.0,
            iconAnchor: IconAnchor.BOTTOM,
          ),
        );
      } else {
        existing.geometry = geometry;
        existing.image = bytes;
        await _pinManager!.update(existing);
      }

      _startRadar();
    } catch (e) {
      debugPrint('placeNativeMarker failed: $e');
    }
  }

  /// Moves just the pin (radar hidden) to a screen point during a drag.
  Future<void> _moveNativePinToScreen(ScreenCoordinate screen) async {
    final map = _map;
    final pin = _pinAnnotation;
    if (map == null || pin == null || _dragMoveBusy) return;
    _dragMoveBusy = true;
    try {
      final point = await map.coordinateForPixel(screen);
      pin.geometry = point;
      await _pinManager?.update(pin);
    } catch (_) {
    } finally {
      _dragMoveBusy = false;
    }
  }

  void _clearPin() {
    if (!mounted) return;
    _liveResolveTimer?.cancel();
    _stopRadar();
    unawaited(_clearBuildingHighlight());
    () async {
      try {
        if (_pinAnnotation != null) await _pinManager?.delete(_pinAnnotation!);
      } catch (_) {}
      try {
        await _radarManager?.deleteAll();
      } catch (_) {}
      _pinAnnotation = null;
      _radarRings.clear();
      _radarDot = null;
    }();
    setState(() {
      _pinned = null;
      _pinScreen = null;
      _dragScreen = null;
      _dragging = false;
      _locked = false;
    });
  }

  // ── Radar animation (native, matches the app's radar look) ─────────────
  void _startRadar() {
    _radarActive = true;
    _radarController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..addListener(_tickRadar);
    if (!_radarController!.isAnimating) {
      _radarController!
        ..reset()
        ..repeat();
    }
  }

  void _stopRadar() {
    _radarActive = false;
    _radarController?.stop();
  }

  /// Frame counter used to throttle radar updates (update every 3rd frame
  /// instead of every frame — native annotation updates are expensive).
  int _radarFrameCount = 0;

  Future<void> _tickRadar() async {
    final manager = _radarManager;
    final controller = _radarController;
    if (!_radarActive ||
        manager == null ||
        controller == null ||
        _radarRings.isEmpty ||
        _radarUpdating ||
        _dragging) {
      return;
    }

    // Skip 2 out of every 3 frames to reduce native annotation churn.
    _radarFrameCount++;
    if (_radarFrameCount % 3 != 0) return;

    _radarUpdating = true;
    final base = controller.value;
    for (var i = 0; i < _radarRings.length; i++) {
      final t = (base + i / _radarRings.length) % 1.0;
      final ring = _radarRings[i];
      ring.circleRadius = _radarMaxRadius * t;
      ring.circleStrokeOpacity = (1 - t) * 0.55;
      // Faint fill inside the leading ring only.
      ring.circleOpacity = i == 0 ? (1 - t) * 0.15 : 0;
    }
    try {
      await Future.wait(_radarRings.map(manager.update));
    } catch (_) {}
    _radarUpdating = false;
  }

  /// Hides the radar rings (used while dragging) without destroying them.
  Future<void> _hideRadar() async {
    final manager = _radarManager;
    if (manager == null) return;
    for (final ring in _radarRings) {
      ring.circleStrokeOpacity = 0;
      ring.circleOpacity = 0;
    }
    final dot = _radarDot;
    if (dot != null) dot.circleOpacity = 0;
    try {
      await Future.wait([
        ..._radarRings.map(manager.update),
        if (dot != null) manager.update(dot),
      ]);
    } catch (_) {}
  }

  // ── Dragging (invisible hit-area over the native pin) ──────────────────
  void _onPinPanStart(DragStartDetails _) {
    if (_locked) return;
    _stopRadar();
    unawaited(_hideRadar());
    setState(() {
      _dragging = true;
      _dragScreen = _pinScreen;
    });
  }

  void _onPinPanUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final current = _dragScreen ?? _pinScreen;
    if (current == null) return;
    final next = ScreenCoordinate(
      x: current.x + details.delta.dx,
      y: current.y + details.delta.dy,
    );
    setState(() => _dragScreen = next);
    unawaited(_moveNativePinToScreen(next));
    _scheduleLiveResolve();
  }

  void _scheduleLiveResolve() {
    _liveResolveTimer?.cancel();
    _liveResolveTimer = Timer(_liveResolveDebounce, () async {
      final map = _map;
      final controller = widget.controller;
      final drop = _dragScreen;
      if (map == null || controller == null || drop == null || !_dragging) {
        return;
      }
      try {
        final point = await map.coordinateForPixel(drop);
        final coords = point.coordinates;
        await controller.resolveDroppedPin(
          longitude: coords.lng.toDouble(),
          latitude: coords.lat.toDouble(),
          live: true,
        );
      } catch (_) {}
    });
  }

  Future<void> _onPinPanEnd(DragEndDetails _) async {
    _liveResolveTimer?.cancel();
    final map = _map;
    final controller = widget.controller;
    final drop = _dragScreen;
    setState(() => _dragging = false);
    if (map == null || controller == null || drop == null) {
      setState(() => _dragScreen = null);
      await _placeNativeMarker(_pinned!);
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
      setState(() {
        _pinned = resolved;
        _dragScreen = null;
      });
      await _placeNativeMarker(resolved);
      await _reprojectHitArea();
      unawaited(_showBuildingHighlight(resolved));
    } catch (_) {
      if (!mounted) return;
      setState(() => _dragScreen = null);
      if (_pinned != null) await _placeNativeMarker(_pinned!);
    }
  }

  /// Recomputes the pin's on-screen position so the invisible drag hit-area
  /// sits over it. Cheap and only needed when the camera is steady.
  Future<void> _reprojectHitArea() async {
    final map = _map;
    final place = _pinned;
    if (map == null || place == null || _dragging || _reprojecting) return;
    _reprojecting = true;
    try {
      final screen = await map.pixelForCoordinate(
        Point(coordinates: Position(place.longitude, place.latitude)),
      );
      if (mounted && !_dragging) setState(() => _pinScreen = screen);
    } catch (_) {
    } finally {
      _reprojecting = false;
    }
  }

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

  // ── Building highlight layer management ────────────────────────────────
  Future<void> _ensureHighlightLayers() async {
    final map = _map;
    if (map == null || _highlightLayersAdded) return;
    _highlightLayersAdded = true;
    try {
      await map.style.addSource(
        GeoJsonSource(id: _highlightSourceId, data: _emptyFeatureCollection),
      );
      await map.style.addLayer(
        FillLayer(
          id: _highlightFillLayerId,
          sourceId: _highlightSourceId,
          slot: 'top',
          fillColor: const Color(0xFFFFEB3B).toARGB32(),
          fillOpacity: 0.20,
        ),
      );
      await map.style.addLayer(
        LineLayer(
          id: _highlightLineLayerId,
          sourceId: _highlightSourceId,
          slot: 'top',
          lineColor: const Color(0xFFFFC400).toARGB32(),
          lineWidth: 3.5,
          lineOpacity: 0.95,
        ),
      );
    } catch (e) {
      debugPrint('Failed to add highlight layers: $e');
      _highlightLayersAdded = false;
    }
  }

  Future<void> _showBuildingHighlight(PlaceResult place) async {
    await _ensureHighlightLayers();
    final map = _map;
    if (map == null) return;
    final geojson = await _buildingService.fetchBuildingPolygon(
      longitude: place.longitude,
      latitude: place.latitude,
    );
    if (!mounted) return;
    final data = geojson ?? _emptyFeatureCollection;
    try {
      final source =
          await map.style.getSource(_highlightSourceId) as GeoJsonSource?;
      if (source != null) await source.updateGeoJSON(data);
    } catch (e) {
      debugPrint('Failed to update highlight source: $e');
    }
  }

  Future<void> _clearBuildingHighlight() async {
    final map = _map;
    if (map == null || !_highlightLayersAdded) return;
    try {
      final source =
          await map.style.getSource(_highlightSourceId) as GeoJsonSource?;
      if (source != null) await source.updateGeoJSON(_emptyFeatureCollection);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hitPos = _dragging ? _dragScreen : _pinScreen;
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('ph-map'),
          styleUri: MapboxStyles.STANDARD,
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: (_) {
            _styleLoaded = true;
            _maybeFireReady();
          },
          // Keep the drag hit-area aligned with the (native) pin once the
          // camera settles. The pin itself is glued natively — no wobble.
          onMapIdleListener: (_) => _reprojectHitArea(),
        ),

        // Invisible drag handle over the pin (only when editable).
        if (_pinned != null && hitPos != null && !_locked)
          Positioned(
            left: hitPos.x - _hitSize / 2,
            // Anchor near the pin body (its tip sits at the coordinate).
            top: hitPos.y - _hitSize + 6,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _onPinPanStart,
              onPanUpdate: _onPinPanUpdate,
              onPanEnd: _onPinPanEnd,
              child: const SizedBox(width: _hitSize, height: _hitSize),
            ),
          ),
      ],
    );
  }

  static const double _hitSize = 64;
}
