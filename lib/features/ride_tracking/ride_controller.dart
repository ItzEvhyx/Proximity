import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:native_geofence/native_geofence.dart';
import '../../core/global_services/foreground_service.dart';
import '../../core/shared_prefs/shared_prefs.dart';
import 'data/ride_stores.dart';
import 'data/station_repository.dart';
import 'domain/boarding_detector.dart';
import 'domain/direction_resolver.dart';
import 'domain/eta_estimator.dart';
import 'domain/geo_utils.dart';
import 'domain/models.dart';
import 'platform/ride_platform_services.dart';
import 'ride_config.dart';

class RideController extends ChangeNotifier {
  RideController._();
  static final instance = RideController._();

  final StationRepository _stations = StationRepository();
  final RideSessionStore _sessions = RideSessionStore();
  final SegmentTimingStore _timings = SegmentTimingStore();
  final RideLogStore _logs = RideLogStore();
  final RideGeofenceService _geofences = RideGeofenceService();
  final RideLocationService _location = RideLocationService();
  final RideAlertScheduler _alerts = RideAlertScheduler();

  RideSession? _session;
  RideSession? get session => _session;
  bool get active => _session != null;
  bool get tentative => _session != null && !_session!.confirmed;
  bool _initialized = false;
  bool _busy = false;
  bool get busy => _busy;
  String? _statusMessage;
  String? get statusMessage => _statusMessage;
  Timer? _approachTimer;
  Timer? _correctionTimer;
  Timer? _arrivalTimer;
  Timer? _manualDepartureTimer;
  Timer? _idleTimer;
  Timer? _eventPollTimer;
  bool _resyncGraceExtended = false;
  final Map<String, _BoardingCandidate> _candidates = {};
  TrainLine? plannedLine;

