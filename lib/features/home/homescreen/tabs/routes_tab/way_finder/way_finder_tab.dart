import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../../../core/global_services/claude_services.dart';
import '../../../../../../core/skeleton_loading/skeleton_loading.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../maps_tab/place_result.dart';
import 'eta_distance_cards.dart';
import 'finder_desc.dart';
import 'route_nodes.dart';
import 'route_transit_selector.dart';
import 'search_guide.dart';

/// Way Finder tab — shows the finder description card, route/transit
/// selector, ETA/distance cards, and step-by-step route nodes.
///
/// After the user picks A→B via the search guide, Claude generates the
/// route steps which are displayed as nodes.
class WayFinderTab extends StatefulWidget {
  const WayFinderTab({super.key, this.active = false});

  final bool active;

  @override
  State<WayFinderTab> createState() => WayFinderTabState();
}

class WayFinderTabState extends State<WayFinderTab> {
  TravelMode _travelMode = TravelMode.drive;
  bool _contentReady = false;

  // Route data (populated after Claude returns)
  RouteResult? _routeResult;
  bool _routeLoading = false;
  String? _routeError;
  PlaceResult? _origin;
  PlaceResult? _destination;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _contentReady = true);
    });
  }

  void _onClear() {
    setState(() {
      _routeResult = null;
      _routeError = null;
      _origin = null;
      _destination = null;
    });
  }

  void _onTravelModeChanged(TravelMode m) {
    setState(() => _travelMode = m);
    // Re-fetch route with new mode if we already have origin + destination.
    if (_origin != null && _destination != null) {
      _fetchRoute();
    }
  }

  /// Called externally (from home_screen) after the search guide returns.
  void handleSearchResult(SearchGuideResult result) {
    setState(() {
      _origin = result.origin;
      _destination = result.destination;
    });
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (_origin == null || _destination == null) return;

    setState(() {
      _routeLoading = true;
      _routeError = null;
    });

    final modeStr = switch (_travelMode) {
      TravelMode.drive => 'drive',
      TravelMode.transit => 'transit',
      TravelMode.walk => 'walk',
    };

    try {
      final result = await ClaudeService.instance.getRoute(
        origin: _origin!.name,
        destination: _destination!.name,
        originLng: _origin!.longitude,
        originLat: _origin!.latitude,
        destLng: _destination!.longitude,
        destLat: _destination!.latitude,
        travelMode: modeStr,
      );
      if (mounted) {
        setState(() {
          _routeResult = result;
          _routeLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _routeError = e.toString();
          _routeLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final topOffset = screenH * 0.07;
    final overlayH = topOffset + 52 + 12 + 40 + 20;

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: overlayH)),

        // ── Way Finder description card ──────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _contentReady
                ? const RepaintBoundary(child: FinderDesc())
                : const SkeletonBox(height: 150, borderRadius: 20),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Route • Preview + Drive/Transit/Walk ─────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _contentReady
                ? RouteTransitSelector(
                    selected: _travelMode,
                    onChanged: _onTravelModeChanged,
                    onClear: _onClear,
                  )
                : const SkeletonBox(height: 100, borderRadius: 16),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // ── ETA + Distance cards ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _contentReady
                ? EtaDistanceCards(
                    etaValue: _routeResult?.totalEta ?? '—',
                    etaUnit: _routeResult != null ? '' : 'Min',
                    distanceValue: _routeResult?.totalDistance ?? '—',
                    distanceUnit: _routeResult != null ? '' : 'Km',
                  )
                : const SkeletonBox(height: 80, borderRadius: 20),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Route content (loading / error / nodes) ──────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildRouteContent(),
          ),
        ),

        SliverToBoxAdapter(child: SizedBox(height: screenH * 0.15)),
      ],
    );
  }

  Widget _buildRouteContent() {
    if (!_contentReady) return const SizedBox.shrink();

    if (_routeLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5),
              SizedBox(height: 12),
              Text(
                'Planning your route...',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.hintGrey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_routeError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Text(
            _routeError!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.error,
            ),
          ),
        ),
      );
    }

    if (_routeResult != null) {
      final nodes = _routeResult!.steps
          .map((s) => RouteNode(
                title: s.title,
                eta: s.eta,
                distance: s.distance,
                description: s.description,
                isDestination: s.isDestination,
              ))
          .toList();
      return RouteNodesWidget(nodes: nodes);
    }

    // No route yet — prompt user to search
    return const Padding(
      padding: EdgeInsets.only(top: 40),
      child: Center(
        child: Text(
          'Tap the search bar to plan a route',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppColors.hintGrey,
          ),
        ),
      ),
    );
  }
}
