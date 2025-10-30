// =====================================================================
// Nova - Email Validator Utility
// =====================================================================
// Purpose: Validate email addresses for @galileimoro.edu.it domain
// Architecture: Static class with regex pattern matching
// =====================================================================

/// Static utility class for email validation
///
/// Validates that email addresses:
/// - Match standard email format
/// - Use the @galileimoro.edu.it domain only
///
/// Usage:
/// ```dart
/// if (EmailValidator.isValid('student@galileimoro.edu.it')) {
///   // Email is valid
/// }
///
/// final error = EmailValidator.validate('invalid@gmail.com');
/// if (error != null) {
///   // Show error message to user
/// }
/// ```
class EmailValidator {
  // Private constructor to prevent instantiation (static class)
  EmailValidator._();

  /// Regular expression for validating @galileimoro.edu.it emails
  ///
  /// Pattern explanation:
  /// - ^[a-zA-Z0-9._%+-]+ : One or more alphanumeric chars or ._%+-
  /// - @ : Literal @ symbol
  /// - galileimoro\.edu\.it : Exact domain match (escaped dots)
  /// - $ : End of string
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@galileimoro\.edu\.it$',
    caseSensitive: false,
  );

  /// Check if email is valid
  ///
  /// Returns:
  /// - `true` if email matches @galileimoro.edu.it pattern
  /// - `false` otherwise
  ///
  /// Example:
  /// ```dart
  /// EmailValidator.isValid('student@galileimoro.edu.it') // true
  /// EmailValidator.isValid('student@gmail.com')          // false
  /// EmailValidator.isValid('invalid-email')              // false
  /// ```
  static bool isValid(String? email) {
    if (email == null || email.isEmpty) {
      return false;
    }

    final trimmedEmail = email.trim().toLowerCase();
    return _emailRegex.hasMatch(trimmedEmail);
  }

  /// Validate email and return error message if invalid
  ///
  /// Returns:
  /// - `null` if email is valid
  /// - Error message string if invalid
  ///
  /// Example:
  /// ```dart
  /// final error = EmailValidator.validate('student@galileimoro.edu.it');
  /// if (error != null) {
  ///   showError(error); // Won't execute - email is valid
  /// }
  ///
  /// final error2 = EmailValidator.validate('student@gmail.com');
  /// if (error2 != null) {
  ///   showError(error2); // Shows: "Please use your school email..."
  /// }
  /// ```
  static String? validate(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email address is required';
    }

    final trimmedEmail = email.trim();

    // Check if email contains @ symbol
    if (!trimmedEmail.contains('@')) {
      return 'Please enter a valid email address';
    }

    // Check if email matches the school domain pattern
    if (!isValid(trimmedEmail)) {
      return 'Please use your school email address (@galileimoro.edu.it)';
    }

    return null; // Email is valid
  }

  /// Normalize email address (trim and lowercase)
  ///
  /// Returns normalized email string
  ///
  /// Example:
  /// ```dart
  /// EmailValidator.normalize('  Student@GALILEIMORO.edu.it  ')
  /// // Returns: 'student@galileimoro.edu.it'
  /// ```
  static String normalize(String email) {
    return email.trim().toLowerCase();
  }
}
