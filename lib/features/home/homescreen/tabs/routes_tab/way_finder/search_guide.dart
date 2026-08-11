import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../../../../../core/theme/app_colors.dart';
import '../../maps_tab/maps_search_service.dart';
import '../../maps_tab/place_result.dart';

/// Result returned from the search guide flow.
class SearchGuideResult {
  final PlaceResult origin;
  final PlaceResult destination;

  const SearchGuideResult({required this.origin, required this.destination});
}

/// Opens the search guide bottom sheet.
Future<SearchGuideResult?> showSearchGuide(BuildContext context) {
  return showModalBottomSheet<SearchGuideResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SearchGuideSheet(),
  );
}

class _SearchGuideSheet extends StatefulWidget {
  const _SearchGuideSheet();

  @override
  State<_SearchGuideSheet> createState() => _SearchGuideSheetState();
}

class _SearchGuideSheetState extends State<_SearchGuideSheet> {
  final _searchService = MapsSearchService();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _originFocus = FocusNode();
  final _destinationFocus = FocusNode();

  _ActiveField _activeField = _ActiveField.origin;

  List<PlaceResult> _results = const [];
  bool _loading = false;
  Timer? _debounce;
  String? _sessionToken;

  PlaceResult? _selectedOrigin;
  PlaceResult? _selectedDestination;

  String _ensureSession() =>
      _sessionToken ??= MapsSearchService.newSessionToken();

  @override
  void initState() {
    super.initState();
    _originController.addListener(_onOriginChanged);
    _destinationController.addListener(_onDestinationChanged);
    _originFocus.addListener(_onFocusChanged);
    _destinationFocus.addListener(_onFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _originFocus.requestFocus();
    });
  }

  void _onFocusChanged() {
    if (_originFocus.hasFocus) {
      setState(() => _activeField = _ActiveField.origin);
    } else if (_destinationFocus.hasFocus) {
      setState(() => _activeField = _ActiveField.destination);
    }
  }

  void _onOriginChanged() => _onQueryChanged(_ActiveField.origin);
  void _onDestinationChanged() => _onQueryChanged(_ActiveField.destination);

  void _onQueryChanged(_ActiveField field) {
    if (field != _activeField) return;
    final query = field == _ActiveField.origin
        ? _originController.text.trim()
        : _destinationController.text.trim();

    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _loading = true);
    try {
      final results = await _searchService.suggest(
        query,
        sessionToken: _ensureSession(),
      );
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings:
            const geo.LocationSettings(accuracy: geo.LocationAccuracy.high),
      );
      final place = PlaceResult(
        name: 'Current Location',
        longitude: pos.longitude,
        latitude: pos.latitude,
      );

      _originController.removeListener(_onOriginChanged);
      _originController.text = 'Current Location';
      _originController.addListener(_onOriginChanged);
      setState(() {
        _selectedOrigin = place;
        _results = const [];
      });
      _destinationFocus.requestFocus();

      _checkBothSelected();
    } catch (_) {
      // Location permission denied or unavailable — ignore.
    }
  }

  Future<void> _selectResult(PlaceResult place) async {
    var resolved = place;
    if (place.needsRetrieve) {
      try {
        resolved = await _searchService.retrieve(
            place, sessionToken: _ensureSession());
        _sessionToken = null;
      } catch (_) {
        return;
      }
    }

    if (_activeField == _ActiveField.origin) {
      _originController.removeListener(_onOriginChanged);
      _originController.text = resolved.name;
      _originController.addListener(_onOriginChanged);
      setState(() {
        _selectedOrigin = resolved;
        _results = const [];
      });
      _destinationFocus.requestFocus();
    } else {
      _destinationController.removeListener(_onDestinationChanged);
      _destinationController.text = resolved.name;
      _destinationController.addListener(_onDestinationChanged);
      setState(() {
        _selectedDestination = resolved;
        _results = const [];
      });
    }

    _checkBothSelected();
  }

  void _checkBothSelected() {
    if (_selectedOrigin != null && _selectedDestination != null) {
      // Both selected — return immediately.
      if (mounted) {
        Navigator.of(context).pop(SearchGuideResult(
          origin: _selectedOrigin!,
          destination: _selectedDestination!,
        ));
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _originController.removeListener(_onOriginChanged);
    _destinationController.removeListener(_onDestinationChanged);
    _originController.dispose();
    _destinationController.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
    _searchService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: screenH * 0.70,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Drag handle ────────────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hintGrey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title ──────────────────────────────────────────────────────
            const Text(
              'Get from Point A to B',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 20),

            // ── A/B input fields ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline: green pin → dashed → red pin
                  Column(
                    children: [
                      const SizedBox(height: 14),
                      const Icon(Icons.location_on,
                          size: 22, color: AppColors.primary),
                      ...List.generate(3, (_) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              width: 2.5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          )),
                      const SizedBox(height: 8),
                      const Icon(Icons.location_on,
                          size: 22, color: AppColors.error),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _SearchField(
                          controller: _originController,
                          focusNode: _originFocus,
                          hint: 'Starting Point',
                          isActive: _activeField == _ActiveField.origin,
                        ),
                        const SizedBox(height: 14),
                        _SearchField(
                          controller: _destinationController,
                          focusNode: _destinationFocus,
                          hint: 'End Destination',
                          isActive: _activeField == _ActiveField.destination,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── "Use Current Location" button (for Point A) ──────────────
            if (_activeField == _ActiveField.origin && _selectedOrigin == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: _useCurrentLocation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.my_location_rounded,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Use Current Location',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // ── Results list ──────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2.5),
                    )
                  : _results.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const ClampingScrollPhysics(),
                          itemCount: _results.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (_, index) {
                            final place = _results[index];
                            return _ResultRow(
                              place: place,
                              onTap: () => _selectResult(place),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ActiveField { origin, destination }

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.isActive,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.border,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          cursorColor: AppColors.primary,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: AppColors.hintGrey,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.place, required this.onTap});

  final PlaceResult place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (place.distanceLabel != null)
                    Text(
                      place.distanceLabel!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.hintGrey,
                      ),
                    ),
                  if (place.address != null)
                    Text(
                      place.address!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.hintGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.location_on, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }
}
