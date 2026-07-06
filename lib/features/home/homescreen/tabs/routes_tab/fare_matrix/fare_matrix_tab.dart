// lib/features/home/homescreen/tabs/routes_tab/fare_matrix/fare_matrix_tab.dart
//
// ── Architecture ──────────────────────────────────────────────────────────────
//
// Global fare matrix tab orchestrator. Hosts the transit type selector
// (LRT-1, LRT-2, MRT, Jeepney, Bus, UV Express, Tricycle) and delegates
// to the appropriate content:
//
// • Train transits (LRT-1/2, MRT) → full rail fare matrix content
// • Other transits (Jeepney, Bus, UV Express, Tricycle) → empty placeholder
//
// The fare matrix tab itself stays globally accessible (not inside
// train_fare_matrix/) since all transit types share it as their entry point.
//
// Mirrors the SleepTrackerScreen zero-animation pattern:
// • CustomScrollView + SliverToBoxAdapter for each section.
// • ClampingScrollPhysics — no overscroll bounce compositing.
// • ZERO in-widget animations. State renders instantly via setState.
// • Deferred content mount via _contentReady flag.
// • Network image gated behind _imagesUnlocked.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../../../core/skeleton_loading/skeleton_loading.dart';
import 'fare_data_models/bus_fares_data_models.dart';
import 'fare_data_models/jeepney_fares_data_models.dart';
import 'fare_data_models/tricycle_fares_data_models.dart';
import 'fare_data_models/uv_fares_data_models.dart';
import 'fare_matrix_desc.dart';
import 'other_transit_fare_matrix/fare_rate_table.dart';
import 'other_transit_fare_matrix/how_it_works.dart';
import 'other_transit_fare_matrix/important_notes.dart';
import 'other_transit_fare_matrix/other_transit_placeholder.dart';
import 'other_transit_fare_matrix/payment_indicator.dart';
import 'train_fare_matrix/check_fare_card.dart';
import 'train_fare_matrix/payment_indicator.dart' as train;
import 'train_fare_matrix/transit_categories.dart';
import 'train_fare_matrix/transit_route_map.dart';
import 'transit_type_selector.dart';

class FareMatrixTab extends StatefulWidget {
  const FareMatrixTab({super.key, this.active = false});

  final bool active;

  @override
  State<FareMatrixTab> createState() => _FareMatrixTabState();
}

class _FareMatrixTabState extends State<FareMatrixTab> {
  // ── Interaction state ────────────────────────────────────────────────────
  TransitType _transitType = TransitType.lrt1;

  // Train-specific state (only relevant when a rail transit is selected)
  FareCategory _category = FareCategory.lrt1;
  train.FareType _fareType = train.FareType.singleJourney;
  String? _origin;
  String? _destination;

  // Bus-specific state
  BusType _busType = BusType.cityOrdinary;

  // UV Express-specific state
  UvExpressType _uvType = UvExpressType.traditional;

  // Tricycle-specific state
  TricycleType _tricycleType = TricycleType.tricycle;

  // Jeepney-specific state
  JeepneyType _jeepneyType = JeepneyType.traditional;

  // ── Render gating ───────────────────────────────────────────────────────
  bool _contentReady = false;
  bool _imagesUnlocked = false;

