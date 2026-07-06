// jeepney_fares_data_models.dart
//
// Static fare data for Philippine jeepneys (traditional and modern).
// Distance-based computation: base fare for first 4 km + per-km rate beyond.
//
// Sources:
//   - LTFRB fare order effective March 19, 2026
//   - https://newsinfo.inquirer.net/2197419/buses-jeepneys-airport-cabs-tnvs-get-fare-hike
//   - https://www.rappler.com/newsbreak/iq/fare-increase-jeepneys-buses-ride-hailing-philippines-march-19-2026/
//
// Traditional Jeepney:
//   Regular base fare (first 4 km): ₱13.00
//   Student/Senior/PWD base fare:   ₱11.00 (not a simple 20% off)
//   Per succeeding km:              ₱1.80
//
// Modern Jeepney:
//   Regular base fare (first 4 km): ₱17.00 (+₱4 over traditional)
//   Student/Senior/PWD base fare:   ₱14.00
//   Per succeeding km:              ₱2.20
//
// Discount: Students, Senior Citizens, and PWDs get a fixed discounted
// base fare (not a flat 20% off the regular fare).

import 'bus_fares_data_models.dart';

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

  /// Chip label shown in the payment indicator selector.
  String get chipLabel => switch (this) {
        JeepneyType.traditional => 'Traditional',
        JeepneyType.modern => 'Modernized',
      };
}

/// Fare configuration for a jeepney type.
class JeepneyFareConfig {
  /// Regular base fare covering the first [baseDistanceKm] km.
  final double baseFare;

  /// Discounted base fare for students/seniors/PWDs.
  final double discountedBaseFare;

  /// Distance (km) covered by the base fare.
  final double baseDistanceKm;

  /// Additional charge per km beyond [baseDistanceKm].
  final double perKmRate;

  const JeepneyFareConfig({
    required this.baseFare,
    required this.discountedBaseFare,
    required this.baseDistanceKm,
    required this.perKmRate,
  });

  /// Computes the regular fare for a given distance in km.
  double regularFare(double distanceKm) {
    if (distanceKm <= baseDistanceKm) return baseFare;
    final extraKm = distanceKm - baseDistanceKm;
    return baseFare + (extraKm * perKmRate);
  }

  /// Computes the discounted fare (student/senior/PWD).
  double discountedFare(double distanceKm) {
    if (distanceKm <= baseDistanceKm) return discountedBaseFare;
    final extraKm = distanceKm - baseDistanceKm;
    return discountedBaseFare + (extraKm * perKmRate);
  }

  /// Converts to a [BusFareConfig] for use with the shared FareRateTable.
  BusFareConfig toBusFareConfig() => BusFareConfig(
        baseFare: baseFare,
        baseDistanceKm: baseDistanceKm,
        perKmRate: perKmRate,
        discountMultiplier: discountedBaseFare / baseFare,
      );
}

/// Central access point for jeepney fare data.
class JeepneyFareData {
  JeepneyFareData._();

  // ── Traditional Jeepney ─────────────────────────────────────────────────
  // Regular base fare (first 4 km): ₱13.00
  // Student/Senior/PWD base fare:   ₱11.00
  // Per succeeding km:              ₱1.80
  static const traditional = JeepneyFareConfig(
    baseFare: 13.00,
    discountedBaseFare: 11.00,
    baseDistanceKm: 4.0,
    perKmRate: 1.80,
  );

  // ── Modern Jeepney ─────────────────────────────────────────────────────
  // Regular base fare (first 4 km): ₱17.00 (+₱4 over traditional)
  // Student/Senior/PWD base fare:   ₱14.00
  // Per succeeding km:              ₱2.20
  static const modern = JeepneyFareConfig(
    baseFare: 17.00,
    discountedBaseFare: 14.00,
    baseDistanceKm: 4.0,
    perKmRate: 2.20,
  );

  /// Returns the fare config for a given jeepney type.
  static JeepneyFareConfig configFor(JeepneyType type) => switch (type) {
        JeepneyType.traditional => traditional,
        JeepneyType.modern => modern,
      };

  /// "How It Works" bullet points for Jeepney transit.
  static const List<HowItWorksPoint> howItWorks = [
    HowItWorksPoint(
      icon: HowItWorksIcon.money,
      text: 'Base fare covers the first 4 km',
    ),
    HowItWorksPoint(
      icon: HowItWorksIcon.plus,
      text: 'Extra per-km rate applies beyond that',
    ),
    HowItWorksPoint(
      icon: HowItWorksIcon.diamond,
      text: 'Modern jeepneys cost slightly more (aircon units)',
    ),
    HowItWorksPoint(
      icon: HowItWorksIcon.discount,
      text: '20% discount for Students, Seniors & PWDs',
    ),
  ];

  /// Important notes shown at the bottom of the jeepney fare screen.
  static const List<String> importantNotes = [
    'Effective Mar 19, 2026 per LTFRB fare order. Traditional and modern '
        'jeepney fares apply nationwide. Some routes may have slightly '
        'different rates — verify against the posted fare inside the vehicle.',
  ];
}
