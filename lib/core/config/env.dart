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

  /// Supabase project URL (e.g. https://xxxx.supabase.co).
  static String get supabaseUrl => _require('SUPABASE_URL');

  /// Supabase publishable (client-safe) key used to initialise the SDK.
  static String get supabasePublishableKey =>
      _require('SUPABASE_PUBLISHABLE_KEY');

  /// Gmail app password used to authenticate the SMTP sender.
  static String get gmailAppPassword => _require('GMAIL_APP__PASSWORDS');

  /// The Gmail address the [gmailAppPassword] belongs to; used as the SMTP
  /// username and the "from" address on OTP emails.
  static String get gmailSenderEmail => _require('GMAIL_SENDER_EMAIL');

  /// Google Web OAuth client ID, used as the serverClientId for native Google
  /// sign-in so Supabase can verify the returned ID token.
  static String get googleWebClientId => _require('GOOGLE_WEB_CLIENT_ID');

  /// Mapbox public access token (starts with "pk."), passed to the Maps SDK
  /// at start-up so it can load map tiles.
  static String get mapboxPublicToken => _require('MAPBOX_PUBLIC_TOKEN');

  /// Cloudinary cloud name — the only value needed to build public image
  /// delivery URLs (`https://res.cloudinary.com/<cloudName>/...`).
  static String get cloudinaryCloudName => _require('CLOUDINARY_CLOUD_NAME');

  /// Default Cloudinary folder/preset used when uploading new assets.
  static String get cloudinaryUploadPreset =>
      _require('CLOUDINARY_UPLOAD_PRESET_FOLDER');

  /// Cloudinary API key — only required for authenticated Admin/Upload API
  /// calls (not for public image delivery).
  static String get cloudinaryApiKey => _require('CLOUDINARY_API_KEY');

  /// Cloudinary API secret — only required for signed/authenticated API
  /// calls. Keep this off the client for anything user-facing.
  static String get cloudinaryApiSecret => _require('CLOUDINARY_API_SECRET');

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
