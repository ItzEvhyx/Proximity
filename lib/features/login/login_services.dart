import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    final validation = LoginValidator.validate(
      email: email,
      password: password,
    );
    if (!validation.isValid) {
      return LoginResult(
        status: LoginStatus.invalidInput,
        fieldErrors: validation.fieldErrors,
      );
    }

    final cleanEmail = email.trim().toLowerCase();

    try {
      await _repo.signInWithPassword(email: cleanEmail, password: password);
      if (!await _repo.isCurrentEmailVerified()) {
        await _repo.signOut();
        return const LoginResult(
          status: LoginStatus.emailNotConfirmed,
          fieldErrors: {
            LoginField.email: 'Please verify your email before logging in.',
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return const LoginResult(
          status: LoginStatus.noAccount,
          fieldErrors: {
            LoginField.email:
                'No existing account for this email. Please sign up.',
          },
        );
      }
      if (e.code == 'user-disabled') {
        return const LoginResult(
          status: LoginStatus.emailNotConfirmed,
          fieldErrors: {
            LoginField.email:
                'This account is unavailable. Please contact support.',
          },
        );
      }
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return const LoginResult(
          status: LoginStatus.wrongPassword,
          fieldErrors: {
            LoginField.password: 'Incorrect password. Please try again.',
          },
        );
      }
      return LoginResult(
        status: LoginStatus.failure,
        message: _emailSignInFailureMessage(e),
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

  /// Native Google sign-in. Firebase creates the Auth account for a new Google
  /// identity, then we create its matching application profile.
  Future<LoginResult> loginWithGoogle() async {
    try {
      final credential = await _repo.signInWithGoogle();
      if (credential == null) {
        return const LoginResult(status: LoginStatus.googleCancelled);
      }
      final user = credential.user;
      if (user == null) {
        return const LoginResult(
          status: LoginStatus.failure,
          message: 'Google did not return an account. Please try again.',
        );
      }
      if (credential.additionalUserInfo?.isNewUser ?? false) {
        // Do not reject a valid first-time Google sign-in. This had made the
        // Google button look broken for every new user.
        try {
          await _repo.ensureGoogleProfile(user);
        } catch (_) {
          // Authentication has succeeded; profile sync can retry later.
        }
      }
      await _persistSession();
      return const LoginResult(status: LoginStatus.success);
    } on FirebaseAuthException catch (e) {
      debugPrint('Google FirebaseAuthException: ${e.code}: ${e.message}');
      return LoginResult(
        status: LoginStatus.failure,
        message: _googleSignInFailureMessage(e),
      );
    } catch (e) {
      debugPrint('Google sign-in exception: $e');
      return LoginResult(
        status: LoginStatus.failure,
        message: _googleSignInFailureMessage(e),
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

  String _emailSignInFailureMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase yet.';
      case 'network-request-failed':
        return 'Could not reach Firebase. Check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return error.message ?? 'Sign-in failed. Please try again.';
    }
  }

  String _googleSignInFailureMessage(Object error) {
    final details = error.toString().toLowerCase();
    if (details.contains('developer_error') ||
        details.contains('api_exception: 10') ||
        details.contains('status code: 10') ||
        details.contains('error 10') ||
        details.contains('10:')) {
      return 'Google sign-in is not configured for this Android build. Add '
          'this app\'s SHA fingerprint in Firebase, then download a new '
          'google-services.json.';
    }
    if (error is FirebaseAuthException &&
        error.code == 'operation-not-allowed') {
      return 'Google sign-in is disabled in Firebase Authentication.';
    }
    if (error is FirebaseAuthException) {
      if (error.code == 'account-exists-with-different-credential') {
        return 'An account already exists for this email with a different '
            'sign-in method.';
      }
      if (error.code == 'invalid-credential') {
        return 'Google returned an invalid credential. Reinstall a fresh '
            'build after updating google-services.json, then try again.';
      }
    }
    if (details.contains('network')) {
      return 'Could not reach Google. Check your internet connection.';
    }
    return 'Google sign-in failed. Please try again.';
  }
}
