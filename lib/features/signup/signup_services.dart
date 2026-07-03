import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/email/otp_mailer.dart';
import 'signup_repo.dart';
import 'signup_validator.dart';

// ── Result types ────────────────────────────────────────────────────────────

/// Outcome of the first step: validating input and emailing the OTP.
enum OtpSendStatus {
  /// OTP generated and emailed; UI should advance to the OTP card.
  sent,

  /// One or more fields failed validation (see [fieldErrors]).
  invalidInput,

  /// An account already exists for this email.
  alreadyExists,

  /// The email could not be sent (SMTP/network error).
  sendFailed,
}

class StartSignUpResult {
  const StartSignUpResult({
    required this.status,
    this.message,
    this.email,
    this.fieldErrors = const {},
  });

  final OtpSendStatus status;
  final String? message;
  final String? email;
  final Map<String, String> fieldErrors;

  bool get isSent => status == OtpSendStatus.sent;
}

/// Outcome of the second step: verifying the code and creating the account.
enum OtpVerifyStatus {
  /// Code correct, auth user created and profile row written.
  success,

  /// Code does not match the one that was sent.
  invalidCode,

  /// Code expired; the user should request a new one.
  expired,

  /// No pending sign-up in progress (e.g. app state was lost).
  noPending,

  /// Any other failure while creating the account/profile.
  failure,
}

class VerifyResult {
  const VerifyResult({required this.status, this.message});

  final OtpVerifyStatus status;
  final String? message;

  bool get isSuccess => status == OtpVerifyStatus.success;
}

// ── Service ──────────────────────────────────────────────────────────────────

/// Business logic for the sign-up + email-OTP flow.
///
/// Step 1 ([startSignUp]) validates the form, guards against duplicates,
/// generates a one-time code and emails it via Gmail SMTP. The raw sign-up
/// details are held in memory (never written to Supabase yet).
///
/// Step 2 ([verifyOtpAndComplete]) checks the code and, only then, creates the
/// Supabase auth user and writes the profile row.
class SignUpService {
  SignUpService({SignUpRepo? repo}) : _repo = repo ?? SignUpRepo();

  final SignUpRepo _repo;

  static const Duration _otpTtl = Duration(minutes: 10);

  // Pending sign-up held between step 1 and step 2.
  String? _pendingFirstName;
  String? _pendingLastName;
  String? _pendingEmail;
  String? _pendingPassword;
  String? _otpCode;
  DateTime? _otpExpiresAt;

  /// The email the current OTP was sent to, for display on the OTP card.
  String? get pendingEmail => _pendingEmail;

  // ── Step 1: validate + send OTP ────────────────────────────────────────────
  Future<StartSignUpResult> startSignUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final validation = SignUpValidator.validate(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );
    if (!validation.isValid) {
      return StartSignUpResult(
        status: OtpSendStatus.invalidInput,
        fieldErrors: validation.fieldErrors,
      );
    }

    final cleanFirstName = firstName.trim();
    final cleanLastName = lastName.trim();
    final cleanEmail = email.trim().toLowerCase();

    try {
      if (await _repo.emailExists(cleanEmail)) {
        return const StartSignUpResult(
          status: OtpSendStatus.alreadyExists,
          message: 'An account with this email already exists.',
        );
      }
    } on Object {
      // Non-fatal: fall through and let account creation catch duplicates.
    }

    // Hold the details in memory until the code is verified.
    _pendingFirstName = cleanFirstName;
    _pendingLastName = cleanLastName;
    _pendingEmail = cleanEmail;
    _pendingPassword = password;

    final code = OtpMailer.generateOtp();
    _otpCode = code;
    _otpExpiresAt = DateTime.now().add(_otpTtl);

    try {
      await _sendOtpEmail(
        toEmail: cleanEmail,
        code: code,
        firstName: cleanFirstName,
      );
    } catch (_) {
      return const StartSignUpResult(
        status: OtpSendStatus.sendFailed,
        message: 'We could not send the verification email. '
            'Please check your connection and try again.',
      );
    }

