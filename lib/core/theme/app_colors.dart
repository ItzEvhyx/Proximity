import 'package:flutter/material.dart';

/// The single, grayscale-only palette used by Proximity.
///
/// Semantic aliases at the bottom let existing presentation widgets migrate
/// without ever reintroducing a coloured value.
class AppColors {
  const AppColors._();

  static const Color bg = Color(0xFF101010);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceRaised = Color(0xFF2C2C2C);
  static const Color surfaceHigh = Color(0xFF3A3A3A);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF7A7A7A);
  static const Color onLight = Color(0xFF101010);
  static const Color mapLand = Color(0xFF5A5A5A);
  static const Color mapWater = Color(0xFF3A3A3A);
  static const Color mapRoad = Color(0xFF8A8A8A);

  static const Color border = Color(0x14FFFFFF);
  static const Color divider = Color(0x0FFFFFFF);
  static const Color scrim = Color(0xA6000000);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceHigh, surfaceRaised],
  );
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surfaceRaised, surface],
  );

  // Temporary semantic aliases for existing feature widgets. New UI should
  // use the explicit token names above.
  // Primary actions are intentionally charcoal, not white. White remains a
  // text/icon color so it stays legible on the dark surfaces.
  static const Color primary = surfaceHigh;
  static const Color white = textPrimary;
  static const Color textDark = textPrimary;
  static const Color textGrey = textSecondary;
  static const Color hintGrey = textMuted;
  static const Color surfaceMuted = surfaceRaised;
  static const Color error = Color(0xFF747474);
  static const Color currentLocation = textPrimary;
  static const Color greenDark = surface;
  static const Color titleShadow = Color(0x59000000);
  static const LinearGradient greenBackground = surfaceGradient;
}
