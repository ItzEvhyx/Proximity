import 'dart:convert';

import '../../../../../../core/global_services/claude_services.dart';

/// A route the user searched via Way Finder, persisted for history display.
class SavedRoute {
  const SavedRoute({
    required this.originName,
    required this.destinationName,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.totalEta,
    required this.totalDistance,
    required this.travelMode,
    required this.steps,
    required this.geometry,
    required this.searchedAt,
  });

  final String originName;
  final String destinationName;
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String totalEta;
  final String totalDistance;

  /// "drive", "transit", or "walk".
  final String travelMode;

  /// Step-by-step directions.
  final List<RouteStep> steps;

  /// Route geometry as [[lng, lat], ...] for drawing on map.
  final List<List<double>> geometry;

  /// When the route was searched.
  final DateTime searchedAt;

  /// Short date label: "12 Jul" or "12 Jul 2025".
  String get dateLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = searchedAt;
    final now = DateTime.now();
    if (d.year == now.year) {
      return '${d.day} ${months[d.month - 1]}';
    }
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Truncated origin name (first 7 characters + ellipsis if longer).
  String get originTruncated =>
      originName.length <= 7 ? originName : '${originName.substring(0, 7)}…';

  /// Truncated destination name (first 7 characters + ellipsis if longer).
  String get destinationTruncated => destinationName.length <= 7
      ? destinationName
      : '${destinationName.substring(0, 7)}…';

  Map<String, dynamic> toJson() => {
        'originName': originName,
        'destName': destinationName,
        'originLat': originLat,
        'originLng': originLng,
        'destLat': destLat,
        'destLng': destLng,
        'eta': totalEta,
        'dist': totalDistance,
        'mode': travelMode,
        'steps': steps
            .map((s) => {
                  'title': s.title,
                  'eta': s.eta,
                  'distance': s.distance,
                  'description': s.description,
                  'isDestination': s.isDestination,
                })
            .toList(),
        'geometry': geometry,
        'at': searchedAt.toIso8601String(),
      };

  static SavedRoute? fromJson(Map<String, dynamic> json) {
    try {
      final at = DateTime.tryParse(json['at'] as String? ?? '');
      if (at == null) return null;

      final stepsJson = json['steps'] as List<dynamic>? ?? [];
      final steps = stepsJson
          .map((s) => RouteStep(
                title: s['title'] as String? ?? '',
                eta: s['eta'] as String? ?? '',
                distance: s['distance'] as String? ?? '',
                description: s['description'] as String? ?? '',
                isDestination: s['isDestination'] as bool? ?? false,
              ))
          .toList();

      final geometryJson = json['geometry'] as List<dynamic>? ?? [];
      final geometry = geometryJson
          .map((coord) => (coord as List<dynamic>)
              .map((c) => (c as num).toDouble())
              .toList())
          .toList();

      return SavedRoute(
        originName: json['originName'] as String? ?? '',
        destinationName: json['destName'] as String? ?? '',
        originLat: (json['originLat'] as num?)?.toDouble() ?? 0,
        originLng: (json['originLng'] as num?)?.toDouble() ?? 0,
        destLat: (json['destLat'] as num?)?.toDouble() ?? 0,
        destLng: (json['destLng'] as num?)?.toDouble() ?? 0,
        totalEta: json['eta'] as String? ?? '',
        totalDistance: json['dist'] as String? ?? '',
        travelMode: json['mode'] as String? ?? 'drive',
        steps: steps,
        geometry: geometry,
        searchedAt: at,
      );
    } catch (_) {
      return null;
    }
  }

  static String encodeList(List<SavedRoute> routes) =>
      jsonEncode(routes.map((r) => r.toJson()).toList());

  static List<SavedRoute> decodeList(String raw) {
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      final result = <SavedRoute>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final route = SavedRoute.fromJson(item);
          if (route != null) result.add(route);
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }
}
