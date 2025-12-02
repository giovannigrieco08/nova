// Use Case: CreateProfile
// Feature: 006-user-profile
// Purpose: Create new user profile (first-time setup)

import '../entities/profile.dart';
import '../../data/repositories/profile_repository.dart';

/// Use case for creating a new profile during first-time setup
///
/// **Business Rules**:
/// - `fullName` is required (minimum 2 characters)
/// - `email` is required (auto-populated from auth)
/// - `username` is auto-generated from email (nome.cognome format)
/// - `classYear` is required for complete profile
/// - If `classYear` is null, profile is incomplete (skip flow)
/// - Avatar and bio are optional
class CreateProfile {
  final ProfileRepository _repository;

  CreateProfile(this._repository);

  /// Execute the use case
  ///
  /// Validates required fields and creates profile in repository
  ///
  /// Throws:
  /// - [ValidationException] if validation fails
  /// - [ProfileAlreadyExistsException] if profile already exists
  /// - [OfflineModeException] if offline (profile queued for sync)
  Future<Profile> call({
    required String userId,
    required String email,
    required String fullName,
    String? classYear,
    String? avatarUrl,
    String? bio,
  }) async {
    // Validate required fields
    _validate(fullName: fullName, email: email, classYear: classYear);

    // Generate username from email (nome.cognome@galileimoro.edu.it → nome.cognome)
    final username = _generateUsername(email);

    // Create profile entity
    final profile = Profile(
      userId: userId,
      email: email,
      fullName: fullName.trim(),
      username: username,
      classYear: classYear,
      avatarUrl: avatarUrl,
      bio: bio?.trim(),
      role: 'student', // Default role
      profileVisible: true, // Default visibility
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      deletedAt: null,
    );

    // Create via repository
    return await _repository.createProfile(profile);
  }

  /// Generate username from email
  /// e.g., "marco.rossi@galileimoro.edu.it" → "marco.rossi"
  String _generateUsername(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex > 0) {
      return email.substring(0, atIndex).toLowerCase();
    }
    return email.toLowerCase();
  }

  /// Validate profile fields
  void _validate({
    required String fullName,
    required String email,
    String? classYear,
  }) {
    // Validate email
    if (email.trim().isEmpty) {
      throw ValidationException('L\'email è obbligatoria');
    }

    if (!email.endsWith('@galileimoro.edu.it')) {
      throw ValidationException('Devi usare l\'email della scuola (@galileimoro.edu.it)');
    }

    // Validate name
    if (fullName.trim().isEmpty) {
      throw ValidationException('Il nome è obbligatorio');
    }

    if (fullName.trim().length < 2) {
      throw ValidationException(
          'Il nome deve contenere almeno 2 caratteri');
    }

    if (fullName.trim().length > 50) {
      throw ValidationException('Il nome non può superare 50 caratteri');
    }

    // Note: classYear can be null (incomplete profile / skip flow)
    // Validation for complete profile is handled by CheckProfileComplete use case
  }
}

/// Validation exception
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}
