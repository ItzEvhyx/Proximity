import 'package:flutter/material.dart';

import '../../../../../../../core/theme/app_colors.dart';

/// Generic wrap-style payment/category indicator for non-train transits.
/// Renders a 3-column grid of chips.
///
/// Each chip shows a label; the selected chip gets a white background with
/// dark text, unselected chips show primary-colored text on a transparent
/// background. Switching animates smoothly.
class OtherTransitPaymentIndicator<T> extends StatelessWidget {
  const OtherTransitPaymentIndicator({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    // Build rows of 3 chips each
    final rows = <List<T>>[];
    for (var i = 0; i < values.length; i += 3) {
      rows.add(values.sublist(i, i + 3 > values.length ? values.length : i + 3));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const SizedBox(height: 4),
            Row(
              children: [
                for (var c = 0; c < rows[r].length; c++) ...[
                  if (c > 0) const SizedBox(width: 4),
                  Expanded(
                    child: _PaymentChip(
                      label: labelOf(rows[r][c]),
                      selected: rows[r][c] == selected,
                      onTap: () => onChanged(rows[r][c]),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
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
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            height: 1.2,
            color: selected ? AppColors.textDark : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
