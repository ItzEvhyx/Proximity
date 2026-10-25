import '../ride_config.dart';
import 'geo_utils.dart';
import 'models.dart';

class BoardingEvidence {
  const BoardingEvidence({
    required this.exitPoint,
    required this.exitAt,
    required this.fix,
    required this.hadDwell,
    this.inVehicle = false,
    this.plannedRide = false,
    this.manual = false,
  });
  final GeoPoint exitPoint;
  final DateTime exitAt;
  final LocationFix fix;
  final bool hadDwell;
  final bool inVehicle;
  final bool plannedRide;
  final bool manual;
}

class BoardingDecision {
  const BoardingDecision({
    required this.passesGates,
    required this.boosters,
    required this.speedMs,
    required this.bearingDeg,
  });
  final bool passesGates;
  final int boosters;
  final double speedMs;
  final double bearingDeg;
  bool get isConfirmed =>
      passesGates && boosters >= RideConfig.autoConfirmBoosters;
}

abstract final class BoardingDetector {
  static BoardingDecision evaluate(
    BoardingEvidence evidence,
    double expectedBearingDeg,
  ) {
    final seconds =
        evidence.fix.at.difference(evidence.exitAt).inMilliseconds / 1000;
    final distance = GeoUtils.distanceM(evidence.exitPoint, evidence.fix.point);
    final speed = seconds <= 0 ? 0.0 : distance / seconds;
    final bearing = GeoUtils.bearingDeg(evidence.exitPoint, evidence.fix.point);
    final gates =
        seconds <= RideConfig.departureWindow.inSeconds &&
        speed >= RideConfig.minTrainSpeedMs &&
        GeoUtils.angularDistanceDeg(bearing, expectedBearingDeg) <=
            RideConfig.headingToleranceDeg;
    final boosters =
        (evidence.hadDwell ? 1 : 0) +
        (evidence.inVehicle ? 1 : 0) +
        (evidence.plannedRide ? 1 : 0) +
        (evidence.manual ? 2 : 0);
    return BoardingDecision(
      passesGates: gates,
      boosters: boosters,
      speedMs: speed,
      bearingDeg: bearing,
    );
  }
}
