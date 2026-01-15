// Repository: TutorRepository
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: Provides clean interface for tutor profile operations

import '../../domain/entities/tutor_profile.dart';
import '../../domain/entities/subject.dart';
import '../datasources/tutor_remote_datasource.dart';

/// Repository for tutor profile operations
///
/// Responsibilities:
/// - Tutor profile CRUD operations
/// - Subject-based tutor search
/// - Price filtering
/// - Profile activation/deactivation
///
/// Note: No offline caching (tutoring is read-heavy, occasional writes)
class TutorRepository {
  final TutorRemoteDataSource _remoteDataSource;

  TutorRepository(this._remoteDataSource);

  // ==========================================================================
  // READ OPERATIONS
  // ==========================================================================

  /// Get tutor profile by user ID
  /// Returns null if user is not a tutor
  Future<TutorProfile?> getTutorProfile(String userId) async {
    final model = await _remoteDataSource.getTutorProfile(userId);
    return model?.toEntity();
  }

  /// Get tutors by subject with pagination
  /// Only returns active tutors
  /// Sorted by rating (desc), then created_at (desc)
  Future<List<TutorProfileWithAuthorData>> getTutorsBySubject(
    Subject subject, {
    int offset = 0,
    int limit = 20,
  }) async {
    final models = await _remoteDataSource.getTutorsBySubject(
      subject.dbValue,
      offset: offset,
      limit: limit,
    );

    return models.map((m) => TutorProfileWithAuthorData(
      profile: m.toEntity(),
      authorName: m.authorName ?? '',
      authorAvatarUrl: m.authorAvatarUrl,
      authorClass: m.authorClass,
      authorUsername: m.authorUsername,
    )).toList();
  }

  /// Get tutors filtered by subject and price
  /// priceFilter: 'free' | '1-15' | '16-30' | null (all)
  Future<List<TutorProfileWithAuthorData>> getTutorsFiltered(
    Subject subject, {
    String? priceFilter,
    int offset = 0,
    int limit = 20,
  }) async {
    final models = await _remoteDataSource.getTutorsFiltered(
      subject.dbValue,
      priceFilter: priceFilter,
      offset: offset,
      limit: limit,
    );

    return models.map((m) => TutorProfileWithAuthorData(
      profile: m.toEntity(),
      authorName: m.authorName ?? '',
      authorAvatarUrl: m.authorAvatarUrl,
      authorClass: m.authorClass,
      authorUsername: m.authorUsername,
    )).toList();
  }

  /// Check if user is already a tutor
  Future<bool> isTutor(String userId) async {
    return await _remoteDataSource.isTutor(userId);
  }

  // ==========================================================================
  // WRITE OPERATIONS
  // ==========================================================================

  /// Create new tutor profile
  /// Throws TutorAlreadyExistsException if user already has a tutor profile
  Future<TutorProfile> createTutorProfile({
    required String userId,
    String? bio,
    required List<Subject> subjects,
    double pricePerHour = 0.0,
    List<AvailabilityDay> availabilityDays = const [],
    String? timeSlot,
    String? whatsappPhone,
    String? instagramUsername,
  }) async {
    final model = await _remoteDataSource.createTutorProfile(
      userId: userId,
      bio: bio,
      subjects: subjects.map((s) => s.dbValue).toList(),
      pricePerHour: pricePerHour,
      availabilityDays: availabilityDays.map((d) => d.dbValue).toList(),
      timeSlot: timeSlot,
      whatsappPhone: whatsappPhone,
      instagramUsername: instagramUsername,
    );

    return model.toEntity();
  }

  /// Update existing tutor profile
  Future<TutorProfile> updateTutorProfile(
    String userId, {
    String? bio,
    List<Subject>? subjects,
    double? pricePerHour,
    List<AvailabilityDay>? availabilityDays,
    String? timeSlot,
    String? whatsappPhone,
    String? instagramUsername,
  }) async {
    final model = await _remoteDataSource.updateTutorProfile(
      userId,
      bio: bio,
      subjects: subjects?.map((s) => s.dbValue).toList(),
      pricePerHour: pricePerHour,
      availabilityDays: availabilityDays?.map((d) => d.dbValue).toList(),
      timeSlot: timeSlot,
      whatsappPhone: whatsappPhone,
      instagramUsername: instagramUsername,
    );

    return model.toEntity();
  }

  /// Deactivate tutor profile (hides from public listings)
  Future<TutorProfile> deactivateTutorProfile(String userId) async {
    final model = await _remoteDataSource.deactivateTutorProfile(userId);
    return model.toEntity();
  }

  /// Reactivate tutor profile (shows in public listings)
  Future<TutorProfile> reactivateTutorProfile(String userId) async {
    final model = await _remoteDataSource.reactivateTutorProfile(userId);
    return model.toEntity();
  }

  /// Toggle tutor profile active status
  Future<TutorProfile> toggleTutorActive(String userId, bool isActive) async {
    if (isActive) {
      return reactivateTutorProfile(userId);
    } else {
      return deactivateTutorProfile(userId);
    }
  }

  /// Delete tutor profile permanently
  Future<void> deleteTutorProfile(String userId) async {
    await _remoteDataSource.deleteTutorProfile(userId);
  }
}

/// Data class combining tutor profile with author profile data
class TutorProfileWithAuthorData {
  final TutorProfile profile;
  final String authorName;
  final String? authorAvatarUrl;
  final String? authorClass;
  final String? authorUsername;

  const TutorProfileWithAuthorData({
    required this.profile,
    required this.authorName,
    this.authorAvatarUrl,
    this.authorClass,
    this.authorUsername,
  });
}
