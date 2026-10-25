import 'package:flutter_test/flutter_test.dart';
import 'package:proximity/features/ride_tracking/data/station_repository.dart';
import 'package:proximity/features/ride_tracking/domain/boarding_detector.dart';
import 'package:proximity/features/ride_tracking/domain/direction_resolver.dart';
import 'package:proximity/features/ride_tracking/domain/eta_estimator.dart';
import 'package:proximity/features/ride_tracking/domain/geo_utils.dart';
import 'package:proximity/features/ride_tracking/domain/models.dart';
import 'package:proximity/features/ride_tracking/domain/ride_simulator.dart';
import 'package:proximity/features/ride_tracking/domain/ride_state_machine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeoUtils', () {
    test('haversine, bearing, and segment projection are sane', () {
      const origin = GeoPoint(14.6, 121.0);
      const east = GeoPoint(14.6, 121.001);
      expect(GeoUtils.distanceM(origin, east), closeTo(108, 3));
      expect(GeoUtils.bearingDeg(origin, east), closeTo(90, .2));
      expect(
        GeoUtils.projectAlongSegmentM(
          from: origin,
          to: east,
          point: const GeoPoint(14.6, 121.0005),
        ),
        closeTo(54, 2),
      );
      expect(GeoUtils.angularDistanceDeg(355, 5), 10);
    });
  });

  group('BoardingDetector', () {
    test('requires speed and heading, then counts independent boosters', () {
      final exit = DateTime.utc(2026, 1, 1);
      final decision = BoardingDetector.evaluate(
        BoardingEvidence(
          exitPoint: const GeoPoint(14.6, 121),
          exitAt: exit,
          fix: LocationFix(
            point: const GeoPoint(14.6, 121.001),
            accuracyM: 8,
            at: exit.add(const Duration(seconds: 10)),
          ),
          hadDwell: true,
          inVehicle: true,
        ),
        90,
      );
      expect(decision.passesGates, isTrue);
      expect(decision.isConfirmed, isTrue);
      expect(decision.boosters, 2);
    });

    test('rejects road movement with an off-line heading', () {
      final exit = DateTime.utc(2026, 1, 1);
      final decision = BoardingDetector.evaluate(
        BoardingEvidence(
          exitPoint: const GeoPoint(14.6, 121),
          exitAt: exit,
          fix: LocationFix(
            point: const GeoPoint(14.601, 121),
            accuracyM: 8,
            at: exit.add(const Duration(seconds: 10)),
          ),
          hadDwell: true,
        ),
        90,
      );
      expect(decision.passesGates, isFalse);
    });
  });

  test('direction resolver handles a middle station and a terminus', () {
    const stations = [
      Station(
        id: 'a',
        line: TrainLine.lrt1,
        name: 'A',
        orderIndex: 0,
        point: GeoPoint(14.6, 121),
      ),
      Station(
        id: 'b',
        line: TrainLine.lrt1,
        name: 'B',
        orderIndex: 1,
        point: GeoPoint(14.6, 121.01),
      ),
      Station(
        id: 'c',
        line: TrainLine.lrt1,
        name: 'C',
        orderIndex: 2,
        point: GeoPoint(14.6, 121.02),
      ),
    ];
    expect(
      DirectionResolver.candidates(stations[1], stations, 90).single.direction,
      1,
    );
    expect(
      DirectionResolver.candidates(stations.first, stations, 270),
      isEmpty,
    );
  });

  test('ETA uses calibrated cruise speed and enforces minimum alert delay', () {
    final now = DateTime.utc(2026, 1, 1);
    final estimate = EtaEstimator.estimate(
      fixAt: now,
      segmentDistanceM: 1000,
      alongM: 400,
      cruiseMs: 10,
      approachLead: const Duration(seconds: 60),
    );
    expect(estimate.etaAt, now.add(const Duration(seconds: 75)));
    expect(estimate.alertAt, now.add(const Duration(seconds: 15)));
    final short = EtaEstimator.estimate(
      fixAt: now,
      segmentDistanceM: 100,
      alongM: 50,
      cruiseMs: 10,
      approachLead: const Duration(seconds: 60),
    );
    expect(short.alertAt, now.add(const Duration(seconds: 5)));
  });

  test('state reducer does not alert an unconfirmed session', () {
    final session = _session(confirmed: false);
    expect(
      RideStateMachine.reduce(session, const ApproachDue()).effects,
      isEmpty,
    );
    final confirmed = _session(confirmed: true);
    final result = RideStateMachine.reduce(confirmed, const ApproachDue());
    expect(result.session!.phase, RidePhase.approaching);
    expect(result.effects.whereType<FireApproachAlert>(), hasLength(1));
  });

  test('session updates preserve a selected destination', () {
    final session = RideSession(
      id: 'ride',
      line: TrainLine.lrt1,
      direction: 1,
      phase: RidePhase.inTransit,
      confirmed: true,
      currentStationId: 'a',
      nextStationId: 'b',
      departedAt: DateTime.utc(2026, 1, 1),
      etaAt: DateTime.utc(2026, 1, 1, 0, 2),
      alertAt: DateTime.utc(2026, 1, 1, 0, 1),
      fixesUsedThisSegment: 1,
      origin: RideOrigin.manual,
      destinationStationId: 'c',
    );
    expect(
      session.copyWith(phase: RidePhase.approaching).destinationStationId,
      'c',
    );
  });

  test('bundled catalogue contains all three complete rail lines', () async {
    final repository = StationRepository();
    expect(await repository.lineStations(TrainLine.lrt1), hasLength(25));
    expect(await repository.lineStations(TrainLine.lrt2), hasLength(13));
    expect(await repository.lineStations(TrainLine.mrt3), hasLength(13));
    final doroteo = await repository.byId('lrt1_doroteo_jose');
    expect(doroteo!.interchangeWith, contains('lrt2_recto'));
  });

  test('simulator covers recovery and false-positive scenarios', () {
    for (final scenario in RideSimulationScenario.values) {
      final result = RideSimulator.run(scenario);
      expect(result.events, isNotEmpty, reason: scenario.name);
      expect(
        result.fixesUsed,
        lessThanOrEqualTo(2),
        reason: '${scenario.name} exceeded the per-segment fix budget',
      );
    }
    expect(
      RideSimulator.run(
        RideSimulationScenario.jeepneyFalsePositive,
      ).approachAlerts,
      0,
    );
    expect(
      RideSimulator.run(RideSimulationScenario.appRestart).approachAlerts,
      1,
    );
  });
}

RideSession _session({required bool confirmed}) => RideSession(
  id: 'ride',
  line: TrainLine.lrt1,
  direction: 1,
  phase: RidePhase.inTransit,
  confirmed: confirmed,
  currentStationId: 'a',
  nextStationId: 'b',
  departedAt: DateTime.utc(2026, 1, 1),
  etaAt: DateTime.utc(2026, 1, 1, 0, 2),
  alertAt: DateTime.utc(2026, 1, 1, 0, 1),
  fixesUsedThisSegment: 1,
  origin: RideOrigin.automatic,
);
