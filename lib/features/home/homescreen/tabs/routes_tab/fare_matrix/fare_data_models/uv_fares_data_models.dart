// uv_fares_data_models.dart
//
// Static fare data for Philippine UV Express (FX) vehicles.
// Flat per-km rate computation (no separate base fare tier).
//
// Sources:
//   - LTFRB general reference rates, current as of March 2026
//   - https://www.pna.gov.ph/articles/1271201
//   - https://newsinfo.inquirer.net/2196867/ltfrb-announces-fare-hike-for-buses-airport-taxis-p2p-tnvs-2
//
// Discount: Students, Senior Citizens, and PWDs get 20% off total fare.
//
// Note: UV Express fares in practice vary significantly by operator, route,
// and terminal — the flat per-km rate here is the LTFRB's general reference
// rate, not a strict published matrix. Actual FX fares for a given route
// are often set/posted per-terminal and may not scale linearly with
// distance. A rate increase petition (filed March 2026) remains under
// LTFRB review and could change these figures once decided.

import 'bus_fares_data_models.dart';

/// UV Express subtypes.
enum UvExpressType { traditional, modernized }

extension UvExpressTypeDisplay on UvExpressType {
  String get label => switch (this) {
        UvExpressType.traditional => 'Traditional UV Express',
        UvExpressType.modernized => 'Modernized UV Express',
      };

  String get shortLabel => switch (this) {
        UvExpressType.traditional => 'Traditional',
        UvExpressType.modernized => 'Modernized',
      };

  /// Chip label shown in the payment indicator selector.
  String get chipLabel => switch (this) {
        UvExpressType.traditional => 'Traditional',
        UvExpressType.modernized => 'Modernized',
      };
}

/// Fare configuration for UV Express — flat per-km rate.
class UvExpressFareConfig {
  /// Flat charge per kilometer.
  final double perKmRate;

  /// Discount multiplier for students/seniors/PWDs (0.80 = 20% off).
  final double discountMultiplier;

  const UvExpressFareConfig({
    required this.perKmRate,
    this.discountMultiplier = 0.80,
  });

  /// Computes the regular fare for a given distance in km.
  double regularFare(double distanceKm) => perKmRate * distanceKm;

  /// Computes the discounted fare (20% off regular).
  double discountedFare(double distanceKm) =>
      regularFare(distanceKm) * discountMultiplier;

  /// Converts to a [BusFareConfig] so we can reuse the same FareRateTable
  /// widget. UV Express is always flat-rate.
  BusFareConfig toBusFareConfig() => BusFareConfig(
        flatPerKmRate: perKmRate,
        discountMultiplier: discountMultiplier,
      );
}

/// Central access point for UV Express fare data.
class UvExpressFareData {
  UvExpressFareData._();

  // ── Traditional UV Express ─────────────────────────────────────────────
  // Flat rate: ₱2.40 per km
  static const traditional = UvExpressFareConfig(
    perKmRate: 2.40,
  );

  // ── Modernized UV Express ──────────────────────────────────────────────
  // Flat rate: ₱2.50 per km
  static const modernized = UvExpressFareConfig(
    perKmRate: 2.50,
  );

  /// Returns the fare config for a given UV Express type.
  static UvExpressFareConfig configFor(UvExpressType type) => switch (type) {
        UvExpressType.traditional => traditional,
        UvExpressType.modernized => modernized,
      };

  /// "How It Works" bullet points for UV Express.
  static const List<HowItWorksPoint> howItWorks = [
    HowItWorksPoint(
      icon: HowItWorksIcon.money,
      text: 'No separate base fare — flat per-km rate only',
    ),
    HowItWorksPoint(
      icon: HowItWorksIcon.plus,
      text: 'Rate depends on unit type (Traditional / Modernized)',
    ),
    HowItWorksPoint(
      icon: HowItWorksIcon.discount,
      text: '20% discount for Students, Seniors & PWDs',
    ),
  ];

  /// Important notes shown at the bottom of the UV Express fare screen.
  static const List<String> importantNotes = [
    'UV Express fares vary by operator, route, and terminal. '
        'The flat per-km rate shown is the LTFRB general reference rate — '
        'actual fares for a given route are often set per-terminal and may '
        'not scale linearly with distance. A rate increase petition '
        '(filed March 2026) remains under LTFRB review.',
  ];
}
