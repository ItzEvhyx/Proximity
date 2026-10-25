import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models.dart';

class RideSessionStore {
  static const _key = 'ride_tracking_session_v1';
  Future<RideSession?> read() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return value == null
        ? null
        : RideSession.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> write(RideSession session) async =>
      (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(session.toJson()),
      );
  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}

class SegmentTimingStore {
  static const _prefix = 'ride_tracking_speed_';
  Future<double?> speedFor(String segmentId) async =>
      (await SharedPreferences.getInstance()).getDouble('$_prefix$segmentId');
  Future<void> record(String segmentId, double actualMs) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getDouble('$_prefix$segmentId');
    final next = previous == null ? actualMs : previous * .7 + actualMs * .3;
    await prefs.setDouble('$_prefix$segmentId', next);
  }
}

class RideLogStore {
  static const _key = 'ride_tracking_log_v1';
  Future<void> add(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList(_key) ?? [];
    logs.add('${DateTime.now().toIso8601String()} $message');
    final retained = logs.length <= 300
        ? logs
        : logs.sublist(logs.length - 300);
    await prefs.setStringList(_key, retained);
  }

  Future<List<String>> read() async =>
      (await SharedPreferences.getInstance()).getStringList(_key) ?? const [];
  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}
