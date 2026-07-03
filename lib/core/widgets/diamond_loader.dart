import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A diamond (rounded square outline) that continuously rotates while pulsing
/// smaller then back to full size once per rotation. Shared by the OTP dialogs
/// and the contribution loading screen.
class DiamondLoader extends StatefulWidget {
  const DiamondLoader({
    super.key,
    this.size = 64,
    this.color = AppColors.primary,
    this.strokeWidth = 3,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  State<DiamondLoader> createState() => _DiamondLoaderState();
}

class _DiamondLoaderState extends State<DiamondLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.65)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.65, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: widget.size,
          width: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.size * 0.19),
            border: Border.all(color: widget.color, width: widget.strokeWidth),
          ),
        ),
      ),
    );
  }
}
