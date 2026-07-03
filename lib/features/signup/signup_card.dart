import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/otp_dialogs.dart';
import 'signup_services.dart';
import 'signup_validator.dart';

/// White sign-up card that spans the bottom of the screen with large rounded
/// top corners. Anchored by its parent; only its inner content scrolls when
/// the keyboard opens. The parent screen owns the login <-> sign up and
/// sign up <-> OTP transitions, so this card never navigates itself — it just
/// calls [onBack] / [onOtpSent].
class SignUpCard extends StatefulWidget {
  const SignUpCard({
    super.key,
    required this.service,
    this.onBack,
    this.onOtpSent,
  });

  /// Shared service that validates input and emails the verification code.
  final SignUpService service;

  /// Fired when the user taps the bottom-left back ("<") button.
  final VoidCallback? onBack;

  /// Fired once the OTP has been emailed; carries the target email so the
  /// parent can advance to the OTP card.
  final ValueChanged<String>? onOtpSent;

  @override
  State<SignUpCard> createState() => _SignUpCardState();
}

class _SignUpCardState extends State<SignUpCard> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Requirements panel appears once the user starts typing a password.
  bool _showRequirements = false;

  // Sign-up flow: validate -> email OTP (account is created only after the
  // code is verified on the OTP card).
  bool _isSubmitting = false;
  // Per-field error messages keyed by SignUpField, rendered inline.
  final Map<String, String?> _fieldErrors = {};

  // ── Live password requirement flags ────────────────────────────────────────
  bool get _hasLength {
    final len = _passwordController.text.length;
    return len >= 8 && len <= 25;
  }

  bool get _hasSpecial =>
      _passwordController.text.contains(RegExp(r'[^A-Za-z0-9\s]'));
  bool get _hasNumber =>
      _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasUppercase =>
      _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase =>
      _passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasNoSpaces =>
      _passwordController.text.isNotEmpty &&
      !_passwordController.text.contains(RegExp(r'\s'));

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final shouldShow = _passwordController.text.isNotEmpty;
    if (shouldShow != _showRequirements) {
      setState(() => _showRequirements = shouldShow);
    } else {
      // Refresh the requirement indicators as the user types.
      setState(() {});
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Validates the form, then emails a verification code. On success the
  /// parent slides in the OTP card; the account itself is created later, once
  /// the code is verified.
  Future<void> _onSignUpPressed() async {
    FocusScope.of(context).unfocus();

    // Validate locally first so we never flash a loading modal for bad input.
    final validation = SignUpValidator.validate(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
    if (!validation.isValid) {
      setState(() {
        _fieldErrors
          ..clear()
          ..addAll(validation.fieldErrors);
      });
      _showSnack('Please fix the highlighted fields.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _fieldErrors.clear();
    });

    // Loading modal while the OTP email is being sent.
    showOtpLoadingDialog(context, title: 'Sending OTP');
    final result = await widget.service.startSignUp(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

    setState(() {
      _isSubmitting = false;
      _fieldErrors
        ..clear()
        ..addAll(result.fieldErrors);
    });

    switch (result.status) {
      case OtpSendStatus.sent:
        widget.onOtpSent?.call(result.email ?? _emailController.text.trim());
      case OtpSendStatus.invalidInput:
        _showSnack('Please fix the highlighted fields.');
      case OtpSendStatus.alreadyExists:
        setState(() => _fieldErrors[SignUpField.email] =
            'An account with this email already exists.');
        _showSnack(result.message ?? 'Account already exists.');
      case OtpSendStatus.sendFailed:
        _showSnack(result.message ?? 'Could not send the verification email.');
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 26,
            bottom: 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
            const Center(
              child: Text(
                'Get Started',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // ── First / Last name row ─────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _fieldLabel('First Name'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _firstNameController,
                        hintText: 'Enter First name...',
                        textCapitalization: TextCapitalization.words,
                        errorText: _fieldErrors[SignUpField.firstName],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _fieldLabel('Last Name'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _lastNameController,
                        hintText: 'Enter Last name...',
                        textCapitalization: TextCapitalization.words,
                        errorText: _fieldErrors[SignUpField.lastName],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Email ─────────────────────────────────────────────────────
            _fieldLabel('Email'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emailController,
              hintText: 'Enter Email...',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              errorText: _fieldErrors[SignUpField.email],
            ),
            const SizedBox(height: 16),
            // ── Password ──────────────────────────────────────────────────
            _fieldLabel('Password'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _passwordController,
              hintText: 'Enter Password...',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              errorText: _fieldErrors[SignUpField.password],
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                LengthLimitingTextInputFormatter(25),
              ],
              suffix: IconButton(
                splashRadius: 20,
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: AppColors.textDark,
                ),
              ),
            ),
            // ── Password requirements (appear while typing) ───────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: _showRequirements
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _PasswordRequirements(
                        hasLength: _hasLength,
                        hasUppercase: _hasUppercase,
                        hasLowercase: _hasLowercase,
                        hasNumber: _hasNumber,
                        hasSpecial: _hasSpecial,
                        hasNoSpaces: _hasNoSpaces,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            // ── Confirm Password ──────────────────────────────────────────
            _fieldLabel('Confirm Password'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _confirmPasswordController,
              hintText: 'Confirm Password...',
              icon: Icons.lock_outline,
              obscureText: _obscureConfirm,
              errorText: _fieldErrors[SignUpField.confirmPassword],
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                LengthLimitingTextInputFormatter(25),
              ],
              suffix: IconButton(
                splashRadius: 20,
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(
                  _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 22),
            _buildSignUpButton(),
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
    IconData? icon,
    bool obscureText = false,
    Widget? suffix,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
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
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
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
            icon != null ? Icon(icon, color: AppColors.textDark, size: 24) : null,
        suffixIcon: suffix,
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

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _onSignUpPressed,
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
        child: _isSubmitting
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Sign-up',
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

/// Password rules that light up green with a check as each one is satisfied.
/// Unmet rules show a red outlined circle; met rules show a green check.
class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({
    required this.hasLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecial,
    required this.hasNoSpaces,
  });

  final bool hasLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecial;
  final bool hasNoSpaces;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          _Req(label: '8 characters minimum, 25 maximum', met: hasLength),
          const SizedBox(height: 6),
          _Req(label: 'At least one special character', met: hasSpecial),
          const SizedBox(height: 6),
          _Req(label: 'At least one number', met: hasNumber),
          const SizedBox(height: 6),
          _Req(label: 'At least one uppercase letter', met: hasUppercase),
          const SizedBox(height: 6),
          _Req(label: 'At least one lowercase letter', met: hasLowercase),
          const SizedBox(height: 6),
          _Req(label: 'No spaces allowed', met: hasNoSpaces),
        ],
      ),
    );
  }
}

class _Req extends StatelessWidget {
  const _Req({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? AppColors.primary : Colors.redAccent;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: color,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Circle when unmet, animated swap to a green check once satisfied.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: met
              ? const Icon(
                  Icons.check_circle_rounded,
                  key: ValueKey('met'),
                  color: AppColors.primary,
                  size: 18,
                )
              : const Icon(
                  Icons.circle_outlined,
                  key: ValueKey('unmet'),
                  color: Colors.redAccent,
                  size: 18,
                ),
        ),
      ],
    );
  }
}
