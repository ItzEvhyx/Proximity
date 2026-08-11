import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../shared_prefs/shared_prefs.dart';
import '../supabase/supabase_client.dart';

/// Handles bidirectional sync between local storage (SharedPreferences +
/// SQLite) and the Supabase `profiles` table.
///
/// • [pushToSqlite] — copies current SharedPreferences settings into SQLite.
/// • [pullFromCloud] — fetches the user's settings from Supabase and writes
///   them to both SharedPreferences and SQLite (used on login / device switch).
/// • [migrateTripsToSqlite] — one-time migration of pinned trips from the
///   SharedPreferences JSON blob into the SQLite `pinned_trips` table.
class SettingsSync {
  SettingsSync._();

  static final SettingsSync instance = SettingsSync._();

  /// Copies all current SharedPreferences alarm settings into SQLite.
  /// Call once at startup to ensure SQLite has the latest local data.
  Future<void> pushToSqlite() async {
    final db = AppDatabase.instance;
    await db.setAllSettings({
      'alarm_sound': AppPrefs.alarmSound,
      'alert_zone_distances':
          AppPrefs.alertZoneDistances.map((d) => d.toString()).join(','),
      'alert_zone_unit': AppPrefs.alertZoneUnit,
      'dismiss_method': AppPrefs.dismissMethod,
      'vibration_intensity': AppPrefs.vibrationIntensity,
    });
  }

  /// Fetches the user's alarm/settings from Supabase and writes them to both
  /// SharedPreferences (for fast synchronous reads) and SQLite (for durability).
  ///
  /// Call this after a successful login to ensure a new device gets the user's
  /// cloud-saved preferences.
  Future<void> pullFromCloud() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final row = await supabase
          .from('profiles')
          .select(
            'alarm_sound, alert_zone_distances, alert_zone_unit, '
            'dismiss_method, vibration_intensity',
          )
          .eq('id', userId)
          .maybeSingle();

      if (row == null) return;

      // ── Alarm sound ──
      final alarmSound = row['alarm_sound'] as String?;
      if (alarmSound != null && alarmSound.isNotEmpty) {
        await AppPrefs.setAlarmSound(alarmSound);
      }

      // ── Alert zone distances ──
      final rawDistances = row['alert_zone_distances'];
      if (rawDistances != null &&
          rawDistances is List &&
          rawDistances.isNotEmpty) {
        final distances = rawDistances
            .map((d) => d is int ? d : (d as num).toInt())
            .toList()
            .cast<int>();
        await AppPrefs.setAlertZoneDistances(distances);
      }

      // ── Alert zone unit ──
      final unit = row['alert_zone_unit'] as String?;
      if (unit != null && unit.isNotEmpty) {
        await AppPrefs.setAlertZoneUnit(unit);
      }

      // ── Dismiss method ──
      final dismissMethod = row['dismiss_method'] as String?;
      if (dismissMethod != null && dismissMethod.isNotEmpty) {
        await AppPrefs.setDismissMethod(dismissMethod);
      }

      // ── Vibration intensity ──
      final vibration = row['vibration_intensity'] as String?;
      if (vibration != null && vibration.isNotEmpty) {
        await AppPrefs.setVibrationIntensity(vibration);
      }

      // Mirror into SQLite.
      await pushToSqlite();
    } catch (_) {
      // Network errors are fine — we still have local defaults.
    }
  }

  /// One-time migration: reads pinned trips from the SharedPreferences JSON
  /// blob and inserts them into the SQLite `pinned_trips` table.
  Future<void> migrateTripsToSqlite() async {
    final db = AppDatabase.instance;

    // Check if migration already happened.
    final marker = await db.getSetting('_trips_migrated');
    if (marker == 'true') return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('pinned_trips_v1');
      if (raw == null || raw.isEmpty) {
        await db.setSetting('_trips_migrated', 'true');
        return;
      }

      final List<dynamic> decoded = jsonDecode(raw);
      final trips = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        trips.add({
          'name': item['name'] as String? ?? '',
          'address': item['address'] as String?,
          'longitude': (item['lng'] as num?)?.toDouble() ?? 0.0,
          'latitude': (item['lat'] as num?)?.toDouble() ?? 0.0,
          'distance_meters': (item['distance'] as num?)?.toDouble(),
          'start_location_name': item['start'] as String?,
          'start_longitude': (item['startLng'] as num?)?.toDouble(),
          'start_latitude': (item['startLat'] as num?)?.toDouble(),
          'pinned_at':
              item['at'] as String? ?? DateTime.now().toIso8601String(),
        });
      }

      if (trips.isNotEmpty) {
        await db.replaceAllTrips(trips);
      }

      await db.setSetting('_trips_migrated', 'true');
    } catch (_) {
      // Migration failure is non-fatal — old SharedPrefs data still works.
    }
  }
}
