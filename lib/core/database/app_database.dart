import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite database for offline-first storage of user settings
/// and pinned trip history.
///
/// Tables:
///  • `user_settings` — key/value store for alarm, vibration, dismiss, etc.
///  • `pinned_trips` — each trip the user has confirmed (destination pin).
///
/// Call [init] once during app startup (after Env.load, before runApp).
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static Database? _db;

  static const int _version = 1;
  static const String _dbName = 'proximity.db';

  // ── Table names ────────────────────────────────────────────────────────
  static const String tableSettings = 'user_settings';
  static const String tableTrips = 'pinned_trips';

  /// Opens (or creates) the database. Safe to call multiple times.
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  /// Initializes the database eagerly. Call once at startup.
  Future<void> init() async {
    _db = await _open();
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Key-value settings table.
    await db.execute('''
      CREATE TABLE $tableSettings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Pinned trips table.
    await db.execute('''
      CREATE TABLE $tableTrips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        longitude REAL NOT NULL,
        latitude REAL NOT NULL,
        distance_meters REAL,
        start_location_name TEXT,
        start_longitude REAL,
        start_latitude REAL,
        pinned_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future schema migrations go here.
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets a setting value by key, or null if not set.
  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      tableSettings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Sets a setting value (insert or replace).
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      tableSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Gets all settings as a Map.
  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final rows = await db.query(tableSettings);
    return {
      for (final row in rows)
        row['key'] as String: row['value'] as String,
    };
  }

  /// Bulk-writes multiple settings in a single transaction.
  Future<void> setAllSettings(Map<String, String> settings) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in settings.entries) {
        await txn.insert(
          tableSettings,
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PINNED TRIPS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Inserts a new pinned trip. Returns the row id.
  Future<int> insertTrip(Map<String, dynamic> trip) async {
    final db = await database;
    return db.insert(tableTrips, trip);
  }

  /// Returns all pinned trips ordered by most recent first.
  Future<List<Map<String, dynamic>>> getAllTrips() async {
    final db = await database;
    return db.query(tableTrips, orderBy: 'pinned_at DESC');
  }

  /// Returns the most recent [limit] trips.
  Future<List<Map<String, dynamic>>> getRecentTrips({int limit = 5}) async {
    final db = await database;
    return db.query(tableTrips, orderBy: 'pinned_at DESC', limit: limit);
  }

  /// Deletes a trip by matching name + coordinates + timestamp.
  Future<int> deleteTrip({
    required String name,
    required double longitude,
    required double latitude,
    required String pinnedAt,
  }) async {
    final db = await database;
    return db.delete(
      tableTrips,
      where: 'name = ? AND longitude = ? AND latitude = ? AND pinned_at = ?',
      whereArgs: [name, longitude, latitude, pinnedAt],
    );
  }

  /// Deletes all trips.
  Future<int> clearTrips() async {
    final db = await database;
    return db.delete(tableTrips);
  }

  /// Replaces all trips with the given list (used for sync from SharedPrefs
  /// or Supabase).
  Future<void> replaceAllTrips(List<Map<String, dynamic>> trips) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableTrips);
      for (final trip in trips) {
        await txn.insert(tableTrips, trip);
      }
    });
  }

  /// Keeps only the most recent [max] trips, deleting older ones.
  Future<void> trimTrips({int max = 5}) async {
    final db = await database;
    // Get the cutoff pinned_at value.
    final rows = await db.query(
      tableTrips,
      columns: ['pinned_at'],
      orderBy: 'pinned_at DESC',
      limit: 1,
      offset: max - 1,
    );
    if (rows.isEmpty) return; // Fewer than max trips, nothing to trim.
    final cutoff = rows.first['pinned_at'] as String;
    await db.delete(
      tableTrips,
      where: 'pinned_at < ?',
      whereArgs: [cutoff],
    );
  }
}
