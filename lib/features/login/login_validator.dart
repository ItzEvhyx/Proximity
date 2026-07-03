/// Field keys shared between the login validator and the login card.
class LoginField {
  const LoginField._();

  static const String email = 'email';
  static const String password = 'password';
}

class LoginValidationResult {
  const LoginValidationResult(this.fieldErrors);

  final Map<String, String> fieldErrors;

  bool get isValid => fieldErrors.isEmpty;
}

/// Lightweight validation for the login form. Unlike sign-up, login only
/// checks that the inputs are present and the email is well-formed — the
/// credentials themselves are verified by Supabase.
class LoginValidator {
  const LoginValidator._();

  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static LoginValidationResult validate({
    required String email,
    required String password,
  }) {
    final errors = <String, String>{};

    final emailError = validateEmail(email);
    if (emailError != null) errors[LoginField.email] = emailError;

    final passwordError = validatePassword(password);
    if (passwordError != null) errors[LoginField.password] = passwordError;

    return LoginValidationResult(errors);
  }

  static String? validateEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Email is required';
    if (!_emailPattern.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  static String? validatePassword(String value) {
    if (value.isEmpty) return 'Password is required';
    return null;
  }
}
