import 'package:flutter/material.dart';

/// Reusable page transitions for the app.
class ScreenTransitions {
  const ScreenTransitions._();

  /// A lightweight cross-fade. Cheap to composite (only opacity animates),
  /// so it stays smooth even when the target screen is complex.
  static Route<T> fade<T>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 450),
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: RepaintBoundary(child: child),
        );
      },
    );
  }

  /// A smooth transition where the new screen fades in while sliding from the
  /// right edge toward the left (right-to-left motion).
  static Route<T> fadeRightToLeft<T>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 350),
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        );
        final slide = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curved);
        // RepaintBoundary lets the fade/slide composite a cached raster layer
        // instead of repainting the whole screen every frame -> smoother.
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: slide,
            child: RepaintBoundary(child: child),
          ),
        );
      },
    );
  }
}
