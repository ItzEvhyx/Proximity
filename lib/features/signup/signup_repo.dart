import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client.dart' as core;

/// Data-access layer for sign-up. Owns every Supabase call: creating the auth
/// user and writing the row into the `profiles` table. It performs no business
/// logic or validation — the service layer decides *when* to call these.
///
/// NOTE ON SCHEMA: this assumes a `profiles` table with the columns
///   id (uuid, primary key = auth user id), first_name, last_name, email
/// and an auto-populated created_at. If your column names differ, adjust
/// [profileColumnId] .. [profileColumnEmail] / [_tableProfiles] below.
class SignUpRepo {
  SignUpRepo({SupabaseClient? client}) : _client = client ?? core.supabase;

  final SupabaseClient _client;

  /// Whether there is an active authenticated session. The profile insert is
  /// governed by an RLS policy (`auth.uid() = id`), so a session is required
  /// for the write to be accepted.
  bool get hasSession => _client.auth.currentSession != null;

  /// Signs in with email/password to establish a session (used right after
  /// sign-up when no session was returned). Throws [AuthException] on failure.
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  static const String _tableProfiles = 'profiles';
  static const String profileColumnId = 'id';
  static const String profileColumnFirstName = 'first_name';
  static const String profileColumnLastName = 'last_name';
  static const String profileColumnEmail = 'email';

  /// True if a profile row already exists for [email].
  ///
  /// Used by the service as an early, friendly "account already exists" check
  /// before hitting auth. Returns false if the query is blocked (e.g. RLS),
  /// so the auth call remains the source of truth for duplicates.
  Future<bool> emailExists(String email) async {
    try {
      final row = await _client
          .from(_tableProfiles)
          .select(profileColumnId)
          .eq(profileColumnEmail, email)
          .limit(1)
          .maybeSingle();
      return row != null;
    } on PostgrestException {
      return false;
    }
  }

  /// Creates the Supabase auth user for [email] / [password]. The first/last
  /// name are also stored in the auth user metadata so they survive even if
  /// the profile write is retried later.
  ///
  /// Returns the created [User], or null if Supabase did not return one.
  /// Throws [AuthException] on failure (e.g. user already registered).
  Future<User?> createAuthUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        profileColumnFirstName: firstName,
        profileColumnLastName: lastName,
      },
    );
    return response.user;
  }

  /// Writes the profile row for a freshly created user. Uses upsert (on the
  /// primary key `id`) so it succeeds whether the row is brand new or was
  /// already created by a database trigger such as `handle_new_user`.
  /// Throws [PostgrestException] on failure (e.g. RLS rejection).
  Future<void> upsertProfile({
    required String id,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    await _client.from(_tableProfiles).upsert({
      profileColumnId: id,
      profileColumnFirstName: firstName,
      profileColumnLastName: lastName,
      profileColumnEmail: email,
    }, onConflict: profileColumnId);
  }
}
