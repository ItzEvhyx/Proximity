import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../../../../../core/config/env.dart';
import 'place_result.dart';

/// Talks to the Mapbox search APIs.
///
/// - [nearbyLandmarks] uses the Tilequery API to pull the closest points of
///   interest around the user, each tagged with a category so the UI can label
///   them ("Mall", "Park", "Convenience Store"…).
/// - [searchAddress] uses the Search Box `/forward` endpoint, which returns
///   both addresses and POIs (with coordinates) in a single request and
///   supports fuzzy, as-you-type matching — Google-Maps-like search. If it
///   yields nothing it falls back to the Geocoding v6 API for address/place
///   coverage.
///
/// Note: Mapbox removed POI data from the Geocoding v5/v6 APIs, so POI search
/// must go through the Search Box API.
class MapsSearchService {
  MapsSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _tilequeryBase =
      'https://api.mapbox.com/v4/mapbox.mapbox-streets-v8/tilequery';
  static const String _searchBoxSuggest =
      'https://api.mapbox.com/search/searchbox/v1/suggest';
  static const String _searchBoxRetrieve =
      'https://api.mapbox.com/search/searchbox/v1/retrieve';
  static const String _searchBoxForward =
      'https://api.mapbox.com/search/searchbox/v1/forward';
  static const String _searchBoxReverse =
      'https://api.mapbox.com/search/searchbox/v1/reverse';
  static const String _geocodeV6Forward =
      'https://api.mapbox.com/search/geocode/v6/forward';

  static final Random _random = Random();

