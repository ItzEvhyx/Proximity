enum TrainLine { lrt1, lrt2, mrt3 }

extension TrainLineText on TrainLine {
  String get id => switch (this) {
    TrainLine.lrt1 => 'LRT1',
    TrainLine.lrt2 => 'LRT2',
    TrainLine.mrt3 => 'MRT3',
  };
  String get label => switch (this) {
    TrainLine.lrt1 => 'LRT-1',
    TrainLine.lrt2 => 'LRT-2',
    TrainLine.mrt3 => 'MRT-3',
  };
  static TrainLine fromId(String value) =>
      TrainLine.values.firstWhere((line) => line.id == value);
}

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
  Map<String, Object> toJson() => {'lat': latitude, 'lng': longitude};
  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
    (json['lat'] as num).toDouble(),
    (json['lng'] as num).toDouble(),
  );
}

class Station {
  const Station({
    required this.id,
    required this.line,
    required this.name,
    required this.orderIndex,
    required this.point,
    this.interchangeWith = const [],
    this.wakeRadiusM,
    this.arriveRadiusM,
  });
  final String id;
  final TrainLine line;
  final String name;
  final int orderIndex;
  final GeoPoint point;
  final List<String> interchangeWith;
  final double? wakeRadiusM;
  final double? arriveRadiusM;
  factory Station.fromJson(Map<String, dynamic> json) => Station(
    id: json['id'] as String,
    line: TrainLineText.fromId(json['line_id'] as String),
    name: json['name'] as String,
    orderIndex: (json['order_index'] as num).toInt(),
    point: GeoPoint.fromJson(json),
    interchangeWith: List<String>.from(json['interchange_with'] ?? const []),
    wakeRadiusM: (json['wake_radius_m'] as num?)?.toDouble(),
    arriveRadiusM: (json['arrive_radius_m'] as num?)?.toDouble(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'line_id': line.id,
    'name': name,
    'order_index': orderIndex,
    ...point.toJson(),
    'interchange_with': interchangeWith,
    'wake_radius_m': wakeRadiusM,
    'arrive_radius_m': arriveRadiusM,
  };
}

class Segment {
  const Segment({
    required this.fromStationId,
    required this.toStationId,
    required this.trackDistanceM,
    required this.bearingDeg,
  });
  final String fromStationId;
  final String toStationId;
  final double trackDistanceM;
  final double bearingDeg;
  String get id => '$fromStationId:$toStationId';
}

enum RidePhase {
  idle,
  nearStation,
  atStation,
  verifyingDeparture,
  inTransit,
  approaching,
  resync,
}

enum RideOrigin { automatic, manual, plannedTrip }

class RideSession {
  const RideSession({
    required this.id,
    required this.line,
    required this.direction,
    required this.phase,
    required this.confirmed,
    required this.currentStationId,
    required this.nextStationId,
    required this.departedAt,
    required this.etaAt,
    required this.alertAt,
    required this.fixesUsedThisSegment,
    required this.origin,
    this.destinationStationId,
    this.segmentAlertSent = false,
  });
  final String id;
  final TrainLine line;
  final int direction;
  final RidePhase phase;
  final bool confirmed;
  final String currentStationId;
  final String? nextStationId;
  final DateTime? departedAt;
  final DateTime? etaAt;
  final DateTime? alertAt;
  final int fixesUsedThisSegment;
  final RideOrigin origin;
  final String? destinationStationId;
  final bool segmentAlertSent;
  RideSession copyWith({
    RidePhase? phase,
    bool? confirmed,
    String? currentStationId,
    String? nextStationId,
    DateTime? departedAt,
    DateTime? etaAt,
    DateTime? alertAt,
    int? fixesUsedThisSegment,
    String? destinationStationId,
    bool? segmentAlertSent,
  }) => RideSession(
    id: id,
    line: line,
    direction: direction,
    phase: phase ?? this.phase,
    confirmed: confirmed ?? this.confirmed,
    currentStationId: currentStationId ?? this.currentStationId,
    nextStationId: nextStationId ?? this.nextStationId,
    departedAt: departedAt ?? this.departedAt,
    etaAt: etaAt ?? this.etaAt,
    alertAt: alertAt ?? this.alertAt,
    fixesUsedThisSegment: fixesUsedThisSegment ?? this.fixesUsedThisSegment,
    origin: origin,
    destinationStationId: destinationStationId ?? this.destinationStationId,
    segmentAlertSent: segmentAlertSent ?? this.segmentAlertSent,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'line': line.id,
    'direction': direction,
    'phase': phase.name,
    'confirmed': confirmed,
    'current': currentStationId,
    'next': nextStationId,
    'departedAt': departedAt?.toIso8601String(),
    'etaAt': etaAt?.toIso8601String(),
    'alertAt': alertAt?.toIso8601String(),
    'fixes': fixesUsedThisSegment,
    'origin': origin.name,
    'destination': destinationStationId,
    'alertSent': segmentAlertSent,
  };
  factory RideSession.fromJson(Map<String, dynamic> json) => RideSession(
    id: json['id'] as String,
    line: TrainLineText.fromId(json['line'] as String),
    direction: json['direction'] as int,
    phase: RidePhase.values.byName(json['phase'] as String),
    confirmed: json['confirmed'] as bool,
    currentStationId: json['current'] as String,
    nextStationId: json['next'] as String?,
    departedAt: _date(json['departedAt']),
    etaAt: _date(json['etaAt']),
    alertAt: _date(json['alertAt']),
    fixesUsedThisSegment: json['fixes'] as int,
    origin: RideOrigin.values.byName(json['origin'] as String),
    destinationStationId: json['destination'] as String?,
    segmentAlertSent: json['alertSent'] as bool? ?? false,
  );
  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}

class LocationFix {
  const LocationFix({
    required this.point,
    required this.accuracyM,
    required this.at,
  });
  final GeoPoint point;
  final double accuracyM;
  final DateTime at;
}
