import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/shared_prefs/shared_prefs.dart';
import 'maps_search_service.dart';
import 'pinned_trip.dart';
import 'place_result.dart';

/// Shared state for the Maps experience: the search field, the results
/// dropdown, and the "pin + confirm" flow.
///
/// Lives above both the search bar (rendered by the home shell) and the map /
/// info card (rendered by [MapsTab]) so they stay in sync. The map renderer
/// registers itself via [attachMap] to receive show-pin and clear requests, and
/// feeds the user's location back via [setUserLocation] so nearby suggestions,
/// distances and search bias work.
///
/// Two kinds of pin exist:
///  * the user's own **current-location** pin (red) — shown by default, always
///    present once the location is known, draggable to fine-tune the exact
///    starting spot; and
///  * a **searched** destination pin (green) — created when the user picks a
///    search result.
class MapsController extends ChangeNotifier {
  MapsController({MapsSearchService? service})
      : _service = service ?? MapsSearchService() {
    searchText.addListener(_onQueryChanged);
    searchFocus.addListener(_onFocusChanged);
    _loadHistory();
  }

  /// How many recent pinned locations to keep; the rest are discarded.
  static const int _maxHistory = 5;
  static const String _historyPrefsKey = 'pinned_trips_v1';

  final MapsSearchService _service;

  final TextEditingController searchText = TextEditingController();
  final FocusNode searchFocus = FocusNode();

  static const Duration _debounce = Duration(milliseconds: 350);
  Timer? _debounceTimer;
  int _requestSeq = 0;

  /// Groups a run of `/suggest` calls and the final `/retrieve` into one
  /// billable Search Box session. Reset after each retrieve.
  String? _sessionToken;
  String _ensureSession() =>
      _sessionToken ??= MapsSearchService.newSessionToken();

  // ── Search / dropdown state ────────────────────────────────────────────
  List<PlaceResult> _results = const [];
  List<PlaceResult> get results => _results;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  /// True while the dropdown of results should be visible.
  bool _resultsVisible = false;
  bool get resultsVisible => _resultsVisible;

  /// When true the results list is collapsed to just its header ("Nearby
  /// places" + a reopen chevron); the user can expand it again anytime.
  bool _resultsCollapsed = false;
  bool get resultsCollapsed => _resultsCollapsed;

  // ── Pinned trip history ────────────────────────────────────────────────
  List<PinnedTrip> _history = const [];
  List<PinnedTrip> get pinnedHistory => _history;

  /// Whether the current results are nearby suggestions (vs. query matches).
  bool _showingNearby = false;
  bool get showingNearby => _showingNearby;

  // ── Selection / pin state ──────────────────────────────────────────────
  /// The searched destination pin (green). Null until the user selects a
  /// search result.
  PlaceResult? _searched;

  /// The user's current-location pin (red). Set once the location is known and
  /// kept in sync as they move / drag it.
  PlaceResult? _currentLocation;
  PlaceResult? get currentLocation => _currentLocation;

  /// True once the user drags (or otherwise engages) the red current-location
  /// pin, so its confirm card is shown even without a search.
  bool _currentEngaged = false;

  /// True once a location has been confirmed: the pin is frozen in place on the
  /// map and the card returns to "past trips". Reset when a new search /
  /// selection or clear happens.
  bool _confirmed = false;
  bool get confirmed => _confirmed;

  /// The place the map should render a pin for: the searched destination if
  /// there is one, otherwise the user's current location.
  PlaceResult? get mapPin => _searched ?? _currentLocation;

  /// True when [mapPin] is the (red) current-location pin rather than a
  /// (green) searched destination.
  bool get mapPinIsCurrent => _searched == null;

  /// The place shown in the confirm card: a searched destination, or the
  /// current location once the user has engaged it. Null keeps the default
  /// "past trips" card visible. A confirmed pin shows no card (past trips).
  PlaceResult? get pinned => _confirmed
      ? null
      : (_searched ?? (_currentEngaged ? _currentLocation : null));
  bool get hasPin => pinned != null;

  /// True once the user taps "Confirm Location": the pin is locked in place and
  /// can no longer be dragged.
  bool _locked = false;
  bool get locked => _locked;

  /// True while a dragged pin is being reverse-geocoded / snapped to a place.
  bool _resolvingPin = false;
  bool get resolvingPin => _resolvingPin;

  // ── Location + map wiring ──────────────────────────────────────────────
  double? _userLng;
  double? _userLat;

