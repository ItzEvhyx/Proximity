import 'dart:async';
import 'dart:io';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Manages the system overlay window that displays ETA + Distance
/// over other apps (like Google Maps' floating navigation card).
///
/// If the user hasn't granted the "Display over other apps" permission,
/// the overlay silently does nothing — the foreground notification serves
/// as the fallback.
class OverlayService {
  OverlayService._();

  static final OverlayService instance = OverlayService._();

  /// Whether the overlay permission has been granted.
  bool _permissionGranted = false;

  /// Whether the overlay is currently visible.
  bool _showing = false;
  bool get isShowing => _showing;

  /// Cached latest ETA and distance so we can re-send on show.
  String _lastEta = '--';
  String _lastDistance = '--';

  StreamSubscription? _listenerSub;

  /// Check if overlay permission is already granted (call at startup).
  Future<void> checkPermission() async {
    if (!Platform.isAndroid) return;
    _permissionGranted = await FlutterOverlayWindow.isPermissionGranted();
  }

  /// Request overlay permission. Opens the system settings page where the
  /// user toggles "Display over other apps". Returns true if granted.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    if (_permissionGranted) return true;
    _permissionGranted =
        await FlutterOverlayWindow.requestPermission() ?? false;
    return _permissionGranted;
  }

  /// Start listening for messages from the overlay (e.g. 'overlay_ready').
  void startListening() {
    _listenerSub?.cancel();
    _listenerSub = FlutterOverlayWindow.overlayListener.listen((data) {
      if (data == 'overlay_ready') {
        // Overlay just booted — send it the latest data.
        _sendData();
      } else if (data == 'open_app') {
        // User tapped the overlay — close it (the app will resume).
        FlutterOverlayWindow.closeOverlay();
        _showing = false;
      }
    });
  }

  /// Shows the overlay card at the top of the screen.
  /// If permission isn't granted, this is a no-op (notification fallback).
  Future<void> show() async {
    if (!Platform.isAndroid) return;

    // Re-check permission in case it was granted after our last check.
    _permissionGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!_permissionGranted) return;

    // Already showing — just send fresh data.
    if (_showing || await FlutterOverlayWindow.isActive()) {
      _showing = true;
      _sendData();
      return;
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      height: 120,
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.topCenter,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      flag: OverlayFlag.defaultFlag,
      overlayTitle: 'Proximity Navigation',
      overlayContent: 'ETA: $_lastEta · Distance: $_lastDistance',
    );
    _showing = true;

    // The overlay engine takes a moment to boot. Send data after delays
    // to ensure the overlay receives it once its listener is active.
    _sendDataWithRetries();
  }

  /// Hides the overlay card.
  Future<void> hide() async {
    if (!Platform.isAndroid || !_showing) return;
    await FlutterOverlayWindow.closeOverlay();
    _showing = false;
  }

  /// Updates the overlay with new ETA and distance values.
  Future<String> update({
    required String eta,
    required String distance,
  }) async {
    _lastEta = eta;
    _lastDistance = distance;

    if (_showing) {
      _sendData();
    }

    return '$distance away · ETA $eta';
  }

  /// Sends the cached data to the overlay widget via the shared data channel.
  void _sendData() {
    // Format: "eta|distance" — parsed by the overlay widget.
    FlutterOverlayWindow.shareData('$_lastEta|$_lastDistance');
  }

  /// Sends data multiple times with delays to overcome the overlay boot race.
  void _sendDataWithRetries() {
    // Fire at 200ms, 500ms, and 1000ms to ensure the overlay catches it.
    Future.delayed(const Duration(milliseconds: 200), _sendData);
    Future.delayed(const Duration(milliseconds: 500), _sendData);
    Future.delayed(const Duration(milliseconds: 1000), _sendData);
  }

  /// Whether the overlay permission is granted (useful for UI decisions).
  bool get hasPermission => _permissionGranted;
}
