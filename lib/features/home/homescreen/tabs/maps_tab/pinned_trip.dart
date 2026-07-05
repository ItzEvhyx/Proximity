import 'dart:convert';

/// A location the user has confirmed ("pinned"), kept as their recent trip
/// history. Only the most recent few are retained (older ones are discarded).
class PinnedTrip {
  const PinnedTrip({
    required this.name,
    required this.longitude,
    required this.latitude,
    required this.pinnedAt,
    this.address,
    this.distanceMeters,
    this.startLocationName,
  });

  final String name;
  final String? address;
  final double longitude;
  final double latitude;
  final double? distanceMeters;

  /// Human label of where the user was when they pinned this (their current
  /// location at the time), used as the trip's starting point.
  final String? startLocationName;

  /// When the location was confirmed.
  final DateTime pinnedAt;

  /// "12 Jul 2026" style date label.
  String get dateLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = pinnedAt;
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// "3:07 PM" style time label.
  String get timeLabel {
    final d = pinnedAt;
    final h24 = d.hour;
    final period = h24 >= 12 ? 'PM' : 'AM';
    var h = h24 % 12;
    if (h == 0) h = 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  /// Short distance label ("120 m", "2.4 km") or "-" when unknown.
  String get distanceLabel {
    final meters = distanceMeters;
    if (meters == null) return '-';
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'lng': longitude,
        'lat': latitude,
        'distance': distanceMeters,
        'start': startLocationName,
        'at': pinnedAt.toIso8601String(),
      };

  static PinnedTrip? fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    final lng = (json['lng'] as num?)?.toDouble();
    final lat = (json['lat'] as num?)?.toDouble();
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    if (name == null || lng == null || lat == null || at == null) return null;
    return PinnedTrip(
      name: name,
      address: json['address'] as String?,
      longitude: lng,
      latitude: lat,
      distanceMeters: (json['distance'] as num?)?.toDouble(),
      startLocationName: json['start'] as String?,
      pinnedAt: at,
    );
  }

  static String encodeList(List<PinnedTrip> trips) =>
      jsonEncode(trips.map((t) => t.toJson()).toList());

  static List<PinnedTrip> decodeList(String raw) {
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      final result = <PinnedTrip>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final trip = PinnedTrip.fromJson(item);
          if (trip != null) result.add(trip);
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }
}
