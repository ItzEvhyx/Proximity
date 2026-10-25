import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import 'package:flutter/services.dart';
import '../../../core/database/app_database.dart';
import '../../../core/firebase/firebase_client.dart';
import '../domain/geo_utils.dart';
import '../domain/models.dart';
import 'ride_stores.dart';

/// Offline station catalogue. The bundled seed is the only source consulted
/// during a ride. Firestore is checked only during explicit startup sync and
/// only when no persisted ride session exists.
class StationRepository {
  StationRepository({FirebaseFirestore? database}) : _firestore = database;

  final FirebaseFirestore? _firestore;
  static List<Station>? _sharedStations;
  static Map<String, Station>? _sharedById;
  static Map<TrainLine, List<Station>>? _sharedByLine;
  static Future<List<Station>>? _sharedLoad;

  Future<List<Station>> all() async {
    if (_sharedStations != null) return _sharedStations!;
    final pending = _sharedLoad ??= _loadLocalCatalogue();
    try {
      final loaded = await pending;
      // A Firebase sync may have installed a newer catalogue while the local
      // read was in flight. Never overwrite that newer snapshot.
      if (_sharedStations == null) _cacheCatalogue(loaded);
      return _sharedStations!;
    } catch (_) {
      if (identical(_sharedLoad, pending)) _sharedLoad = null;
      rethrow;
    }
  }

  Future<List<Station>> _loadLocalCatalogue() async {
    List<Station>? loaded;
    try {
      final cached = await AppDatabase.instance.getCachedTransitStations();
      if (cached.isNotEmpty) {
        loaded = cached
            .map(
              (value) =>
                  Station.fromJson(jsonDecode(value) as Map<String, dynamic>),
            )
            .toList(growable: false);
      }
    } catch (_) {
      // Database may not be initialized in pure domain tests or early launch.
    }
    if (loaded == null) {
      final raw = await rootBundle.loadString(
        'public/assets/transit/stations.json',
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      loaded = (decoded['stations'] as List)
          .cast<Map<String, dynamic>>()
          .map(Station.fromJson)
          .toList(growable: false);
    }
    return loaded;
  }

  static void _cacheCatalogue(List<Station> stations) {
    final catalogue = List<Station>.unmodifiable(stations);
    final byLine = <TrainLine, List<Station>>{};
    for (final line in TrainLine.values) {
      final lineStations =
          catalogue.where((station) => station.line == line).toList()
            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      byLine[line] = List<Station>.unmodifiable(lineStations);
    }
    _sharedStations = catalogue;
    _sharedById = {for (final station in catalogue) station.id: station};
    _sharedByLine = Map<TrainLine, List<Station>>.unmodifiable(byLine);
  }

  /// Pulls the globally readable Firebase catalogue only when its version has
  /// changed. This method returns before touching Firestore when a ride is
  /// active, preserving the zero-network-during-ride invariant.
  Future<bool> syncFromFirebaseIfChanged() async {
    if (await RideSessionStore().read() != null ||
        firebaseAuth.currentUser == null) {
      return false;
    }
    try {
      final database = _firestore ?? firestore;
      final versionDoc = await database
          .collection('transit_config')
          .doc('current')
          .get(const GetOptions(source: Source.server));
      final remoteVersion = (versionDoc.data()?['version'] as num?)?.toInt();
      if (remoteVersion == null || remoteVersion <= 0) return false;
      final localVersion = await AppDatabase.instance.getTransitVersion();
      if (localVersion == remoteVersion) return false;

      final snapshot = await database
          .collection('transit_stations')
          .get(const GetOptions(source: Source.server));
      if (snapshot.docs.isEmpty) return false;
      final parsed = <Station>[];
      for (final document in snapshot.docs) {
        final data = <String, dynamic>{...document.data()};
        data['id'] ??= document.id;
        parsed.add(Station.fromJson(data));
      }
      _validateCatalogue(parsed);
      await AppDatabase.instance.replaceTransitStations(
        version: remoteVersion,
        stationsJson: {
          for (final station in parsed)
            station.id: jsonEncode(station.toJson()),
        },
      );
      _cacheCatalogue(parsed);
      return true;
    } catch (_) {
      // Offline, unauthenticated, or malformed remote data: retain the last
      // validated SQLite cache (or the bundled seed on a first install).
      return false;
    }
  }

  void _validateCatalogue(List<Station> stations) {
    final ids = <String>{};
    final lineOrders = <String>{};
    for (final station in stations) {
      if (!ids.add(station.id)) {
        throw const FormatException('Duplicate transit station id');
      }
      if (!lineOrders.add('${station.line.id}:${station.orderIndex}')) {
        throw const FormatException('Duplicate station order on a line');
      }
      if (station.point.latitude < 14 ||
          station.point.latitude > 15 ||
          station.point.longitude < 120 ||
          station.point.longitude > 122) {
        throw const FormatException(
          'Station coordinate is outside Metro Manila',
        );
      }
    }
    for (final line in TrainLine.values) {
      if (stations.where((station) => station.line == line).length < 2) {
        throw const FormatException('A train line has fewer than two stations');
      }
    }
  }

  Future<Station?> byId(String id) async {
    await all();
    return _sharedById![id];
  }

  Future<List<Station>> lineStations(TrainLine line) async {
    await all();
    return List<Station>.of(_sharedByLine![line] ?? const []);
  }

  Future<Station?> neighbor(Station station, int direction) async {
    final line = await lineStations(station.line);
    final index =
        line.indexWhere((candidate) => candidate.id == station.id) + direction;
    return index < 0 || index >= line.length ? null : line[index];
  }

  Future<Segment?> segment(Station from, int direction) async {
    final to = await neighbor(from, direction);
    if (to == null) return null;
    final straight = GeoUtils.distanceM(from.point, to.point);
    return Segment(
      fromStationId: from.id,
      toStationId: to.id,
      trackDistanceM: straight * 1.10,
      bearingDeg: GeoUtils.bearingDeg(from.point, to.point),
    );
  }

  Future<List<Station>> nearest(GeoPoint point, {int limit = 15}) async {
    final result = [...await all()]
      ..sort(
        (a, b) => GeoUtils.distanceM(
          a.point,
          point,
        ).compareTo(GeoUtils.distanceM(b.point, point)),
      );
    return result.take(math.min(limit, result.length)).toList();
  }
}
