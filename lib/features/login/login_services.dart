import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/database/settings_sync.dart';
import '../../core/session/user_session.dart';
import 'login_repo.dart';
import 'login_validator.dart';

/// Discrete outcomes the login card can react to.
enum LoginStatus {
  success,
  invalidInput,
  noAccount,
  wrongPassword,
  emailNotConfirmed,
  googleNoAccount,
  googleCancelled,
  failure,
}

class LoginResult {
  const LoginResult({
    required this.status,
    this.message,
    this.fieldErrors = const {},
  });

  final LoginStatus status;
  final String? message;
  final Map<String, String> fieldErrors;

  bool get isSuccess => status == LoginStatus.success;
}

/// Business logic for logging in with email/password or Google.
class LoginService {
  LoginService({LoginRepo? repo}) : _repo = repo ?? LoginRepo();

  final LoginRepo _repo;

  Future<LoginResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final validation = LoginValidator.validate(email: email, password: password);
    if (!validation.isValid) {
      return LoginResult(
        status: LoginStatus.invalidInput,
        fieldErrors: validation.fieldErrors,
      );
    }

    final cleanEmail = email.trim().toLowerCase();

    if (!await _repo.emailExists(cleanEmail)) {
      return const LoginResult(
        status: LoginStatus.noAccount,
        fieldErrors: {
          LoginField.email:
              'No existing account for this email. Please sign up.',
        },
      );
    }

    try {
      await _repo.signInWithPassword(email: cleanEmail, password: password);
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        return const LoginResult(
          status: LoginStatus.emailNotConfirmed,
          fieldErrors: {
            LoginField.email: 'Please verify your email before logging in.',
          },
        );
      }
      return const LoginResult(
        status: LoginStatus.wrongPassword,
        fieldErrors: {
          LoginField.password: 'Incorrect password. Please try again.',
        },
      );
    } catch (_) {
      return const LoginResult(
        status: LoginStatus.failure,
        message: 'Something went wrong. Check your connection and try again.',
      );
    }

    await _persistSession();
    return const LoginResult(status: LoginStatus.success);
  }

  /// Native Google sign-in (awaitable end-to-end). Requires that the chosen
  /// email already has an account in our database; otherwise signs out and
  /// rejects, since Google has no password to gate on.
  Future<LoginResult> loginWithGoogle() async {
    try {
      final user = await _repo.signInWithGoogle();
      if (user == null) {
        return const LoginResult(status: LoginStatus.googleCancelled);
      }

      final email = user.email;
      final exists =
          email != null && await _repo.emailExists(email.toLowerCase());
      if (!exists) {
        await _repo.signOut();
        return const LoginResult(
          status: LoginStatus.googleNoAccount,
          message: 'No existing account for this Google email. Please sign up.',
        );
      }
      await _persistSession();
      return const LoginResult(status: LoginStatus.success);
    } on AuthException catch (e) {
      // Supabase throws this while trying to CREATE a brand-new auth user
      // (a Google account that never signed up), so treat it as "no account".
      final msg = e.message.toLowerCase();
      if (e.code == 'unexpected_failure' ||
          msg.contains('database error saving new user')) {
        await _repo.signOut();
        return const LoginResult(
          status: LoginStatus.googleNoAccount,
          message: 'No existing account for this Google email. Please sign up.',
        );
      }
      return const LoginResult(
        status: LoginStatus.failure,
        message: 'Google sign-in failed. Please try again.',
      );
    } catch (_) {
      return const LoginResult(
        status: LoginStatus.failure,
        message: 'Google sign-in failed. Please try again.',
      );
    }
  }

  /// Persists the authenticated user's id locally so routing keeps them logged
  /// in across app restarts.
  Future<void> _persistSession() async {
    final uid = _repo.currentUserId;
    if (uid != null) await UserSession.instance.onLogin(uid);
    // Pull the user's settings from the cloud so a new device gets the
    // correct alarm/vibration/dismiss/zone preferences immediately.
    SettingsSync.instance.pullFromCloud();
  }
}

