import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/animations/tabs_transitions.dart';
import '../../../core/navbar/navbar_widget.dart';
import '../../../core/skeleton_loading/skeleton_loading.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/search_bar.dart';
import 'tabs/history_tab/history_tab.dart';
import 'tabs/maps_tab/maps_controller.dart';
import 'tabs/maps_tab/maps_tab.dart';
import 'tabs/maps_tab/search_results_dropdown.dart';
import 'tabs/profile_tab/profile_tab.dart';
import 'tabs/routes_tab/routes_tab.dart';

/// Home shell: hosts the four tabs behind the floating navbar, with a sliding
/// tab transition.
///
/// Loading order on first entry: the map initializes and centers on the user's
/// location while a skeleton covers everything. Once the map is ready the
/// skeleton fades out and the search bar and navbar fade in together.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Duration _revealDuration = Duration(milliseconds: 300);

  int _tabIndex = 0;
  bool _mapReady = false;
  bool _skeletonVisible = true;
  Timer? _readyTimeout;

  late final MapsController _mapsController;

  @override
  void initState() {
    super.initState();
    _mapsController = MapsController();
    // Safety net: reveal the UI even if the map never reports ready (e.g. no
    // network / stuck tiles) so the app is never stuck on the skeleton.
    _readyTimeout = Timer(const Duration(seconds: 8), _handleMapReady);
  }

  @override
  void dispose() {
    _readyTimeout?.cancel();
    _mapsController.dispose();
    super.dispose();
  }


  void _handleMapReady() {
    if (_mapReady || !mounted) return;
    _readyTimeout?.cancel();
    setState(() => _mapReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topOffset = screenHeight * 0.07;
    final showSearchBar = _tabIndex == 0 || _tabIndex == 1;

    final tabs = <Widget>[
      MapsTab(onMapReady: _handleMapReady, controller: _mapsController),
      const RoutesTab(),
      const HistoryTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.white,
      // Keep the map, info card and navbar fixed when the keyboard opens; the
      // keyboard overlays them instead of pushing the whole layout up.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: TabsTransition(index: _tabIndex, children: tabs),
          ),

          // Tap-away scrim: closes the search dropdown when tapping the map.
          if (showSearchBar)
            AnimatedBuilder(
              animation: _mapsController,
              builder: (context, _) {
                if (!_mapsController.resultsVisible) {
                  return const SizedBox.shrink();
                }
                return Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _mapsController.dismissResults,
                  ),
                );
              },
            ),

          // Search bar + results dropdown (Maps/Routes only), revealed once the
          // map is ready.
          if (showSearchBar)
            Positioned(
              top: topOffset,
              left: 16,
              right: 16,
              child: IgnorePointer(
                ignoring: !_mapReady,
                child: AnimatedOpacity(
                  opacity: _mapReady ? 1 : 0,
                  duration: _revealDuration,
                  child: AnimatedBuilder(
                    animation: _mapsController,
                    builder: (context, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LocationSearchBar(
                            controller: _mapsController.searchText,
                            focusNode: _mapsController.searchFocus,
                          ),
                          if (_mapsController.resultsVisible)
                            SearchResultsDropdown(
                              results: _mapsController.results,
                              loading: _mapsController.loading,
                              showingNearby: _mapsController.showingNearby,
                              error: _mapsController.error,
                              onSelect: _mapsController.selectResult,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

          // Navbar, revealed together with the search bar.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: IgnorePointer(
                  ignoring: !_mapReady,
                  child: AnimatedOpacity(
                    opacity: _mapReady ? 1 : 0,
                    duration: _revealDuration,
                    child: NavBar(
                      currentIndex: _tabIndex,
                      onTap: (index) => setState(() => _tabIndex = index),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Skeleton overlay while the map initializes + locates the user.
          // Fades out on ready, then unmounts (disposing its shimmer tickers).
          if (_skeletonVisible)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _mapReady,
                child: AnimatedOpacity(
                  opacity: _mapReady ? 0 : 1,
                  duration: _revealDuration,
                  onEnd: () {
                    if (_mapReady && mounted) {
                      setState(() => _skeletonVisible = false);
                    }
                  },
                  child: _HomeSkeleton(topOffset: topOffset),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Skeleton layout shown while the home shell loads: a full-screen map
/// placeholder with search-bar and navbar placeholders in their real spots.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton({required this.topOffset});

  final double topOffset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: SkeletonBox(borderRadius: 0)),
        Positioned(
          top: topOffset,
          left: 16,
          right: 16,
          child: const SkeletonBox(
            width: double.infinity,
            height: 52,
            borderRadius: 26,
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: const SkeletonBox(
                width: double.infinity,
                height: 60,
                borderRadius: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