  /// Fires the real-time location refresh described in the requirements: every
  /// [_locationPollInterval] it re-reads the user's position and, if it has
  /// moved, refreshes distances / nearby landmarks and the current-location
  /// pin.
  static const Duration _locationPollInterval = Duration(seconds: 5);
  static const double _movedThresholdMeters = 12;
  Timer? _locationTimer;

  void Function(PlaceResult place, {bool animateCamera})? _onShowPin;
  VoidCallback? _onClearPin;

  /// Optional hook fired when the user taps "Confirm Location".
  ValueChanged<PlaceResult>? onConfirmed;

  /// Optional hook fired when user enters an alert zone (proximity alarm).
  VoidCallback? onAlarmTriggered;

  // ── ETA / Distance tracking (after confirm) ────────────────────────────
  /// Distance in meters from the user to the confirmed destination.
  double? _distanceToDestination;
  double? get distanceToDestination => _distanceToDestination;

  /// Estimated time of arrival string (e.g. "5 min").
  String? _etaToDestination;
  String? get etaToDestination => _etaToDestination;

  /// True while tracking (after confirm, before alarm or clear).
  bool _tracking = false;
  bool get tracking => _tracking;

  /// Which alert zone phases have already fired (to avoid re-triggering).
  final Set<int> _firedAlertPhases = {};

  /// The confirmed destination coordinates (kept separately so poll can
  /// compute distance even after _searched is frozen).
  double? _confirmedLng;
  double? _confirmedLat;

  /// Called by the map renderer once it can move the camera and draw pins.
  void attachMap({
    required void Function(PlaceResult place, {bool animateCamera}) onShowPin,
    required VoidCallback onClearPin,
  }) {
    _onShowPin = onShowPin;
    _onClearPin = onClearPin;
  }

  /// Seeds / refreshes the user's location. The first call also plants the red
  /// current-location pin and starts the periodic location refresh.
  void setUserLocation({required double longitude, required double latitude}) {
    final first = _userLng == null || _userLat == null;
    _userLng = longitude;
    _userLat = latitude;
    if (first) {
      _initCurrentLocation(longitude, latitude);
      _startLocationUpdates();
    }
  }

  Future<void> _initCurrentLocation(double lng, double lat) async {
    // Draw the pin immediately with a placeholder, then fill in the address.
    _currentLocation = PlaceResult(
      name: 'Current location',
      longitude: lng,
      latitude: lat,
      isCurrentLocation: true,
      distanceMeters: 0,
    );
    notifyListeners();
    _onShowPin?.call(_currentLocation!, animateCamera: false);

    try {
      final resolved =
          await _service.reverseGeocode(longitude: lng, latitude: lat);
      if (resolved != null && _searched == null) {
        _currentLocation = resolved.copyWith(
          isCurrentLocation: true,
          distanceMeters: 0,
        );
        notifyListeners();
      }
    } catch (_) {
      // Keep the placeholder name on failure.
    }
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(_locationPollInterval, (_) {
      _pollLocation();
    });
  }

  /// Reads the current position; if the user has moved meaningfully, refreshes
  /// distances, the nearby-landmarks list, and the red current-location pin.
  Future<void> _pollLocation() async {
    geo.Position pos;
    try {
      pos = await geo.Geolocator.getCurrentPosition(
        locationSettings:
            const geo.LocationSettings(accuracy: geo.LocationAccuracy.high),
      );
    } catch (_) {
      return;
    }

    final prevLng = _userLng;
    final prevLat = _userLat;
    if (prevLng != null && prevLat != null) {
      final moved = _haversineMeters(prevLat, prevLng, pos.latitude, pos.longitude);
      if (moved < _movedThresholdMeters) return; // negligible movement
    }

    _userLng = pos.longitude;
    _userLat = pos.latitude;

    // Recompute distances on whatever results are currently displayed.
    // Only notify if the results list is actually visible to the user.
    if (_results.isNotEmpty) {
      _results = _withDistances(_results);
    }

    // Refresh the red pin (unless the user has dragged it or is searching).
    if (_searched == null && !_currentEngaged) {
      unawaited(_refreshCurrentLocationPin(pos.longitude, pos.latitude));
    }

    // If the empty-field "nearby" list is showing, refresh it for the new spot.
    // Otherwise skip the notification — distances updated silently until the
    // user opens the dropdown again.
    if (_resultsVisible && _showingNearby) {
      unawaited(_loadNearby());
    } else if (_resultsVisible) {
      notifyListeners();
    }

    // Update ETA/distance tracking and check proximity if confirmed.
    if (_tracking) {
      _updateDistanceAndEta();
    }
    // No notifyListeners when results are hidden — avoids unnecessary rebuilds.
  }

