import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A performance-optimized asset image for icons and small images.
///
/// The problem this solves: `Image.asset` decodes the source PNG at its
/// FULL native resolution (e.g. 300×300) into a raw RGBA bitmap, then scales
/// it down for display. A 300×300 icon shown at 24×24 still costs the full
/// 300×300 decode + memory (~360 KB in RAM), and that cost multiplies across
/// every icon on screen — causing jank during scroll.
///
/// [AssetIcon] passes `cacheWidth`/`cacheHeight` to the decoder so the image
/// is downsampled to the display size BEFORE the bitmap is created. To keep
/// icons crisp on high-DPI screens, the cache dimensions are multiplied by
/// the device pixel ratio (e.g. a 24 logical-px icon on a 3x screen decodes
/// at 72×72 instead of 300×300).
///
/// Use this anywhere a fixed-size asset icon is rendered.
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

    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ??
        ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final cacheW = (w * dpr).ceil();
    final cacheH = (h * dpr).ceil();

    return Image.asset(
      asset,
      width: w,
      height: h,
      fit: fit,
      color: color,
      cacheWidth: cacheW,
      cacheHeight: cacheH,
      gaplessPlayback: true,
    );
  }
}
