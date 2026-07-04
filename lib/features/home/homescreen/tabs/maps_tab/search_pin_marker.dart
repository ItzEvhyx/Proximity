import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// A green location pin sitting on top of an animated "radar" pulse — a set of
/// green rings that expand outward from the pin and fade, like sonar/radar
/// sweeps. Used to highlight a searched / pinned location on the map.
///
/// The widget's origin (top-left) is [size] x [size]; the pin's tip sits at the
/// horizontal center and vertical center of that box, so callers can position
/// the box centered on the target screen coordinate.
///
/// For a draggable marker the renderer composes [RadarPulse] and [MapPinGraphic]
/// directly (so only the pin captures gestures); this widget is the simple
/// non-interactive combination.
class SearchPinMarker extends StatelessWidget {
  const SearchPinMarker({
    super.key,
    this.size = 220,
    this.pinHeight = 46,
  });

  /// Side length of the square that contains the radar rings.
  final double size;

  /// Height of the green pin drawn above the anchor point.
  final double pinHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          RadarPulse(size: size),
          Transform.translate(
            offset: Offset(0, -pinHeight / 2),
            child: MapPinGraphic(height: pinHeight),
          ),
        ],
      ),
    );
  }
}

/// Animated concentric rings expanding from the center and fading out. Set
/// [active] to false to freeze the pulse (e.g. once a location is locked).
class RadarPulse extends StatefulWidget {
  const RadarPulse({super.key, required this.size, this.active = true});

  final double size;
  final bool active;

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(RadarPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _RadarPainter(
            progress: _controller.value,
            active: widget.active,
          ),
        ),
      ),
    );
  }
}

/// Paints concentric rings that expand from the center and fade out, staggered
/// so a new ring is always emerging as the previous ones dissipate.
class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress, required this.active});

  /// Loops 0 -> 1.
  final double progress;
  final bool active;

  static const int _ringCount = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    if (active) {
      for (var i = 0; i < _ringCount; i++) {
        // Stagger each ring by an even fraction of the cycle.
        final t = (progress + i / _ringCount) % 1.0;
        final radius = maxRadius * t;
        if (radius <= 0) continue;

        // Fade out as the ring grows.
        final opacity = (1.0 - t) * 0.55;
        final strokePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = AppColors.primary.withValues(alpha: opacity);
        canvas.drawCircle(center, radius, strokePaint);

        // Soft filled wash inside the leading (smallest) ring.
        if (i == 0) {
          final fillPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = AppColors.primary.withValues(alpha: opacity * 0.25);
          canvas.drawCircle(center, radius, fillPaint);
        }
      }
    } else {
      // Locked: a single soft static halo instead of the moving sweep.
      final haloPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.primary.withValues(alpha: 0.12);
      canvas.drawCircle(center, maxRadius * 0.32, haloPaint);
    }

    // Solid dot at the very center under the pin.
    final dotPaint = Paint()..color = AppColors.primary.withValues(alpha: 0.9);
    canvas.drawCircle(center, math.min(6, maxRadius), dotPaint);
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.active != active;
}

/// A classic teardrop map pin in the brand green with a white core, plus a soft
/// shadow. [dragging] scales it up slightly for lift feedback (anchored at the
/// tip so the point stays put); [locked] gives it a confirmed check accent.
class MapPinGraphic extends StatelessWidget {
  const MapPinGraphic({
    super.key,
    this.height = 46,
    this.dragging = false,
    this.locked = false,
  });

  final double height;
  final bool dragging;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final h = height;
    final pin = SizedBox(
      // Square box so the glyph is never clipped; the tip sits at bottom-center.
      width: h,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Tight elliptical ground shadow directly under the pin's tip, so the
          // shadow reads as belonging to the pin rather than floating off it.
          Positioned(
            bottom: h * 0.03,
            child: Container(
              width: h * 0.30,
              height: h * 0.10,
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.all(
                  Radius.elliptical(h * 0.15, h * 0.05),
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x1F000000), blurRadius: 2.5),
                ],
              ),
            ),
          ),
          // Pin glyph (no offset drop shadow — the ground shadow does the work).
          Icon(Icons.location_on, size: h, color: AppColors.primary),
          // White core dot (or a check once locked) for a marker look.
          Positioned(
            top: h * 0.22,
            child: Container(
              width: h * 0.30,
              height: h * 0.30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
              child: locked
                  ? Icon(
                      Icons.check_rounded,
                      size: h * 0.22,
                      color: AppColors.primary,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );

    // Scale up a touch while dragging, keeping the tip (bottom center) fixed.
    return AnimatedScale(
      scale: dragging ? 1.18 : 1.0,
      duration: const Duration(milliseconds: 120),
      alignment: Alignment.bottomCenter,
      child: pin,
    );
  }
}
