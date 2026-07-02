import 'package:flutter/material.dart';

/// Central palette for the app. Tweak these to adjust the brand greens
/// everywhere at once.
class AppColors {
  const AppColors._();

  /// Background / primary brand green.
  static const Color primary = Color(0xFF009F45);

  /// Background gradient (135°) built around the primary green.
  static const Color gradientTop = Color(0xFF009F45);
  static const Color gradientBottom = Color(0xFF008C3C);

  /// Solid (non-blurred) backdrop shadow behind the title/logo.
  static const Color titleShadow = Color(0xFF046A2C);

  static const Color textDark = Color(0xFF111111);
  static const Color textGrey = Color(0xFF7A7A7A);
  static const Color hintGrey = Color(0xFF9E9E9E);
}
