import 'package:flutter/material.dart';

/// Central color palette. Change a value here to update it across the app.
class AppColors {
  const AppColors._();

  // ── Brand greens ──────────────────────────────────────────────────────
  /// Dominant brand green (#019D43) used across all green surfaces.
  static const Color primary = Color(0xFF019D43);

  /// Darker green for the subtle fade at the top of green screens.
  static const Color greenDark = Color(0xFF009232);

  /// Vertical background gradient for green screens; the darker green is
  /// confined to the top ~18% so the rest reads as solid [primary].
  static const LinearGradient greenBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [greenDark, primary],
    stops: [0.0, 0.18],
  );

  /// Solid backdrop shadow behind the title/logo.
  static const Color titleShadow = Color(0xFF046A2C);

  // ── Neutrals ──────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF111111);
  static const Color textGrey = Color(0xFF7A7A7A);
  static const Color hintGrey = Color(0xFF9E9E9E);

  /// Muted fill and hairline border for panels (e.g. password checklist).
  static const Color surfaceMuted = Color(0xFFF6F6F6);
  static const Color border = Color(0xFFE0E0E0);

  // ── Feedback / overlay ─────────────────────────────────────────────────
  /// Error accent for invalid fields and error snackbars (Colors.redAccent).
  static const Color error = Color(0xFFFF5252);

  /// Red accent for the user's current-location pin and its radar rings.
  static const Color currentLocation = Color(0xFFE53935);

  /// Dialog barrier scrim (Colors.black26).
  static const Color scrim = Color(0x42000000);
}
