import 'dart:math' as math;
import 'models.dart';

abstract final class GeoUtils {
  static const _earthRadiusM = 6371000.0;
  static double distanceM(GeoPoint a, GeoPoint b) {
    final dLat = _rad(b.latitude - a.latitude),
        dLng = _rad(b.longitude - a.longitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return _earthRadiusM * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static double bearingDeg(GeoPoint a, GeoPoint b) {
    final dLng = _rad(b.longitude - a.longitude);
    final y = math.sin(dLng) * math.cos(_rad(b.latitude));
    final x =
        math.cos(_rad(a.latitude)) * math.sin(_rad(b.latitude)) -
        math.sin(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double angularDistanceDeg(double a, double b) =>
      ((a - b + 540) % 360 - 180).abs();
  static double projectAlongSegmentM({
    required GeoPoint from,
    required GeoPoint to,
    required GeoPoint point,
  }) {
    final referenceLat = _rad((from.latitude + to.latitude) / 2);
    double x(GeoPoint p) =>
        _rad(p.longitude - from.longitude) *
        _earthRadiusM *
        math.cos(referenceLat);
    double y(GeoPoint p) => _rad(p.latitude - from.latitude) * _earthRadiusM;
    final dx = x(to), dy = y(to), denominator = dx * dx + dy * dy;
    if (denominator == 0) return 0;
    final ratio = ((x(point) * dx + y(point) * dy) / denominator).clamp(
      0.0,
      1.0,
    );
    return math.sqrt(denominator) * ratio;
  }

  static double _rad(double degrees) => degrees * math.pi / 180;
}
