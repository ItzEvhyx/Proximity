import 'package:shared_preferences/shared_preferences.dart';

/// Local, offline-first key/value storage backed by SharedPreferences.
///
/// Holds the small amount of state the app needs to decide where to route the
/// user at launch — without a network call:
///  • whether the one-time onboarding (contribution/welcome) flow was seen, and
///  • the id of the currently logged-in user, so they stay logged in across
///    app restarts.
///
/// Call [init] once in `main()` before `runApp`.
class AppPrefs {
  const AppPrefs._();

  static late final SharedPreferences _prefs;

  static const String _kOnboarded = 'has_completed_onboarding';
  static const String _kUserId = 'logged_in_user_id';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Onboarding ─────────────────────────────────────────────────────────────
  /// True once the user has seen the one-time contribution/welcome flow. New
  /// installs start false, so only a brand-new user is shown that screen.
  static bool get hasCompletedOnboarding => _prefs.getBool(_kOnboarded) ?? false;

  static Future<void> setOnboardingComplete() =>
      _prefs.setBool(_kOnboarded, true);

  // ── Logged-in user ──────────────────────────────────────────────────────────
  /// The id of the currently logged-in user, or null when logged out. Each
  /// user has a unique id, so switching accounts simply overwrites this.
  static String? get loggedInUserId => _prefs.getString(_kUserId);

  static Future<void> setLoggedInUserId(String id) =>
      _prefs.setString(_kUserId, id);

  static Future<void> clearLoggedInUserId() => _prefs.remove(_kUserId);

  // ── Alarm sound ────────────────────────────────────────────────────────────
  static const String _kAlarmSound = 'selected_alarm_sound';

  /// The asset key of the selected alarm sound (e.g. 'default_alarm').
  static String get alarmSound => _prefs.getString(_kAlarmSound) ?? 'default_alarm';

  static Future<void> setAlarmSound(String key) =>
      _prefs.setString(_kAlarmSound, key);

  // ── Alarm mode ─────────────────────────────────────────────────────────────
  static const String _kAlarmMode = 'selected_alarm_mode';

  /// The key of the selected alarm mode (e.g. 'push_notification', 'fullscreen').
  static String get alarmMode => _prefs.getString(_kAlarmMode) ?? 'push_notification';

  static Future<void> setAlarmMode(String key) =>
      _prefs.setString(_kAlarmMode, key);

  // ── Alert zone distances ───────────────────────────────────────────────────
  static const String _kAlertZoneDistances = 'alert_zone_distances';
  static const String _kAlertZoneUnit = 'alert_zone_unit';

  /// List of alert zone distances in meters (up to 3). Defaults to [400].
  static List<int> get alertZoneDistances {
    final raw = _prefs.getStringList(_kAlertZoneDistances);
    if (raw == null || raw.isEmpty) return [400];
    return raw.map((e) => int.tryParse(e) ?? 400).toList();
  }

  static Future<void> setAlertZoneDistances(List<int> distances) =>
      _prefs.setStringList(
        _kAlertZoneDistances,
        distances.map((d) => d.toString()).toList(),
      );

  /// Unit for alert zone: 'meters' or 'km'. Defaults to 'meters'.
  static String get alertZoneUnit =>
      _prefs.getString(_kAlertZoneUnit) ?? 'meters';

  static Future<void> setAlertZoneUnit(String unit) =>
      _prefs.setString(_kAlertZoneUnit, unit);
}
