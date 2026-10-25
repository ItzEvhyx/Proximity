import 'models.dart';

sealed class RideEvent {
  const RideEvent();
}

class StationEntered extends RideEvent {
  const StationEntered(this.stationId);
  final String stationId;
}

class StationDwelled extends RideEvent {
  const StationDwelled(this.stationId);
  final String stationId;
}

class StationExited extends RideEvent {
  const StationExited(this.stationId);
  final String stationId;
}

class ApproachDue extends RideEvent {
  const ApproachDue();
}

class ArrivalConfirmed extends RideEvent {
  const ArrivalConfirmed();
}

class RideCancelled extends RideEvent {
  const RideCancelled();
}

sealed class RideEffect {
  const RideEffect();
}

class PersistRide extends RideEffect {
  const PersistRide(this.session);
  final RideSession session;
}

class RequestDepartureFix extends RideEffect {
  const RequestDepartureFix();
}

class FireApproachAlert extends RideEffect {
  const FireApproachAlert();
}

class EndRide extends RideEffect {
  const EndRide();
}

class RideReduction {
  const RideReduction(this.session, this.effects);
  final RideSession? session;
  final List<RideEffect> effects;
}

/// Pure, dependency-free reducer. ETA calculation and geofence setup remain
/// controller effects because they require the local station catalogue.
abstract final class RideStateMachine {
  static RideReduction reduce(RideSession? session, RideEvent event) {
    if (event is RideCancelled) return const RideReduction(null, [EndRide()]);
    if (session == null) return const RideReduction(null, []);
    if (event is StationEntered && session.phase == RidePhase.idle) {
      final next = session.copyWith(
        phase: RidePhase.nearStation,
        currentStationId: event.stationId,
      );
      return RideReduction(next, [PersistRide(next)]);
    }
    if (event is StationDwelled &&
        (session.phase == RidePhase.nearStation ||
            session.phase == RidePhase.atStation)) {
      final next = session.copyWith(phase: RidePhase.atStation);
      return RideReduction(next, [PersistRide(next)]);
    }
    if (event is StationExited &&
        (session.phase == RidePhase.nearStation ||
            session.phase == RidePhase.atStation)) {
      final next = session.copyWith(phase: RidePhase.verifyingDeparture);
      return RideReduction(next, [
        PersistRide(next),
        const RequestDepartureFix(),
      ]);
    }
    if (event is ApproachDue &&
        session.confirmed &&
        !session.segmentAlertSent) {
      final next = session.copyWith(
        phase: RidePhase.approaching,
        segmentAlertSent: true,
      );
      return RideReduction(next, [
        PersistRide(next),
        const FireApproachAlert(),
      ]);
    }
    if (event is ArrivalConfirmed) {
      final next = session.copyWith(phase: RidePhase.atStation);
      return RideReduction(next, [PersistRide(next)]);
    }
    return RideReduction(session, const []);
  }
}
