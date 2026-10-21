import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to values loaded from the `.env.local` file.
///
/// Call [load] once during app start-up (before reading any getter) so the
/// values are available synchronously afterwards. The file is bundled as an
/// asset (see `pubspec.yaml`) and is git-ignored so the keys never leave the
/// machine.
class Env {
  const Env._();

  /// Name of the env file bundled as an asset and read at runtime.
  static const String fileName = '.env.local';

  /// Loads the env file into memory. Safe to call exactly once at start-up.
  static Future<void> load() => dotenv.load(fileName: fileName);

  /// Mapbox public access token (starts with "pk."), passed to the Maps SDK
  /// at start-up so it can load map tiles.
  static String get mapboxPublicToken => _require('MAPBOX_PUBLIC_TOKEN');

  /// Non-throwing variant — returns null when the key is missing or empty,
  /// so callers can skip Mapbox initialisation gracefully during development.
  static String? get mapboxPublicTokenOrNull {
    final value = dotenv.env['MAPBOX_PUBLIC_TOKEN'];
    return (value != null && value.isNotEmpty) ? value : null;
  }

  /// Cloudinary cloud name — the only value needed to build public image
  /// delivery URLs (`https://res.cloudinary.com/<cloudName>/...`).
  static String get cloudinaryCloudName => _require('CLOUDINARY_CLOUD_NAME');

  /// Default Cloudinary folder/preset used when uploading new assets.
  static String get cloudinaryUploadPreset =>
      _require('CLOUDINARY_UPLOAD_PRESET_FOLDER');

  /// Reads [key] from the loaded env, throwing a clear error if it is missing
  /// so misconfiguration surfaces immediately instead of failing later.
  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing "$key" in $fileName. Make sure the file exists, is listed '
        'under flutter > assets in pubspec.yaml, and defines this key.',
      );
    }
    return value;
  }
}
