import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// Fetches the OSM building / area polygon for a location and returns it as a
/// GeoJSON FeatureCollection string, suitable for adding to a Mapbox source.
///
/// Uses OpenStreetMap Nominatim's reverse endpoint with `polygon_geojson=1` —
/// the same data source and rendering behavior as openstreetmap.org, where a
/// selected building/land parcel is outlined. Falls back gracefully to null
/// when no polygon exists for the point (e.g. an unmapped building), in which
/// case only the pin is shown.
class BuildingHighlightService {
  BuildingHighlightService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const String _reverseUrl =
      'https://nominatim.openstreetmap.org/reverse';
  static const Map<String, String> _headers = {
    'User-Agent': 'ProximityApp/1.0 (contact: support@proximity.app)',
    'Accept': 'application/json',
  };

  /// Reverse-geocodes ([latitude], [longitude]) requesting the feature's
  /// polygon geometry. Returns a GeoJSON FeatureCollection wrapping the
  /// building / area shape, or null if the feature has no drawable outline.
  Future<String?> fetchBuildingPolygon({
    required double longitude,
    required double latitude,
  }) async {
    final params = <String, String>{
      'lat': '$latitude',
      'lon': '$longitude',
      'format': 'jsonv2',
      'polygon_geojson': '1',
      'zoom': '18', // building / house-number level
      'accept-language': 'en',
    };

    final uri = Uri.parse(_reverseUrl).replace(queryParameters: params);
    try {
      final response = await _client.get(uri, headers: _headers);
      if (response.statusCode != 200) {
        debugPrint(
          'Highlight reverse failed ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['error'] != null) return null;

      final geometry = decoded['geojson'];
      if (geometry is! Map<String, dynamic>) return null;

      final type = geometry['type'] as String?;
      // Only outline shapes with area/lines; a bare Point has nothing to draw.
      const drawable = {
        'Polygon',
        'MultiPolygon',
        'LineString',
        'MultiLineString',
      };
      if (type == null || !drawable.contains(type)) return null;

      final feature = {
        'type': 'Feature',
        'geometry': geometry,
        'properties': <String, dynamic>{
          'name': decoded['name'] ?? decoded['display_name'] ?? '',
        },
      };
      final featureCollection = {
        'type': 'FeatureCollection',
        'features': [feature],
      };
      return jsonEncode(featureCollection);
    } catch (e) {
      debugPrint('Highlight fetch error: $e');
      return null;
    }
  }

  void dispose() => _client.close();
}
