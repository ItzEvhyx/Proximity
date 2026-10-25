import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../shared_prefs/shared_prefs.dart';

/// Top-level callback required by flutter_foreground_task.
/// Must be a top-level or static function annotated with @pragma.
@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_ProximityTaskHandler());
}

/// Runs independently of the UI isolate. This is what keeps active proximity
/// tracking alive after the user removes the app from Recents.
class _ProximityTaskHandler extends TaskHandler {
  bool _refreshing = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _restoreRingingAlarmIfNeeded();
    await _refreshTrackingNotification();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_refreshTrackingNotification());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Cleanup if needed — currently nothing.
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    // Bring the app to the foreground when the user taps the notification.
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {}

  /// If Android recreates this service after reclaiming the app process, bring
  /// back an alarm that was already ringing. The payload was persisted before
  /// the UI was shown, so HomeScreen can restore the user's selected snooze
  /// challenge without depending on the old Flutter isolate.
  Future<void> _restoreRingingAlarmIfNeeded() async {
    final active = await FlutterForegroundTask.getData<bool>(
      key: ProximityForegroundService._trackingActiveKey,
    );
    final ringing = await FlutterForegroundTask.getData<bool>(
      key: ProximityForegroundService._alarmRingingKey,
    );
    final pending = await FlutterForegroundTask.getData<bool>(
      key: ProximityForegroundService._pendingAlarmKey,
    );
    if (active == true && ringing == true && pending == true) {
      FlutterForegroundTask.launchApp('/');
    }
  }

  Future<void> _refreshTrackingNotification() async {
    if (_refreshing) return;
    _refreshing = true;

    try {
      final active = await FlutterForegroundTask.getData<bool>(
        key: ProximityForegroundService._trackingActiveKey,
      );
      if (active != true) return;

      final destinationLat = await FlutterForegroundTask.getData<double>(
        key: ProximityForegroundService._destinationLatitudeKey,
      );
      final destinationLng = await FlutterForegroundTask.getData<double>(
        key: ProximityForegroundService._destinationLongitudeKey,
      );
      final destinationName = await FlutterForegroundTask.getData<String>(
        key: ProximityForegroundService._destinationNameKey,
      );
      final zoneMeters = await FlutterForegroundTask.getData<int>(
        key: ProximityForegroundService._alertZoneMetersKey,
      );
      final isAlarmRinging = await FlutterForegroundTask.getData<bool>(
        key: ProximityForegroundService._alarmRingingKey,
      );
      final snoozedUntilMs = await FlutterForegroundTask.getData<int>(
        key: ProximityForegroundService._snoozedUntilMsKey,
      );

      if (destinationLat == null || destinationLng == null) return;

      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));
      final meters = geo.Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        destinationLat,
        destinationLng,
      );
      final distanceLabel = meters < 1000
          ? '${meters.round()} m'
          : '${(meters / 1000).toStringAsFixed(1)} km';

      await FlutterForegroundTask.updateService(
        notificationTitle: 'Proximity alarm active',
        notificationText:
            'Tracking ${destinationName ?? 'your destination'} · $distanceLabel away',
      );

      // This isolate stays alive after the UI is removed from Recents. Persist
      // a pending alarm before asking Android to reopen the app so a cold UI
      // isolate can recover the exact alarm session rather than losing it.
      final canRing =
          isAlarmRinging != true &&
          DateTime.now().millisecondsSinceEpoch >= (snoozedUntilMs ?? 0);
      if (zoneMeters != null &&
          zoneMeters > 0 &&
          meters <= zoneMeters &&
          canRing) {
        final etaMinutes = (meters / 1.4 / 60).round();
        final eta = etaMinutes < 60
            ? '$etaMinutes min'
            : '${etaMinutes ~/ 60}h ${etaMinutes % 60}m';
        await Future.wait([
          FlutterForegroundTask.saveData(
            key: ProximityForegroundService._alarmRingingKey,
            value: true,
          ),
          FlutterForegroundTask.saveData(
            key: ProximityForegroundService._pendingAlarmKey,
            value: true,
          ),
          FlutterForegroundTask.saveData(
            key: ProximityForegroundService._alarmDistanceKey,
            value: distanceLabel,
          ),
          FlutterForegroundTask.saveData(
            key: ProximityForegroundService._alarmEtaKey,
            value: eta,
          ),
        ]);
        final alarm = <String, Object>{
          'type': 'background_alarm',
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'destinationName': destinationName ?? 'your destination',
          'distance': distanceLabel,
          'eta': eta,
        };
        FlutterForegroundTask.sendDataToMain(alarm);
        // If the main isolate is not present, this opens it. The persisted
        // pending alarm above is consumed by HomeScreen during startup.
        FlutterForegroundTask.launchApp('/');
        return;
      }

      // Let the foreground UI refresh immediately when it still exists.
      FlutterForegroundTask.sendDataToMain({
        'type': 'background_location',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'distanceMeters': meters,
      });
    } catch (_) {
      // Keep the foreground service and its persistent notification alive if
      // one GPS read fails (for example, while a tunnel blocks reception).
    } finally {
      _refreshing = false;
    }
  }
}