  Future<void> _refreshCurrentLocationPin(double lng, double lat) async {
    PlaceResult updated;
    try {
      final resolved =
          await _service.reverseGeocode(longitude: lng, latitude: lat);
      updated = (resolved ??
              PlaceResult(name: 'Current location', longitude: lng, latitude: lat))
          .copyWith(isCurrentLocation: true, distanceMeters: 0);
    } catch (_) {
      updated = PlaceResult(
        name: _currentLocation?.name ?? 'Current location',
        longitude: lng,
        latitude: lat,
        isCurrentLocation: true,
        distanceMeters: 0,
      );
    }
    if (_searched != null || _currentEngaged) return; // superseded
    _currentLocation = updated;
    notifyListeners();
    _onShowPin?.call(_currentLocation!, animateCamera: false);
  }

  // ── Query handling ─────────────────────────────────────────────────────
  /// The text of the most recently selected place. Used to stop the dropdown
  /// from re-opening when focus briefly returns to the field right after a
  /// selection (which otherwise required a second tap to dismiss).
  String? _selectedText;

  void _onFocusChanged() {
    if (searchFocus.hasFocus) {
      // If the user taps the search bar while a location is confirmed,
      // reset the confirmed state so a new search can proceed.
      if (_confirmed) {
        _confirmed = false;
        _searched = null;
        _locked = false;
        _tracking = false;
      }

      final text = searchText.text.trim();
      // Opening the field: if empty, show nearby landmarks. If it holds a
      // place we just selected, keep the dropdown closed (the user is looking
      // at their selection, not searching). Otherwise re-show matches.
      if (text.isEmpty) {
        _loadNearby();
      } else if (text != _selectedText) {
        _resultsVisible = true;
        notifyListeners();
      }
    }
  }

  void _onQueryChanged() {
    final query = searchText.text.trim();
    _debounceTimer?.cancel();

    // Any real edit clears the "just selected" guard so search resumes.
    if (query != _selectedText) _selectedText = null;

    // Clearing the query drops any pending selection and shows nearby again.
    if (query.isEmpty) {
      if (searchFocus.hasFocus) {
        _loadNearby();
      } else {
        _setResults(const [], visible: false, nearby: false);
      }
      return;
    }

    _debounceTimer = Timer(_debounce, () => _runSearch(query));
  }

  Future<void> _loadNearby() async {
    if (_userLng == null || _userLat == null) {
      _setResults(const [], visible: true, nearby: true);
      return;
    }
    final seq = ++_requestSeq;
    _loading = true;
    _resultsVisible = true;
    _resultsCollapsed = false;
    _showingNearby = true;
    _error = null;
    notifyListeners();

    try {
      final nearby = await _service.nearbyLandmarks(
        longitude: _userLng!,
        latitude: _userLat!,
        limit: 5,
      );
      if (seq != _requestSeq) return; // superseded
      _results = _withDistances(nearby);
      _loading = false;
      notifyListeners();
    } catch (e) {
      if (seq != _requestSeq) return;
      _loading = false;
      _error = 'Could not load nearby places.';
      notifyListeners();
    }
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_requestSeq;
    _loading = true;
    _resultsVisible = true;
    _resultsCollapsed = false;
    _showingNearby = false;
    _error = null;
    notifyListeners();

    try {
      final matches = await _service.suggest(
        query,
        sessionToken: _ensureSession(),
        longitude: _userLng,
        latitude: _userLat,
      );
      if (seq != _requestSeq) return;
      // If the field no longer holds this query (e.g. a result was selected
      // while this was in flight), drop these stale results.
      if (searchText.text.trim() != query) {
        _loading = false;
        return;
      }
      _results = _withDistances(matches);
      _loading = false;
      notifyListeners();
    } catch (e) {
      if (seq != _requestSeq) return;
      _loading = false;
      _error = 'Search failed. Check your connection.';
      notifyListeners();
    }
  }

  void _setResults(
    List<PlaceResult> results, {
    required bool visible,
    required bool nearby,
  }) {
    _results = results;
    _resultsVisible = visible;
    _showingNearby = nearby;
    _loading = false;
    notifyListeners();
  }

