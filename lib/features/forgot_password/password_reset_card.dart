import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/otp_dialogs.dart';
import 'forgot_password_service.dart';

/// White password-reset / OTP card that spans the bottom of the screen with
/// large rounded top corners. Shown after the user submits their email on the
/// forgot-password card. Anchored by its parent; only its inner content
/// scrolls when the keyboard opens. The parent screen owns the
/// forgot-password <-> reset transition, so this card never navigates itself —
/// it verifies the code and then calls [onBack] / [onConfirmed].
class PasswordResetCard extends StatefulWidget {
  const PasswordResetCard({
    super.key,
    required this.service,
    required this.email,
    this.onBack,
    this.onConfirmed,
  });

  /// Shared service holding the pending reset + issued code.
  final ForgotPasswordService service;

  /// The email the code was sent to, shown in the instruction line.
  final String email;

  /// Fired when the user taps the bottom-left back ("<") button.
  final VoidCallback? onBack;

  /// Fired once the code is verified successfully. The parent advances to the
  /// set-new-password card.
  final VoidCallback? onConfirmed;

  @override
  State<PasswordResetCard> createState() => _PasswordResetCardState();
}

class _PasswordResetCardState extends State<PasswordResetCard> {
  // One controller + focus node per OTP digit box.
  static const int _otpLength = 6;
  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;

  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _otpControllers =
        List.generate(_otpLength, (_) => TextEditingController());
    _otpFocusNodes = List.generate(_otpLength, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _otpControllers.map((c) => c.text).join();

  /// Advance to the next box on entry, retreat to the previous one on delete,
  /// so the six boxes behave like a single OTP field.
  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _otpLength - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _onConfirm() async {
    if (_code.length < _otpLength) {
      _showSnack('Please enter the full 6-digit code.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isBusy = true);

    showOtpLoadingDialog(context, title: 'Verifying OTP');
    final result = await widget.service.verifyOtp(_code);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _isBusy = false);

    switch (result.status) {
      case ResetVerifyStatus.success:
        await showOtpSuccessDialog(
          context,
          title: 'Verification Successful',
          message: 'Your identity has been verified. '
              'You can now set a new password.',
        );
        widget.onConfirmed?.call();
      case ResetVerifyStatus.invalidCode:
        _showSnack(result.message ?? 'That code is incorrect.');
      case ResetVerifyStatus.expired:
        _showSnack(result.message ?? 'This code has expired.');
      case ResetVerifyStatus.noPending:
        _showSnack('Your session expired. Please start again.');
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
      _showSnack('A new code has been sent to your email.', isError: false);
    } else {
      _showSnack(result.message ?? 'Could not resend the code.');
    }
  }

  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = mq.padding.bottom;
    final keyboardHeight = mq.viewInsets.bottom;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      // Reserve the keyboard height at the bottom so the scroll viewport ends
      // right above the keyboard. The card frame itself stays anchored to the
      // bottom; only its inner contents scroll up to clear the keyboard.
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
                    // ── Mailbox illustration ──────────────────────────────
                    Center(
                      child: Image.asset(
                        'public/assets/images/forgot_mailbox_img.png',
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Password Reset Sent',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        text: 'Please enter the OTP we sent to ',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.textGrey,
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
                          const TextSpan(
                            text: ' to verify your identity and reset your '
                                'password.',
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildOtpRow(),
                    const SizedBox(height: 24),
                    _buildConfirmButton(),
                    const SizedBox(height: 14),
                    _buildResendRow(),
                  ],
                ),
              ),
            ),
            // ── Bottom-left back button, pinned to the card's bottom edge ──
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                bottom: 8 + bottomPadding,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: widget.onBack,
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

  /// Six digit boxes, split 3 — 3 with a dash spacer in the middle.
  Widget _buildOtpRow() {
    return Row(
      children: [
        Expanded(child: _otpBox(0)),
        const SizedBox(width: 8),
        Expanded(child: _otpBox(1)),
        const SizedBox(width: 8),
        Expanded(child: _otpBox(2)),
        // Center dash separator.
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '-',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: AppColors.textGrey,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: _otpBox(3)),
        const SizedBox(width: 8),
        Expanded(child: _otpBox(4)),
        const SizedBox(width: 8),
        Expanded(child: _otpBox(5)),
      ],
    );
  }

  Widget _otpBox(int index) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    );
    return SizedBox(
      height: 58,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        // Only digits, single character.
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        onChanged: (value) => _onDigitChanged(index, value),
        style: const TextStyle(
          fontFamily: 'Poppins',
          color: AppColors.textDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        decoration: const InputDecoration(
          counterText: '',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
          enabledBorder: border,
          focusedBorder: border,
          border: border,
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
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Confirm',
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
          "Didn't receive the code? ",
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
