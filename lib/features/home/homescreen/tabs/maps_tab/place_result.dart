import 'package:flutter/material.dart';

/// A place returned by the Mapbox search / nearby APIs.
///
/// [name] is the human label (e.g. "SM Megamall"), [address] is the fuller
/// context line shown underneath, and [category] is a canonical POI category
/// used to pick an icon and a friendly type label ("Mall", "Park", …).
class PlaceResult {
  const PlaceResult({
    required this.name,
    required this.longitude,
    required this.latitude,
    this.address,
    this.category,
    this.mapboxId,
    this.distanceMeters,
    this.isCurrentLocation = false,
  });

  final String name;
  final String? address;
  final String? category;
  final double longitude;
  final double latitude;

  /// Search Box feature id. When set (and coordinates are still unknown), this
  /// result came from the `/suggest` endpoint and needs a `/retrieve` call to
  /// resolve its coordinates before it can be shown on the map.
  final String? mapboxId;

  /// Straight-line distance from the user's current location, in meters. Null
  /// when the user's location is unknown or not yet computed.
  final double? distanceMeters;

  /// True when this place represents the user's own (draggable) current
  /// location pin rather than a searched destination.
  final bool isCurrentLocation;

  /// True for `/suggest` results that must be retrieved to obtain coordinates.
  bool get needsRetrieve => mapboxId != null;

  /// Returns a copy with selected fields overridden.
  PlaceResult copyWith({
    String? name,
    String? address,
    String? category,
    double? longitude,
    double? latitude,
    String? mapboxId,
    double? distanceMeters,
    bool? isCurrentLocation,
  }) {
    return PlaceResult(
      name: name ?? this.name,
      address: address ?? this.address,
      category: category ?? this.category,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      mapboxId: mapboxId ?? this.mapboxId,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      isCurrentLocation: isCurrentLocation ?? this.isCurrentLocation,
    );
  }

  /// A short, human-friendly distance label ("120 m", "2.4 km") or null when
  /// no distance is known.
  String? get distanceLabel {
    final meters = distanceMeters;
    if (meters == null) return null;
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
  }

  /// A friendly, capitalized type label derived from [category]
  /// (e.g. "convenience" -> "Convenience Store").
  String get categoryLabel => PlaceCategories.labelFor(category);

  /// A Material icon representing [category].
  IconData get categoryIcon => PlaceCategories.iconFor(category);

  @override
  bool operator ==(Object other) =>
      other is PlaceResult &&
      other.name == name &&
      other.longitude == longitude &&
      other.latitude == latitude;

  @override
  int get hashCode => Object.hash(name, longitude, latitude);
}

/// Maps raw Mapbox POI categories / maki icon names to friendly labels and
/// Material icons. Mapbox exposes many category strings; this normalizes the
/// common ones and falls back to a sensible default for the rest.
class PlaceCategories {
  const PlaceCategories._();

  /// Ordered keyword checks: the first substring found in the raw category
  /// wins. Keeps matching resilient to compound categories like
  /// "food_and_drink" or "convenience_store".
  static const List<(String, String, IconData)> _rules = [
    ('mall', 'Mall', Icons.local_mall_rounded),
    ('shopping', 'Shopping', Icons.local_mall_rounded),
    ('department', 'Department Store', Icons.local_mall_rounded),
    ('convenience', 'Convenience Store', Icons.storefront_rounded),
    ('grocery', 'Grocery', Icons.local_grocery_store_rounded),
    ('supermarket', 'Supermarket', Icons.local_grocery_store_rounded),
    ('market', 'Market', Icons.storefront_rounded),
    ('park', 'Park', Icons.park_rounded),
    ('garden', 'Garden', Icons.park_rounded),
    ('playground', 'Playground', Icons.park_rounded),
    ('restaurant', 'Restaurant', Icons.restaurant_rounded),
    ('food', 'Restaurant', Icons.restaurant_rounded),
    ('cafe', 'Cafe', Icons.local_cafe_rounded),
    ('coffee', 'Cafe', Icons.local_cafe_rounded),
    ('bar', 'Bar', Icons.local_bar_rounded),
    ('fast_food', 'Fast Food', Icons.fastfood_rounded),
    ('hotel', 'Hotel', Icons.hotel_rounded),
    ('lodging', 'Hotel', Icons.hotel_rounded),
    ('hospital', 'Hospital', Icons.local_hospital_rounded),
    ('clinic', 'Clinic', Icons.local_hospital_rounded),
    ('pharmacy', 'Pharmacy', Icons.local_pharmacy_rounded),
    ('school', 'School', Icons.school_rounded),
    ('college', 'College', Icons.school_rounded),
    ('university', 'University', Icons.school_rounded),
    ('education', 'School', Icons.school_rounded),
    ('bank', 'Bank', Icons.account_balance_rounded),
    ('atm', 'ATM', Icons.local_atm_rounded),
    ('fuel', 'Gas Station', Icons.local_gas_station_rounded),
    ('gas', 'Gas Station', Icons.local_gas_station_rounded),
    ('petrol', 'Gas Station', Icons.local_gas_station_rounded),
    ('church', 'Church', Icons.church_rounded),
    ('place_of_worship', 'Place of Worship', Icons.church_rounded),
    ('mosque', 'Mosque', Icons.mosque_rounded),
    ('gym', 'Gym', Icons.fitness_center_rounded),
    ('fitness', 'Gym', Icons.fitness_center_rounded),
    ('cinema', 'Cinema', Icons.local_movies_rounded),
    ('theatre', 'Theatre', Icons.theater_comedy_rounded),
    ('museum', 'Museum', Icons.museum_rounded),
    ('library', 'Library', Icons.local_library_rounded),
    ('police', 'Police', Icons.local_police_rounded),
    ('airport', 'Airport', Icons.local_airport_rounded),
    ('bus', 'Bus Station', Icons.directions_bus_rounded),
    ('train', 'Train Station', Icons.train_rounded),
    ('station', 'Station', Icons.directions_transit_rounded),
    ('parking', 'Parking', Icons.local_parking_rounded),
    ('office', 'Office', Icons.business_rounded),
    ('commercial', 'Business', Icons.business_rounded),
    ('store', 'Store', Icons.storefront_rounded),
    ('shop', 'Shop', Icons.storefront_rounded),
  ];

  static String labelFor(String? category) {
    final match = _match(category);
    if (match != null) return match.$2;
    return 'Place';
  }

  static IconData iconFor(String? category) {
    final match = _match(category);
    if (match != null) return match.$3;
    return Icons.place_rounded;
  }

  static (String, String, IconData)? _match(String? category) {
    if (category == null || category.isEmpty) return null;
    final normalized = category.toLowerCase();
    for (final rule in _rules) {
      if (normalized.contains(rule.$1)) return rule;
    }
    return null;
  }
}
