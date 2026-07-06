import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';

/// Two side-by-side green cards showing "Est. time" and "Distance" for a
/// route preview. Compact: label + value + unit all on one line per card.
class EtaDistanceCards extends StatelessWidget {
  const EtaDistanceCards({
    super.key,
    required this.etaValue,
    required this.etaUnit,
    required this.distanceValue,
    required this.distanceUnit,
  });

  final String etaValue;
  final String etaUnit;
  final String distanceValue;
  final String distanceUnit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfoCard(
            label: 'Est. time',
            value: etaValue,
            unit: etaUnit,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _InfoCard(
            label: 'Distance',
            value: distanceValue,
            unit: distanceUnit,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    height: 1.0,
                    color: AppColors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.white,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
