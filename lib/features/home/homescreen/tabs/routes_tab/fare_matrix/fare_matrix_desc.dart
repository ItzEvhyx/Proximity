import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';

/// Green gradient header card — "Fare Matrix" title + money icon + description.
/// Fully static, no state, no animations. Renders in a single paint pass.
class FareMatrixDesc extends StatelessWidget {
  const FareMatrixDesc({super.key});

  static final Color _gradientEnd =
      Color.lerp(AppColors.primary, Colors.black, 0.18)!;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary, _gradientEnd],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Fare Matrix',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    height: 1.1,
                    color: AppColors.white,
                  ),
                ),
                Image.asset(
                  'public/assets/icons/money_icon.png',
                  width: 32,
                  height: 32,
                  color: AppColors.white,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'A quick fare lookup tool for Metro Manila commutes — covering '
              'rail lines, buses, and other public transport options. Pick '
              'your origin and destination to instantly see the regular '
              'fare, or browse the full station-to-station matrix for stored '
              'value and single journey rates.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.4,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
