// bus_fares_data_models.dart
//
// Static fare data for Philippine buses (Metro Manila city buses and
// provincial buses). Distance-based computation.
//
// Sources:
//   - LTFRB fare order effective March 19, 2026
//     (Provincial bus rates effective March 14, 2026)
//   - https://newsinfo.inquirer.net/2196867/ltfrb-announces-fare-hike-for-buses-airport-taxis-p2p-tnvs-2
//   - https://www.pna.gov.ph/articles/1271201
//
// Discount: Students, Senior Citizens, and PWDs get 20% off total fare.
//
// Note: Air-conditioned city bus succeeding-km rate varied slightly across
// news sources during rollout (₱2.45 vs ₱2.98). This model uses ₱2.98,
// the more commonly cited figure. Verify against LTFRB's official posted
// fare guide before final use.

/// Bus subtypes with different fare structures.
enum BusType {
  cityOrdinary,
  cityAircon,
  provincialOrdinary,
  provincialSuperDeluxe,
  provincialDeluxe,
  provincialLuxury,
}

extension BusTypeDisplay on BusType {
  String get label => switch (this) {
        BusType.cityOrdinary => 'City Bus (Ordinary)',
        BusType.cityAircon => 'City Bus (Aircon)',
        BusType.provincialOrdinary => 'Provincial (Ordinary)',
        BusType.provincialSuperDeluxe => 'Provincial (Super Deluxe)',
        BusType.provincialDeluxe => 'Provincial (Deluxe)',
        BusType.provincialLuxury => 'Provincial (Luxury)',
      };

  String get shortLabel => switch (this) {
        BusType.cityOrdinary => 'Ordinary',
        BusType.cityAircon => 'Aircon',
        BusType.provincialOrdinary => 'Prov. Ordinary',
        BusType.provincialSuperDeluxe => 'Super Deluxe',
        BusType.provincialDeluxe => 'Deluxe',
        BusType.provincialLuxury => 'Luxury',
      };
}

/// Fare configuration for a bus type.
///
/// For base-fare types: fare = baseFare for first [baseDistanceKm] km,
/// then + perKmRate for each additional km.
///
/// For flat-rate types (Deluxe, Luxury): fare = flatPerKmRate × distance.
/// [baseFare] and [baseDistanceKm] are 0 in that case.
class BusFareConfig {
  final double baseFare;
  final double baseDistanceKm;
  final double perKmRate;

  /// If non-zero, this is a flat per-km rate (no separate base fare).
  final double flatPerKmRate;

  final double discountMultiplier;

  const BusFareConfig({
    this.baseFare = 0,
    this.baseDistanceKm = 0,
    this.perKmRate = 0,
    this.flatPerKmRate = 0,
    this.discountMultiplier = 0.80,
  });

  bool get isFlat => flatPerKmRate > 0;

  /// Computes the regular fare for a given distance in km.
  double regularFare(double distanceKm) {
    if (isFlat) return flatPerKmRate * distanceKm;
    if (distanceKm <= baseDistanceKm) return baseFare;
    final extraKm = distanceKm - baseDistanceKm;
    return baseFare + (extraKm * perKmRate);
  }

  /// Computes the discounted fare (20% off regular).
  double discountedFare(double distanceKm) {
    return regularFare(distanceKm) * discountMultiplier;
  }
}

/// Central access point for bus fare data.
class BusFareData {
  BusFareData._();

  // ── Metro Manila / City Bus — Ordinary (non-aircon) ─────────────────────
  // Base fare (1-5 km): ₱15.00 | Per succeeding km: ₱2.49
  static const cityOrdinary = BusFareConfig(
    baseFare: 15.00,
    baseDistanceKm: 5.0,
    perKmRate: 2.49,
  );

  // ── Metro Manila / City Bus — Air-conditioned ──────────────────────────
  // Base fare (1-5 km): ₱18.00 | Per succeeding km: ₱2.98
  static const cityAircon = BusFareConfig(
    baseFare: 18.00,
    baseDistanceKm: 5.0,
    perKmRate: 2.98,
  );

  // ── Provincial Bus — Ordinary ──────────────────────────────────────────
  // Base fare (1-5 km): ₱12.00 | Per succeeding km: ₱2.20
  static const provincialOrdinary = BusFareConfig(
    baseFare: 12.00,
    baseDistanceKm: 5.0,
    perKmRate: 2.20,
  );

  // ── Provincial Bus — Super Deluxe (aircon) ─────────────────────────────
  // Base fare (1-5 km): ₱13.50 | Per succeeding km: ₱2.70
  static const provincialSuperDeluxe = BusFareConfig(
    baseFare: 13.50,
    baseDistanceKm: 5.0,
    perKmRate: 2.70,
  );

  // ── Provincial Bus — Deluxe (aircon) ───────────────────────────────────
  // Flat rate: ₱2.60 per km (no separate base fare)
  static const provincialDeluxe = BusFareConfig(
    flatPerKmRate: 2.60,
  );

  // ── Provincial Bus — Luxury ────────────────────────────────────────────
  // Flat rate: ₱3.35 per km (no separate base fare)
  static const provincialLuxury = BusFareConfig(
    flatPerKmRate: 3.35,
  );

  /// Returns the fare config for a given bus type.
  static BusFareConfig configFor(BusType type) => switch (type) {
        BusType.cityOrdinary => cityOrdinary,
        BusType.cityAircon => cityAircon,
        BusType.provincialOrdinary => provincialOrdinary,
        BusType.provincialSuperDeluxe => provincialSuperDeluxe,
        BusType.provincialDeluxe => provincialDeluxe,
        BusType.provincialLuxury => provincialLuxury,
      };
}
