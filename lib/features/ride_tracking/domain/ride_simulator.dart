/// Deterministic desk-test scenarios for the rail state machine. The simulator
/// intentionally contains no timers or plugins; UI can run it instantly while
/// preserving the order and timing of the real sensor events.
enum RideSimulationScenario {
  normal,
  stall,
  missedGeofence,
  wrongDirection,
  jeepneyFalsePositive,
  alightMidLine,
  appRestart,
}

enum SimulatedEventType {
  enter,
  dwell,
  exit,
  fix,
  fixFailed,
  restart,
  alert,
  end,
}

class SimulatedEvent {
  const SimulatedEvent(this.second, this.type, this.note);
  final int second;
  final SimulatedEventType type;
  final String note;
}

class RideSimulationResult {
  const RideSimulationResult({
    required this.events,
    required this.approachAlerts,
    required this.fixesUsed,
    required this.endedCleanly,
  });
  final List<SimulatedEvent> events;
  final int approachAlerts;
  final int fixesUsed;
  final bool endedCleanly;
}

abstract final class RideSimulator {
  static RideSimulationResult run(RideSimulationScenario scenario) {
    final base = <SimulatedEvent>[
      const SimulatedEvent(0, SimulatedEventType.enter, 'origin'),
      const SimulatedEvent(30, SimulatedEventType.dwell, 'boarding confidence'),
      const SimulatedEvent(45, SimulatedEventType.exit, 'depart'),
      const SimulatedEvent(70, SimulatedEventType.fix, 'verification'),
    ];
    switch (scenario) {
      case RideSimulationScenario.normal:
        return RideSimulationResult(
          events: [
            ...base,
            const SimulatedEvent(130, SimulatedEventType.fix, 'correction'),
            const SimulatedEvent(155, SimulatedEventType.alert, 'approach'),
            const SimulatedEvent(210, SimulatedEventType.enter, 'arrival'),
          ],
          approachAlerts: 1,
          fixesUsed: 2,
          endedCleanly: false,
        );
      case RideSimulationScenario.stall:
        return RideSimulationResult(
          events: [
            ...base,
            const SimulatedEvent(
              130,
              SimulatedEventType.fix,
              'no progress; push ETA',
            ),
            const SimulatedEvent(
              240,
              SimulatedEventType.alert,
              'delayed approach',
            ),
            const SimulatedEvent(295, SimulatedEventType.enter, 'arrival'),
          ],
          approachAlerts: 1,
          fixesUsed: 2,
          endedCleanly: false,
        );
      case RideSimulationScenario.missedGeofence:
        return RideSimulationResult(
          events: [
            ...base,
            const SimulatedEvent(
              130,
              SimulatedEventType.fixFailed,
              'correction unavailable; retain ETA',
            ),
            const SimulatedEvent(275, SimulatedEventType.fix, 'bounded resync'),
          ],
          approachAlerts: 1,
          fixesUsed: 2,
          endedCleanly: false,
        );
      case RideSimulationScenario.wrongDirection:
        return RideSimulationResult(
          events: [
            ...base,
            const SimulatedEvent(
              130,
              SimulatedEventType.fix,
              'reverse progress',
            ),
            const SimulatedEvent(
              131,
              SimulatedEventType.end,
              'direction inconsistent',
            ),
          ],
          approachAlerts: 0,
          fixesUsed: 2,
          endedCleanly: true,
        );
      case RideSimulationScenario.jeepneyFalsePositive:
        return RideSimulationResult(
          events: [
            base.first,
            base[2],
            base[3],
            const SimulatedEvent(
              215,
              SimulatedEventType.end,
              'tentative validation failed',
            ),
          ],
          approachAlerts: 0,
          fixesUsed: 1,
          endedCleanly: true,
        );
      case RideSimulationScenario.alightMidLine:
        return RideSimulationResult(
          events: [
            ...base,
            const SimulatedEvent(210, SimulatedEventType.enter, 'arrival'),
            const SimulatedEvent(
              250,
              SimulatedEventType.exit,
              'walk-speed departure',
            ),
            const SimulatedEvent(275, SimulatedEventType.end, 'alighted'),
          ],
          approachAlerts: 1,
          fixesUsed: 2,
          endedCleanly: true,
        );
      case RideSimulationScenario.appRestart:
        return RideSimulationResult(
          events: [
            ...base,
            const SimulatedEvent(
              100,
              SimulatedEventType.restart,
              'restore persisted ETA',
            ),
            const SimulatedEvent(
              155,
              SimulatedEventType.alert,
              'scheduled notification survives',
            ),
            const SimulatedEvent(210, SimulatedEventType.enter, 'arrival'),
          ],
          approachAlerts: 1,
          fixesUsed: 2,
          endedCleanly: false,
        );
    }
  }
}
