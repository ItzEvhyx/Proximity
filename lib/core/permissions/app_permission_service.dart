import 'package:permission_handler/permission_handler.dart';

import '../shared_prefs/shared_prefs.dart';

/// Permissions shown in Settings. A system permission has to be granted
/// before its switch becomes available; the switch then controls whether this
/// app is allowed to use the capability.
enum AppPermission {
  location,
  notifications,
  exactAlarm,
  overlay,
  batteryOptimization,
  microphone,
  photoLibrary,
}

class AppPermissionState {
  const AppPermissionState({
    required this.systemGranted,
    required this.appEnabled,
    this.detail,
  });

  final bool systemGranted;
  final bool appEnabled;
  final String? detail;
}

class AppPermissionService {
  const AppPermissionService._();

  static const instance = AppPermissionService._();

  Future<AppPermissionState> stateFor(AppPermission permission) async {
    final status = await _statusFor(permission);
    final systemGranted = status.isGranted || status.isLimited;
    return AppPermissionState(
      systemGranted: systemGranted,
      appEnabled: AppPrefs.isPermissionUsageEnabled(_id(permission)),
      detail: await _detailFor(permission, systemGranted),
    );
  }

  Future<void> setAppEnabled(AppPermission permission, bool enabled) {
    return AppPrefs.setPermissionUsageEnabled(_id(permission), enabled);
  }

  Future<PermissionStatus> _statusFor(AppPermission permission) {
    switch (permission) {
      case AppPermission.location:
        return Permission.locationWhenInUse.status;
      case AppPermission.notifications:
        return Permission.notification.status;
      case AppPermission.exactAlarm:
        return Permission.scheduleExactAlarm.status;
      case AppPermission.overlay:
        return Permission.systemAlertWindow.status;
      case AppPermission.batteryOptimization:
        return Permission.ignoreBatteryOptimizations.status;
      case AppPermission.microphone:
        return Permission.microphone.status;
      case AppPermission.photoLibrary:
        return Permission.photos.status;
    }
  }

  Future<String?> _detailFor(
    AppPermission permission,
    bool systemGranted,
  ) async {
    if (permission != AppPermission.location || !systemGranted) return null;
    final hasBackgroundAccess =
        (await Permission.locationAlways.status).isGranted;
    return hasBackgroundAccess ? 'Foreground & background' : 'Foreground only';
  }

  String _id(AppPermission permission) {
    switch (permission) {
      case AppPermission.location:
        return 'location';
      case AppPermission.notifications:
        return 'notifications';
      case AppPermission.exactAlarm:
        return 'exact_alarm';
      case AppPermission.overlay:
        return 'overlay';
      case AppPermission.batteryOptimization:
        return 'battery_optimization';
      case AppPermission.microphone:
        return 'microphone';
      case AppPermission.photoLibrary:
        return 'photo_library';
    }
  }
}
