import 'dart:math';

/// Tunables for rail ride tracking. These are deliberately centralized so
/// calibration from the local ride log can improve them without changing flow.
abstract final class RideConfig {
  static const double stationWakeRadiusM = 150;
  static const double stationArriveRadiusM = 50;
  static const double recenterRadiusM = 2000;
  static const int geofenceRingSize = 15;
  static const Duration dwellLoiter = Duration(seconds: 30);
  static const Duration departureVerifyDelay = Duration(seconds: 25);
  static const Duration departureWindow = Duration(seconds: 180);
  static const double minTrainSpeedMs = 6;
  static const double headingToleranceDeg = 40;
  static const int autoConfirmBoosters = 2;
  static const double tentativeEtaTolerance = .40;
  static const double defaultCruiseMs = 9.7;
  static const int brakeAllowanceS = 15;
  static const double emaAlpha = .3;
  static const double correctionFixAtFraction = .60;
  static const int maxFixesPerSegment = 2;
  static const Duration fixTimeout = Duration(seconds: 12);
  static const double maxFixAccuracyM = 80;
  static const Duration defaultApproachLead = Duration(seconds: 60);
  static const Duration minAlertDelay = Duration(seconds: 5);
  static const Duration arrivalSettle = Duration(seconds: 15);
  static const Duration manualStationDwell = Duration(seconds: 20);
  static const Duration rideIdleTimeout = Duration(minutes: 10);
  static int arrivalGraceS(int etaSegmentS) =>
      max(45, (.4 * etaSegmentS).round());
}
