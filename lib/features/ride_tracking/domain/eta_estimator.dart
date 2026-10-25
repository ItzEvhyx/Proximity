import '../ride_config.dart';

class EtaEstimate {
  const EtaEstimate({
    required this.etaAt,
    required this.alertAt,
    required this.remainingM,
    required this.cruiseMs,
  });
  final DateTime etaAt;
  final DateTime alertAt;
  final double remainingM;
  final double cruiseMs;
}

abstract final class EtaEstimator {
  static EtaEstimate estimate({
    required DateTime fixAt,
    required double segmentDistanceM,
    required double alongM,
    required double cruiseMs,
    required Duration approachLead,
  }) {
    final remaining = (segmentDistanceM - alongM).clamp(0.0, segmentDistanceM);
    final eta = fixAt
        .add(Duration(milliseconds: ((remaining / cruiseMs) * 1000).round()))
        .add(const Duration(seconds: RideConfig.brakeAllowanceS));
    final wantedAlert = eta.subtract(approachLead);
    final floor = fixAt.add(RideConfig.minAlertDelay);
    return EtaEstimate(
      etaAt: eta,
      alertAt: wantedAlert.isBefore(floor) ? floor : wantedAlert,
      remainingM: remaining,
      cruiseMs: cruiseMs,
    );
  }
}
