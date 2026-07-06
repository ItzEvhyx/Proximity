// tricycle_fares_data_models.dart
//
// Static fare data for Philippine tricycles, e-trikes, and pedicabs.
// LGU-regulated (per city/municipality), NOT LTFRB.
//
// Sources:
//   - City of Manila, Ordinance No. 8979, Series of 2022
//     (New Tri-Wheel Fare Matrix — Tricycle · E-trike · Pedicab)
//   - Manila Public Information Office / Manila Traffic Parking Bureau
//     https://www.facebook.com/ManilaPIO/posts/667583042222154
//
// Standard Fare Matrix (per passenger):
//   Distance Traveled  │  Fare Per Passenger
//   0 to 1 km          │  ₱16.00
//   1 km + 500 m       │  ₱21.00
//   1 km + 1 km        │  ₱26.00
//   1 km + 1 km + 500m │  ₱31.00
//   1 km + 2 km        │  ₱36.00
//
// Fare computation (tricycle & pedicab, per one passenger):
//   ₱16.00 — First 1 kilometer
//   +₱5.00 — Every succeeding 500 meters
//
// Fare computation (e-trike, per one passenger):
//   ₱20.00 — Flat rate within its approved route
//
// Discount: Students, Senior Citizens, and PWDs get 20% off total fare
// (nationwide mandate regardless of LGU).
//
// IMPORTANT: Tricycle and pedicab fares are NOT standardized nationwide.
// Each city or municipality sets its own fare matrix through local
// ordinance, so actual rates in your area may differ significantly from
// this example. Check with your city's Tricycle Regulatory Unit or Traffic
// Management Office for the exact posted fare matrix in your area.

import 'bus_fares_data_models.dart';

/// Tricycle / pedicab subtypes.
enum TricycleType { tricycle, eTrike }

extension TricycleTypeDisplay on TricycleType {
  String get label => switch (this) {
        TricycleType.tricycle => 'Tricycle',
        TricycleType.eTrike => 'E-Trike',
      };

  /// Chip label shown in the payment indicator selector.
  String get chipLabel => switch (this) {
        TricycleType.tricycle => 'Tricycle',
        TricycleType.eTrike => 'E - Trike',
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

  /// Converts to a [BusFareConfig] for use with the shared FareRateTable.
  /// Tricycle uses base fare for first 1 km, then per-increment rate.
  /// We approximate it as base-fare style with per-km = perIncrementRate
  /// scaled to km equivalent.
  BusFareConfig toBusFareConfig() {
    if (isFlat) {
      return BusFareConfig(flatPerKmRate: flatFare);
    }
    return BusFareConfig(
      baseFare: baseFare,
      baseDistanceKm: 1.0,
      perKmRate: perIncrementRate,
      discountMultiplier: discountMultiplier,
    );
  }
}

/// Central access point for tricycle fare data (Manila example).
class TricycleFareData {
  TricycleFareData._();

  // ── Tricycle (Manila example) ───────────────────────────────────────────
  // First 1 km: ₱16.00 | Per succeeding 500m: ₱5.00
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
        TricycleType.eTrike => eTrike,
      };

  /// "How It Works" bullet points for Tricycle transit.
  static const List<HowItWorksPoint> howItWorks = [
    HowItWorksPoint(
      icon: HowItWorksIcon.money,
      text: 'Set per city/municipality (LGU) — not the LTFRB',
    ),
    HowItWorksPoint(
      icon: HowItWorksIcon.plus,
      text: 'Rates vary a lot depending on where you are',
    ),
  ];

  /// Important notes shown at the bottom of the tricycle fare screen.
  static const List<String> importantNotes = [
    'Example uses Manila\'s posted rates. Tricycle/pedicab fares are NOT '
        'standardized nationwide — check your city\'s Tricycle Regulatory Unit '
        'for the exact local matrix. Hired "special trips" usually cost ~3x '
        'the regular fare.',
  ];
}
