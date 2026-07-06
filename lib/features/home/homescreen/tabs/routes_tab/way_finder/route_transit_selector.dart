import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/widgets/asset_icon.dart';

/// The three travel modes available for a route preview.
enum TravelMode { drive, transit, walk }

/// Display label for a [TravelMode].
String travelModeLabel(TravelMode m) => switch (m) {
      TravelMode.drive => 'Drive',
      TravelMode.transit => 'Transit',
      TravelMode.walk => 'Walk',
    };

/// Icon asset path for a [TravelMode].
String travelModeIcon(TravelMode m) => switch (m) {
      TravelMode.drive => 'public/assets/icons/car_icon.png',
      TravelMode.transit => 'public/assets/icons/train_icon.png',
      TravelMode.walk => 'public/assets/icons/walk_icon.png',
    };

/// "Route • Preview" header with a Clear action, plus a row of
/// Drive / Transit / Walk mode chips.
class RouteTransitSelector extends StatelessWidget {
  const RouteTransitSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.onClear,
  });

  final TravelMode selected;
  final ValueChanged<TravelMode> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header: "Route • Preview" + Clear ────────────────────────────
        Row(
          children: [
            const Text(
              'Route',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppColors.textDark,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '•',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Text(
              'Preview',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: AppColors.textDark.withValues(alpha: 0.5),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_rounded,
                      size: 14,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Clear',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Drive / Transit / Walk chips ─────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < TravelMode.values.length; i++) ...[
              if (i != 0) const SizedBox(width: 8),
              _TravelModeChip(
                mode: TravelMode.values[i],
                selected: TravelMode.values[i] == selected,
                onTap: () => onChanged(TravelMode.values[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TravelModeChip extends StatelessWidget {
  const _TravelModeChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TravelMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.white : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssetIcon(
              travelModeIcon(mode),
              size: 16,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              travelModeLabel(mode),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
