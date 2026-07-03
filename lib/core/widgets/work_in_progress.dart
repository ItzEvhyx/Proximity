import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Blank white placeholder shown for sections that aren't built yet: a green
/// "Work in progress" heading with a short message. An optional [child] is
/// rendered below the message (e.g. the logout button on the profile tab).
class WorkInProgressView extends StatelessWidget {
  const WorkInProgressView({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.construction_rounded,
                  color: AppColors.primary,
                  size: 56,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Work in progress',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "This section is still being built. Check back soon.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.primary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (child != null) ...[
                  const SizedBox(height: 28),
                  child!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