  /// Tags each result with its straight-line distance from the user (when the
  /// user's location is known). Suggestions without resolved coordinates
  /// (Mapbox `/suggest` rows) are left without a distance.
  List<PlaceResult> _withDistances(List<PlaceResult> places) {
    final lng = _userLng;
    final lat = _userLat;
    if (lng == null || lat == null) return places;
    return [
      for (final p in places)
        if (p.needsRetrieve || (p.longitude == 0 && p.latitude == 0))
          p
        else
          p.copyWith(
            distanceMeters:
                _haversineMeters(lat, lng, p.latitude, p.longitude),
          ),
    ];
  }

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0; // meters
    double toRad(double d) => d * math.pi / 180.0;
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) *
            math.cos(toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  // ── Selection ──────────────────────────────────────────────────────────
  /// User tapped a result: close the dropdown, resolve its coordinates (if it
  /// came from `/suggest`), reflect the name in the field, drop a green pin,
  /// and fly the camera there. A single tap is all that is needed.
  Future<void> selectResult(PlaceResult place) async {
    _debounceTimer?.cancel();
    _requestSeq++; // cancel any in-flight search results

    _results = const [];
    _resultsVisible = false;
    _loading = false;
    // Immediately notify so the dropdown dismisses on this frame — no need for
    // the user to tap twice.
    notifyListeners();

    var resolved = place;
    if (place.needsRetrieve) {
      // Show a lightweight "loading" cue by pinning the name early.
      _resolvingPin = true;
      notifyListeners();
      try {
        resolved =
            await _service.retrieve(place, sessionToken: _ensureSession());
      } catch (_) {
        _resolvingPin = false;
        _error = 'Could not load that location.';
        notifyListeners();
        return;
      } finally {
        // A retrieve ends the billing session; the next search starts a new one.
        _sessionToken = null;
      }
      _resolvingPin = false;
    }

    // Attach the distance from the user's current location.
    if (_userLng != null && _userLat != null) {
      resolved = resolved.copyWith(
        distanceMeters: _haversineMeters(
          _userLat!,
          _userLng!,
          resolved.latitude,
          resolved.longitude,
        ),
      );
    }

    // Update the field text without re-triggering a search.
    searchText.removeListener(_onQueryChanged);
    searchText.text = resolved.name;
    searchText.addListener(_onQueryChanged);
    // Remember this so a focus bounce doesn't re-open the dropdown.
    _selectedText = resolved.name.trim();

    _searched = resolved;
    _locked = false;
    _confirmed = false;
    // Keep the dropdown dismissed even if focus bounces back to the field.
    _results = const [];
    _resultsVisible = false;
    searchFocus.unfocus();
    notifyListeners();

    _onShowPin?.call(resolved, animateCamera: true);
  }

  /// Reverse-geocodes a dragged pin's coordinate, snapping it to the nearest
  /// address / road, and updates the active pin (and the search field text when
  /// a destination is being edited). Returns the resolved place so the map can
  /// move the marker to the snapped point. If reverse geocoding fails, the raw
  /// coordinate is kept.
  ///
  /// [live] marks intermediate updates during an in-progress drag (used to
  /// update the address in real time) vs. the final drop.
  Future<PlaceResult> resolveDroppedPin({
    required double longitude,
    required double latitude,
    bool live = false,
  }) async {
    final editingCurrent = _searched == null;
    _resolvingPin = true;
    if (editingCurrent) _currentEngaged = true;
    notifyListeners();

    PlaceResult resolved;
    try {
      resolved = await _service.reverseGeocode(
            longitude: longitude,
            latitude: latitude,
          ) ??
          PlaceResult(
            name: 'Dropped pin',
            longitude: longitude,
            latitude: latitude,
          );
    } catch (_) {
      resolved = PlaceResult(
        name: 'Dropped pin',
        longitude: longitude,
        latitude: latitude,
      );
    }

    if (editingCurrent) {
      // A moved current-location pin is no longer at distance 0.
      final dist = (_userLng != null && _userLat != null)
          ? _haversineMeters(
              _userLat!, _userLng!, resolved.latitude, resolved.longitude)
          : null;
      resolved = resolved.copyWith(
        isCurrentLocation: true,
        distanceMeters: dist,
      );
      _currentLocation = resolved;
    } else {
      _searched = resolved;
      // Reflect the snapped name in the field without triggering a new search.
      searchText.removeListener(_onQueryChanged);
      searchText.text = resolved.name;
      searchText.addListener(_onQueryChanged);
      _selectedText = resolved.name.trim();
    }

    _resolvingPin = false;
    notifyListeners();
    return resolved;
  }

  /// Confirms the currently pinned place: records it in the user's recent-trip
  /// history and freezes the pin in place on the map (glued, non-draggable, not
  /// updated by GPS), while the card returns to the "past trips" browsing view.
  void confirmPin() {
    final place = pinned;
    if (place == null) return;
    _addToHistory(place);
    onConfirmed?.call(place);

    // Freeze the confirmed spot as a static (green) pin so it no longer moves
    // with GPS updates or drags. Promote a confirmed current-location pin to a
    // plain searched pin so the poll leaves it alone.
    final frozen = place.copyWith(isCurrentLocation: false);
    _searched = frozen;
    _currentEngaged = false;
    _confirmed = true;
    _locked = true;
    _resolvingPin = false;
    // Clear the field text and the dropdown so the card shows past trips.
    _selectedText = null;
    searchText.removeListener(_onQueryChanged);
    searchText.clear();
    searchText.addListener(_onQueryChanged);
    _results = const [];
    _resultsVisible = false;

    // Start proximity tracking.
    _confirmedLng = frozen.longitude;
    _confirmedLat = frozen.latitude;
    _tracking = true;
    _firedAlertPhases.clear();
    _updateDistanceAndEta();

    notifyListeners();

    // Re-draw the pin at the confirmed coordinate, locked (no camera move).
    _onShowPin?.call(frozen, animateCamera: false);
  }

  /// Removes a saved trip from the user's history (e.g. via the trash button).
  void removeTrip(PinnedTrip trip) {
    final next = _history
        .where((t) => !(t.name == trip.name &&
            t.longitude == trip.longitude &&
            t.latitude == trip.latitude &&
            t.pinnedAt == trip.pinnedAt))
        .toList();
    if (next.length == _history.length) return;
    _history = next;
    notifyListeners();
    unawaited(_saveHistory());
  }

  /// Selects a past trip as the current destination, pins it, and confirms.
  void selectTrip(PinnedTrip trip) {
    final place = PlaceResult(
      name: trip.name,
      address: trip.address,
      longitude: trip.longitude,
      latitude: trip.latitude,
      distanceMeters: trip.distanceMeters,
    );

    _searched = place;
    _locked = false;
    _confirmed = false;
    _resultsVisible = false;
    _results = const [];
    notifyListeners();

    _onShowPin?.call(place, animateCamera: true);

    // Auto-confirm after showing the pin.
    Future.delayed(const Duration(milliseconds: 300), () {
      confirmPin();
    });
  }

  /// Reverses a past trip: the user's old start location becomes the new
  /// destination. The idea is: if the original trip was A→B, reversing makes
  /// B (current) → A (destination).
  void reverseTrip(PinnedTrip trip) {
    final startLng = trip.startLongitude;
    final startLat = trip.startLatitude;
    if (startLng == null || startLat == null) return;

    final place = PlaceResult(
      name: trip.startLocationName ?? 'Previous location',
      longitude: startLng,
      latitude: startLat,
    );

    _searched = place;
    _locked = false;
    _confirmed = false;
    _resultsVisible = false;
    _results = const [];
    notifyListeners();

    _onShowPin?.call(place, animateCamera: true);

    // Auto-confirm after showing the pin.
    Future.delayed(const Duration(milliseconds: 300), () {
      confirmPin();
    });
  }

  void _addToHistory(PlaceResult place) {
    final entry = PinnedTrip(
      name: place.name,
      address: place.address,
      longitude: place.longitude,
      latitude: place.latitude,
      distanceMeters: place.distanceMeters,
      startLocationName: _currentLocation?.name ?? 'Current location',
      startLongitude: _currentLocation?.longitude ?? _userLng,
      startLatitude: _currentLocation?.latitude ?? _userLat,
      pinnedAt: DateTime.now(),
    );
    // De-dupe by name + coordinates so re-confirming the same spot doesn't
    // create duplicates; newest first; cap at [_maxHistory].
    final next = <PinnedTrip>[
      entry,
      ..._history.where((t) =>
          !(t.name == entry.name &&
              t.longitude == entry.longitude &&
              t.latitude == entry.latitude)),
    ];
    if (next.length > _maxHistory) {
      next.removeRange(_maxHistory, next.length);
    }
    _history = next;
    notifyListeners();
    unawaited(_saveHistory());
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyPrefsKey);
      if (raw == null) return;
      final loaded = PinnedTrip.decodeList(raw);
      if (loaded.isEmpty) return;
      _history = loaded.length > _maxHistory
          ? loaded.sublist(0, _maxHistory)
          : loaded;
      notifyListeners();
    } catch (_) {
      // Ignore corrupt / unavailable storage.
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyPrefsKey, PinnedTrip.encodeList(_history));
    } catch (_) {
      // Best-effort persistence.
    }
  }

  // ── Results collapse / expand ──────────────────────────────────────────
  /// Collapses the results list to just its header, leaving a reopen control.
  void collapseResults() {
    if (_resultsCollapsed) return;
    _resultsCollapsed = true;
    notifyListeners();
  }

  /// Re-expands a collapsed results list.
  void expandResults() {
    if (!_resultsCollapsed) return;
    _resultsCollapsed = false;
    notifyListeners();
  }

  /// Unlocks a confirmed pin so it can be dragged again.
  void unlockPin() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }

  /// Clears the confirm card. A searched destination reverts to the user's
  /// current-location pin; an engaged current-location pin simply disengages
  /// (back to the "past trips" browsing state).
  void clearPin() {
    _locked = false;
    _confirmed = false;
    _resolvingPin = false;
    _selectedText = null;
    stopTracking();
    searchText.removeListener(_onQueryChanged);
    searchText.clear();
    searchText.addListener(_onQueryChanged);

    if (_searched != null) {
      _searched = null;
      _currentEngaged = false;
      notifyListeners();
      // Redraw the red current-location pin if we still know where the user is.
      final current = _currentLocation;
      if (current != null) {
        _onShowPin?.call(current, animateCamera: true);
      } else {
        _onClearPin?.call();
      }
      return;
    }

    // No search: stop engaging the current-location pin and snap it back to the
    // user's actual GPS location.
    _currentEngaged = false;
    final lng = _userLng;
    final lat = _userLat;
    if (lng != null && lat != null) {
      _currentLocation = PlaceResult(
        name: 'Current location',
        longitude: lng,
        latitude: lat,
        isCurrentLocation: true,
        distanceMeters: 0,
      );
      notifyListeners();
      _onShowPin?.call(_currentLocation!, animateCamera: false);
      unawaited(_refreshCurrentLocationPin(lng, lat));
    } else {
      notifyListeners();
    }
  }

  /// Dismisses the dropdown without changing the selection (e.g. tap-away).
  void dismissResults() {
    if (!_resultsVisible) return;
    _resultsVisible = false;
    searchFocus.unfocus();
    notifyListeners();
  }

  // ── Proximity tracking ─────────────────────────────────────────────────

  /// Computes the current distance/ETA to the confirmed destination and
  /// triggers the alarm callback if within an alert zone distance.
  void _updateDistanceAndEta() {
    final lng = _userLng;
    final lat = _userLat;
    final destLng = _confirmedLng;
    final destLat = _confirmedLat;
    if (lng == null || lat == null || destLng == null || destLat == null) return;

    final dist = _haversineMeters(lat, lng, destLat, destLng);
    _distanceToDestination = dist;

    // Estimate ETA: assume ~5 km/h walking, ~30 km/h driving as rough average.
    // Since we don't know the mode here, use ~1.4 m/s (~walking pace).
    final etaSeconds = dist / 1.4;
    final etaMin = (etaSeconds / 60).round();
    _etaToDestination = etaMin < 60 ? '$etaMin min' : '${etaMin ~/ 60}h ${etaMin % 60}m';

    notifyListeners();

    // Check alert zone distances (sorted descending: first = farthest).
    final zones = AppPrefs.alertZoneDistances;
    for (var i = 0; i < zones.length; i++) {
      if (dist <= zones[i] && !_firedAlertPhases.contains(i)) {
        _firedAlertPhases.add(i);
        // Fire alarm on the closest phase that triggers.
        onAlarmTriggered?.call();
        break;
      }
    }
  }

  /// Stops proximity tracking (e.g. after alarm dismissed or user clears pin).
  void stopTracking() {
    _tracking = false;
    _distanceToDestination = null;
    _etaToDestination = null;
    _confirmedLng = null;
    _confirmedLat = null;
    _firedAlertPhases.clear();
    notifyListeners();
  }

  /// Returns a formatted distance string for UI display.
  String get distanceLabel {
    final d = _distanceToDestination;
    if (d == null) return '—';
    if (d < 1000) return '${d.round()} m';
    return '${(d / 1000).toStringAsFixed(1)} km';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _locationTimer?.cancel();
    searchText.removeListener(_onQueryChanged);
    searchFocus.removeListener(_onFocusChanged);
    searchText.dispose();
    searchFocus.dispose();
    _service.dispose();
    super.dispose();
  }
}