  @override
  void initState() {
    super.initState();
    _imagesUnlocked = widget.active;
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

  void _setTransitType(TransitType t) {
    if (t == _transitType) return;
    setState(() {
      _transitType = t;
      // Sync train-specific FareCategory when switching between rail lines
      if (isTrainTransit(t)) {
        _category = _transitTypeToFareCategory(t);
        // Reset station selections when switching lines
        _origin = null;
        _destination = null;
      }
    });
  }

  FareCategory _transitTypeToFareCategory(TransitType t) => switch (t) {
        TransitType.lrt1 => FareCategory.lrt1,
        TransitType.lrt2 => FareCategory.lrt2,
        TransitType.mrt => FareCategory.mrt,
        _ => _category, // keep current for non-train
      };

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

        // ── Transit type selector (all 7 types) ─────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _contentReady
                ? TransitTypeSelector(
                    selected: _transitType,
                    onChanged: _setTransitType,
                  )
                : const SkeletonBox(height: 44, borderRadius: 16),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Content: train fare matrix OR other transit placeholder ───────
        if (isTrainTransit(_transitType))
          ..._buildTrainContent()
        else
          ..._buildOtherTransitContent(),

        // Bottom dead space so last card isn't flush with navbar.
        SliverToBoxAdapter(child: SizedBox(height: screenH * 0.15)),
      ],
    );
  }

  /// Builds the full train fare matrix content (payment indicator, check
  /// fare card, transit info card, route map).
  List<Widget> _buildTrainContent() {
    return [
      // ── Payment indicator (Stored Value / Single Journey / Discounted)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? train.PaymentIndicator(
                  selected: _fareType,
                  onChanged: (t) => setState(() => _fareType = t),
                )
              : const SkeletonBox(height: 48, borderRadius: 20),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 16)),

      // ── Check Your Fare card ───────────────────────────────────────────
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

      const SliverToBoxAdapter(child: SizedBox(height: 16)),

      // ── Rail transit route map ─────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child:
              _contentReady ? TransitRouteMap(category: _category) : const SizedBox.shrink(),
        ),
      ),
    ];
  }

  /// Builds the placeholder content for non-train transit types.
  List<Widget> _buildOtherTransitContent() {
    if (_transitType == TransitType.bus) {
      return _buildBusContent();
    }
    if (_transitType == TransitType.uvExpress) {
      return _buildUvExpressContent();
    }
    if (_transitType == TransitType.tricycle) {
      return _buildTricycleContent();
    }
    if (_transitType == TransitType.jeepney) {
      return _buildJeepneyContent();
    }

    // Other transits show placeholder for now
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: _contentReady
            ? OtherTransitPlaceholder(type: _transitType)
            : const SizedBox.shrink(),
      ),
    ];
  }

  /// Builds the bus fare content: payment indicator (bus types), how it
  /// works card, fare rate table, and important notes.
  List<Widget> _buildBusContent() {
    final config = BusFareData.configFor(_busType);

    return [
      // ── Bus type selector (City Ordinary, Aircon, Provincial, etc.) ────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? OtherTransitPaymentIndicator<BusType>(
                  values: BusType.values,
                  selected: _busType,
                  labelOf: (t) => t.chipLabel,
                  onChanged: (t) => setState(() => _busType = t),
                )
              : const SkeletonBox(height: 80, borderRadius: 20),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 12)),

      // ── How It Works card ──────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? const HowItWorksCard(points: BusFareData.howItWorks)
              : const SkeletonBox(height: 180, borderRadius: 20),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 12)),

      // ── Fare Rate Table ────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? FareRateTable(config: config)
              : const SkeletonBox(height: 320, borderRadius: 20),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 12)),

      // ── Important Notes ────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? const ImportantNotesCard(notes: BusFareData.importantNotes)
              : const SkeletonBox(height: 120, borderRadius: 20),
        ),
      ),
    ];
  }

  /// Builds the UV Express fare content: payment indicator (Traditional /
  /// Modernized), how it works card, fare rate table, and important notes.
  List<Widget> _buildUvExpressContent() {
    final config = UvExpressFareData.configFor(_uvType).toBusFareConfig();

    return [
      // ── UV Express type selector (Traditional / Modernized) ────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? OtherTransitPaymentIndicator<UvExpressType>(
                  values: UvExpressType.values,
                  selected: _uvType,
                  labelOf: (t) => t.chipLabel,
                  onChanged: (t) => setState(() => _uvType = t),
                )
              : const SkeletonBox(height: 48, borderRadius: 20),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 12)),

      // ── How It Works card ──────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? const HowItWorksCard(points: UvExpressFareData.howItWorks)
              : const SkeletonBox(height: 140, borderRadius: 20),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 12)),

      // ── Fare Rate Table ────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? FareRateTable(config: config)
              : const SkeletonBox(height: 320, borderRadius: 20),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 12)),

      // ── Important Notes ────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? const ImportantNotesCard(notes: UvExpressFareData.importantNotes)
              : const SkeletonBox(height: 120, borderRadius: 20),
        ),
      ),
    ];
  }

  /// Builds the Tricycle fare content: payment indicator (Tricycle / E-Trike),
  /// how it works card, fare rate table, and important notes.
  List<Widget> _buildTricycleContent() {
    final config = TricycleFareData.configFor(_tricycleType).toBusFareConfig();

    return [
      // ── Tricycle type selector (Tricycle / E-Trike) ────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? OtherTransitPaymentIndicator<TricycleType>(
                  values: TricycleType.values,
                  selected: _tricycleType,
                  labelOf: (t) => t.chipLabel,
                  onChanged: (t) => setState(() => _tricycleType = t),
                )
              : const SkeletonBox(height: 48, borderRadius: 20),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 12)),

      // ── How It Works card ──────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? const HowItWorksCard(points: TricycleFareData.howItWorks)
              : const SkeletonBox(height: 120, borderRadius: 20),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 12)),

      // ── Fare Rate Table ────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? FareRateTable(
                  config: config,
                  baseLabel: 'First 1 km',
                  perUnitLabel: 'Per succeeding 500m',
                )
              : const SkeletonBox(height: 320, borderRadius: 20),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 12)),

      // ── Important Notes ────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? const ImportantNotesCard(notes: TricycleFareData.importantNotes)
              : const SkeletonBox(height: 120, borderRadius: 20),
        ),
      ),
    ];
  }

  /// Builds the Jeepney fare content: payment indicator (Traditional /
  /// Modernized), how it works card, fare rate table, and important notes.
  List<Widget> _buildJeepneyContent() {
    final config = JeepneyFareData.configFor(_jeepneyType).toBusFareConfig();

    return [
      // ── Jeepney type selector (Traditional / Modernized) ───────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? OtherTransitPaymentIndicator<JeepneyType>(
                  values: JeepneyType.values,
                  selected: _jeepneyType,
                  labelOf: (t) => t.chipLabel,
                  onChanged: (t) => setState(() => _jeepneyType = t),
                )
              : const SkeletonBox(height: 48, borderRadius: 20),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 12)),

      // ── How It Works card ──────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? const HowItWorksCard(points: JeepneyFareData.howItWorks)
              : const SkeletonBox(height: 160, borderRadius: 20),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 12)),

      // ── Fare Rate Table ────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? FareRateTable(config: config)
              : const SkeletonBox(height: 320, borderRadius: 20),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 12)),

      // ── Important Notes ────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _contentReady
              ? const ImportantNotesCard(notes: JeepneyFareData.importantNotes)
              : const SkeletonBox(height: 120, borderRadius: 20),
        ),
      ),
    ];
  }
}
