import 'package:firebase_auth/firebase_auth.dart';

import '../signup/signup_validator.dart';
import 'forgot_password_repo.dart';

enum ResetSendStatus { sent, invalidEmail, noAccount, sendFailed }

class StartResetResult {
  const StartResetResult({required this.status, this.message, this.email});
  final ResetSendStatus status;
  final String? message;
  final String? email;
  bool get isSent => status == ResetSendStatus.sent;
}

// Kept for the inactive legacy cards while password reset is completed in the
// Firebase-hosted action page linked from the email.
enum ResetVerifyStatus { success, invalidCode, expired, noPending }

class ResetVerifyResult {
  const ResetVerifyResult({required this.status, this.message});
  final ResetVerifyStatus status;
  final String? message;
  bool get isSuccess => status == ResetVerifyStatus.success;
}

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

class ForgotPasswordService {
  ForgotPasswordService({ForgotPasswordRepo? repo})
    : _repo = repo ?? ForgotPasswordRepo();
  final ForgotPasswordRepo _repo;

  Future<StartResetResult> startReset({required String email}) async {
    final error = SignUpValidator.validateEmail(email);
    if (error != null) {
      return StartResetResult(
        status: ResetSendStatus.invalidEmail,
        message: error,
      );
    }
    final cleanEmail = email.trim().toLowerCase();
    try {
      await _repo.sendPasswordResetEmail(cleanEmail);
      // Firebase can be configured to hide user enumeration, so intentionally
      // return the same result for both existing and unknown email addresses.
      return StartResetResult(status: ResetSendStatus.sent, email: cleanEmail);
    } on FirebaseAuthException catch (e) {
      return StartResetResult(
        status: ResetSendStatus.sendFailed,
        message: e.message ?? 'We could not send the reset email.',
      );
    } catch (_) {
      return const StartResetResult(
        status: ResetSendStatus.sendFailed,
        message: 'We could not send the reset email. Please try again.',
      );
    }
  }

  Future<StartResetResult> resendOtp() async => const StartResetResult(
    status: ResetSendStatus.sendFailed,
    message: 'Use the password reset link in your email.',
  );

  Future<ResetVerifyResult> verifyOtp(String _) async =>
      const ResetVerifyResult(
        status: ResetVerifyStatus.noPending,
        message: 'Use the password reset link in your email.',
      );

  Future<ResetCompleteResult> completeReset({
    required String newPassword,
    required String confirmPassword,
  }) async => const ResetCompleteResult(
    status: ResetCompleteStatus.noPending,
    message: 'Use the password reset link in your email.',
  );
}
