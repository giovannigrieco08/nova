// Core Utility: Input Validators
// Feature: 002-profile-setup
// Purpose: Validation and sanitization for profile inputs (name, bio)

class Validators {
  // ============================================================================
  // NAME VALIDATION
  // ============================================================================

  /// Regex for valid names: letters (including accented), spaces, hyphens, apostrophes
  /// Allows: a-z, A-Z, accented letters (À-ž), spaces, hyphens, apostrophes
  /// Disallows: numbers, special symbols (except - and ')
  /// Length: 2-50 characters
  static final RegExp _nameRegex = RegExp(
    r"^[a-zA-Z\u00C0-\u017F\s'-]{2,50}$",
  );

  /// Validates full name
  /// Returns null if valid, error message if invalid
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Il nome è obbligatorio';
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return 'Il nome deve contenere almeno 2 caratteri';
    }

    if (trimmed.length > 50) {
      return 'Il nome non può superare 50 caratteri';
    }

    if (!_nameRegex.hasMatch(trimmed)) {
      return 'Il nome può contenere solo lettere, spazi, trattini e apostrofi';
    }

    return null; // Valid
  }

  /// Checks if name contains numbers or invalid symbols
  static bool hasInvalidCharacters(String name) {
    return !_nameRegex.hasMatch(name.trim());
  }

  // ============================================================================
  // BIO VALIDATION & SANITIZATION
  // ============================================================================

  /// HTML tag regex for stripping HTML
  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>');

  /// URL regex for removing URLs
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
  );

  /// Validates bio text
  /// Returns null if valid, error message if invalid
  static String? validateBio(String? value) {
    // Bio is optional, so null/empty is valid
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final trimmed = value.trim();

    if (trimmed.length > 150) {
      return 'La bio non può superare 150 caratteri';
    }

    // Check for HTML tags
    if (_htmlTagRegex.hasMatch(trimmed)) {
      return 'La bio non può contenere tag HTML';
    }

    // Check for URLs
    if (_urlRegex.hasMatch(trimmed)) {
      return 'La bio non può contenere link';
    }

    // Note: Character validation relaxed for MVP - emojis and unicode supported
    // Strict validation can be added later if needed

    return null; // Valid
  }

  /// Sanitizes bio text (removes HTML, URLs, trims whitespace)
  /// Used server-side as additional safety layer
  static String sanitizeBio(String bio) {
    String sanitized = bio.trim();

    // Strip HTML tags
    sanitized = sanitized.replaceAll(_htmlTagRegex, '');

    // Remove URLs
    sanitized = sanitized.replaceAll(_urlRegex, '');

    // Truncate to 150 chars if exceeded
    if (sanitized.length > 150) {
      sanitized = sanitized.substring(0, 150);
    }

    // Remove leading/trailing whitespace
    sanitized = sanitized.trim();

    return sanitized;
  }

  // ============================================================================
  // CLASS VALIDATION
  // ============================================================================

  /// Validates class selection
  /// Returns null if valid, error message if invalid
  static String? validateClass(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La classe è obbligatoria';
    }

    return null; // Valid (specific class values validated by SchoolClass enum)
  }

  // ============================================================================
  // GENERAL UTILITIES
  // ============================================================================

  /// Trims and normalizes whitespace in a string
  static String normalizeWhitespace(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Checks if string is empty or only whitespace
  static bool isEmpty(String? value) {
    return value == null || value.trim().isEmpty;
  }
}
