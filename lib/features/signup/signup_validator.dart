/// Pure, side-effect-free validation for the sign-up form.
///
/// Knows nothing about Supabase or the UI — it just takes the raw field
/// values and reports which ones fail and why. The service layer calls this
/// first; the card renders the returned per-field messages inline.
library;

/// Field keys used in [SignUpValidationResult.fieldErrors] so the UI and the
/// validator agree on names without relying on loose strings.
class SignUpField {
  const SignUpField._();

  static const String firstName = 'firstName';
  static const String lastName = 'lastName';
  static const String email = 'email';
  static const String password = 'password';
  static const String confirmPassword = 'confirmPassword';
}

/// Outcome of validating the whole form.
class SignUpValidationResult {
  const SignUpValidationResult(this.fieldErrors);

  /// Map of [SignUpField] -> human-readable error. Empty when everything is
  /// valid.
  final Map<String, String> fieldErrors;

  bool get isValid => fieldErrors.isEmpty;
}

class SignUpValidator {
  const SignUpValidator._();

  // Names: letters (incl. accented), spaces, hyphens and apostrophes.
  static final RegExp _namePattern = RegExp(r"^[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ' -]*$");
  // Pragmatic email shape check (not a full RFC validator).
  static final RegExp _emailPattern =
      RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static const int _nameMax = 50;
  static const int _passwordMin = 8;
  static const int _passwordMax = 25;

  /// Validates every field and returns the combined result.
  static SignUpValidationResult validate({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    final errors = <String, String>{};

    final firstNameError = validateName(firstName, label: 'First name');
    if (firstNameError != null) errors[SignUpField.firstName] = firstNameError;

    final lastNameError = validateName(lastName, label: 'Last name');
    if (lastNameError != null) errors[SignUpField.lastName] = lastNameError;

    final emailError = validateEmail(email);
    if (emailError != null) errors[SignUpField.email] = emailError;

    final passwordError = validatePassword(password);
    if (passwordError != null) errors[SignUpField.password] = passwordError;

    final confirmError = validateConfirmPassword(password, confirmPassword);
    if (confirmError != null) {
      errors[SignUpField.confirmPassword] = confirmError;
    }

    return SignUpValidationResult(errors);
  }

  /// Returns an error message, or null when the name is valid.
  static String? validateName(String value, {required String label}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '$label is required';
    if (trimmed.length > _nameMax) {
      return '$label must be $_nameMax characters or fewer';
    }
    if (!_namePattern.hasMatch(trimmed)) {
      return '$label can only contain letters, spaces, - and \'';
    }
    return null;
  }

  static String? validateEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Email is required';
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Mirrors the live requirement checklist shown on the sign-up card:
  /// 8–25 chars, at least one upper/lower/number/special, and no spaces.
  static String? validatePassword(String value) {
    if (value.isEmpty) return 'Password is required';
    if (value.contains(RegExp(r'\s'))) return 'Password cannot contain spaces';
    if (value.length < _passwordMin || value.length > _passwordMax) {
      return 'Password must be $_passwordMin–$_passwordMax characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Add at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Add at least one lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Add at least one number';
    }
    if (!value.contains(RegExp(r'[^A-Za-z0-9\s]'))) {
      return 'Add at least one special character';
    }
    return null;
  }

  static String? validateConfirmPassword(String password, String confirm) {
    if (confirm.isEmpty) return 'Please confirm your password';
    if (password != confirm) return 'Passwords do not match';
    return null;
  }
}
