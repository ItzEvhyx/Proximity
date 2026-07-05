// tricycle_fares_data_models.dart
//
// Static fare data for Philippine tricycles and pedicabs.
// LGU-regulated (per city/municipality), NOT LTFRB.
//
// Sources:
//   - City of Manila Ordinance (in effect since Oct. 25, 2023) — used as
//     the reference example
//   - https://www.pna.gov.ph/articles/1271201
//
// Discount: Students, Senior Citizens, and PWDs get 20% off total fare
// (nationwide mandate regardless of LGU).
//
// IMPORTANT: Tricycle and pedicab fares are NOT standardized nationwide.
// Each city or municipality sets its own fare matrix through local
// ordinance, so actual rates in your area may differ significantly from
// this example. Common patterns seen across LGUs:
//   - Minimum/base fare: ₱10 – ₱25 depending on the city
//   - Per-km or per-500m increments: ₱2 – ₱10
//   - "Special trip" (private hire, whole tricycle): ~3× regular fare
//
// Check with your city's Tricycle Regulatory Unit or Traffic Management
// Office for the exact posted fare matrix in your area.

/// Tricycle / pedicab subtypes.
enum TricycleType { tricycle, pedicab, eTrike }

extension TricycleTypeDisplay on TricycleType {
  String get label => switch (this) {
        TricycleType.tricycle => 'Tricycle',
        TricycleType.pedicab => 'Pedicab',
        TricycleType.eTrike => 'E-Trike',
      };
}

/// Fare configuration for tricycles/pedicabs.
///
/// For distance-based types: first km = [baseFare], then
/// [perIncrementRate] for each [incrementMeters] beyond.
///
/// For flat-rate types (E-Trike): [flatFare] per ride regardless of
/// distance within the assigned route.
class TricycleFareConfig {
  /// Base fare covering the first km (or first increment).
  final double baseFare;

  /// Additional charge per increment beyond the first km.
  final double perIncrementRate;

  /// Size of each increment in meters (e.g. 500 = per 500m).
  final double incrementMeters;

  /// If non-zero, this is a flat fare per ride (no distance calc).
  final double flatFare;

  /// Discount multiplier for students/seniors/PWDs (0.80 = 20% off).
  final double discountMultiplier;

  /// Multiplier for special/private trips.
  final double specialTripMultiplier;

  const TricycleFareConfig({
    this.baseFare = 0,
    this.perIncrementRate = 0,
    this.incrementMeters = 500,
    this.flatFare = 0,
    this.discountMultiplier = 0.80,
    this.specialTripMultiplier = 3.0,
  });

  bool get isFlat => flatFare > 0;

  /// Computes the regular fare for a given distance in meters.
  double regularFare(double distanceMeters) {
    if (isFlat) return flatFare;
    if (distanceMeters <= 1000) return baseFare;
    final extraMeters = distanceMeters - 1000;
    final increments = (extraMeters / incrementMeters).ceil();
    return baseFare + (increments * perIncrementRate);
  }

  /// Computes the discounted fare (20% off regular).
  double discountedFare(double distanceMeters) =>
      regularFare(distanceMeters) * discountMultiplier;

  /// Special trip fare (private hire, whole tricycle).
  double specialTripFare(double distanceMeters) =>
      regularFare(distanceMeters) * specialTripMultiplier;
}

/// Central access point for tricycle fare data (Manila example).
class TricycleFareData {
  TricycleFareData._();

  // ── Tricycle / Pedicab (Manila example) ─────────────────────────────────
  // First km: ₱16.00 | Per succeeding 500m: ₱5.00
  static const tricycleManila = TricycleFareConfig(
    baseFare: 16.00,
    perIncrementRate: 5.00,
    incrementMeters: 500,
  );

  // ── E-Trike (Manila example) ───────────────────────────────────────────
  // Flat rate: ₱20.00 per passenger within approved route
  static const eTrike = TricycleFareConfig(
    flatFare: 20.00,
  );

  /// Returns the fare config for a given tricycle type (Manila defaults).
  static TricycleFareConfig configFor(TricycleType type) => switch (type) {
        TricycleType.tricycle => tricycleManila,
        TricycleType.pedicab => tricycleManila, // same rate as tricycle
        TricycleType.eTrike => eTrike,
      };
}
