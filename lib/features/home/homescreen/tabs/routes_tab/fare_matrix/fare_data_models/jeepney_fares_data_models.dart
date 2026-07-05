// jeepney_fares_data_models.dart
//
// Static fare data for Philippine jeepneys (traditional and modern).
// Distance-based computation: base fare for first 4 km + per-km rate beyond.
//
// Sources:
//   - LTFRB fare order effective March 19, 2026
//   - https://www.sunstar.com.ph/manila/ltfrb-approves-fare-increase-on-all-pujs
//   - https://www.pna.gov.ph/articles/1271201
//
// Discount: Students, Senior Citizens, and PWDs get 20% off total fare.

/// Jeepney subtypes with different fare structures.
enum JeepneyType { traditional, modern }

extension JeepneyTypeDisplay on JeepneyType {
  String get label => switch (this) {
        JeepneyType.traditional => 'Traditional Jeepney',
        JeepneyType.modern => 'Modern Jeepney',
      };

  String get shortLabel => switch (this) {
        JeepneyType.traditional => 'Traditional',
        JeepneyType.modern => 'Modern',
      };
}

/// Fare configuration for a jeepney type.
class JeepneyFareConfig {
  /// Base fare covering the first [baseDistanceKm] km.
  final double baseFare;

  /// Distance (km) covered by the base fare.
  final double baseDistanceKm;

  /// Additional charge per km beyond [baseDistanceKm].
  final double perKmRate;

  /// Discount multiplier for students/seniors/PWDs (0.80 = 20% off).
  final double discountMultiplier;

  const JeepneyFareConfig({
    required this.baseFare,
    required this.baseDistanceKm,
    required this.perKmRate,
    this.discountMultiplier = 0.80,
  });

  /// Computes the regular fare for a given distance in km.
  double regularFare(double distanceKm) {
    if (distanceKm <= baseDistanceKm) return baseFare;
    final extraKm = distanceKm - baseDistanceKm;
    return baseFare + (extraKm * perKmRate);
  }

  /// Computes the discounted fare (20% off regular).
  double discountedFare(double distanceKm) {
    return regularFare(distanceKm) * discountMultiplier;
  }
}

/// Central access point for jeepney fare data.
class JeepneyFareData {
  JeepneyFareData._();

  // ── Traditional Jeepney ─────────────────────────────────────────────────
  // Base fare (1-4 km): ₱14.00 | Per succeeding km: ₱2.00
  static const traditional = JeepneyFareConfig(
    baseFare: 14.00,
    baseDistanceKm: 4.0,
    perKmRate: 2.00,
  );

  // ── Modern Jeepney ─────────────────────────────────────────────────────
  // Base fare (1-4 km): ₱17.00 | Per succeeding km: ₱2.30
  static const modern = JeepneyFareConfig(
    baseFare: 17.00,
    baseDistanceKm: 4.0,
    perKmRate: 2.30,
  );

  /// Returns the fare config for a given jeepney type.
  static JeepneyFareConfig configFor(JeepneyType type) => switch (type) {
        JeepneyType.traditional => traditional,
        JeepneyType.modern => modern,
      };
}
