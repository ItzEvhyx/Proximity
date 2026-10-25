import 'dart:convert';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:native_geofence/native_geofence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../../core/global_services/foreground_service.dart';
import '../../../core/shared_prefs/shared_prefs.dart';
import '../data/ride_stores.dart';
import '../data/station_repository.dart';
import '../domain/boarding_detector.dart';
import '../domain/direction_resolver.dart';
import '../domain/eta_estimator.dart';
import '../domain/geo_utils.dart';
import '../domain/models.dart';
import '../ride_config.dart';

class RideGeofenceEvent {
  const RideGeofenceEvent(
    this.id,
    this.event,
    this.point,
    this.at, {
    this.processedInBackground = false,
  });
  final String id;
  final GeofenceEvent event;
  final GeoPoint? point;
  final DateTime at;
  final bool processedInBackground;
}

/// The native callback has no UI isolate guarantee. It persists a compact event
/// queue which the controller consumes after launch/resume, avoiding network
/// work or a continuous location stream.
@pragma('vm:entry-point')
Future<void> rideGeofenceCallback(GeofenceCallbackParams params) async {
  var processed = false;
  try {
    processed = await _BackgroundRideProcessor().handle(params);
  } catch (_) {
    // Preserve the raw callback for the main isolate if headless processing
    // cannot complete on a particular device/OEM.
  }
  final prefs = await SharedPreferences.getInstance();
  final queue =
      prefs.getStringList(RideGeofenceService._eventQueueKey) ?? <String>[];
  for (final fence in params.geofences) {
    queue.add(
      jsonEncode({
        'id': fence.id,
        'event': params.event.name,
        'lat': params.location?.latitude,
        'lng': params.location?.longitude,
        'at': DateTime.now().toIso8601String(),
        'processed': processed,
      }),
    );
  }
  await prefs.setStringList(
    RideGeofenceService._eventQueueKey,
    queue.length <= 50 ? queue : queue.sublist(queue.length - 50),
  );
}

@pragma('vm:entry-point')
Future<void> rideNotificationBackgroundResponse(
  NotificationResponse response,
) async {
  await _handleRideNotificationResponse(response.actionId);
}

Future<void> _handleRideNotificationResponse(String? actionId) async {
  if (actionId != 'ride_yes' && actionId != 'ride_no') return;
  final sessions = RideSessionStore();
  final session = await sessions.read();
  if (session == null || session.confirmed) return;
  if (actionId == 'ride_no') {
    await sessions.clear();
    await RideAlertScheduler().cancelApproach();
    await ProximityForegroundService.instance.stopRide();
    return;
  }
  final confirmed = session.copyWith(confirmed: true);
  await sessions.write(confirmed);
  if (confirmed.alertAt != null && confirmed.nextStationId != null) {
    final next = await StationRepository().byId(confirmed.nextStationId!);
    if (next != null) {
      await RideAlertScheduler().scheduleApproach(
        stationName: next.name,
        when: confirmed.alertAt!,
      );
    }
  }
}

class RideGeofenceService {
  static const _eventQueueKey = 'ride_tracking_geofence_events_v1';
  bool _ready = false;
  Future<void> initialize() async {
    if (_ready || !Platform.isAndroid && !Platform.isIOS) return;
    await NativeGeofenceManager.instance.initialize();
    _ready = true;
  }

  Future<void> replace(List<Station> stations, {GeoPoint? recenterAt}) async {
    await initialize();
    if (!_ready) return;
    await NativeGeofenceManager.instance.removeAllGeofences();
    for (final station in stations) {
      final fence = Geofence(
        id: 'station:${station.id}',
        location: Location(
          latitude: station.point.latitude,
          longitude: station.point.longitude,
        ),
        radiusMeters: station.wakeRadiusM ?? RideConfig.stationWakeRadiusM,
        triggers: {
          GeofenceEvent.enter,
          GeofenceEvent.exit,
          GeofenceEvent.dwell,
        },
        iosSettings: const IosGeofenceSettings(),
        androidSettings: AndroidGeofenceSettings(
          initialTriggers: const {},
          loiteringDelay: RideConfig.dwellLoiter,
          notificationResponsiveness: const Duration(seconds: 30),
        ),
      );
      await NativeGeofenceManager.instance.createGeofence(
        fence,
        rideGeofenceCallback,
      );
    }
    if (recenterAt != null) {
      await NativeGeofenceManager.instance.createGeofence(
        Geofence(
          id: 'recenter',
          location: Location(
            latitude: recenterAt.latitude,
            longitude: recenterAt.longitude,
          ),
          radiusMeters: RideConfig.recenterRadiusM,
          triggers: {GeofenceEvent.exit},
          iosSettings: const IosGeofenceSettings(),
          androidSettings: const AndroidGeofenceSettings(
            initialTriggers: {},
            notificationResponsiveness: Duration(seconds: 30),
          ),
        ),
        rideGeofenceCallback,
      );
    }
  }

