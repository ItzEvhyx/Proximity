import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/otp_dialogs.dart';
import 'forgot_password_service.dart';

/// White forgot-password card that spans the bottom of the screen with large
/// rounded top corners. Same height as the login card. Anchored by its parent;
/// only its inner content scrolls when the keyboard opens. The parent screen
/// owns the login <-> forgot-password transition, so this card never navigates
/// itself — it just calls [onBack] / [onOtpSent].
class ForgotPassCard extends StatefulWidget {
  const ForgotPassCard({
    super.key,
    required this.service,
    this.onBack,
    this.onOtpSent,
  });

  /// Shared service that validates the email and emails the reset code.
  final ForgotPasswordService service;

  /// Fired when the user taps the bottom-left back ("<") button.
  final VoidCallback? onBack;

  /// Fired once the reset code has been emailed; carries the target email so
  /// the parent can advance to the OTP card.
  final ValueChanged<String>? onOtpSent;

  @override
  State<ForgotPassCard> createState() => _ForgotPassCardState();
}

class _ForgotPassCardState extends State<ForgotPassCard> {
  final TextEditingController _emailController = TextEditingController();

  bool _isSubmitting = false;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSendPressed() async {
    FocusScope.of(context).unfocus();
    setState(() => _emailError = null);

    showOtpLoadingDialog(context, title: 'Sending OTP');
    setState(() => _isSubmitting = true);
    final result = await widget.service.startReset(
      email: _emailController.text,
    );
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
    setState(() => _isSubmitting = false);

    switch (result.status) {
      case ResetSendStatus.sent:
        widget.onOtpSent?.call(result.email ?? _emailController.text.trim());
      case ResetSendStatus.invalidEmail:
        setState(() => _emailError = result.message ?? 'Invalid email');
      case ResetSendStatus.noAccount:
        setState(() => _emailError = result.message ?? 'No account found');
      case ResetSendStatus.sendFailed:
        _showSnack(result.message ?? 'Could not send the reset email.');
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
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

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
                  top: 20,
                  bottom: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
              // ── Lock illustration ─────────────────────────────────────
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
                  'Forgot Password',
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
                'Please enter your email address to reset your password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textGrey,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _fieldLabel('Email'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                hintText: 'Enter Email...',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
              ),
                    const SizedBox(height: 20),
                    _buildSendButton(),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
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
      keyboardType: keyboardType,
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
        prefixIcon: Icon(icon, color: AppColors.textDark, size: 24),
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

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _onSendPressed,
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
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send OTP',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 22),
          ],
        ),
      ),
    );
  }
}