  /// Uses the route endpoints to identify a likely single-line rail journey.
  /// This is only a confidence hint for automatic boarding detection; it never
  /// starts a ride on its own.
  Future<void> setPlannedTripFromEndpoints({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    const maximumEndpointDistanceM = 2500.0;
    TrainLine? bestLine;
    var bestScore = double.infinity;
    for (final line in TrainLine.values) {
      final stations = await _stations.lineStations(line);
      if (stations.isEmpty) continue;
      final originDistance = stations
          .map((station) => GeoUtils.distanceM(origin, station.point))
          .reduce((a, b) => a < b ? a : b);
      final destinationDistance = stations
          .map((station) => GeoUtils.distanceM(destination, station.point))
          .reduce((a, b) => a < b ? a : b);
      final score = originDistance + destinationDistance;
      if (originDistance <= maximumEndpointDistanceM &&
          destinationDistance <= maximumEndpointDistanceM &&
          score < bestScore) {
        bestLine = line;
        bestScore = score;
      }
    }
    plannedLine = bestLine;
  }

  void clearPlannedTrip() => plannedLine = null;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _alerts.initialize();
    _session = await _sessions.read();
    if (_session != null) {
      final current = await _stations.byId(_session!.currentStationId);
      final next = _session!.nextStationId == null
          ? null
          : await _stations.byId(_session!.nextStationId!);
      if (current == null ||
          (_session!.nextStationId != null && next == null)) {
        await _sessions.clear();
        _session = null;
      } else {
        await _resumeSessionTimers();
      }
    }
    if (AppPrefs.trainRideAlertsEnabled && !active) {
      await _registerIdleRing();
    }
    await processPendingGeofenceEvents();
    _eventPollTimer ??= Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(processPendingGeofenceEvents()),
    );
    notifyListeners();
  }

  Future<bool> enableAutoDetection() async {
    _setBusy(true);
    try {
      if (!AppPrefs.isPermissionUsageEnabled('location')) {
        _statusMessage = 'Location access is turned off in Settings.';
        return false;
      }
      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        _statusMessage = 'Turn on device location to enable train detection.';
        return false;
      }
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        _statusMessage =
            'Location permission was not granted. Manual mode still works.';
        return false;
      }
      if (!await _alerts.requestPermission()) {
        _statusMessage =
            'Notification permission is needed for station alerts.';
        return false;
      }
      if (permission != geo.LocationPermission.always) {
        _statusMessage =
            'Choose “Allow all the time” in app settings for automatic detection. Manual mode is available now.';
        return false;
      }
      await AppPrefs.setTrainRideAlertsEnabled(true);
      await _registerIdleRing();
      _statusMessage = null;
      return true;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> disable() async {
    await AppPrefs.setTrainRideAlertsEnabled(false);
    await stopRide(reason: 'feature disabled', notify: false);
    await _geofences.clear();
    notifyListeners();
  }

  Future<void> openAppSettings() => geo.Geolocator.openAppSettings();

  Future<void> _registerIdleRing() async {
    final fix = await _location.getFix();
    if (fix == null) return;
    final nearest = await _stations.nearest(
      fix.point,
      limit: RideConfig.geofenceRingSize,
    );
    try {
      await _geofences.replace(nearest, recenterAt: fix.point);
      await _logs.add('registered idle ring (${nearest.length} stations)');
    } catch (_) {
      _statusMessage = 'Automatic detection needs background location access.';
    }
  }

  Future<void> processPendingGeofenceEvents() async {
    List<RideGeofenceEvent> events;
    try {
      events = await _geofences.consumeEvents();
    } catch (_) {
      return;
    }
    for (final event in events) {
      if (!event.processedInBackground) {
        await handleGeofenceEvent(event);
      }
    }
    final restored = await _sessions.read();
    final changed = !_sameSession(restored, _session);
    if (changed) {
      _session = restored;
      _approachTimer?.cancel();
      _correctionTimer?.cancel();
      _arrivalTimer?.cancel();
      if (_session != null) {
        if (_session!.confirmed && _session!.alertAt != null) {
          await _scheduleApproachForCurrentSession();
        }
        _armCorrectionAndArrivalTimers();
      }
      notifyListeners();
    }
  }

  Future<void> handleGeofenceEvent(RideGeofenceEvent event) async {
    final station = await _stations.byId(event.id);
    if (station == null) return;
    await _logs.add('${event.event.name} ${station.id}');
    if (_session == null) {
      if (!AppPrefs.trainRideAlertsEnabled || !AppPrefs.trainAutoDetect) return;
      if (event.event == GeofenceEvent.enter) {
        _candidates[station.id] = _BoardingCandidate(
          station: station,
          enteredAt: event.at,
          enterPoint: event.point ?? station.point,
        );
      } else if (event.event == GeofenceEvent.dwell) {
        final candidate = _candidates[station.id];
        if (candidate != null) candidate.dwelled = true;
      } else if (event.event == GeofenceEvent.exit) {
        final candidate = _candidates.remove(station.id);
        if (candidate != null &&
            event.at.difference(candidate.enteredAt) <=
                RideConfig.departureWindow) {
          unawaited(_verifyAutomaticDeparture(candidate, event));
        }
      }
      return;
    }

    final ride = _session!;
    if (event.event == GeofenceEvent.enter && event.id == ride.nextStationId) {
      if (ride.confirmed && !ride.segmentAlertSent) {
        await _alerts.showApproach(station.name);
        _session = ride.copyWith(
          phase: RidePhase.approaching,
          segmentAlertSent: true,
        );
        await _sessions.write(_session!);
      }
      final fix = await _location.getFix();
      if (fix != null &&
          GeoUtils.distanceM(fix.point, station.point) <=
              (station.arriveRadiusM ?? RideConfig.stationArriveRadiusM)) {
        await _confirmArrival(station, fix.at);
      } else {
        Timer(RideConfig.arrivalSettle, () {
          if (_session?.nextStationId == station.id) {
            unawaited(_confirmArrival(station, DateTime.now()));
          }
        });
      }
    } else if (event.event == GeofenceEvent.exit &&
        event.id == ride.currentStationId &&
        ride.phase == RidePhase.atStation) {
      Timer(RideConfig.departureVerifyDelay, () {
        unawaited(_departFromOnboardStation());
      });
    }
  }

  Future<void> _verifyAutomaticDeparture(
    _BoardingCandidate candidate,
    RideGeofenceEvent exit,
  ) async {
    await Future<void>.delayed(RideConfig.departureVerifyDelay);
    if (_session != null) return;
    final fix = await _location.getFix();
    if (fix == null || fix.accuracyM > RideConfig.maxFixAccuracyM) return;
    final movementBearing = GeoUtils.bearingDeg(
      exit.point ?? candidate.enterPoint,
      fix.point,
    );
    final matches = DirectionResolver.candidates(
      candidate.station,
      await _stations.all(),
      movementBearing,
    );
    if (matches.isEmpty) return;
    final match = matches.first;
    final expected = await _stations.neighbor(
      candidate.station,
      match.direction,
    );
    if (expected == null) return;
    final decision = BoardingDetector.evaluate(
      BoardingEvidence(
        exitPoint: exit.point ?? candidate.enterPoint,
        exitAt: exit.at,
        fix: fix,
        hadDwell: candidate.dwelled,
        plannedRide: plannedLine == candidate.station.line,
      ),
      GeoUtils.bearingDeg(candidate.station.point, expected.point),
    );
    if (!decision.passesGates) return;
    await _startSegment(
      current: candidate.station,
      direction: match.direction,
      confirmed: decision.isConfirmed,
      origin: plannedLine == candidate.station.line
          ? RideOrigin.plannedTrip
          : RideOrigin.automatic,
      fix: fix,
      departedAt: exit.at,
    );
    if (!decision.isConfirmed) {
      final lineStations = await _stations.lineStations(candidate.station.line);
      await _alerts.showConfirmPrompt(
        lineLabel: candidate.station.line.label,
        terminusName:
            (match.direction > 0 ? lineStations.last : lineStations.first).name,
      );
    }
  }

  Future<void> manualStart({
    required TrainLine line,
    required int direction,
    required Station current,
    String? destinationStationId,
  }) async {
    if (!await _alerts.requestPermission()) {
      _statusMessage =
          'Notification access is off. The ride will still track in-app, but station alerts may be delayed.';
    }
    await _startSegment(
      current: current,
      direction: direction,
      confirmed: true,
      origin: RideOrigin.manual,
      destinationStationId: destinationStationId,
      departedAt: DateTime.now(),
    );
  }

  Future<void> confirmTentative(bool yes) async {
    if (_session == null || _session!.confirmed) return;
    if (!yes) {
      await stopRide(reason: 'user rejected tentative ride', notify: false);
      return;
    }
    _session = _session!.copyWith(confirmed: true);
    await _sessions.write(_session!);
    await _scheduleApproachForCurrentSession();
    notifyListeners();
  }

  Future<void> _startSegment({
    required Station current,
    required int direction,
    required bool confirmed,
    required RideOrigin origin,
    LocationFix? fix,
    DateTime? departedAt,
    String? destinationStationId,
  }) async {
    _manualDepartureTimer?.cancel();
    _idleTimer?.cancel();
    _resyncGraceExtended = false;
    final segment = await _stations.segment(current, direction);
    if (segment == null) {
      _statusMessage = 'That direction has no station after ${current.name}.';
      notifyListeners();
      return;
    }
    final next = await _stations.byId(segment.toStationId);
    if (next == null) return;
    final departed = departedAt ?? DateTime.now();
    var alongM = 0.0;
    if (fix != null && fix.accuracyM <= RideConfig.maxFixAccuracyM) {
      alongM = GeoUtils.projectAlongSegmentM(
        from: current.point,
        to: next.point,
        point: fix.point,
      );
    }
    final cruise =
        await _timings.speedFor(segment.id) ?? RideConfig.defaultCruiseMs;
    final estimate = EtaEstimator.estimate(
      fixAt: fix?.at ?? departed,
      segmentDistanceM: segment.trackDistanceM,
      alongM: alongM,
      cruiseMs: cruise,
      approachLead: Duration(seconds: AppPrefs.trainApproachLeadSeconds),
    );
    _session = RideSession(
      id: _session?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      line: current.line,
      direction: direction,
      phase: RidePhase.inTransit,
      confirmed: confirmed,
      currentStationId: current.id,
      nextStationId: next.id,
      departedAt: departed,
      etaAt: estimate.etaAt,
      alertAt: estimate.alertAt,
      fixesUsedThisSegment: fix == null ? 0 : 1,
      origin: origin,
      destinationStationId:
          destinationStationId ?? _session?.destinationStationId,
    );
    await _sessions.write(_session!);
    await _logs.add('started ${current.id}->${next.id}, confirmed=$confirmed');
    await ProximityForegroundService.instance.startRide(
      title: '${current.line.label} → ${await terminusName(_session!)}',
      text: 'Next: ${next.name} · ${etaLabel(_session!)}',
    );
    await _registerActiveFences(current, next, direction);
    if (confirmed) await _scheduleApproachForCurrentSession();
    _armCorrectionAndArrivalTimers();
    notifyListeners();
  }

  Future<void> _registerActiveFences(
    Station current,
    Station next,
    int direction,
  ) async {
    final after = await _stations.neighbor(next, direction);
    try {
      await _geofences.replace([current, next, ?after]);
    } catch (_) {
      // Exact alerts and ETA remain useful when geofences are unavailable.
    }
  }

  Future<void> _scheduleApproachForCurrentSession() async {
    final ride = _session;
    if (ride == null || !ride.confirmed || ride.alertAt == null) return;
    final next = await _stations.byId(ride.nextStationId!);
    if (next == null) return;
    await _alerts.scheduleApproach(stationName: next.name, when: ride.alertAt!);
    _approachTimer?.cancel();
    final delay = ride.alertAt!.difference(DateTime.now());
    _approachTimer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      final current = _session;
      if (current == null || current.segmentAlertSent) return;
      _session = current.copyWith(
        phase: RidePhase.approaching,
        segmentAlertSent: true,
      );
      await _sessions.write(_session!);
      notifyListeners();
    });
  }

  void _armCorrectionAndArrivalTimers() {
    _correctionTimer?.cancel();
    _arrivalTimer?.cancel();
    final ride = _session;
    if (ride?.departedAt == null || ride?.etaAt == null) return;
    if (ride!.origin == RideOrigin.manual) {
      final arrivalAt = ride.etaAt!.add(RideConfig.arrivalSettle);
      final arrivalDelay = arrivalAt.difference(DateTime.now());
      _arrivalTimer = Timer(
        arrivalDelay.isNegative ? Duration.zero : arrivalDelay,
        () async {
          final current = _session;
          if (current == null || current.id != ride.id) return;
          final next = current.nextStationId == null
              ? null
              : await _stations.byId(current.nextStationId!);
          if (next != null) {
            await _confirmArrival(next, current.etaAt ?? DateTime.now());
          }
        },
      );
      return;
    }
    final total = ride.etaAt!.difference(ride.departedAt!);
    final correctionAt = ride.departedAt!.add(
      Duration(
        milliseconds:
            (total.inMilliseconds * RideConfig.correctionFixAtFraction).round(),
      ),
    );
    final correctionDelay = correctionAt.difference(DateTime.now());
    if (ride.fixesUsedThisSegment < RideConfig.maxFixesPerSegment) {
      _correctionTimer = Timer(
        correctionDelay.isNegative ? Duration.zero : correctionDelay,
        () => unawaited(_takeCorrectionFix()),
      );
    }
    final segmentSeconds = total.inSeconds;
    final resyncAt = ride.etaAt!.add(
      Duration(seconds: RideConfig.arrivalGraceS(segmentSeconds)),
    );
    final arrivalDelay = resyncAt.difference(DateTime.now());
    _arrivalTimer = Timer(
      arrivalDelay.isNegative ? Duration.zero : arrivalDelay,
      () => unawaited(_resync()),
    );
  }

  Future<void> _takeCorrectionFix() async {
    final ride = _session;
    if (ride == null ||
        ride.fixesUsedThisSegment >= RideConfig.maxFixesPerSegment) {
      return;
    }
    final current = await _stations.byId(ride.currentStationId);
    final next = await _stations.byId(ride.nextStationId!);
    final fix = await _location.getFix();
    if (current == null ||
        next == null ||
        fix == null ||
        fix.accuracyM > RideConfig.maxFixAccuracyM) {
      return;
    }
    final segment = await _stations.segment(current, ride.direction);
    if (segment == null) return;
    final along = GeoUtils.projectAlongSegmentM(
      from: current.point,
      to: next.point,
      point: fix.point,
    );
    final cruise =
        await _timings.speedFor(segment.id) ?? RideConfig.defaultCruiseMs;
    final estimate = EtaEstimator.estimate(
      fixAt: fix.at,
      segmentDistanceM: segment.trackDistanceM,
      alongM: along,
      cruiseMs: cruise,
      approachLead: Duration(seconds: AppPrefs.trainApproachLeadSeconds),
    );
    _session = ride.copyWith(
      etaAt: estimate.etaAt,
      alertAt: estimate.alertAt,
      fixesUsedThisSegment: ride.fixesUsedThisSegment + 1,
    );
    await _sessions.write(_session!);
    if (ride.confirmed) await _scheduleApproachForCurrentSession();
    _armCorrectionAndArrivalTimers();
    notifyListeners();
  }

  Future<void> _resync() async {
    final ride = _session;
    if (ride == null) return;
    if (ride.fixesUsedThisSegment >= RideConfig.maxFixesPerSegment) {
      await _extendResyncGraceOrStop('location-fix budget exhausted');
      return;
    }
    final fix = await _location.getFix();
    if (fix == null) {
      await _extendResyncGraceOrStop('resync fix unavailable');
      return;
    }
    _session = ride.copyWith(
      phase: RidePhase.resync,
      fixesUsedThisSegment: ride.fixesUsedThisSegment + 1,
    );
    await _sessions.write(_session!);
    final line = await _stations.lineStations(ride.line);
    line.sort(
      (a, b) => GeoUtils.distanceM(
        a.point,
        fix.point,
      ).compareTo(GeoUtils.distanceM(b.point, fix.point)),
    );
    final nearest = line.first;
    if (nearest.id == ride.nextStationId) {
      await _confirmArrival(nearest, fix.at);
      return;
    }
    await stopRide(
      reason: 'could not resync to expected next station',
      notify: false,
    );
  }

  Future<void> _extendResyncGraceOrStop(String reason) async {
    if (!_resyncGraceExtended && _session != null) {
      _resyncGraceExtended = true;
      _session = _session!.copyWith(phase: RidePhase.resync);
      await _sessions.write(_session!);
      await _logs.add('$reason; extending arrival grace once');
      _arrivalTimer?.cancel();
      _arrivalTimer = Timer(
        const Duration(seconds: 45),
        () => unawaited(_resync()),
      );
      notifyListeners();
      return;
    }
    await stopRide(reason: reason, notify: false);
  }

  Future<void> _confirmArrival(Station arrived, DateTime at) async {
    final ride = _session;
    if (ride == null || arrived.id != ride.nextStationId) return;
    _arrivalTimer?.cancel();
    _correctionTimer?.cancel();
    _approachTimer?.cancel();
    await _alerts.cancelApproach();
    var confirmed = ride.confirmed;
    if (!confirmed && ride.etaAt != null && ride.departedAt != null) {
      final expected = ride.etaAt!
          .difference(ride.departedAt!)
          .inMilliseconds
          .abs();
      final drift = at.difference(ride.etaAt!).inMilliseconds.abs();
      confirmed =
          expected > 0 && drift <= expected * RideConfig.tentativeEtaTolerance;
      if (!confirmed) {
        await stopRide(
          reason: 'tentative ETA validation failed',
          notify: false,
        );
        return;
      }
    }
    final from = await _stations.byId(ride.currentStationId);
    if (from != null &&
        ride.departedAt != null &&
        confirmed &&
        ride.origin != RideOrigin.manual) {
      final segment = await _stations.segment(from, ride.direction);
      final seconds = at.difference(ride.departedAt!).inMilliseconds / 1000;
      if (segment != null && seconds > 0) {
        final speed = segment.trackDistanceM / seconds;
        if (speed >= RideConfig.defaultCruiseMs * .5 &&
            speed <= RideConfig.defaultCruiseMs * 2) {
          await _timings.record(segment.id, speed);
        }
      }
    }
    final next = await _stations.neighbor(arrived, ride.direction);
    final finished = arrived.id == ride.destinationStationId || next == null;
    if (finished) {
      await _alerts.showInfo(
        next == null ? 'End of line' : 'You’ve arrived',
        'At ${arrived.name}',
      );
      await stopRide(reason: 'destination or terminus reached', notify: false);
      return;
    }
    _session = RideSession(
      id: ride.id,
      line: ride.line,
      direction: ride.direction,
      phase: RidePhase.atStation,
      confirmed: confirmed,
      currentStationId: arrived.id,
      nextStationId: next.id,
      departedAt: null,
      etaAt: null,
      alertAt: null,
      fixesUsedThisSegment: 0,
      origin: ride.origin,
      destinationStationId: ride.destinationStationId,
    );
    await _sessions.write(_session!);
    await ProximityForegroundService.instance.updateNotification(
      title: '${ride.line.label} → ${await terminusName(_session!)}',
      text: 'At ${arrived.name} · next: ${next.name}',
    );
    await _registerActiveFences(arrived, next, ride.direction);
    if (ride.origin == RideOrigin.manual) {
      _scheduleManualDeparture(at);
    } else {
      _idleTimer?.cancel();
      _idleTimer = Timer(RideConfig.rideIdleTimeout, () {
        if (_session?.phase == RidePhase.atStation) {
          unawaited(stopRide(reason: 'no departure detected', notify: false));
        }
      });
    }
    notifyListeners();
  }

  void _scheduleManualDeparture(DateTime arrivedAt) {
    _manualDepartureTimer?.cancel();
    final departureAt = arrivedAt.add(RideConfig.manualStationDwell);
    final delay = departureAt.difference(DateTime.now());
    _manualDepartureTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(_departManualStation()),
    );
  }

  Future<void> _departManualStation() async {
    final ride = _session;
    if (ride == null ||
        ride.origin != RideOrigin.manual ||
        ride.phase != RidePhase.atStation) {
      return;
    }
    final current = await _stations.byId(ride.currentStationId);
    if (current == null) return;
    await _startSegment(
      current: current,
      direction: ride.direction,
      confirmed: true,
      origin: RideOrigin.manual,
      destinationStationId: ride.destinationStationId,
      departedAt: DateTime.now(),
    );
  }

  Future<void> _departFromOnboardStation() async {
    final ride = _session;
    if (ride == null || ride.phase != RidePhase.atStation) return;
    final current = await _stations.byId(ride.currentStationId);
    if (current == null) return;
    final fix = await _location.getFix();
    if (fix != null) {
      final next = await _stations.neighbor(current, ride.direction);
      if (next == null) return;
      final distance = GeoUtils.distanceM(current.point, fix.point);
      final elapsed = RideConfig.departureVerifyDelay.inSeconds;
      final speed = distance / elapsed;
      final bearing = GeoUtils.bearingDeg(current.point, fix.point);
      final expected = GeoUtils.bearingDeg(current.point, next.point);
      if (speed < RideConfig.minTrainSpeedMs ||
          GeoUtils.angularDistanceDeg(bearing, expected) >
              RideConfig.headingToleranceDeg) {
        await stopRide(reason: 'user appears to have alighted', notify: false);
        return;
      }
    }
    await _startSegment(
      current: current,
      direction: ride.direction,
      confirmed: ride.confirmed,
      origin: ride.origin,
      destinationStationId: ride.destinationStationId,
      fix: fix,
      departedAt: DateTime.now().subtract(RideConfig.departureVerifyDelay),
    );
  }

  Future<void> stopRide({required String reason, bool notify = true}) async {
    final old = _session;
    _session = null;
    _approachTimer?.cancel();
    _correctionTimer?.cancel();
    _arrivalTimer?.cancel();
    _manualDepartureTimer?.cancel();
    _idleTimer?.cancel();
    await _alerts.cancelApproach();
    await _sessions.clear();
    await ProximityForegroundService.instance.stopRide();
    await _logs.add('ended: $reason');
    if (notify && old != null) {
      await _alerts.showInfo('Train ride alerts stopped', reason);
    }
    if (AppPrefs.trainRideAlertsEnabled) await _registerIdleRing();
    notifyListeners();
  }

  Future<void> reverseDirection() async {
    final ride = _session;
    if (ride == null) return;
    final current = await _stations.byId(ride.currentStationId);
    if (current == null) return;
    await _startSegment(
      current: current,
      direction: -ride.direction,
      confirmed: true,
      origin: RideOrigin.manual,
      destinationStationId: ride.destinationStationId,
    );
  }

  Future<void> setDestination(String stationId) async {
    final ride = _session;
    if (ride == null) return;
    final station = await _stations.byId(stationId);
    final current = await _stations.byId(ride.currentStationId);
    if (station == null || current == null || station.line != ride.line) return;
    final isAhead = ride.direction > 0
        ? station.orderIndex > current.orderIndex
        : station.orderIndex < current.orderIndex;
    if (!isAhead) return;
    _session = ride.copyWith(destinationStationId: stationId);
    await _sessions.write(_session!);
    notifyListeners();
  }

  Future<void> _resumeSessionTimers() async {
    final ride = _session!;
    await ProximityForegroundService.instance.startRide(
      title: '${ride.line.label} train ride',
      text: ride.nextStationId == null
          ? 'Restoring ride…'
          : 'Next: ${(await _stations.byId(ride.nextStationId!))?.name ?? 'station'}',
    );
    if (ride.origin == RideOrigin.manual) {
      if (ride.phase == RidePhase.atStation) {
        _scheduleManualDeparture(DateTime.now());
      } else {
        if (ride.confirmed) await _scheduleApproachForCurrentSession();
        _armCorrectionAndArrivalTimers();
      }
    } else if (ride.etaAt != null &&
        ride.etaAt!.add(const Duration(minutes: 5)).isBefore(DateTime.now())) {
      await _resync();
    } else {
      if (ride.confirmed) await _scheduleApproachForCurrentSession();
      _armCorrectionAndArrivalTimers();
    }
  }

  Future<List<Station>> stationsFor(TrainLine line) =>
      _stations.lineStations(line);

  Future<String> currentStationName(RideSession ride) async =>
      (await _stations.byId(ride.currentStationId))?.name ?? 'Unknown station';
  Future<String> nextStationName(RideSession ride) async =>
      ride.nextStationId == null
      ? 'End of line'
      : (await _stations.byId(ride.nextStationId!))?.name ?? 'Unknown station';
  Future<String> terminusName(RideSession ride) async {
    final stations = await _stations.lineStations(ride.line);
    return (ride.direction > 0 ? stations.last : stations.first).name;
  }

  String etaLabel(RideSession ride) {
    if (ride.etaAt == null) return 'waiting to depart';
    final minutes = ride.etaAt!.difference(DateTime.now()).inSeconds / 60;
    final rounded = minutes.ceil().clamp(1, 99);
    return '~$rounded min${ride.origin == RideOrigin.manual ? ' est.' : ''}';
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  static bool _sameSession(RideSession? a, RideSession? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.id == b.id &&
        a.line == b.line &&
        a.direction == b.direction &&
        a.phase == b.phase &&
        a.confirmed == b.confirmed &&
        a.currentStationId == b.currentStationId &&
        a.nextStationId == b.nextStationId &&
        a.departedAt == b.departedAt &&
        a.etaAt == b.etaAt &&
        a.alertAt == b.alertAt &&
        a.fixesUsedThisSegment == b.fixesUsedThisSegment &&
        a.origin == b.origin &&
        a.destinationStationId == b.destinationStationId &&
        a.segmentAlertSent == b.segmentAlertSent;
  }
}

class _BoardingCandidate {
  _BoardingCandidate({
    required this.station,
    required this.enteredAt,
    required this.enterPoint,
  });
  final Station station;
  final DateTime enteredAt;
  final GeoPoint enterPoint;
  bool dwelled = false;
}