  Future<void> clear() async {
    if (_ready) await NativeGeofenceManager.instance.removeAllGeofences();
  }

  Future<List<RideGeofenceEvent>> consumeEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_eventQueueKey) ?? const <String>[];
    await prefs.remove(_eventQueueKey);
    return raw.map((item) {
      final json = jsonDecode(item) as Map<String, dynamic>;
      final latitude = json['lat'] as num?;
      final longitude = json['lng'] as num?;
      return RideGeofenceEvent(
        (json['id'] as String).replaceFirst('station:', ''),
        GeofenceEvent.values.byName(json['event'] as String),
        latitude == null || longitude == null
            ? null
            : GeoPoint(latitude.toDouble(), longitude.toDouble()),
        DateTime.parse(json['at'] as String),
        processedInBackground: json['processed'] as bool? ?? false,
      );
    }).toList();
  }
}

class _BackgroundRideProcessor {
  static const _candidateKey = 'ride_tracking_boarding_candidate_v1';
  final _stations = StationRepository();
  final _sessions = RideSessionStore();
  final _location = RideLocationService();
  final _alerts = RideAlertScheduler();

  Future<bool> handle(GeofenceCallbackParams params) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('train_ride_alerts_enabled') ?? false;
    final autoDetect = prefs.getBool('train_auto_detect') ?? true;
    var session = await _sessions.read();
    var handled = false;
    for (final fence in params.geofences) {
      if (fence.id == 'recenter' && params.event == GeofenceEvent.exit) {
        final fix = await _location.getFix();
        if (fix != null) {
          final nearest = await _stations.nearest(
            fix.point,
            limit: RideConfig.geofenceRingSize,
          );
          try {
            await RideGeofenceService().replace(nearest, recenterAt: fix.point);
          } catch (_) {
            // Re-registration is retried by the main isolate on next launch.
          }
        }
        handled = true;
        continue;
      }
      final stationId = fence.id.replaceFirst('station:', '');
      final station = await _stations.byId(stationId);
      if (station == null) continue;
      final point = params.location == null
          ? station.point
          : GeoPoint(params.location!.latitude, params.location!.longitude);
      if (session == null) {
        if (!enabled || !autoDetect) continue;
        handled =
            await _handleIdleEvent(
              prefs: prefs,
              station: station,
              event: params.event,
              point: point,
            ) ||
            handled;
        session = await _sessions.read();
        continue;
      }
      if (params.event == GeofenceEvent.enter &&
          station.id == session.nextStationId) {
        await _handleArrival(session, station, point);
        session = await _sessions.read();
        handled = true;
      } else if (params.event == GeofenceEvent.exit &&
          station.id == session.currentStationId &&
          session.phase == RidePhase.atStation) {
        await _promoted(() => _departExistingSession(session!, station));
        session = await _sessions.read();
        handled = true;
      }
    }
    return handled;
  }

  Future<bool> _handleIdleEvent({
    required SharedPreferences prefs,
    required Station station,
    required GeofenceEvent event,
    required GeoPoint point,
  }) async {
    if (event == GeofenceEvent.enter) {
      await prefs.setString(
        _candidateKey,
        jsonEncode({
          'station': station.id,
          'enteredAt': DateTime.now().toIso8601String(),
          'lat': point.latitude,
          'lng': point.longitude,
          'dwelled': false,
        }),
      );
      return true;
    }
    final raw = prefs.getString(_candidateKey);
    if (raw == null) return false;
    final candidate = jsonDecode(raw) as Map<String, dynamic>;
    if (candidate['station'] != station.id) return false;
    if (event == GeofenceEvent.dwell) {
      candidate['dwelled'] = true;
      await prefs.setString(_candidateKey, jsonEncode(candidate));
      return true;
    }
    if (event != GeofenceEvent.exit) return false;
    await prefs.remove(_candidateKey);
    final enteredAt = DateTime.parse(candidate['enteredAt'] as String);
    if (DateTime.now().difference(enteredAt) > RideConfig.departureWindow) {
      return true;
    }
    await _promoted(() async {
      await Future<void>.delayed(RideConfig.departureVerifyDelay);
      final fix = await _location.getFix();
      if (fix == null || fix.accuracyM > RideConfig.maxFixAccuracyM) return;
      final exitPoint = point;
      final observedBearing = GeoUtils.bearingDeg(exitPoint, fix.point);
      final matches = DirectionResolver.candidates(
        station,
        await _stations.all(),
        observedBearing,
      );
      if (matches.isEmpty) return;
      final match = matches.first;
      final neighbor = await _stations.neighbor(station, match.direction);
      if (neighbor == null) return;
      final decision = BoardingDetector.evaluate(
        BoardingEvidence(
          exitPoint: exitPoint,
          exitAt: DateTime.now().subtract(RideConfig.departureVerifyDelay),
          fix: fix,
          hadDwell: candidate['dwelled'] as bool? ?? false,
        ),
        GeoUtils.bearingDeg(station.point, neighbor.point),
      );
      if (!decision.passesGates) return;
      await _startSegment(
        current: station,
        direction: match.direction,
        confirmed: decision.isConfirmed,
        origin: RideOrigin.automatic,
        fix: fix,
        departedAt: DateTime.now().subtract(RideConfig.departureVerifyDelay),
      );
      if (!decision.isConfirmed) {
        final lineStations = await _stations.lineStations(station.line);
        await _alerts.showConfirmPrompt(
          lineLabel: station.line.label,
          terminusName:
              (match.direction > 0 ? lineStations.last : lineStations.first)
                  .name,
        );
      }
    });
    return true;
  }

  Future<void> _handleArrival(
    RideSession session,
    Station station,
    GeoPoint eventPoint,
  ) async {
    if (session.confirmed && !session.segmentAlertSent) {
      await _alerts.showApproach(station.name);
    }
    if (GeoUtils.distanceM(eventPoint, station.point) >
        (station.arriveRadiusM ?? RideConfig.stationArriveRadiusM)) {
      await Future<void>.delayed(RideConfig.arrivalSettle);
    }
    var confirmed = session.confirmed;
    final now = DateTime.now();
    if (!confirmed && session.etaAt != null && session.departedAt != null) {
      final expected = session.etaAt!
          .difference(session.departedAt!)
          .inMilliseconds
          .abs();
      final drift = now.difference(session.etaAt!).inMilliseconds.abs();
      confirmed =
          expected > 0 && drift <= expected * RideConfig.tentativeEtaTolerance;
      if (!confirmed) {
        await _sessions.clear();
        await _alerts.cancelApproach();
        await ProximityForegroundService.instance.stopRide();
        return;
      }
    }
    final next = await _stations.neighbor(station, session.direction);
    if (station.id == session.destinationStationId || next == null) {
      await _alerts.showInfo(
        next == null ? 'End of line' : 'You’ve arrived',
        'At ${station.name}',
      );
      await _sessions.clear();
      await _alerts.cancelApproach();
      await ProximityForegroundService.instance.stopRide();
      return;
    }
    final advanced = RideSession(
      id: session.id,
      line: session.line,
      direction: session.direction,
      phase: RidePhase.atStation,
      confirmed: confirmed,
      currentStationId: station.id,
      nextStationId: next.id,
      departedAt: null,
      etaAt: null,
      alertAt: null,
      fixesUsedThisSegment: 0,
      origin: session.origin,
      destinationStationId: session.destinationStationId,
    );
    await _sessions.write(advanced);
    await _alerts.cancelApproach();
    await ProximityForegroundService.instance.updateNotification(
      title: '${session.line.label} train ride',
      text: 'At ${station.name} · next: ${next.name}',
    );
    await _registerActiveFences(station, next, session.direction);
  }

  Future<void> _departExistingSession(
    RideSession session,
    Station current,
  ) async {
    await Future<void>.delayed(RideConfig.departureVerifyDelay);
    final fix = await _location.getFix();
    if (fix != null) {
      final next = await _stations.neighbor(current, session.direction);
      if (next == null) return;
      final speed =
          GeoUtils.distanceM(current.point, fix.point) /
          RideConfig.departureVerifyDelay.inSeconds;
      final headingDelta = GeoUtils.angularDistanceDeg(
        GeoUtils.bearingDeg(current.point, fix.point),
        GeoUtils.bearingDeg(current.point, next.point),
      );
      if (speed < RideConfig.minTrainSpeedMs ||
          headingDelta > RideConfig.headingToleranceDeg) {
        await _sessions.clear();
        await ProximityForegroundService.instance.stopRide();
        return;
      }
    }
    await _startSegment(
      current: current,
      direction: session.direction,
      confirmed: session.confirmed,
      origin: session.origin,
      fix: fix,
      departedAt: DateTime.now().subtract(RideConfig.departureVerifyDelay),
      destinationStationId: session.destinationStationId,
      rideId: session.id,
    );
  }

  Future<void> _startSegment({
    required Station current,
    required int direction,
    required bool confirmed,
    required RideOrigin origin,
    required DateTime departedAt,
    LocationFix? fix,
    String? destinationStationId,
    String? rideId,
  }) async {
    final segment = await _stations.segment(current, direction);
    if (segment == null) return;
    final next = await _stations.byId(segment.toStationId);
    if (next == null) return;
    final along = fix == null || fix.accuracyM > RideConfig.maxFixAccuracyM
        ? 0.0
        : GeoUtils.projectAlongSegmentM(
            from: current.point,
            to: next.point,
            point: fix.point,
          );
    final speed =
        await SegmentTimingStore().speedFor(segment.id) ??
        RideConfig.defaultCruiseMs;
    final prefs = await SharedPreferences.getInstance();
    final estimate = EtaEstimator.estimate(
      fixAt: fix?.at ?? departedAt,
      segmentDistanceM: segment.trackDistanceM,
      alongM: along,
      cruiseMs: speed,
      approachLead: Duration(
        seconds: prefs.getInt('train_approach_lead_seconds') ?? 60,
      ),
    );
    final session = RideSession(
      id: rideId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      line: current.line,
      direction: direction,
      phase: RidePhase.inTransit,
      confirmed: confirmed,
      currentStationId: current.id,
      nextStationId: next.id,
      departedAt: departedAt,
      etaAt: estimate.etaAt,
      alertAt: estimate.alertAt,
      fixesUsedThisSegment: fix == null ? 0 : 1,
      origin: origin,
      destinationStationId: destinationStationId,
    );
    await _sessions.write(session);
    if (confirmed) {
      await _alerts.scheduleApproach(
        stationName: next.name,
        when: estimate.alertAt,
      );
    }
    await ProximityForegroundService.instance.startRide(
      title: '${current.line.label} train ride',
      text: 'Next: ${next.name}',
      requestPermissions: false,
    );
    await _registerActiveFences(current, next, direction);
  }

  Future<void> _registerActiveFences(
    Station current,
    Station next,
    int direction,
  ) async {
    final after = await _stations.neighbor(next, direction);
    try {
      await RideGeofenceService().replace([current, next, ?after]);
    } catch (_) {
      // The scheduled notification remains the primary process-independent
      // alert if an OEM refuses geofence replacement in this callback.
    }
  }

  Future<void> _promoted(Future<void> Function() action) async {
    try {
      await NativeGeofenceBackgroundManager.instance.promoteToForeground();
      await action();
    } finally {
      try {
        await NativeGeofenceBackgroundManager.instance.demoteToBackground();
      } catch (_) {
        // The callback may already have been demoted by Android.
      }
    }
  }
}

