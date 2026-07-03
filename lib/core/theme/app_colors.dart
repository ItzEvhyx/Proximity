import 'package:flutter/material.dart';

/// Central palette for the app. Tweak these to adjust the brand greens
/// everywhere at once.
class AppColors {
  const AppColors._();

  /// Background / primary brand green (exact design hex #019D43). This is the
  /// dominant color you should see across green surfaces.
  static const Color primary = Color(0xFF019D43);

  /// Darker green used only for a subtle fade at the very top of green screens.
  static const Color greenDark = Color(0xFF009232);

  /// Vertical background gradient shared by all green screens. The darker green
  /// is confined to the top ~18% so the rest of the screen is solid [primary]
  /// (#019D43) — i.e. the visible green matches the design instead of reading
  /// as the darker fade colour.
  static const LinearGradient greenBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [greenDark, primary],
    stops: [0.0, 0.18],
  );

  /// Kept for existing references (top/bottom of the green gradient).
  static const Color gradientTop = greenDark;
  static const Color gradientBottom = primary;

  /// Solid (non-blurred) backdrop shadow behind the title/logo.
  static const Color titleShadow = Color(0xFF046A2C);

  static const Color textDark = Color(0xFF111111);
  static const Color textGrey = Color(0xFF7A7A7A);
  static const Color hintGrey = Color(0xFF9E9E9E);
}
