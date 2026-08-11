import 'dart:async';

import 'package:vibration/vibration.dart';

import '../shared_prefs/shared_prefs.dart';

/// Provides repeating vibration at the user's chosen intensity.
///
/// Intensity levels:
/// - off: no vibration
/// - light: short gentle pulses (amplitude ~64)
/// - medium: moderate pulses (amplitude ~128)
/// - strong: maximum intensity (amplitude 255)
///
/// Call [start] to begin a repeating vibration loop and [stop] to end it.
class VibrationService {
  VibrationService._() {
    // Pre-check capabilities at construction so it's ready before first use.
    _checkCapabilities();
  }

  static final VibrationService instance = VibrationService._();

  Timer? _timer;
  bool _running = false;

  /// Whether the device supports vibration with amplitude control.
  bool _hasAmplitude = false;

  Future<void> _checkCapabilities() async {
    _hasAmplitude = await Vibration.hasAmplitudeControl() ?? false;
  }

  /// Starts a repeating vibration pattern based on the user's intensity pref.
  /// If [intensityOverride] is provided, it uses that instead of the saved pref.
  /// This fires the first pulse synchronously — no delay.
  void start({String? intensityOverride}) {
    final intensity = intensityOverride ?? AppPrefs.vibrationIntensity;
    if (intensity == 'off') return;

    stop(); // Cancel any existing loop.

    _running = true;

    // Fire first pulse immediately so it's in sync with the audio.
    _vibrate(intensity);

    // Repeat at intervals matching the intensity.
    final interval = _intervalFor(intensity);
    _timer = Timer.periodic(interval, (_) {
      if (_running) _vibrate(intensity);
    });
  }

  /// Stops vibration and cancels the repeat timer.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    Vibration.cancel();
  }

  void _vibrate(String intensity) {
    final duration = _durationFor(intensity);
    final amplitude = _amplitudeFor(intensity);

    if (_hasAmplitude && amplitude > 0) {
      Vibration.vibrate(duration: duration, amplitude: amplitude);
    } else {
      Vibration.vibrate(duration: duration);
    }
  }

  /// Vibration duration per pulse.
  int _durationFor(String intensity) {
    switch (intensity) {
      case 'light':
        return 100;
      case 'medium':
        return 200;
      case 'strong':
        return 400;
      default:
        return 0;
    }
  }

  /// Amplitude (1–255). Only effective on devices with amplitude control.
  int _amplitudeFor(String intensity) {
    switch (intensity) {
      case 'light':
        return 64;
      case 'medium':
        return 128;
      case 'strong':
        return 255;
      default:
        return 0;
    }
  }

  /// Interval between repeating pulses.
  Duration _intervalFor(String intensity) {
    switch (intensity) {
      case 'light':
        return const Duration(milliseconds: 1200);
      case 'medium':
        return const Duration(milliseconds: 800);
      case 'strong':
        return const Duration(milliseconds: 600);
      default:
        return const Duration(milliseconds: 1000);
    }
  }
}