/// Wraps flutter_foreground_task to provide a simple start/stop API for
/// keeping the app alive in the background during proximity tracking or
/// wayfinding navigation.
///
/// Usage:
///   await ProximityForegroundService.instance.start(...);
///   await ProximityForegroundService.instance.stop();
class ProximityForegroundService {
  ProximityForegroundService._();

  static final ProximityForegroundService instance =
      ProximityForegroundService._();

  bool _initialized = false;

  static const _trackingActiveKey = 'proximity_tracking_active';
  static const _rideTrackingActiveKey = 'train_ride_tracking_active';
  static const _destinationLatitudeKey = 'proximity_destination_latitude';
  static const _destinationLongitudeKey = 'proximity_destination_longitude';
  static const _destinationNameKey = 'proximity_destination_name';
  static const _alertZoneMetersKey = 'proximity_alert_zone_meters';
  static const _alarmRingingKey = 'proximity_alarm_ringing';
  static const _pendingAlarmKey = 'proximity_pending_alarm';
  static const _alarmDistanceKey = 'proximity_alarm_distance';
  static const _alarmEtaKey = 'proximity_alarm_eta';
  static const _snoozedUntilMsKey = 'proximity_snoozed_until_ms';

  /// Initialize the foreground task options. Call once at app startup.
  void init() {
    if (_initialized) return;
    _initialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'proximity_tracking',
        channelName: 'Proximity Tracking',
        channelDescription:
            'Keeps proximity alarm and navigation active in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        // Low importance = no sound/vibration, just persistent icon.
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // The task isolate owns tracking after the UI task is removed.
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        // Be explicit: swiping Proximity from Recents must not stop an active
        // alarm, and Android should recreate the service if it is reclaimed.
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  /// Requests notification permission (Android 13+) so the foreground service
  /// notification can be shown. Returns true if granted.
  Future<bool> requestPermissions() async {
    if (!AppPrefs.isPermissionUsageEnabled('notifications')) return false;
    final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      final result =
          await FlutterForegroundTask.requestNotificationPermission();
      if (result != NotificationPermission.granted) return false;
    }

    if (Platform.isAndroid &&
        AppPrefs.isPermissionUsageEnabled('battery_optimization')) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }

