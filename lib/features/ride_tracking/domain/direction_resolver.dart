import '../ride_config.dart';
import 'geo_utils.dart';
import 'models.dart';

class DirectionMatch {
  const DirectionMatch(this.line, this.direction, this.deltaDeg);
  final TrainLine line;
  final int direction;
  final double deltaDeg;
}

abstract final class DirectionResolver {
  static List<DirectionMatch> candidates(
    Station station,
    List<Station> all,
    double movementBearing,
  ) {
    final onLine = all.where((s) => s.line == station.line).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final here = onLine.indexWhere((s) => s.id == station.id);
    final result = <DirectionMatch>[];
    if (here > 0) {
      final d = GeoUtils.angularDistanceDeg(
        movementBearing,
        GeoUtils.bearingDeg(station.point, onLine[here - 1].point),
      );
      if (d <= RideConfig.headingToleranceDeg) {
        result.add(DirectionMatch(station.line, -1, d));
      }
    }
    if (here < onLine.length - 1) {
      final d = GeoUtils.angularDistanceDeg(
        movementBearing,
        GeoUtils.bearingDeg(station.point, onLine[here + 1].point),
      );
      if (d <= RideConfig.headingToleranceDeg) {
        result.add(DirectionMatch(station.line, 1, d));
      }
    }
    result.sort((a, b) => a.deltaDeg.compareTo(b.deltaDeg));
    return result;
  }
}
