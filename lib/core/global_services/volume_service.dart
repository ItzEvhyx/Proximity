import 'package:volume_controller/volume_controller.dart';

/// Manages system volume override for the alarm.
///
/// When the alarm fires, [maximizeVolume] saves the user's current volume
/// level and sets the system to maximum (1.0). When the alarm is dismissed,
/// [restoreVolume] returns the volume to the saved level.
///
/// The system volume UI is hidden during these changes to avoid distracting
/// the user with the OS overlay.
class VolumeService {
  VolumeService._();

  static final VolumeService instance = VolumeService._();

  double? _previousVolume;

  /// Saves the current system volume and sets it to maximum (1.0).
  Future<void> maximizeVolume() async {
    try {
      VolumeController.instance.showSystemUI = false;
      _previousVolume = await VolumeController.instance.getVolume();
      await VolumeController.instance.setVolume(1.0);
    } catch (_) {
      // Volume control may not be available on all devices/emulators.
    }
  }

  /// Restores the system volume to whatever it was before [maximizeVolume].
  Future<void> restoreVolume() async {
    try {
      final prev = _previousVolume;
      if (prev != null) {
        await VolumeController.instance.setVolume(prev);
        _previousVolume = null;
      }
      VolumeController.instance.showSystemUI = true;
    } catch (_) {}
  }
}
