// Use Case: CreateProfile
// Feature: 002-profile-setup
// Purpose: Create new user profile (first-time setup)

import '../entities/profile.dart';
import '../../data/repositories/profile_repository.dart';

/// Use case for creating a new profile during first-time setup
///
/// **Business Rules**:
/// - `fullName` is required (minimum 2 characters)
/// - `classValue` is required for complete profile
/// - If `classValue` is null, profile is incomplete (skip flow)
/// - Avatar, pronouns, and bio are optional
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
    required String fullName,
    String? classValue,
    String? pronouns,
    String? avatarUrl,
    String? bio,
  }) async {
    // Validate required fields
    _validate(fullName: fullName, classValue: classValue);

    // Create profile entity
    final profile = Profile(
      userId: userId,
      fullName: fullName.trim(),
      classValue: classValue,
      pronouns: pronouns,
      avatarUrl: avatarUrl,
      bio: bio?.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Create via repository
    return await _repository.createProfile(profile);
  }

  /// Validate profile fields
  void _validate({
    required String fullName,
    String? classValue,
  }) {
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

    // Note: classValue can be null (incomplete profile / skip flow)
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
