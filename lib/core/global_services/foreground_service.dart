import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Top-level callback required by flutter_foreground_task.
/// Must be a top-level or static function annotated with @pragma.
@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_ProximityTaskHandler());
}

/// Minimal task handler — we don't need repeated events, the foreground
/// service is purely to keep the process alive while proximity tracking or
/// wayfinding is active.
class _ProximityTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Nothing to initialize — tracking logic lives in the main isolate.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No-op. We only need the sticky notification, not repeated work.
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
        // We don't need repeat events; set a large interval.
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Requests notification permission (Android 13+) so the foreground service
  /// notification can be shown. Returns true if granted.
  Future<bool> requestPermissions() async {
    final notifPerm =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      final result =
          await FlutterForegroundTask.requestNotificationPermission();
      if (result != NotificationPermission.granted) return false;
    }

    if (Platform.isAndroid) {
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
  }) async {
    if (!_initialized) init();

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

  /// Stops the foreground service and removes the sticky notification.
  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
