import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/supabase/supabase_client.dart' as core;

/// Data-access layer for login: profile lookups and the Supabase/Google auth
/// calls.
class LoginRepo {
  LoginRepo({SupabaseClient? client, GoogleSignIn? googleSignIn})
      : _client = client ?? core.supabase,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(serverClientId: Env.googleWebClientId);

  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;

  /// The id of the currently authenticated Supabase user, if any.
  String? get currentUserId => _client.auth.currentUser?.id;

  static const String _tableProfiles = 'profiles';
  static const String _columnId = 'id';
  static const String _columnEmail = 'email';

  /// True if a profile row exists for [email].
  Future<bool> emailExists(String email) async {
    final row = await _client
        .from(_tableProfiles)
        .select(_columnId)
        .eq(_columnEmail, email)
        .limit(1)
        .maybeSingle();
    return row != null;
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Runs the native Google account picker and signs into Supabase with the
  /// returned ID token. Returns the [User], or null if the user cancelled.
  /// Throws on any other failure.
  Future<User?> signInWithGoogle() async {
    // Sign out first so the account picker is always shown.
    await _googleSignIn.signOut();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // cancelled

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null) {
      throw const AuthException('Google sign-in failed. Please try again.');
    }

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    return response.user;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _client.auth.signOut();
  }
}
