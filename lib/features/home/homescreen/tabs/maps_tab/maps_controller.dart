import 'dart:async';

import 'package:flutter/material.dart';

import 'maps_search_service.dart';
import 'place_result.dart';

/// Shared state for the Maps experience: the search field, the results
/// dropdown, and the "pin + confirm" flow.
///
/// Lives above both the search bar (rendered by the home shell) and the map /
/// info card (rendered by [MapsTab]) so they stay in sync. The map renderer
/// registers itself via [attachMap] to receive fly-to and pin requests, and
/// feeds the user's location back via [setUserLocation] so nearby suggestions
/// and search bias work.
class MapsController extends ChangeNotifier {
  MapsController({MapsSearchService? service})
      : _service = service ?? MapsSearchService() {
    searchText.addListener(_onQueryChanged);
    searchFocus.addListener(_onFocusChanged);
  }

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

  /// Whether the current results are nearby suggestions (vs. query matches).
  bool _showingNearby = false;
  bool get showingNearby => _showingNearby;

  // ── Selection / pin state ──────────────────────────────────────────────
  PlaceResult? _pinned;
  PlaceResult? get pinned => _pinned;
  bool get hasPin => _pinned != null;

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

  void Function(PlaceResult place)? _onFlyToPin;
  VoidCallback? _onClearPin;

  /// Optional hook fired when the user taps "Confirm Location".
  ValueChanged<PlaceResult>? onConfirmed;

  /// Called by the map renderer once it can fly the camera and drop pins.
  void attachMap({
    required void Function(PlaceResult place) onFlyToPin,
    required VoidCallback onClearPin,
  }) {
    _onFlyToPin = onFlyToPin;
    _onClearPin = onClearPin;
  }

  void setUserLocation({required double longitude, required double latitude}) {
    _userLng = longitude;
    _userLat = latitude;
  }

  // ── Query handling ─────────────────────────────────────────────────────
  void _onFocusChanged() {
    if (searchFocus.hasFocus) {
      // Opening the field: if empty, show nearby landmarks; otherwise keep the
      // existing matches visible.
      if (searchText.text.trim().isEmpty) {
        _loadNearby();
      } else {
        _resultsVisible = true;
        notifyListeners();
      }
    }
  }

  void _onQueryChanged() {
    final query = searchText.text.trim();
    _debounceTimer?.cancel();

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
    _showingNearby = true;
    _error = null;
    notifyListeners();

    try {
      final nearby = await _service.nearbyLandmarks(
        longitude: _userLng!,
        latitude: _userLat!,
      );
      if (seq != _requestSeq) return; // superseded
      _results = nearby;
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
      _results = matches;
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

  // ── Selection ──────────────────────────────────────────────────────────
  /// User tapped a result: close the dropdown, resolve its coordinates (if it
  /// came from `/suggest`), reflect the name in the field, drop a green pin,
  /// and fly the camera there.
  Future<void> selectResult(PlaceResult place) async {
    _debounceTimer?.cancel();
    _requestSeq++; // cancel any in-flight search results

    searchFocus.unfocus();
    _results = const [];
    _resultsVisible = false;
    _loading = false;

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

    // Update the field text without re-triggering a search.
    searchText.removeListener(_onQueryChanged);
    searchText.text = resolved.name;
    searchText.addListener(_onQueryChanged);

    _pinned = resolved;
    _locked = false;
    notifyListeners();

    _onFlyToPin?.call(resolved);
  }

  /// Reverse-geocodes a dragged pin's coordinate, snapping it to the nearest
  /// address / road, and updates the pinned place (and the search field text).
  /// Returns the resolved place so the map can move the marker to the snapped
  /// point. If reverse geocoding fails, the raw coordinate is kept.
  Future<PlaceResult> resolveDroppedPin({
    required double longitude,
    required double latitude,
  }) async {
    _resolvingPin = true;
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

    _pinned = resolved;
    _resolvingPin = false;

    // Reflect the snapped name in the field without triggering a new search.
    searchText.removeListener(_onQueryChanged);
    searchText.text = resolved.name;
    searchText.addListener(_onQueryChanged);

    notifyListeners();
    return resolved;
  }

  /// Confirms the currently pinned place and locks it in place.
  void confirmPin() {
    final place = _pinned;
    if (place == null) return;
    _locked = true;
    notifyListeners();
    onConfirmed?.call(place);
  }

  /// Unlocks a confirmed pin so it can be dragged again.
  void unlockPin() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }

  /// Clears the pin and the confirm card, returning to the browsing state.
  void clearPin() {
    if (_pinned == null) return;
    _pinned = null;
    _locked = false;
    _resolvingPin = false;
    searchText.removeListener(_onQueryChanged);
    searchText.clear();
    searchText.addListener(_onQueryChanged);
    notifyListeners();
    _onClearPin?.call();
  }

  /// Dismisses the dropdown without changing the selection (e.g. tap-away).
  void dismissResults() {
    if (!_resultsVisible) return;
    _resultsVisible = false;
    searchFocus.unfocus();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    searchText.removeListener(_onQueryChanged);
    searchFocus.removeListener(_onFocusChanged);
    searchText.dispose();
    searchFocus.dispose();
    _service.dispose();
    super.dispose();
  }
}
