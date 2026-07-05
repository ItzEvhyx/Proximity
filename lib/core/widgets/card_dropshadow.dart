import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reusable card with a subtle offset drop-shadow — zero blur, zero GPU
/// compositing cost during scroll. Use this anywhere a white content card
/// with depth is needed (fare matrix, route finder, history, etc.).
///
/// The shadow is a solid-color rectangle offset 4px right and 4px down,
/// with NO [blurRadius]. This means the rendering backend can paint it as a
/// single flat rect (no Gaussian convolution, no saveLayer, no extra
/// compositing pass) which keeps the raster thread free during scroll.
///
/// Usage:
/// ```dart
/// DropShadowCard(
///   child: Column(children: [...]),
/// )
/// ```
class DropShadowCard extends StatelessWidget {
  const DropShadowCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0x10000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000), // ~8% black
            offset: Offset(4, 4),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
