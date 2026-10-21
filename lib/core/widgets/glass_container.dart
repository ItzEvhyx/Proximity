import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Shared translucent surface for controls that float above the map.
///
/// This deliberately uses a painted glass treatment instead of a live
/// [BackdropFilter]. A backdrop blur must re-sample every pixel behind it on
/// each map frame or list scroll, which made the always-visible navigation bar
/// a costly compositor layer on every tab.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.radius = AppRadii.pill,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.tint = .10,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double tint;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: const [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: shape,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.textPrimary.withValues(alpha: tint + .04),
                AppColors.textPrimary.withValues(
                  alpha: (tint - .07).clamp(0, 1),
                ),
              ],
            ),
            border: Border.all(color: const Color(0x59FFFFFF)),
          ),
          child: child,
        ),
      ),
    );
  }
}
