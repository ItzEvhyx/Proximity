import 'package:flutter/material.dart';

/// A single shimmering placeholder block used for skeleton loading states.
///
/// All skeleton boxes share a single animation phase driven by the inherited
/// [_ShimmerPhase] so only one ticker runs globally regardless of how many
/// boxes are on screen.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  static const Color _base = Color(0xFFE3E6E8);
  static const Color _highlight = Color(0xFFF4F6F7);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _ShimmerBox(
        width: width,
        height: height,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Provides a shared shimmer animation to all descendant [SkeletonBox] widgets
/// using a single [AnimationController]. Wrap your skeleton layout with this.
///
/// If no [ShimmerProvider] is found in the ancestor tree, [_ShimmerBox] falls
/// back to a static grey (no animation) to avoid crashes.
class ShimmerProvider extends StatefulWidget {
  const ShimmerProvider({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerProvider> createState() => _ShimmerProviderState();
}

class _ShimmerProviderState extends State<ShimmerProvider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerPhase(controller: _controller, child: widget.child);
  }
}

/// InheritedWidget that makes the shimmer animation available to descendants.
class _ShimmerPhase extends InheritedWidget {
  const _ShimmerPhase({required this.controller, required super.child});

  final AnimationController controller;

  static AnimationController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShimmerPhase>()?.controller;
  }

  @override
  bool updateShouldNotify(covariant _ShimmerPhase oldWidget) =>
      controller != oldWidget.controller;
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    this.width,
    this.height,
    required this.borderRadius,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final controller = _ShimmerPhase.of(context);
    if (controller == null) {
      // Fallback: static placeholder when no ShimmerProvider is above us.
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: SkeletonBox._base,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = controller.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                SkeletonBox._base,
                SkeletonBox._highlight,
                SkeletonBox._base,
              ],
              stops: [
                (v - 0.3).clamp(0.0, 1.0),
                v.clamp(0.0, 1.0),
                (v + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