class RideLocationService {
  Future<LocationFix?> getFix() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: RideConfig.fixTimeout,
        ),
      );
      return LocationFix(
        point: GeoPoint(position.latitude, position.longitude),
        accuracyM: position.accuracy,
        at: position.timestamp,
      );
    } catch (_) {
      return null;
    }
  }
}

class RideAlertScheduler {
  RideAlertScheduler() {
    tz_data.initializeTimeZones();
  }
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  static const _approachId = 4101;
  Future<void> initialize() async {
    if (_ready) return;
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_train'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _handleRideNotificationResponse(response.actionId),
      onDidReceiveBackgroundNotificationResponse:
          rideNotificationBackgroundResponse,
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!AppPrefs.isPermissionUsageEnabled('notifications')) return false;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final notifications =
        await android?.requestNotificationsPermission() ?? true;
    if (!notifications) return false;
    if (AppPrefs.isPermissionUsageEnabled('exact_alarm') &&
        android != null &&
        await android.canScheduleExactNotifications() != true) {
      return await android.requestExactAlarmsPermission() ?? false;
    }
    return true;
  }

  Future<void> scheduleApproach({
    required String stationName,
    required DateTime when,
  }) async {
    await initialize();
    if (!AppPrefs.isPermissionUsageEnabled('notifications')) return;
    if (!when.isAfter(DateTime.now())) {
      await showApproach(stationName);
      return;
    }
    final vibrateOnly =
        (await SharedPreferences.getInstance()).getString(
          'train_alert_style',
        ) ==
        'vibrate';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        vibrateOnly ? 'ride_approach_vibrate' : 'ride_approach_sound',
        vibrateOnly
            ? 'Train ride approaches (vibrate)'
            : 'Train ride approaches',
        channelDescription: 'Alerts shortly before the next train station.',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: !vibrateOnly,
        category: AndroidNotificationCategory.transport,
      ),
    );
    try {
      await _notifications.zonedSchedule(
        id: _approachId,
        title: 'Approaching $stationName',
        body: 'Your next station is $stationName · get ready to alight',
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: details,
        androidScheduleMode: AppPrefs.isPermissionUsageEnabled('exact_alarm')
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // Manual mode remains useful when exact-alarm access is denied. Android
      // may deliver this fallback later under Doze, but the next-station
      // geofence still provides an immediate safety-net alert.
      await _notifications.zonedSchedule(
        id: _approachId,
        title: 'Approaching $stationName',
        body: 'Your next station is $stationName · get ready to alight',
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> showApproach(String stationName) async {
    await initialize();
    if (!AppPrefs.isPermissionUsageEnabled('notifications')) return;
    final vibrateOnly =
        (await SharedPreferences.getInstance()).getString(
          'train_alert_style',
        ) ==
        'vibrate';
    await _notifications.show(
      id: _approachId,
      title: 'Approaching $stationName',
      body: 'Your next station is $stationName · get ready to alight',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          vibrateOnly ? 'ride_approach_vibrate' : 'ride_approach_sound',
          vibrateOnly
              ? 'Train ride approaches (vibrate)'
              : 'Train ride approaches',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: !vibrateOnly,
        ),
      ),
    );
  }

  Future<void> showInfo(String title, String body) async {
    await initialize();
    if (!AppPrefs.isPermissionUsageEnabled('notifications')) return;
    await _notifications.show(
      id: 4102,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'ride_status',
          'Train ride status',
          importance: Importance.defaultImportance,
        ),
      ),
    );
  }

  Future<void> showConfirmPrompt({
    required String lineLabel,
    required String terminusName,
  }) async {
    await initialize();
    if (!AppPrefs.isPermissionUsageEnabled('notifications')) return;
    await _notifications.show(
      id: 4103,
      title: 'Riding $lineLabel toward $terminusName?',
      body: 'Confirm to turn on approaching-station alerts.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'ride_confirm',
          'Train ride confirmation',
          channelDescription: 'Quiet prompts to confirm detected train rides.',
          importance: Importance.low,
          priority: Priority.low,
          actions: [
            AndroidNotificationAction('ride_yes', 'Yes'),
            AndroidNotificationAction('ride_no', 'No'),
          ],
        ),
      ),
    );
  }

  Future<void> cancelApproach() async => _notifications.cancel(id: _approachId);
}
