// =====================================================================
// Nova - Email Validator Utility
// =====================================================================
// Purpose: Validate email addresses for @galileimoro.edu.it domain
// Architecture: Static class with regex pattern matching
// =====================================================================

import 'package:flutter/foundation.dart';

/// Static utility class for email validation
///
/// Development Mode:
/// - When isDevelopment = true, accepts any valid email
/// - Used for testing with personal emails (Gmail, Outlook, etc.)
///
/// Production Mode:
/// - When isDevelopment = false, accepts only @galileimoro.edu.it
/// - Enforces school email requirement
///
/// Usage:
/// ```dart
/// if (EmailValidator.isValid('student@galileimoro.edu.it')) {
///   // Email is valid
/// }
///
/// final error = EmailValidator.validate('test@gmail.com');
/// if (error != null) {
///   // Show error message to user
/// }
/// ```
class EmailValidator {
  // Private constructor to prevent instantiation (static class)
  EmailValidator._();

  /// Development mode flag (auto-detected from build mode)
  ///
  /// Automatically set based on Flutter build mode:
  /// - DEBUG builds: true (accepts any valid email for testing)
  /// - RELEASE builds: false (only @galileimoro.edu.it accepted)
  ///
  /// Uses kDebugMode from package:flutter/foundation.dart
  /// This prevents accidentally deploying with development mode enabled.
  static final bool isDevelopment = kDebugMode;

  /// TEMPORARY: Force allow personal emails even in release builds
  ///
  /// ⚠️ WARNING: Set this to false before deploying to production!
  /// This flag allows testing with personal emails (Gmail, etc.) in release APKs.
  ///
  /// Usage: Set to true for testing, false for production deployment.
  static const bool forceAllowPersonalEmails = true;

  /// Regular expression for validating @galileimoro.edu.it emails
  ///
  /// Pattern explanation:
  /// - ^[a-zA-Z0-9._%+-]+ : One or more alphanumeric chars or ._%+-
  /// - @ : Literal @ symbol
  /// - galileimoro\.edu\.it : Exact domain match (escaped dots)
  /// - $ : End of string
  static final RegExp _schoolEmailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@galileimoro\.edu\.it$',
    caseSensitive: false,
  );

  /// Regular expression for validating any email address
  ///
  /// Used in development mode to accept personal emails for testing
  ///
  /// Pattern explanation:
  /// - ^[a-zA-Z0-9._%+-]+ : Username part
  /// - @ : Literal @ symbol
  /// - [a-zA-Z0-9.-]+ : Domain name
  /// - \. : Literal dot
  /// - [a-zA-Z]{2,} : TLD (at least 2 characters)
  /// - $ : End of string
  static final RegExp _genericEmailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    caseSensitive: false,
  );

  /// Check if email is valid
  ///
  /// ⚠️ IMPORTANT: Always use [normalize] before storing emails in the database
  /// to ensure consistency (lowercase, trimmed).
  ///
  /// Returns:
  /// - `true` if email is valid (depends on isDevelopment mode)
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
  /// Development mode (isDevelopment = true):
  /// ```dart
  /// EmailValidator.isValid('student@galileimoro.edu.it') // true
  /// EmailValidator.isValid('test@gmail.com')              // true
  /// EmailValidator.isValid('invalid-email')               // false
  /// ```
  ///
  /// Production mode (isDevelopment = false):
  /// ```dart
  /// EmailValidator.isValid('student@galileimoro.edu.it') // true
  /// EmailValidator.isValid('test@gmail.com')              // false
  /// EmailValidator.isValid('invalid-email')               // false
  /// ```
  static bool isValid(String? email) {
    if (email == null || email.isEmpty) {
      return false;
    }

    final trimmedEmail = email.trim().toLowerCase();

    // In development: accept any valid email
    // In production: only @galileimoro.edu.it
    if (isDevelopment || forceAllowPersonalEmails) {
      return _genericEmailRegex.hasMatch(trimmedEmail);
    } else {
      return _schoolEmailRegex.hasMatch(trimmedEmail);
    }
  }

  /// Validate email and return error message if invalid
  ///
  /// ⚠️ IMPORTANT: Always use [normalize] before storing emails in the database
  /// to ensure consistency (lowercase, trimmed).
  ///
  /// Returns:
  /// - `null` if email is valid
  /// - Error message string if invalid (depends on isDevelopment mode)
  ///
  /// Example with normalization:
  /// ```dart
  /// final error = EmailValidator.validate(email);
  /// if (error == null) {
  ///   final normalizedEmail = EmailValidator.normalize(email);
  ///   await repository.saveEmail(normalizedEmail);
  /// }
  /// ```
  ///
  /// Development mode example:
  /// ```dart
  /// final error = EmailValidator.validate('test@gmail.com');
  /// if (error != null) {
  ///   showError(error); // Won't execute - email is valid in dev mode
  /// }
  /// ```
  ///
  /// Production mode example:
  /// ```dart
  /// final error = EmailValidator.validate('test@gmail.com');
  /// if (error != null) {
  ///   showError(error); // Shows: "Please use your school email..."
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

    // Check if email matches the pattern (school or generic, depends on mode)
    if (!isValid(trimmedEmail)) {
      if (isDevelopment || forceAllowPersonalEmails) {
        return 'Please enter a valid email address';
      } else {
        return 'Please use your school email address (@galileimoro.edu.it)';
      }
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
