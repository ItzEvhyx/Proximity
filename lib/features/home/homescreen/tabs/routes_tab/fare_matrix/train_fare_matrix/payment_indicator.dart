import 'package:flutter/material.dart';

import '../../../../../../../core/theme/app_colors.dart';

/// Fare type categories — determines the fare column shown.
enum FareType { storedValue, singleJourney, discounted }

/// Display label for a [FareType].
String fareTypeLabel(FareType t) => switch (t) {
      FareType.storedValue => 'Stored Value',
      FareType.singleJourney => 'Single Journey',
      FareType.discounted => 'Discounted 50%',
    };

/// Pill-shaped segmented row for selecting fare type.
/// No animations — instant color swap on tap via parent setState.
class PaymentIndicator extends StatelessWidget {
  const PaymentIndicator({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final FareType selected;
  final ValueChanged<FareType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (final type in FareType.values)
            Expanded(child: _Pill(type: type, selected: type == selected, onTap: () => onChanged(type))),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final FareType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    offset: Offset(0, 2),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Text(
          fareTypeLabel(type),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: selected ? AppColors.textDark : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
