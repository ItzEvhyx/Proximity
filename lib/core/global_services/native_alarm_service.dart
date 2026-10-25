import 'dart:io';

import 'package:flutter/services.dart';

import 'foreground_service.dart';

/// Bridges the Flutter alarm flow to Android's alarm-class notification APIs.
///
/// The notification is intentionally owned by Android rather than an overlay:
/// that lets it appear above the lock screen as a full-screen intent when the
/// OS permits it. Flutter still owns the selected snooze challenge UI.
class NativeAlarmService {
  NativeAlarmService._();

  static final NativeAlarmService instance = NativeAlarmService._();
  static const _channel = MethodChannel('com.example.proximity/alarm_wake');

  Future<void> initialize(
    void Function(ProximityAlarmData alarm) onAlarm,
  ) async {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'alarmTriggered' && call.arguments is Map) {
        onAlarm(
          ProximityAlarmData.fromMap(
            Map<Object?, Object?>.from(call.arguments as Map),
          ),
        );
      }
    });
  }

  /// Posts the native high-priority alarm notification and wakes the device.
  /// The HomeScreen shows the chosen Flutter snooze method immediately as well,
  /// so this also behaves correctly while the app is already visible.
  Future<void> trigger(ProximityAlarmData alarm) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('triggerAlarm', alarm.toMap());
    } on PlatformException {
      // The in-app alarm remains available if a vendor ROM rejects the
      // full-screen notification request.
    }
  }

  Future<ProximityAlarmData?> consumeNativePendingAlarm() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'consumePendingAlarm',
      );
      if (raw == null) return null;
      return ProximityAlarmData.fromMap(raw);
    } on PlatformException {
      return null;
    }
  }

  Future<void> clear() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('clearAlarm');
    } on PlatformException {
      // Notification cancellation is cleanup only; never block snoozing.
    }
  }

  /// Android 14+ lets users and Play policy revoke full-screen alarm access.
  /// We keep a high-priority notification fallback, but expose the official
  /// settings panel when a user enables proximity tracking.
  Future<void> requestFullScreenIntentAccessIfNeeded() async {
    if (!Platform.isAndroid) return;
    try {
      final allowed =
          await _channel.invokeMethod<bool>('canUseFullScreenIntent') ?? false;
      if (!allowed) {
        await _channel.invokeMethod<void>('requestFullScreenIntentAccess');
      }
    } on PlatformException {
      // Older Android versions and vendor ROMs simply use the notification
      // fallback when this API is unavailable.
    }
  }
}
