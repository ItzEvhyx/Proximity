import 'dart:io';

import 'package:flutter/services.dart';

/// Manages waking the screen and showing the app over the lock screen
/// when the proximity alarm fires.
///
/// Uses a platform channel to invoke Android-specific window flags
/// (FLAG_SHOW_WHEN_LOCKED, FLAG_TURN_SCREEN_ON) and a PowerManager
/// wake lock — the same mechanism the default Clock app uses.
class WakeService {
  WakeService._();

  static final WakeService instance = WakeService._();

  static const _channel = MethodChannel('com.example.proximity/alarm_wake');

  /// Wakes the screen and brings the app to the foreground over the lock
  /// screen. Call this immediately before showing the alarm dismissal screen.
  Future<void> wakeUpScreen() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('wakeUpScreen');
    } on PlatformException {
      // Silently fail on unsupported devices — the alarm still fires,
      // just won't wake the screen.
    }
  }

  /// Clears the wake/lock-screen flags after the alarm is dismissed.
  /// Call this when the alarm screen is popped so the app doesn't stay
  /// permanently shown over the lock screen.
  Future<void> clearWakeFlags() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('clearWakeFlags');
    } on PlatformException {
      // Non-fatal.
    }
  }
}
