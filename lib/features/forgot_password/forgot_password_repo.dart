import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client.dart' as core;

/// Data-access layer for the forgot-password flow.
///
/// The OTP itself is generated/sent/verified in the service (client-side, same
/// as sign-up). The one thing that can't happen client-side is changing a
/// user's password without their session — that requires the Supabase Admin
/// API, which must run server-side. So [updatePassword] calls a Supabase Edge
/// Function (`reset-user-password`) that holds the service-role key as a
/// server secret and performs the update.
class ForgotPasswordRepo {
  ForgotPasswordRepo({SupabaseClient? client})
      : _client = client ?? core.supabase;

  final SupabaseClient _client;

  static const String _tableProfiles = 'profiles';
  static const String _profileColumnEmail = 'email';
  static const String _profileColumnId = 'id';

  /// Name of the Edge Function that performs the admin password update.
  static const String _resetFunction = 'reset-user-password';

  /// True if a profile row exists for [email] (i.e. an account to reset).
  Future<bool> emailExists(String email) async {
    try {
      final row = await _client
          .from(_tableProfiles)
          .select(_profileColumnId)
          .eq(_profileColumnEmail, email)
          .limit(1)
          .maybeSingle();
      return row != null;
    } on PostgrestException {
      // If the read is blocked, don't leak that as "no account"; let the
      // caller proceed (the function will no-op for unknown emails).
      return true;
    }
  }

  /// Updates the password for [email] via the server-side Edge Function.
  /// Throws on any non-success response so the service can surface a failure.
  Future<void> updatePassword({
    required String email,
    required String newPassword,
  }) async {
    final response = await _client.functions.invoke(
      _resetFunction,
      body: {'email': email, 'new_password': newPassword},
    );

    if (response.status != 200) {
      final data = response.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'status ${response.status}';
      throw Exception('Password update failed: $message');
    }
  }
}
