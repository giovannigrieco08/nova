// =====================================================================
// Nova - Email Validator Utility
// =====================================================================
// Purpose: Validate email addresses
// Architecture: Static class with regex pattern matching
// =====================================================================

/// Static utility class for email validation
///
/// Accepts any valid email address format.
///
/// Usage:
/// ```dart
/// if (EmailValidator.isValid('user@example.com')) {
///   // Email is valid
/// }
///
/// final error = EmailValidator.validate('invalid-email');
/// if (error != null) {
///   // Show error message to user
/// }
/// ```
class EmailValidator {
  // Private constructor to prevent instantiation (static class)
  EmailValidator._();

  /// Regular expression for validating email addresses
  ///
  /// Pattern explanation:
  /// - ^[a-zA-Z0-9._%+-]+ : Username part
  /// - @ : Literal @ symbol
  /// - [a-zA-Z0-9.-]+ : Domain name
  /// - \. : Literal dot
  /// - [a-zA-Z]{2,} : TLD (at least 2 characters)
  /// - $ : End of string
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    caseSensitive: false,
  );

  /// Check if email is valid
  ///
  /// ⚠️ IMPORTANT: Always use [normalize] before storing emails in the database
  /// to ensure consistency (lowercase, trimmed).
  ///
  /// Returns:
  /// - `true` if email is valid
  /// - `false` otherwise
  ///
  /// Example usage:
  /// ```dart
  /// if (EmailValidator.isValid(email)) {
  ///   final normalizedEmail = EmailValidator.normalize(email);
  ///   await repository.saveEmail(normalizedEmail);
  /// }
  /// ```
  ///
  /// Examples:
  /// ```dart
  /// EmailValidator.isValid('user@example.com')  // true
  /// EmailValidator.isValid('test@gmail.com')    // true
  /// EmailValidator.isValid('invalid-email')     // false
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
  /// ⚠️ IMPORTANT: Always use [normalize] before storing emails in the database
  /// to ensure consistency (lowercase, trimmed).
  ///
  /// Returns:
  /// - `null` if email is valid
  /// - Error message string if invalid
  ///
  /// Example with normalization:
  /// ```dart
  /// final error = EmailValidator.validate(email);
  /// if (error == null) {
  ///   final normalizedEmail = EmailValidator.normalize(email);
  ///   await repository.saveEmail(normalizedEmail);
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

    // Check if email matches a valid pattern
    if (!isValid(trimmedEmail)) {
      return 'Please enter a valid email address';
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
