import 'package:flutter/material.dart';

import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/widgets/asset_icon.dart';
import '../transit_type_selector.dart';

/// Placeholder content shown when a non-train transit type is selected.
/// Shows an empty state with the transit name — content for these modes
/// will be implemented separately since they have entirely different
/// structures from the rail transit fare matrix.
class OtherTransitPlaceholder extends StatelessWidget {
  const OtherTransitPlaceholder({super.key, required this.type});

  final TransitType type;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssetIcon(
              transitTypeIcon(type),
              size: 56,
              color: AppColors.hintGrey,
            ),
            const SizedBox(height: 16),
            Text(
              transitTypeLabel(type),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fare information for ${transitTypeLabel(type)} is coming soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                height: 1.4,
                color: AppColors.textDark.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
