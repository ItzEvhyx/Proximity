import 'package:flutter/foundation.dart';

import '../../core/email/otp_mailer.dart';
import '../signup/signup_validator.dart';
import 'forgot_password_repo.dart';

// ── Result types ────────────────────────────────────────────────────────────

/// Outcome of step 1: validating the email and sending the reset OTP.
enum ResetSendStatus { sent, invalidEmail, noAccount, sendFailed }

class StartResetResult {
  const StartResetResult({required this.status, this.message, this.email});

  final ResetSendStatus status;
  final String? message;
  final String? email;

  bool get isSent => status == ResetSendStatus.sent;
}

/// Outcome of step 2: verifying the code.
enum ResetVerifyStatus { success, invalidCode, expired, noPending }

class ResetVerifyResult {
  const ResetVerifyResult({required this.status, this.message});

  final ResetVerifyStatus status;
  final String? message;

  bool get isSuccess => status == ResetVerifyStatus.success;
}

/// Outcome of step 3: validating + applying the new password.
enum ResetCompleteStatus { success, invalidInput, noPending, failure }

class ResetCompleteResult {
  const ResetCompleteResult({
    required this.status,
    this.message,
    this.passwordError,
    this.confirmError,
  });

  final ResetCompleteStatus status;
  final String? message;
  final String? passwordError;
  final String? confirmError;

  bool get isSuccess => status == ResetCompleteStatus.success;
}

// ── Service ──────────────────────────────────────────────────────────────────

/// Business logic for the forgot-password + email-OTP flow, mirroring the
/// sign-up flow. Step 1 ([startReset]) emails a code, step 2 ([verifyOtp])
/// checks it, step 3 ([completeReset]) applies the new password via the repo's
/// server-side Edge Function.
class ForgotPasswordService {
  ForgotPasswordService({ForgotPasswordRepo? repo})
      : _repo = repo ?? ForgotPasswordRepo();

  final ForgotPasswordRepo _repo;

  static const Duration _otpTtl = Duration(minutes: 10);

  String? _pendingEmail;
  String? _otpCode;
  DateTime? _otpExpiresAt;
  bool _verified = false;

  String? get pendingEmail => _pendingEmail;

  // ── Step 1: validate + send OTP ────────────────────────────────────────────
  Future<StartResetResult> startReset({required String email}) async {
    final emailError = SignUpValidator.validateEmail(email);
    if (emailError != null) {
      return StartResetResult(
        status: ResetSendStatus.invalidEmail,
        message: emailError,
      );
    }

    final cleanEmail = email.trim().toLowerCase();

    final exists = await _repo.emailExists(cleanEmail);
    if (!exists) {
      return const StartResetResult(
        status: ResetSendStatus.noAccount,
        message: 'No account was found for this email.',
      );
    }

    _pendingEmail = cleanEmail;
    _verified = false;
    final code = OtpMailer.generateOtp();
    _otpCode = code;
    _otpExpiresAt = DateTime.now().add(_otpTtl);

    try {
      await _sendResetEmail(cleanEmail, code);
    } catch (e, st) {
      debugPrint('Reset OTP send failed: $e');
      debugPrint('$st');
      return const StartResetResult(
        status: ResetSendStatus.sendFailed,
        message: 'We could not send the reset email. '
            'Please check your connection and try again.',
      );
    }

    return StartResetResult(status: ResetSendStatus.sent, email: cleanEmail);
  }

  Future<StartResetResult> resendOtp() async {
    final email = _pendingEmail;
    if (email == null) {
      return const StartResetResult(
        status: ResetSendStatus.sendFailed,
        message: 'Your session expired. Please start again.',
      );
    }
    final code = OtpMailer.generateOtp();
    _otpCode = code;
    _otpExpiresAt = DateTime.now().add(_otpTtl);
    try {
      await _sendResetEmail(email, code);
    } catch (e, st) {
      debugPrint('Reset OTP resend failed: $e');
      debugPrint('$st');
      return const StartResetResult(
        status: ResetSendStatus.sendFailed,
        message: 'We could not resend the email. Please try again.',
      );
    }
    return StartResetResult(status: ResetSendStatus.sent, email: email);
  }

  // ── Step 2: verify code ────────────────────────────────────────────────────
  Future<ResetVerifyResult> verifyOtp(String code) async {
    if (_pendingEmail == null || _otpCode == null || _otpExpiresAt == null) {
      return const ResetVerifyResult(status: ResetVerifyStatus.noPending);
    }
    if (DateTime.now().isAfter(_otpExpiresAt!)) {
      return const ResetVerifyResult(
        status: ResetVerifyStatus.expired,
        message: 'This code has expired. Please request a new one.',
      );
    }
    if (code.trim() != _otpCode) {
      return const ResetVerifyResult(
        status: ResetVerifyStatus.invalidCode,
        message: 'That code is incorrect. Please try again.',
      );
    }
    _verified = true;
    return const ResetVerifyResult(status: ResetVerifyStatus.success);
  }

  // ── Step 3: validate + apply new password ──────────────────────────────────
  Future<ResetCompleteResult> completeReset({
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (_pendingEmail == null || !_verified) {
      return const ResetCompleteResult(
        status: ResetCompleteStatus.noPending,
        message: 'Your session expired. Please start again.',
      );
    }

    final passwordError = SignUpValidator.validatePassword(newPassword);
    final confirmError =
        SignUpValidator.validateConfirmPassword(newPassword, confirmPassword);
    if (passwordError != null || confirmError != null) {
      return ResetCompleteResult(
        status: ResetCompleteStatus.invalidInput,
        passwordError: passwordError,
        confirmError: confirmError,
      );
    }

    try {
      await _repo.updatePassword(
        email: _pendingEmail!,
        newPassword: newPassword,
      );
    } catch (e, st) {
      debugPrint('Password update failed: $e');
      debugPrint('$st');
      return const ResetCompleteResult(
        status: ResetCompleteStatus.failure,
        message: 'We could not update your password. Please try again.',
      );
    }

    _clearPending();
    return const ResetCompleteResult(status: ResetCompleteStatus.success);
  }

  void _clearPending() {
    _pendingEmail = null;
    _otpCode = null;
    _otpExpiresAt = null;
    _verified = false;
  }

  Future<void> _sendResetEmail(String email, String code) {
    return OtpMailer.sendOtp(
      toEmail: email,
      code: code,
      subject: 'Your Proximity password reset code',
      greeting: 'Hello,',
      intro: 'Use the verification code below to reset your Proximity '
          'password.',
    );
  }
}
