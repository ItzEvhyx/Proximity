import 'package:shared_preferences/shared_preferences.dart';

import 'saved_route.dart';

/// Manages persisting and loading route search history.
class RouteHistoryService {
  RouteHistoryService._();

  static final RouteHistoryService instance = RouteHistoryService._();

  static const String _prefsKey = 'route_history_v1';
  static const int _maxEntries = 20;

  List<SavedRoute> _routes = const [];
  List<SavedRoute> get routes => _routes;

  bool _loaded = false;

  /// Loads route history from disk. Safe to call multiple times.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      _routes = SavedRoute.decodeList(raw);
    }
    _loaded = true;
  }

  /// Adds a new route to history (most recent first). Persists immediately.
  Future<void> addRoute(SavedRoute route) async {
    await load();
    _routes = [route, ..._routes];
    if (_routes.length > _maxEntries) {
      _routes = _routes.sublist(0, _maxEntries);
    }
    await _save();
  }

  /// Clears all route history.
  Future<void> clear() async {
    _routes = const [];
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, SavedRoute.encodeList(_routes));
  }
}