  /// Generates a UUIDv4-style session token used to group `/suggest` +
  /// `/retrieve` calls into one billable search session.
  static String newSessionToken() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final s = bytes.map(hex).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}'
        '-${s.substring(16, 20)}-${s.substring(20)}';
  }

  /// Returns up to [limit] labeled POIs nearest to ([latitude], [longitude]).
  Future<List<PlaceResult>> nearbyLandmarks({
    required double longitude,
    required double latitude,
    int limit = 5,
    int radiusMeters = 1500,
  }) async {
    final uri = Uri.parse('$_tilequeryBase/$longitude,$latitude.json').replace(
      queryParameters: {
        'radius': '$radiusMeters',
        // Over-fetch so we can drop unnamed features and de-dupe before taking
        // the closest [limit].
        'limit': '30',
        'dedupe': 'true',
        'layers': 'poi_label',
        'access_token': Env.mapboxPublicToken,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      debugPrint('Tilequery failed ${response.statusCode}: ${response.body}');
      throw MapsSearchException(
        'Nearby search failed (${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (body['features'] as List?) ?? const [];

    final results = <PlaceResult>[];
    final seenNames = <String>{};
    for (final feature in features) {
      final result = _placeFromTilequery(feature as Map<String, dynamic>);
      if (result == null) continue;
      // Tilequery returns features ordered by distance; keep the first of each
      // distinct name so we don't show the same POI twice.
      if (!seenNames.add(result.name.toLowerCase())) continue;
      results.add(result);
      if (results.length >= limit) break;
    }
    return results;
  }

  /// Google-Maps-style autocomplete. Returns up to [limit] suggestions for
  /// [query] (specific addresses, POIs, streets, places…) biased toward the
  /// user. Suggestions carry a [PlaceResult.mapboxId] and need [retrieve] to
  /// resolve their coordinates before they can be shown on the map.
  ///
  /// Falls back to the one-shot `/forward` (then Geocoding v6) endpoints —
  /// which already include coordinates — if `/suggest` returns nothing.
  Future<List<PlaceResult>> suggest(
    String query, {
    required String sessionToken,
    double? longitude,
    double? latitude,
    int limit = 7,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final params = <String, String>{
      'q': trimmed,
      'access_token': Env.mapboxPublicToken,
      'session_token': sessionToken,
      'language': 'en',
      'limit': '$limit',
      'country': 'ph',
      'types':
          'poi,address,street,place,locality,neighborhood,district,postcode',
    };
    if (longitude != null && latitude != null) {
      params['proximity'] = '$longitude,$latitude';
    }

    final uri = Uri.parse(_searchBoxSuggest).replace(queryParameters: params);
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestions = (body['suggestions'] as List?) ?? const [];
      final results = <PlaceResult>[];
      for (final s in suggestions) {
        final r = _placeFromSuggestion(s as Map<String, dynamic>);
        if (r != null) results.add(r);
      }
      if (results.isNotEmpty) return results;
    } else {
      debugPrint('Suggest failed ${response.statusCode}: ${response.body}');
    }

    // Fallbacks — these already carry coordinates, so no retrieve is needed.
    final viaForward = await _searchViaSearchBox(
      trimmed,
      longitude: longitude,
      latitude: latitude,
      limit: limit,
    );
    if (viaForward.isNotEmpty) return viaForward;
    return _searchViaGeocodeV6(
      trimmed,
      longitude: longitude,
      latitude: latitude,
      limit: limit,
    );
  }

  /// Resolves a `/suggest` result to full coordinates via `/retrieve`, using
  /// the same [sessionToken] as the suggestions (so it counts as one session).
  Future<PlaceResult> retrieve(
    PlaceResult suggestion, {
    required String sessionToken,
  }) async {
    final id = suggestion.mapboxId;
    if (id == null) return suggestion; // already has coordinates

    final params = <String, String>{
      'access_token': Env.mapboxPublicToken,
      'session_token': sessionToken,
      'language': 'en',
    };
    final uri =
        Uri.parse('$_searchBoxRetrieve/$id').replace(queryParameters: params);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      debugPrint('Retrieve failed ${response.statusCode}: ${response.body}');
      throw MapsSearchException('Could not load that location.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (body['features'] as List?) ?? const [];
    if (features.isEmpty) throw MapsSearchException('Location not found.');
    final resolved =
        _placeFromSearchBox(features.first as Map<String, dynamic>);
    if (resolved == null) throw MapsSearchException('Location not found.');

    // Keep the suggestion's (usually nicer) name/address, take the coordinates.
    return PlaceResult(
      name: suggestion.name.isNotEmpty ? suggestion.name : resolved.name,
      address: suggestion.address ?? resolved.address,
      category: suggestion.category ?? resolved.category,
      longitude: resolved.longitude,
      latitude: resolved.latitude,
    );
  }

  PlaceResult? _placeFromSuggestion(Map<String, dynamic> s) {
    final name = (s['name'] as String?)?.trim();
    final id = s['mapbox_id'] as String?;
    if (name == null || name.isEmpty || id == null) return null;

    final fullAddress =
        (s['full_address'] ?? s['place_formatted'])?.toString();
    final poiCategories = s['poi_category'] as List?;
    final category = poiCategories != null && poiCategories.isNotEmpty
        ? poiCategories.first.toString()
        : (s['maki'] ?? s['feature_type'])?.toString();

    return PlaceResult(
      name: name,
      address: fullAddress,
      category: category,
      mapboxId: id,
      longitude: 0,
      latitude: 0,
    );
  }

  Future<List<PlaceResult>> _searchViaSearchBox(
    String query, {
    double? longitude,
    double? latitude,
    required int limit,
  }) async {
    final params = <String, String>{
      'q': query,
      'access_token': Env.mapboxPublicToken,
      'language': 'en',
      'limit': '$limit',
      'country': 'ph',
      'types': 'poi,address,street,place,locality,neighborhood,district',
      // Partial + fuzzy matching for as-you-type search.
      'auto_complete': 'true',
    };
    if (longitude != null && latitude != null) {
      params['proximity'] = '$longitude,$latitude';
    }

    final uri = Uri.parse(_searchBoxForward).replace(queryParameters: params);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      debugPrint('SearchBox failed ${response.statusCode}: ${response.body}');
      return const [];
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (body['features'] as List?) ?? const [];
    final results = <PlaceResult>[];
    for (final feature in features) {
      final result = _placeFromSearchBox(feature as Map<String, dynamic>);
      if (result != null) results.add(result);
    }
    return results;
  }

  Future<List<PlaceResult>> _searchViaGeocodeV6(
    String query, {
    double? longitude,
    double? latitude,
    required int limit,
  }) async {
    final params = <String, String>{
      'q': query,
      'access_token': Env.mapboxPublicToken,
      'autocomplete': 'true',
      'limit': '$limit',
      'country': 'ph',
      'language': 'en',
      // v6 no longer supports the "poi" type; addresses/places only.
      'types': 'address,street,place,locality,neighborhood,district,postcode',
    };
    if (longitude != null && latitude != null) {
      params['proximity'] = '$longitude,$latitude';
    }

    final uri = Uri.parse(_geocodeV6Forward).replace(queryParameters: params);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      debugPrint('Geocode v6 failed ${response.statusCode}: ${response.body}');
      throw MapsSearchException('Search failed (${response.statusCode}).');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (body['features'] as List?) ?? const [];
    final results = <PlaceResult>[];
    for (final feature in features) {
      final result = _placeFromGeocodeV6(feature as Map<String, dynamic>);
      if (result != null) results.add(result);
    }
    return results;
  }

  /// Reverse-geocodes a dropped-pin coordinate to the nearest address / street,
  /// "snapping" it to an appropriate real place instead of an arbitrary point
  /// (e.g. a rooftop). Prefers the feature's routable point (on the road
  /// network) when available.
  ///
  /// Returns null if nothing sensible is found; the caller can then keep the
  /// raw coordinate.
  Future<PlaceResult?> reverseGeocode({
    required double longitude,
    required double latitude,
  }) async {
    final params = <String, String>{
      'longitude': '$longitude',
      'latitude': '$latitude',
      'access_token': Env.mapboxPublicToken,
      'language': 'en',
      'limit': '1',
      'country': 'ph',
      // Snap to real addresses / streets (POIs aren't valid reverse types).
      'types': 'address,street',
    };

    final uri = Uri.parse(_searchBoxReverse).replace(queryParameters: params);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      debugPrint('Reverse failed ${response.statusCode}: ${response.body}');
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (body['features'] as List?) ?? const [];
    if (features.isEmpty) return null;
    return _placeFromReverse(features.first as Map<String, dynamic>);
  }

  PlaceResult? _placeFromReverse(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>?;
    if (props == null) return null;

    final name = (props['name'] ?? props['address'] ?? 'Selected location')
        .toString()
        .trim();
    final fullAddress =
        (props['full_address'] ?? props['place_formatted'])?.toString();
    final category = props['feature_type'] as String?;

    // Prefer the routable point (on a road) so the pin can't land on a roof.
    double? lng;
    double? lat;
    final coordsObj = props['coordinates'] as Map<String, dynamic>?;
    final routable = coordsObj?['routable_points'] as List?;
    if (routable != null && routable.isNotEmpty) {
      final rp = routable.first as Map<String, dynamic>;
      lng = (rp['longitude'] as num?)?.toDouble();
      lat = (rp['latitude'] as num?)?.toDouble();
    }
    if ((lng == null || lat == null) && coordsObj != null) {
      lng = (coordsObj['longitude'] as num?)?.toDouble();
      lat = (coordsObj['latitude'] as num?)?.toDouble();
    }
    if (lng == null || lat == null) {
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List?;
      if (coords != null && coords.length >= 2) {
        lng = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      }
    }
    if (lng == null || lat == null) return null;

    return PlaceResult(
      name: name.isEmpty ? 'Selected location' : name,
      address: fullAddress,
      longitude: lng,
      latitude: lat,
      category: category,
    );
  }

  PlaceResult? _placeFromTilequery(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final coords = geometry?['coordinates'] as List?;
    final props = feature['properties'] as Map<String, dynamic>?;
    if (coords == null || coords.length < 2 || props == null) return null;

    final name = (props['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    // `type` is the specific label ("Restaurant"); `maki`/`class` are broader.
    final category = (props['type'] ??
            props['maki'] ??
            props['class'] ??
            props['category_en'])
        ?.toString();

    return PlaceResult(
      name: name,
      longitude: (coords[0] as num).toDouble(),
      latitude: (coords[1] as num).toDouble(),
      category: category,
    );
  }

  PlaceResult? _placeFromSearchBox(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final coords = geometry?['coordinates'] as List?;
    final props = feature['properties'] as Map<String, dynamic>?;
    if (coords == null || coords.length < 2 || props == null) return null;

    final name = (props['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    final fullAddress =
        (props['full_address'] ?? props['place_formatted'])?.toString();

    // Prefer a specific POI category, then the maki icon, then feature type.
    final poiCategories = props['poi_category'] as List?;
    final category = poiCategories != null && poiCategories.isNotEmpty
        ? poiCategories.first.toString()
        : (props['maki'] ?? props['feature_type'])?.toString();

    return PlaceResult(
      name: name,
      address: fullAddress,
      longitude: (coords[0] as num).toDouble(),
      latitude: (coords[1] as num).toDouble(),
      category: category,
    );
  }

  PlaceResult? _placeFromGeocodeV6(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final coords = geometry?['coordinates'] as List?;
    final props = feature['properties'] as Map<String, dynamic>?;
    if (coords == null || coords.length < 2 || props == null) return null;

    final name = (props['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    final fullAddress =
        (props['full_address'] ?? props['place_formatted'])?.toString();
    final category = props['feature_type'] as String?;

    return PlaceResult(
      name: name,
      address: fullAddress,
      longitude: (coords[0] as num).toDouble(),
      latitude: (coords[1] as num).toDouble(),
      category: category,
    );
  }

  void dispose() => _client.close();
}

/// Thrown when a Mapbox search request fails.
class MapsSearchException implements Exception {
  MapsSearchException(this.message);
  final String message;

  @override
  String toString() => 'MapsSearchException: $message';
}
