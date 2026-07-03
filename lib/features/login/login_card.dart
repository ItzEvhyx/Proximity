import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import 'login_services.dart';
import 'login_validator.dart';

/// White login card that spans the bottom of the screen with large rounded
/// top corners. The card is anchored by its parent; only its inner content
/// scrolls when the keyboard opens.
class LoginCard extends StatefulWidget {
  const LoginCard({super.key, this.onSignUp, this.onForgotPassword});

  /// Fired when the user taps the "Sign up" text. The parent screen owns the
  /// login <-> sign up transition, so this card never navigates itself.
  final VoidCallback? onSignUp;

  /// Fired when the user taps "Forgot Password?". The parent screen owns the
  /// login <-> forgot-password transition.
  final VoidCallback? onForgotPassword;

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  final LoginService _loginService = LoginService();

  bool _isLoggingIn = false;
  bool _isGoogleLoading = false;

  String? _emailError;
  String? _passwordError;
  String? _googleError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoggingIn = true;
      _emailError = null;
      _passwordError = null;
      _googleError = null;
    });

    final result = await _loginService.loginWithEmail(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() {
      _isLoggingIn = false;
      _emailError = result.fieldErrors[LoginField.email];
      _passwordError = result.fieldErrors[LoginField.password];
    });

    if (result.isSuccess) {
      _goAfterLogin();
    } else if (result.status == LoginStatus.failure) {
      _showSnack(result.message ?? 'Something went wrong.');
    }
  }

  Future<void> _onGooglePressed() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isGoogleLoading = true;
      _googleError = null;
      _emailError = null;
      _passwordError = null;
    });

    final result = await _loginService.loginWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    switch (result.status) {
      case LoginStatus.success:
        _goAfterLogin();
      case LoginStatus.googleCancelled:
        break; // user backed out — no error
      default:
        setState(() => _googleError = result.message ?? 'Google sign-in failed.');
    }
  }

  void _goAfterLogin() {
    Navigator.of(context).pushReplacement(AppRouter.afterLogin());
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
    // Targeted accessors: only rebuild for padding/keyboard changes, not every
    // MediaQuery change.
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
        child: SingleChildScrollView(
          // Clamped (no bounce); the keyboard is dismissed when the user drags.
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 30,
            bottom: 24 + bottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
            _fieldLabel('Email'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emailController,
              hintText: 'Enter Email...',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
            ),
            const SizedBox(height: 16),
            _fieldLabel('Password'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _passwordController,
              hintText: 'Enter Password...',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              errorText: _passwordError,
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onForgotPassword,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildLoginButton(),
            const SizedBox(height: 18),
            _buildDivider(),
            const SizedBox(height: 18),
            _buildSocialButtons(),
            if (_googleError != null) ...[
              const SizedBox(height: 10),
              Text(
                _googleError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.redAccent,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 22),
            _buildSignUpPrompt(),
          ],
        ),
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
    bool obscureText = false,
    Widget? suffix,
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
      obscureText: obscureText,
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
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
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

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoggingIn ? null : _onLoginPressed,
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
        child: _isLoggingIn
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Log In',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.primary, thickness: 1.2)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Or',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: AppColors.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.primary, thickness: 1.2)),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      children: [
        Expanded(
          child: _socialButton(
            label: 'Google',
            assetPath: 'public/assets/icons/google_icon.png',
            onPressed: _isGoogleLoading ? null : _onGooglePressed,
            loading: _isGoogleLoading,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _socialButton(
            label: 'Facebook',
            assetPath: 'public/assets/icons/facebook_icon.png',
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _socialButton({
    required String label,
    required String assetPath,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textDark,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(assetPath, height: 22, width: 22),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSignUpPrompt() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Don't have an account? ",
            style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textGrey,
              fontSize: 14,
            ),
          ),
          GestureDetector(
            onTap: widget.onSignUp,
            child: const Text(
              'Sign up',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