    return true;
  }

  /// Starts the foreground service with a sticky notification.
  /// [title] and [text] customize the notification content.
  Future<void> start({
    String title = 'Proximity is active',
    String text = 'Tracking your location in the background',
    required double destinationLatitude,
    required double destinationLongitude,
    required String destinationName,
    int? alertZoneMeters,
  }) async {
    if (!_initialized) init();

    // Ask only when the user starts background tracking, never while the app
    // is launching. This avoids a system permission/settings activity keeping
    // the launch splash visible indefinitely.
    if (!await requestPermissions()) return;

    await Future.wait([
      FlutterForegroundTask.saveData(key: _trackingActiveKey, value: true),
      FlutterForegroundTask.saveData(
        key: _destinationLatitudeKey,
        value: destinationLatitude,
      ),
      FlutterForegroundTask.saveData(
        key: _destinationLongitudeKey,
        value: destinationLongitude,
      ),
      FlutterForegroundTask.saveData(
        key: _destinationNameKey,
        value: destinationName,
      ),
      FlutterForegroundTask.saveData(
        key: _alertZoneMetersKey,
        value: alertZoneMeters ?? 0,
      ),
      FlutterForegroundTask.saveData(key: _alarmRingingKey, value: false),
      FlutterForegroundTask.saveData(key: _pendingAlarmKey, value: false),
      FlutterForegroundTask.saveData(key: _snoozedUntilMsKey, value: 0),
    ]);

    if (await FlutterForegroundTask.isRunningService) {
      // Already running — just update the notification text.
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 100,
      notificationTitle: title,
      notificationText: text,
      notificationIcon: null,
      notificationButtons: [],
      notificationInitialRoute: '/',
      callback: _startCallback,
    );
  }

  /// Keeps Android from reclaiming an active train ride without starting the
  /// 15-second destination polling loop. Train tracking is driven by OS
  /// geofences plus bounded single-shot fixes instead.
  Future<bool> startRide({
    required String title,
    required String text,
    bool requestPermissions = true,
  }) async {
    if (!_initialized) init();
    if (requestPermissions && !await this.requestPermissions()) return false;
    await FlutterForegroundTask.saveData(
      key: _rideTrackingActiveKey,
      value: true,
    );
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
      return true;
    }
    await FlutterForegroundTask.startService(
      serviceId: 101,
      notificationTitle: title,
      notificationText: text,
      notificationInitialRoute: '/',
      callback: _startCallback,
    );
    return true;
  }

  Future<void> stopRide() async {
    await FlutterForegroundTask.removeData(key: _rideTrackingActiveKey);
    final proximityActive = await FlutterForegroundTask.getData<bool>(
      key: _trackingActiveKey,
    );
    if (proximityActive != true &&
        await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  /// Updates the notification text (e.g. with new ETA/distance info).
  /// Uses a multi-line format for better readability in the notification shade:
  ///   📍 Distance: 350 m
  ///   ⏱ ETA: 4 min
  Future<void> updateNotification({
    String? title,
    String? text,
    String? eta,
    String? distance,
  }) async {
    if (!await FlutterForegroundTask.isRunningService) return;

    // If ETA and distance are provided, format as a structured notification.
    final notifText = (eta != null && distance != null)
        ? '📍 Distance: $distance\n⏱ ETA: $eta'
        : text ?? 'Tracking your location in the background';

    await FlutterForegroundTask.updateService(
      notificationTitle: title ?? 'Proximity is active',
      notificationText: notifText,
    );
  }

  /// Persists an active alarm before presenting UI. This prevents duplicate
  /// background triggers and allows a recreated service/UI to recover the
  /// exact alarm instead of silently dropping it.
  Future<void> markAlarmRinging(ProximityAlarmData alarm) async {
    await Future.wait([
      FlutterForegroundTask.saveData(key: _alarmRingingKey, value: true),
      FlutterForegroundTask.saveData(key: _pendingAlarmKey, value: true),
      FlutterForegroundTask.saveData(
        key: _alarmDistanceKey,
        value: alarm.distance,
      ),
      FlutterForegroundTask.saveData(key: _alarmEtaKey, value: alarm.eta),
    ]);
  }

  /// Snoozing intentionally keeps location tracking alive. After this period,
  /// the background isolate is allowed to ring again if the user is still in
  /// the alert zone.
  Future<void> snooze({Duration duration = const Duration(minutes: 5)}) async {
    await Future.wait([
      FlutterForegroundTask.saveData(key: _alarmRingingKey, value: false),
      FlutterForegroundTask.saveData(key: _pendingAlarmKey, value: false),
      FlutterForegroundTask.saveData(
        key: _snoozedUntilMsKey,
        value: DateTime.now().add(duration).millisecondsSinceEpoch,
      ),
    ]);
    await updateNotification(
      title: 'Proximity alarm snoozed',
      text: 'We will alert you again in 5 minutes if you are still nearby.',
    );
  }

  /// Reads an alarm raised by the background task before Flutter's UI existed.
  /// It remains stored until the user completes their snooze method, so it can
  /// be restored even if Android reclaims the UI while it is ringing.
  Future<ProximityAlarmData?> consumePendingAlarm() async {
    final pending = await FlutterForegroundTask.getData<bool>(
      key: _pendingAlarmKey,
    );
    if (pending != true) return null;
    final destination = await FlutterForegroundTask.getData<String>(
      key: _destinationNameKey,
    );
    final distance = await FlutterForegroundTask.getData<String>(
      key: _alarmDistanceKey,
    );
    final eta = await FlutterForegroundTask.getData<String>(key: _alarmEtaKey);
    return ProximityAlarmData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      destinationName: destination ?? 'your destination',
      distance: distance ?? '—',
      eta: eta ?? '—',
    );
  }

  /// Stops the foreground service and removes the sticky notification.
  Future<void> stop() async {
    await Future.wait([
      FlutterForegroundTask.saveData(key: _trackingActiveKey, value: false),
      FlutterForegroundTask.removeData(key: _destinationLatitudeKey),
      FlutterForegroundTask.removeData(key: _destinationLongitudeKey),
      FlutterForegroundTask.removeData(key: _destinationNameKey),
      FlutterForegroundTask.removeData(key: _alertZoneMetersKey),
      FlutterForegroundTask.removeData(key: _alarmRingingKey),
      FlutterForegroundTask.removeData(key: _pendingAlarmKey),
      FlutterForegroundTask.removeData(key: _alarmDistanceKey),
      FlutterForegroundTask.removeData(key: _alarmEtaKey),
      FlutterForegroundTask.removeData(key: _snoozedUntilMsKey),
    ]);
    final rideActive = await FlutterForegroundTask.getData<bool>(
      key: _rideTrackingActiveKey,
    );
    if (rideActive != true && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

/// Serializable alarm information that can cross the foreground-task/UI
/// isolate boundary without depending on a running Flutter widget tree.
class ProximityAlarmData {
  const ProximityAlarmData({
    required this.id,
    required this.destinationName,
    required this.distance,
    required this.eta,
  });

  final String id;
  final String destinationName;
  final String distance;
  final String eta;

  Map<String, Object> toMap() => {
    'id': id,
    'destinationName': destinationName,
    'distance': distance,
    'eta': eta,
  };

  factory ProximityAlarmData.fromMap(Map<Object?, Object?> map) {
    return ProximityAlarmData(
      id:
          map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      destinationName: map['destinationName']?.toString() ?? 'your destination',
      distance: map['distance']?.toString() ?? '—',
      eta: map['eta']?.toString() ?? '—',
    );
  }
}
