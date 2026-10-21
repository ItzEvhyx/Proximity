import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/otp_dialogs.dart';
import 'signup_services.dart';

/// White email-verification card shown after the user submits the sign-up
/// form and Firebase has sent an email-verification link.
/// The parent screen owns the sign-up <-> OTP slide, so this card never
/// navigates itself — it just calls [onBack] / [onVerified].
class SignUpOtpCard extends StatefulWidget {
  const SignUpOtpCard({
    super.key,
    required this.service,
    required this.email,
    this.onBack,
    this.onVerified,
  });

  /// Shared service holding the pending Firebase email verification.
  final SignUpService service;

  /// The email Firebase sent the verification link to.
  final String email;

  /// Fired when the user taps the bottom-left back ("<") button.
  final VoidCallback? onBack;

  /// Fired once the account is created and confirmed successfully.
  final VoidCallback? onVerified;

  @override
  State<SignUpOtpCard> createState() => _SignUpOtpCardState();
}

class _SignUpOtpCardState extends State<SignUpOtpCard> {
  bool _isBusy = false;

  Future<void> _onConfirm() async {
    FocusScope.of(context).unfocus();
    setState(() => _isBusy = true);

    showOtpLoadingDialog(context, title: 'Checking verification');
    final result = await widget.service.verifyOtpAndComplete('');
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    setState(() => _isBusy = false);

    switch (result.status) {
      case OtpVerifyStatus.success:
        await showOtpSuccessDialog(
          context,
          title: 'Email verified',
          message: 'Your Proximity account is ready.',
        );
        widget.onVerified?.call();
      case OtpVerifyStatus.invalidCode:
        _showSnack(result.message ?? 'That code is incorrect.');
      case OtpVerifyStatus.expired:
        _showSnack(result.message ?? 'This code has expired.');
      case OtpVerifyStatus.noPending:
        _showSnack('Your session expired. Please sign up again.');
      case OtpVerifyStatus.failure:
        _showSnack(result.message ?? 'Something went wrong.');
    }
  }

  Future<void> _onResend() async {
    FocusScope.of(context).unfocus();
    setState(() => _isBusy = true);

    showOtpLoadingDialog(context, title: 'Sending OTP');
    final result = await widget.service.resendOtp();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    setState(() => _isBusy = false);

    if (result.isSent) {
      _showSnack(
        'A new verification link has been sent to your email.',
        isError: false,
      );
    } else {
      _showSnack(result.message ?? 'Could not resend the code.');
    }
  }

  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 12,
                  bottom: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Email illustration ────────────────────────────────
                    Center(
                      child: SvgPicture.asset(
                        'public/assets/images/email_otp_img.svg',
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Instruction with the target email highlighted.
                    Text.rich(
                      TextSpan(
                        text: 'Open the verification link we sent to ',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.textDark,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Can't find it? Check your spam or trash folder.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textGrey,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildConfirmButton(),
                    const SizedBox(height: 14),
                    _buildResendRow(),
                  ],
                ),
              ),
            ),
            // ── Bottom-left back button ────────────────────────────────────
            Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8 + bottomPadding),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _isBusy ? null : widget.onBack,
                  splashRadius: 24,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isBusy ? null : _onConfirm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          disabledForegroundColor: AppColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          "I've verified",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildResendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Didn't receive the link? ",
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textGrey,
            fontSize: 13,
          ),
        ),
        GestureDetector(
          onTap: _isBusy ? null : _onResend,
          child: const Text(
            'Resend',
            style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
