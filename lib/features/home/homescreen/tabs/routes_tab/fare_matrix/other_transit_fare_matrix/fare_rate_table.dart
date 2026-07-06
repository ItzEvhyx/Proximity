import 'package:flutter/material.dart';

import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/widgets/card_dropshadow.dart';
import '../fare_data_models/bus_fares_data_models.dart';

/// "RATE" card — shows the base fare and per-km rate at the top in green
/// pills, followed by a distance-based fare table with columns for
/// Distance, Regular, and Student/Senior/PWD.
///
/// Shared across all non-train transit types; the content is driven by the
/// [config] parameter from the data model.
class FareRateTable extends StatelessWidget {
  const FareRateTable({
    super.key,
    required this.config,
    this.baseLabel,
    this.perUnitLabel,
  });

  final BusFareConfig config;

  /// Custom label for the base fare pill. If null, uses the default
  /// "Base (1–X km)" format.
  final String? baseLabel;

  /// Custom label for the per-unit pill. If null, uses "Per succeeding km".
  final String? perUnitLabel;

  @override
  Widget build(BuildContext context) {
    return DropShadowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'RATE',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          // Green rate pills
          _buildRatePills(),
          const SizedBox(height: 12),
          // Table header
          _buildTableHeader(),
          const SizedBox(height: 4),
          // Table rows (sample distances)
          ..._buildTableRows(),
        ],
      ),
    );
  }

  Widget _buildRatePills() {
    if (config.isFlat) {
      // Flat-rate types only show per-km
      return Row(
        children: [
          Expanded(
            child: _RatePill(
              label: 'Flat rate per km',
              value: '₱${config.flatPerKmRate.toStringAsFixed(2)}',
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _RatePill(
            label: baseLabel ?? 'Base (1–${config.baseDistanceKm.toInt()} km)',
            value: '₱${config.baseFare.toStringAsFixed(2)}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RatePill(
            label: perUnitLabel ?? 'Per succeeding km',
            value: '₱${config.perKmRate.toStringAsFixed(2)}',
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Distance',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                color: AppColors.textDark,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Regular',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                color: AppColors.primary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Student/Senior/PWD',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTableRows() {
    // Generate sample distances for the table
    final distances = <double>[5, 10, 15, 20, 30, 50];

    return [
      for (var i = 0; i < distances.length; i++) ...[
        _TableRow(
          distance: distances[i],
          regular: config.regularFare(distances[i]),
          discounted: config.discountedFare(distances[i]),
        ),
        if (i < distances.length - 1)
          const Divider(height: 1, color: Color(0xFFE8E8E8)),
      ],
    ];
  }
}

class _RatePill extends StatelessWidget {
  const _RatePill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.distance,
    required this.regular,
    required this.discounted,
  });

  final double distance;
  final double regular;
  final double discounted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '${distance.toInt()} km',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₱${regular.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '₱${discounted.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