    return StartSignUpResult(status: OtpSendStatus.sent, email: cleanEmail);
  }

  /// Regenerates and re-sends a fresh code to the pending email.
  Future<StartSignUpResult> resendOtp() async {
    final email = _pendingEmail;
    final firstName = _pendingFirstName;
    if (email == null || firstName == null) {
      return const StartSignUpResult(
        status: OtpSendStatus.sendFailed,
        message: 'Your session expired. Please sign up again.',
      );
    }

    final code = OtpMailer.generateOtp();
    _otpCode = code;
    _otpExpiresAt = DateTime.now().add(_otpTtl);

    try {
      await _sendOtpEmail(toEmail: email, code: code, firstName: firstName);
    } catch (_) {
      return const StartSignUpResult(
        status: OtpSendStatus.sendFailed,
        message: 'We could not resend the email. Please try again.',
      );
    }
    return StartSignUpResult(status: OtpSendStatus.sent, email: email);
  }

  // ── Step 2: verify code + create account ───────────────────────────────────
  Future<VerifyResult> verifyOtpAndComplete(String code) async {
    if (_pendingEmail == null || _otpCode == null || _otpExpiresAt == null) {
      return const VerifyResult(status: OtpVerifyStatus.noPending);
    }
    if (DateTime.now().isAfter(_otpExpiresAt!)) {
      return const VerifyResult(
        status: OtpVerifyStatus.expired,
        message: 'This code has expired. Please request a new one.',
      );
    }
    if (code.trim() != _otpCode) {
      return const VerifyResult(
        status: OtpVerifyStatus.invalidCode,
        message: 'That code is incorrect. Please try again.',
      );
    }

    try {
      final user = await _repo.createAuthUser(
        email: _pendingEmail!,
        password: _pendingPassword!,
        firstName: _pendingFirstName!,
        lastName: _pendingLastName!,
      );
      if (user == null) {
        return const VerifyResult(
          status: OtpVerifyStatus.failure,
          message: 'Could not create your account. Please try again.',
        );
      }

      // The profile insert is governed by RLS (auth.uid() = id), so a session
      // is required. If sign-up didn't return one, sign in with the password
      // to establish it before writing the profile row.
      if (!_repo.hasSession) {
        try {
          await _repo.signInWithPassword(
            email: _pendingEmail!,
            password: _pendingPassword!,
          );
        } on AuthException catch (_) {}
      }

      try {
        await _repo.upsertProfile(
          id: user.id,
          firstName: _pendingFirstName!,
          lastName: _pendingLastName!,
          email: _pendingEmail!,
        );
      } on PostgrestException catch (e) {
        // 23505 = duplicate; the row already exists, so treat it as done.
        if (e.code != '23505') {
          return const VerifyResult(
            status: OtpVerifyStatus.failure,
            message: 'Your account was created but we could not save your '
                'profile. Please check your email confirmation setting.',
          );
        }
      }

      _clearPending();
      return const VerifyResult(status: OtpVerifyStatus.success);
    } on AuthException catch (e) {
      return VerifyResult(status: OtpVerifyStatus.failure, message: e.message);
    } on PostgrestException catch (_) {
      return const VerifyResult(
        status: OtpVerifyStatus.failure,
        message: 'Something went wrong saving your profile. Please try again.',
      );
    } catch (_) {
      return const VerifyResult(
        status: OtpVerifyStatus.failure,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  void _clearPending() {
    _pendingFirstName = null;
    _pendingLastName = null;
    _pendingEmail = null;
    _pendingPassword = null;
    _otpCode = null;
    _otpExpiresAt = null;
  }

  // ── Gmail SMTP (shared mailer) ─────────────────────────────────────────────
  Future<void> _sendOtpEmail({
    required String toEmail,
    required String code,
    required String firstName,
  }) {
    return OtpMailer.sendOtp(
      toEmail: toEmail,
      code: code,
      subject: 'Your Proximity verification code',
      greeting: 'Hi $firstName,',
      intro: 'Use the verification code below to finish creating your '
          'Proximity account.',
    );
  }
}
