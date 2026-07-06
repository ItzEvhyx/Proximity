import 'package:flutter/material.dart';
import 'package:proximity/core/theme/app_colors.dart';
import 'package:proximity/core/widgets/asset_icon.dart';
import 'package:proximity/core/widgets/card_dropshadow.dart';
import 'package:proximity/features/home/homescreen/tabs/routes_tab/fare_matrix/train_fare_matrix/payment_indicator.dart';
import 'package:proximity/features/home/homescreen/tabs/routes_tab/fare_matrix/fare_data_models/train_fares_data_models.dart';
import 'package:proximity/features/home/homescreen/tabs/routes_tab/fare_matrix/train_fare_matrix/transit_categories.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MAPPING: FareCategory → RailLine
// ═══════════════════════════════════════════════════════════════════════════

RailLine _toRailLine(FareCategory c) => switch (c) {
      FareCategory.lrt1 => RailLine.lrt1,
      FareCategory.lrt2 => RailLine.lrt2,
      FareCategory.mrt => RailLine.mrt3,
    };

/// Returns the station name list for a [FareCategory] from the data model.
List<String> stationsForCategory(FareCategory category) {
  return RailFareData.matrixFor(_toRailLine(category)).stationNames;
}

/// Computes the fare between two stations for the given category and fare type.
/// Returns null if either station is not selected.
int? computeFare({
  required FareCategory category,
  required FareType fareType,
  required String? origin,
  required String? destination,
}) {
  if (origin == null || destination == null) return null;
  if (origin == destination) return 0;

  final line = _toRailLine(category);
  final matrix = RailFareData.matrixFor(line);

  try {
    final baseFare = matrix.fareBetween(origin, destination);
    switch (fareType) {
      case FareType.storedValue:
        return baseFare;
      case FareType.singleJourney:
        // Single journey tickets are the same base fare for all 3 lines
        // (no stored-value discount applies — this IS the regular fare).
        return baseFare;
      case FareType.discounted:
        // 50% discount for students/seniors/PWDs, rounded up.
        return (baseFare / 2).ceil();
    }
  } catch (_) {
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHECK FARE CARD
// ═══════════════════════════════════════════════════════════════════════════

/// "CHECK YOUR FARE" card — origin/destination selectors (open modal),
/// swap button, fare result, and sources footnote.
class CheckFareCard extends StatelessWidget {
  const CheckFareCard({
    super.key,
    required this.origin,
    required this.destination,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onSwap,
    required this.fareType,
    required this.category,
  });

  final String? origin;
  final String? destination;
  final ValueChanged<String?> onOriginChanged;
  final ValueChanged<String?> onDestinationChanged;
  final VoidCallback onSwap;
  final FareType fareType;
  final FareCategory category;

  @override
  Widget build(BuildContext context) {
    final stations = stationsForCategory(category);
    final fare = computeFare(
      category: category,
      fareType: fareType,
      origin: origin,
      destination: destination,
    );

    return DropShadowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHECK YOUR FARE',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: 0.2,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StationField(
                  label: 'From',
                  value: origin,
                  category: category,
                  stations: stations,
                  onSelected: onOriginChanged,
                ),
              ),
              const SizedBox(width: 10),
              _SwapButton(onTap: onSwap),
              const SizedBox(width: 10),
              Expanded(
                child: _StationField(
                  label: 'To',
                  value: destination,
                  category: category,
                  stations: stations,
                  onSelected: onDestinationChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FareResult(fare: fare, fareType: fareType, category: category),
          const SizedBox(height: 12),
          // Sources footnote
          Text(
            'Sources: LRTA official fare matrices (lrta.gov.ph) · '
            'LRT‑2 Stored Value Matrix, effective Aug 2, 2023 · '
            'LRMC LRT‑1 New Stored Value Fare Matrix, effective Apr 2, 2025 · '
            'DOTr MRT‑3 Regular Fare Matrix.\n'
            'Fares shown are regular (undiscounted) rates for reference — '
            'always confirm against the posted station fare matrix.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              height: 1.4,
              color: AppColors.textDark.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATION FIELD (tap to open modal)
// ═══════════════════════════════════════════════════════════════════════════

class _StationField extends StatelessWidget {
  const _StationField({
    required this.label,
    required this.value,
    required this.category,
    required this.stations,
    required this.onSelected,
  });

  final String label;
  final String? value;
  final FareCategory category;
  final List<String> stations;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppColors.textDark.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final selected = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _StationPickerModal(
                category: category,
                stations: stations,
                currentValue: value,
              ),
            );
            if (selected != null) onSelected(selected);
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1F000000)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? 'Select',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: value != null
                          ? AppColors.textDark
                          : AppColors.textDark.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textDark.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATION PICKER MODAL
// ═══════════════════════════════════════════════════════════════════════════

class _StationPickerModal extends StatefulWidget {
  const _StationPickerModal({
    required this.category,
    required this.stations,
    required this.currentValue,
  });

  final FareCategory category;
  final List<String> stations;
  final String? currentValue;

  @override
  State<_StationPickerModal> createState() => _StationPickerModalState();
}

class _StationPickerModalState extends State<_StationPickerModal> {
  late String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentValue;
  }

  @override
  Widget build(BuildContext context) {
    final modalHeight = MediaQuery.sizeOf(context).height * 0.55;

    return Container(
      height: modalHeight,
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
          const SizedBox(height: 12),

          // ── Line name header ───────────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const AssetIcon(
                  'public/assets/icons/train_icon.png',
                  size: 18,
                  color: AppColors.white,
                ),
                const SizedBox(width: 10),
                Text(
                  fareCategoryLabel(widget.category),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.stations.length} stations',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Station list with radio buttons ────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.stations.length,
              itemBuilder: (context, index) {
                final station = widget.stations[index];
                final isSelected = station == _selected;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final nav = Navigator.of(context);
                    setState(() => _selected = station);
                    Future.delayed(const Duration(milliseconds: 150), () {
                      if (mounted) nav.pop(station);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.hintGrey,
                              width: isSelected ? 2 : 1.5,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            station,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SWAP BUTTON & FARE RESULT
// ═══════════════════════════════════════════════════════════════════════════

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 22),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const AssetIcon(
              'public/assets/icons/revert_icon.png',
              size: 20,
              color: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _FareResult extends StatelessWidget {
  const _FareResult({
    required this.fare,
    required this.fareType,
    required this.category,
  });

  final int? fare;
  final FareType fareType;
  final FareCategory category;

  static final Color _end = Color.lerp(AppColors.primary, Colors.black, 0.08)!;

  @override
  Widget build(BuildContext context) {
    // Format the fare display
    final String fareDisplay;
    if (fare == null) {
      fareDisplay = '—';
    } else if (fare == 0) {
      fareDisplay = '₱0';
    } else {
      fareDisplay = '₱$fare';
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary, _end],
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fare',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fareDisplay,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${fareTypeLabel(fareType)} • ${fareCategoryLabel(category)}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
