import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Reusable SVG icon that can be tinted for the surface it sits on.
///
/// The app's symbols are vector assets, so they remain crisp at every size.
/// White is the default for the dark interface; callers provide a dark tint
/// when an icon is placed on a light selection pill.
class AssetIcon extends StatelessWidget {
  const AssetIcon(
    this.asset, {
    super.key,
    required this.size,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.contain,
  });

  final String asset;

  /// Default size used for both width and height when [width]/[height] are
  /// not specified.
  final double size;

  /// Optional explicit width (overrides [size] for the horizontal dimension).
  final double? width;

  /// Optional explicit height (overrides [size] for the vertical dimension).
  final double? height;

  final Color? color;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;

    return SvgPicture.asset(
      asset,
      width: w,
      height: h,
      fit: fit,
      colorFilter: ColorFilter.mode(
        color ?? AppColors.textPrimary,
        BlendMode.srcIn,
      ),
    );
  }
}
