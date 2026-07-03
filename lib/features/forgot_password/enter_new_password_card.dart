import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/otp_dialogs.dart';
import 'forgot_password_service.dart';

/// White "set a new password" card shown after the forgot-password OTP has
/// been verified. Reuses the lock illustration. Has two fields (new password +
/// confirm) and a confirm button. The parent screen owns the slide
/// transitions, so this card never navigates itself — it applies the new
/// password via the service and then calls [onConfirmed].
class EnterNewPasswordCard extends StatefulWidget {
  const EnterNewPasswordCard({
    super.key,
    required this.service,
    this.onBack,
    this.onConfirmed,
  });

  /// Shared service that applies the new password (server-side).
  final ForgotPasswordService service;

  /// Fired when the user taps the bottom-left back ("<") button.
  final VoidCallback? onBack;

  /// Fired once the password has been reset successfully.
  final VoidCallback? onConfirmed;

  @override
  State<EnterNewPasswordCard> createState() => _EnterNewPasswordCardState();
}

class _EnterNewPasswordCardState extends State<EnterNewPasswordCard> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isBusy = false;

  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _passwordError = null;
      _confirmError = null;
      _isBusy = true;
    });

    showOtpLoadingDialog(context, title: 'Resetting Password');
    final result = await widget.service.completeReset(
      newPassword: _passwordController.text,
      confirmPassword: _confirmController.text,
    );
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _isBusy = false);

    switch (result.status) {
      case ResetCompleteStatus.success:
        await showOtpSuccessDialog(
          context,
          title: 'Password Reset Successful',
          message: 'Your password has been updated. You can now log in with '
              'your new password.',
        );
        widget.onConfirmed?.call();
      case ResetCompleteStatus.invalidInput:
        setState(() {
          _passwordError = result.passwordError;
          _confirmError = result.confirmError;
        });
      case ResetCompleteStatus.noPending:
        _showSnack(result.message ?? 'Your session expired.');
      case ResetCompleteStatus.failure:
        _showSnack(result.message ?? 'Could not update your password.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
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
                    // ── Lock illustration (reused) ────────────────────────
                    Center(
                      child: Image.asset(
                        'public/assets/images/forgot_lock_img.png',
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Create New Password',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your new password must be different from your '
                      'previously used password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textGrey,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _fieldLabel('New Password'),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _passwordController,
                      hintText: 'Enter New Password...',
                      obscure: _obscurePassword,
                      onToggle: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                      errorText: _passwordError,
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel('Confirm New Password'),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _confirmController,
                      hintText: 'Confirm New Password...',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      errorText: _confirmError,
                    ),
                    const SizedBox(height: 24),
                    _buildConfirmButton(),
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

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        color: AppColors.textDark,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscure,
    required VoidCallback onToggle,
    String? errorText,
  }) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    );
    const errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
    );
    return TextField(
      controller: controller,
      obscureText: obscure,
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
        LengthLimitingTextInputFormatter(25),
      ],
      style: const TextStyle(
        fontFamily: 'Inter',
        color: AppColors.textDark,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          color: AppColors.hintGrey,
          fontSize: 15,
        ),
        prefixIcon:
            const Icon(Icons.lock_outline, color: AppColors.textDark, size: 24),
        suffixIcon: IconButton(
          splashRadius: 20,
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility : Icons.visibility_off,
            color: AppColors.textDark,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        errorText: errorText,
        errorMaxLines: 2,
        errorStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12),
        enabledBorder: border,
        focusedBorder: border,
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder,
        border: border,
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
}
