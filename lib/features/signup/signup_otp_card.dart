import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/otp_dialogs.dart';
import 'signup_services.dart';

/// White email-verification card shown after the user submits the sign-up
/// form and the OTP has been emailed. Mirrors the password-reset card style.
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

  /// Shared service holding the pending sign-up + issued code.
  final SignUpService service;

  /// The email the code was sent to, shown in the instruction line.
  final String email;

  /// Fired when the user taps the bottom-left back ("<") button.
  final VoidCallback? onBack;

  /// Fired once the account is created and confirmed successfully.
  final VoidCallback? onVerified;

  @override
  State<SignUpOtpCard> createState() => _SignUpOtpCardState();
}

class _SignUpOtpCardState extends State<SignUpOtpCard> {
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

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _otpLength - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    setState(() {}); // refresh Confirm button enabled state
  }

  Future<void> _onConfirm() async {
    if (_code.length < _otpLength) {
      _showSnack('Please enter the full 6-digit code.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isBusy = true);

    // Loading modal while verifying + creating the account.
    showOtpLoadingDialog(context, title: 'Verifying OTP');
    final result = await widget.service.verifyOtpAndComplete(_code);
    if (!mounted) return;
    // Dismiss the loading modal.
    Navigator.of(context, rootNavigator: true).pop();

    setState(() => _isBusy = false);

    switch (result.status) {
      case OtpVerifyStatus.success:
        await showOtpSuccessDialog(
          context,
          title: 'Verification Successful',
          message: 'Your Proximity account has been created.',
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
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
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
                      child: Image.asset(
                        'public/assets/images/email_otp_img.png',
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Instruction with the target email highlighted.
                    Text.rich(
                      TextSpan(
                        text: 'Please enter the verification code we sent to ',
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
                    _buildOtpRow(),
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

  Widget _buildOtpRow() {
    return Row(
      children: [
        Expanded(child: _otpBox(0)),
        const SizedBox(width: 8),
        Expanded(child: _otpBox(1)),
        const SizedBox(width: 8),
        Expanded(child: _otpBox(2)),
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
