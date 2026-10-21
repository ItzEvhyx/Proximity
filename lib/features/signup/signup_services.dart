import 'package:firebase_auth/firebase_auth.dart';

import 'signup_repo.dart';
import 'signup_validator.dart';

enum OtpSendStatus { sent, invalidInput, alreadyExists, sendFailed }

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

enum OtpVerifyStatus { success, invalidCode, expired, noPending, failure }

class VerifyResult {
  const VerifyResult({required this.status, this.message});
  final OtpVerifyStatus status;
  final String? message;
  bool get isSuccess => status == OtpVerifyStatus.success;
}

/// Firebase email verification workflow. The retained result names keep the
/// existing presentation layer stable while Firebase owns the secure link.
class SignUpService {
  SignUpService({SignUpRepo? repo}) : _repo = repo ?? SignUpRepo();
  final SignUpRepo _repo;

  String? _pendingEmail;
  String? get pendingEmail => _pendingEmail;

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

    final cleanEmail = email.trim().toLowerCase();
    try {
      await _repo.createAuthUser(
        email: cleanEmail,
        password: password,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
      );
      await _repo.sendEmailVerification();
      _pendingEmail = cleanEmail;
      return StartSignUpResult(status: OtpSendStatus.sent, email: cleanEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return const StartSignUpResult(
          status: OtpSendStatus.alreadyExists,
          message: 'An account with this email already exists.',
        );
      }
      return StartSignUpResult(
        status: OtpSendStatus.sendFailed,
        message: e.message ?? 'We could not create your account.',
      );
    } catch (_) {
      return const StartSignUpResult(
        status: OtpSendStatus.sendFailed,
        message:
            'We could not create your account or send the verification email.',
      );
    }
  }

  Future<StartSignUpResult> resendOtp() async {
    final email = _pendingEmail;
    if (email == null) {
      return const StartSignUpResult(
        status: OtpSendStatus.sendFailed,
        message: 'Your session expired. Please sign up again.',
      );
    }
    try {
      await _repo.sendEmailVerification();
      return StartSignUpResult(status: OtpSendStatus.sent, email: email);
    } catch (_) {
      return const StartSignUpResult(
        status: OtpSendStatus.sendFailed,
        message:
            'We could not resend the verification email. Please try again.',
      );
    }
  }

  /// The parameter is intentionally ignored: Firebase validates its signed
  /// link, rather than exposing a client-verifiable one-time code.
  Future<VerifyResult> verifyOtpAndComplete(String _) async {
    if (_pendingEmail == null) {
      return const VerifyResult(status: OtpVerifyStatus.noPending);
    }
    try {
      if (!await _repo.refreshEmailVerification()) {
        return const VerifyResult(
          status: OtpVerifyStatus.invalidCode,
          message: 'Open the verification link in your email, then try again.',
        );
      }
      _pendingEmail = null;
      return const VerifyResult(status: OtpVerifyStatus.success);
    } catch (_) {
      return const VerifyResult(
        status: OtpVerifyStatus.failure,
        message: 'Could not check your verification status. Please try again.',
      );
    }
  }
}
