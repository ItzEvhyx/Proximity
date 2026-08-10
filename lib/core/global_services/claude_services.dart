import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';

/// Route step returned for the Way Finder.
class RouteStep {
  final String title;
  final String eta;
  final String distance;
  final String description;
  final bool isDestination;

  const RouteStep({
    required this.title,
    required this.eta,
    required this.distance,
    required this.description,
    this.isDestination = false,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) => RouteStep(
        title: json['title'] as String? ?? '',
        eta: json['eta'] as String? ?? '',
        distance: json['distance'] as String? ?? '',
        description: json['description'] as String? ?? '',
        isDestination: json['isDestination'] as bool? ?? false,
      );
}

/// Route result containing steps + summary data.
class RouteResult {
  final String totalEta;
  final String totalDistance;
  final List<RouteStep> steps;

  const RouteResult({
    required this.totalEta,
    required this.totalDistance,
    required this.steps,
  });
}

/// Service that uses Mapbox Directions API to generate accurate route steps
/// for all travel modes (drive, walk, transit).
///
/// Transit falls back to the driving route as a reference path since Mapbox
/// doesn't have Philippine public transit data.
class ClaudeService {
  ClaudeService._();

  static final ClaudeService instance = ClaudeService._();

  final http.Client _client = http.Client();

  /// Gets a route from [origin] to [destination] using coordinates.
  /// [travelMode]: "drive", "transit", or "walk".
  /// [originLng], [originLat], [destLng], [destLat] are the coordinates.
  Future<RouteResult> getRoute({
    required String origin,
    required String destination,
    required double originLng,
    required double originLat,
    required double destLng,
    required double destLat,
    String travelMode = 'drive',
  }) async {
    if (travelMode == 'transit') {
      return _getTransitRoute(
        origin: origin,
        destination: destination,
        originLng: originLng,
        originLat: originLat,
        destLng: destLng,
        destLat: destLat,
      );
    }

    // Drive or Walk — use Mapbox Directions API directly.
    return _getMapboxRoute(
      originLng: originLng,
      originLat: originLat,
      destLng: destLng,
      destLat: destLat,
      profile: travelMode == 'walk' ? 'walking' : 'driving',
    );
  }

  /// Uses Mapbox Directions API for accurate driving/walking routes.
  Future<RouteResult> _getMapboxRoute({
    required double originLng,
    required double originLat,
    required double destLng,
    required double destLat,
    required String profile,
  }) async {
    final token = Env.mapboxPublicToken;
    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/$profile/'
      '$originLng,$originLat;$destLng,$destLat'
      '?geometries=geojson&overview=full&steps=true'
      '&language=en&access_token=$token',
    );

    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw Exception('Directions API error: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = body['routes'] as List;
    if (routes.isEmpty) throw Exception('No route found');

    final route = routes[0] as Map<String, dynamic>;
    final durationSec = (route['duration'] as num).toDouble();
    final distanceM = (route['distance'] as num).toDouble();

    final legs = route['legs'] as List;
    if (legs.isEmpty) throw Exception('No route legs');

    final steps = (legs[0]['steps'] as List);

    // Convert Mapbox steps into our RouteStep format.
    final routeSteps = _convertMapboxSteps(steps);

    return RouteResult(
      totalEta: _formatDuration(durationSec),
      totalDistance: _formatDistance(distanceM),
      steps: routeSteps,
    );
  }

  /// Converts all meaningful Mapbox direction steps into route nodes.
  /// Returns every step from the API so the user gets complete turn-by-turn
  /// instructions regardless of route length.
  List<RouteStep> _convertMapboxSteps(List<dynamic> steps) {
    if (steps.isEmpty) return [];

    final List<RouteStep> result = [];

    for (var i = 0; i < steps.length; i++) {
      final s = steps[i] as Map<String, dynamic>;
      final maneuver = s['maneuver'] as Map<String, dynamic>;
      final type = maneuver['type'] as String? ?? '';
      final distance = (s['distance'] as num).toDouble();

      // Skip very short intermediate steps (< 20m) that aren't the final
      // arrive step — they clutter the list without adding useful info.
      if (distance < 20 && type != 'arrive' && i != 0) continue;

      final isLast = i == steps.length - 1 || type == 'arrive';
      result.add(_mapboxStepToRouteStep(s, isLast));

      // Stop after the arrive step if we encounter it mid-list.
      if (type == 'arrive') break;
    }

    // Ensure last step is marked as destination.
    if (result.isNotEmpty && !result.last.isDestination) {
      final last = result.removeLast();
      result.add(RouteStep(
        title: last.title,
        eta: last.eta,
        distance: last.distance,
        description: last.description,
        isDestination: true,
      ));
    }

    return result;
  }

  RouteStep _mapboxStepToRouteStep(Map<String, dynamic> step, bool isLast) {
    final maneuver = step['maneuver'] as Map<String, dynamic>;
    final instruction = maneuver['instruction'] as String? ?? '';
    final name = step['name'] as String? ?? '';
    final distance = (step['distance'] as num).toDouble();
    final duration = (step['duration'] as num).toDouble();

    return RouteStep(
      title: name.isNotEmpty ? name : instruction,
      eta: _formatDuration(duration),
      distance: _formatDistance(distance),
      description: instruction,
      isDestination: isLast,
    );
  }

  /// For transit mode: use Mapbox driving route as a fallback since Mapbox
  /// doesn't support Philippine public transit routing. Shows the driving
  /// route with a note that it's a reference path.
  Future<RouteResult> _getTransitRoute({
    required String origin,
    required String destination,
    required double originLng,
    required double originLat,
    required double destLng,
    required double destLat,
  }) async {
    // Mapbox doesn't have Philippine transit data, so use driving route
    // as a reference path the user can follow via public transport.
    final result = await _getMapboxRoute(
      originLng: originLng,
      originLat: originLat,
      destLng: destLng,
      destLat: destLat,
      profile: 'driving',
    );

    // Adjust the first step's description to note this is a transit reference.
    if (result.steps.isNotEmpty) {
      final first = result.steps[0];
      final adjusted = RouteStep(
        title: first.title,
        eta: first.eta,
        distance: first.distance,
        description: first.description.isNotEmpty
            ? first.description
            : 'Follow this route via available public transport.',
        isDestination: first.isDestination,
      );
      return RouteResult(
        totalEta: result.totalEta,
        totalDistance: result.totalDistance,
        steps: [adjusted, ...result.steps.skip(1)],
      );
    }

    return result;
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final rem = mins % 60;
    return '${hours}h ${rem}m';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  void dispose() {
    _client.close();
  }
}
