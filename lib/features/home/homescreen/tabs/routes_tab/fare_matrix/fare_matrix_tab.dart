// lib/features/home/homescreen/tabs/routes_tab/fare_matrix/fare_matrix_tab.dart
//
// ── Architecture ──────────────────────────────────────────────────────────────
//
// Mirrors the SleepTrackerScreen zero-animation pattern:
//
// • CustomScrollView + SliverToBoxAdapter for each section.
// • ClampingScrollPhysics — no overscroll bounce compositing.
// • ZERO in-widget animations. State renders instantly via setState.
// • Deferred content mount: the first frame renders lightweight skeletons
//   for all sections. After the first frame paints, _contentReady flips true
//   and the real widgets mount on the second frame. This guarantees the
//   initial build never drops frames (the skeleton is trivially cheap to
//   render — just flat colored rectangles).
// • Each section lives in its own file so the widget tree stays shallow and
//   each build() call is minimal.
// • Network image gated behind _imagesUnlocked (latches true when the Routes
//   tab first becomes active).

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../../../core/skeleton_loading/skeleton_loading.dart';
import 'check_fare_card.dart';
import 'fare_matrix_desc.dart';
import 'payment_indicator.dart';
import 'transit_categories.dart';
import 'transit_route_map.dart';

class FareMatrixTab extends StatefulWidget {
  const FareMatrixTab({super.key, this.active = false});

  final bool active;

  @override
  State<FareMatrixTab> createState() => _FareMatrixTabState();
}

class _FareMatrixTabState extends State<FareMatrixTab> {
  // ── Interaction state ────────────────────────────────────────────────────
  FareCategory _category = FareCategory.lrt1;
  FareType _fareType = FareType.singleJourney;
  String? _origin;
  String? _destination;

  // ── Render gating ───────────────────────────────────────────────────────
  /// False on first frame (shows skeletons), flips true after the first
  /// post-frame callback so the real widgets mount on frame 2.
  bool _contentReady = false;

  /// Latches true the first time the tab is active. Prevents network image
  /// fetch until the user actually opens the Routes tab.
  bool _imagesUnlocked = false;

  @override
  void initState() {
    super.initState();
    _imagesUnlocked = widget.active;
    // Defer real content mount to the next frame so the first frame renders
    // only lightweight skeletons (no jank on tab switch).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _contentReady = true);
    });
  }

  @override
  void didUpdateWidget(covariant FareMatrixTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_imagesUnlocked) {
      setState(() => _imagesUnlocked = true);
    }
  }

  void _setCategory(FareCategory c) {
    if (c == _category) return;
    setState(() => _category = c);
  }

  void _swapStations() {
    setState(() {
      final tmp = _origin;
      _origin = _destination;
      _destination = tmp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final topOffset = screenH * 0.07;
    // search bar (~52) + gap (12) + toggle (~40) + breathing room (20)
    final overlayH = topOffset + 52 + 12 + 40 + 20;

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        // Clear the floating search bar + mode toggle overlay.
        SliverToBoxAdapter(child: SizedBox(height: overlayH)),

        // ── Fare Matrix description card ─────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _contentReady
                ? const FareMatrixDesc()
                : const SkeletonBox(height: 180, borderRadius: 20),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Transit category chips (LRT-1, LRT-2, MRT) ──────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _contentReady
                ? TransitCategoryChips(
                    selected: _category,
                    onChanged: _setCategory,
                  )
                : const SkeletonBox(height: 44, borderRadius: 16),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Payment indicator (Stored Value / Single Journey / Discounted)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _contentReady
                ? PaymentIndicator(
                    selected: _fareType,
                    onChanged: (t) => setState(() => _fareType = t),
                  )
                : const SkeletonBox(height: 48, borderRadius: 20),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Check Your Fare card ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _contentReady
                ? CheckFareCard(
                    origin: _origin,
                    destination: _destination,
                    onOriginChanged: (s) => setState(() => _origin = s),
                    onDestinationChanged: (s) =>
                        setState(() => _destination = s),
                    onSwap: _swapStations,
                    fareType: _fareType,
                    category: _category,
                  )
                : const SkeletonBox(height: 260, borderRadius: 20),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 28)),

        // ── Transit info card (train photo — network image) ──────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _contentReady
                ? TransitInfoCard(
                    category: _category,
                    loadImage: _imagesUnlocked,
                  )
                : const SkeletonBox(height: 240, borderRadius: 20),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // ── Rail transit route map (only for LRT/MRT) ────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _contentReady ? const TransitRouteMap() : const SizedBox.shrink(),
          ),
        ),

        // Bottom dead space so last card isn't flush with navbar.
        SliverToBoxAdapter(child: SizedBox(height: screenH * 0.15)),
      ],
    );
  }
}
