import 'package:flutter/material.dart';

import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/widgets/card_dropshadow.dart';
import '../fare_data_models/bus_fares_data_models.dart';

/// "HOW IT WORKS" card — shows a list of bullet points explaining the
/// fare structure. Each point has an icon and description text.
///
/// This widget is shared across all non-train transit types; the content
/// is driven by the [points] list passed in from the data model.
class HowItWorksCard extends StatelessWidget {
  const HowItWorksCard({super.key, required this.points});

  final List<HowItWorksPoint> points;

  @override
  Widget build(BuildContext context) {
    return DropShadowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: info icon + title
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 22,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'HOW IT WORKS',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Bullet points
          for (var i = 0; i < points.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _BulletPoint(point: points[i]),
          ],
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({required this.point});

  final HowItWorksPoint point;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Center(child: howItWorksIconWidget(point.icon, size: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            point.text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.4,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}
