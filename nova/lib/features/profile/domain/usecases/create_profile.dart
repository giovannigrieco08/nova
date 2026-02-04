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
/// - `username` is required (chosen by user, 3-20 chars, no spaces, globally unique)
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
    required String username,
    String? classYear,
    String? avatarUrl,
    String? bio,
  }) async {
    // Validate required fields
    _validate(
      fullName: fullName,
      email: email,
      username: username,
      classYear: classYear,
    );

    // Create profile entity
    final profile = Profile(
      userId: userId,
      email: email,
      fullName: fullName.trim(),
      username: username.trim(),
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

  /// Validate profile fields
  void _validate({
    required String fullName,
    required String email,
    required String username,
    String? classYear,
  }) {
    // Validate email
    if (email.trim().isEmpty) {
      throw ValidationException('L\'email è obbligatoria');
    }

    // Validate name
    if (fullName.trim().isEmpty) {
      throw ValidationException('Il nome è obbligatorio');
    }

    if (fullName.trim().length < 2) {
      throw ValidationException('Il nome deve contenere almeno 2 caratteri');
    }

    if (fullName.trim().length > 50) {
      throw ValidationException('Il nome non può superare 50 caratteri');
    }

    // Validate username
    if (username.trim().isEmpty) {
      throw ValidationException('Lo username è obbligatorio');
    }

    if (username.contains(' ')) {
      throw ValidationException('Lo username non può contenere spazi');
    }

    if (username.trim().length < 3) {
      throw ValidationException(
          'Lo username deve contenere almeno 3 caratteri');
    }

    if (username.trim().length > 20) {
      throw ValidationException('Lo username non può superare 20 caratteri');
    }

    // Note: classYear can be null (incomplete profile / skip flow)
    // Validation for complete profile is handled by CheckProfileComplete use case
    // Note: Username uniqueness is validated by the database (unique constraint)
  }
}

/// Validation exception
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}
