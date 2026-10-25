import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/widgets/asset_icon.dart';

/// All transit types available in the fare matrix.
enum TransitType { lrt1, lrt2, mrt, jeepney, bus, uvExpress, tricycle }

/// Whether a [TransitType] is a train/rail transit.
bool isTrainTransit(TransitType t) => switch (t) {
  TransitType.lrt1 => true,
  TransitType.lrt2 => true,
  TransitType.mrt => true,
  _ => false,
};

/// Display label for a [TransitType].
String transitTypeLabel(TransitType t) => switch (t) {
  TransitType.lrt1 => 'LRT-1',
  TransitType.lrt2 => 'LRT-2',
  TransitType.mrt => 'MRT',
  TransitType.jeepney => 'Jeepney',
  TransitType.bus => 'Bus',
  TransitType.uvExpress => 'UV Express',
  TransitType.tricycle => 'Tricycle',
};

/// Icon asset path for a [TransitType].
String transitTypeIcon(TransitType t) => switch (t) {
  TransitType.lrt1 => 'public/assets/icons/train_icon.svg',
  TransitType.lrt2 => 'public/assets/icons/train_icon.svg',
  TransitType.mrt => 'public/assets/icons/train_icon.svg',
  TransitType.jeepney => 'public/assets/icons/jeepney_icon.svg',
  TransitType.bus => 'public/assets/icons/bus_icon.svg',
  TransitType.uvExpress => 'public/assets/icons/uv_express_icon.svg',
  TransitType.tricycle => 'public/assets/icons/motorcycle_icon.svg',
};

/// Horizontally scrollable row of transit type chips.
/// Shows all 7 transit types. No animations — instant state swap.
class TransitTypeSelector extends StatelessWidget {
  const TransitTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TransitType selected;
  final ValueChanged<TransitType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < TransitType.values.length; i++) ...[
            if (i != 0) const SizedBox(width: 8),
            _TransitChip(
              type: TransitType.values[i],
              selected: TransitType.values[i] == selected,
              onTap: () => onChanged(TransitType.values[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransitChip extends StatelessWidget {
  const _TransitChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final TransitType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const foreground = AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceHigh : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.textPrimary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssetIcon(transitTypeIcon(type), size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              transitTypeLabel(type),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
