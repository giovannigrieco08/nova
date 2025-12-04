import '../../domain/entities/subject.dart';
import '../../domain/entities/tutor_profile.dart';

/// TutorProfileModel - Data Transfer Object
///
/// Handles JSON serialization/deserialization for Supabase API responses.
/// Maps between database schema (snake_case) and domain entity (camelCase).
///
/// Constitutional Principle 5 (SPEC_FIRST): Data layer provides implementations
/// for domain contracts. This model transforms Supabase JSON to TutorProfile entity.
class TutorProfileModel {
  final String id;
  final String userId;
  final String? bio;
  final List<String> subjects;
  final double pricePerHour;
  final List<String> availabilityDays;
  final String? timeSlot;
  final String? whatsappPhone;
  final String? instagramUsername;
  final double rating;
  final int totalReviews;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined profile data (from Supabase JOIN)
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorClass;
  final String? authorUsername;

  const TutorProfileModel({
    required this.id,
    required this.userId,
    this.bio,
    this.subjects = const [],
    this.pricePerHour = 0.0,
    this.availabilityDays = const [],
    this.timeSlot,
    this.whatsappPhone,
    this.instagramUsername,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.authorName,
    this.authorAvatarUrl,
    this.authorClass,
    this.authorUsername,
  });

  // ==========================================================================
  // JSON DESERIALIZATION (Supabase → TutorProfileModel)
  // ==========================================================================

  /// Create TutorProfileModel from Supabase JSON response
  ///
  /// Handles nested profile data from JOINs and optional fields.
  factory TutorProfileModel.fromJson(Map<String, dynamic> json) {
    return TutorProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bio: json['bio'] as String?,
      subjects: (json['subjects'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
      availabilityDays: (json['availability_days'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      timeSlot: json['time_slot'] as String?,
      whatsappPhone: json['whatsapp_phone'] as String?,
      instagramUsername: json['instagram_username'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // Profile data from JOIN (nested object 'profiles')
      authorName: _extractProfileField(json, 'full_name'),
      authorAvatarUrl: _extractProfileField(json, 'avatar_url'),
      authorClass: _extractProfileField(json, 'class'),
      authorUsername: _extractProfileField(json, 'username'),
    );
  }

  /// Helper to extract fields from nested 'profiles' object in JOIN query
  static String? _extractProfileField(Map<String, dynamic> json, String field) {
    if (json['profiles'] != null && json['profiles'] is Map) {
      return json['profiles'][field] as String?;
    }
    // Fallback to flat field name
    return json['author_$field'] as String?;
  }

  // ==========================================================================
  // JSON SERIALIZATION (TutorProfileModel → JSON)
  // ==========================================================================

  /// Convert TutorProfileModel to JSON for API requests
  ///
  /// Used for INSERT and UPDATE operations to Supabase.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'bio': bio,
      'subjects': subjects,
      'price_per_hour': pricePerHour,
      'availability_days': availabilityDays,
      'time_slot': timeSlot,
      'whatsapp_phone': whatsappPhone,
      'instagram_username': instagramUsername,
      'rating': rating,
      'total_reviews': totalReviews,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to JSON for INSERT (exclude read-only fields)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'bio': bio,
      'subjects': subjects,
      'price_per_hour': pricePerHour,
      'availability_days': availabilityDays,
      'time_slot': timeSlot,
      'whatsapp_phone': whatsappPhone,
      'instagram_username': instagramUsername,
    };
  }

  /// Convert to JSON for UPDATE (exclude id and timestamps)
  Map<String, dynamic> toUpdateJson() {
    return {
      'bio': bio,
      'subjects': subjects,
      'price_per_hour': pricePerHour,
      'availability_days': availabilityDays,
      'time_slot': timeSlot,
      'whatsapp_phone': whatsappPhone,
      'instagram_username': instagramUsername,
      'is_active': isActive,
    };
  }

  // ==========================================================================
  // DOMAIN ENTITY CONVERSION (TutorProfileModel → TutorProfile)
  // ==========================================================================

  /// Convert data model to domain entity
  ///
  /// Maps subject strings to Subject enum and availabilityDays to AvailabilityDay enum.
  TutorProfile toEntity() {
    return TutorProfile(
      id: id,
      userId: userId,
      bio: bio,
      subjects: Subject.fromDbValues(subjects),
      pricePerHour: pricePerHour,
      availabilityDays: AvailabilityDay.fromDbValues(availabilityDays),
      timeSlot: timeSlot,
      whatsappPhone: whatsappPhone,
      instagramUsername: instagramUsername,
      rating: rating,
      totalReviews: totalReviews,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // ==========================================================================
  // DOMAIN ENTITY CONVERSION (TutorProfile → TutorProfileModel)
  // ==========================================================================

  /// Create TutorProfileModel from domain entity
  ///
  /// Useful for converting entities back to models for API operations.
  factory TutorProfileModel.fromEntity(TutorProfile entity) {
    return TutorProfileModel(
      id: entity.id,
      userId: entity.userId,
      bio: entity.bio,
      subjects: entity.subjects.map((s) => s.dbValue).toList(),
      pricePerHour: entity.pricePerHour,
      availabilityDays: entity.availabilityDays.map((d) => d.dbValue).toList(),
      timeSlot: entity.timeSlot,
      whatsappPhone: entity.whatsappPhone,
      instagramUsername: entity.instagramUsername,
      rating: entity.rating,
      totalReviews: entity.totalReviews,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TutorProfileModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TutorProfileModel(id: $id, userId: $userId, subjects: $subjects)';
  }
}

/// Extended TutorProfileModel with joined profile data for display purposes.
///
/// Used when querying tutors list to include author profile information.
class TutorProfileWithAuthor extends TutorProfileModel {
  const TutorProfileWithAuthor({
    required super.id,
    required super.userId,
    super.bio,
    super.subjects,
    super.pricePerHour,
    super.availabilityDays,
    super.timeSlot,
    super.whatsappPhone,
    super.instagramUsername,
    super.rating,
    super.totalReviews,
    super.isActive,
    required super.createdAt,
    required super.updatedAt,
    super.authorName,
    super.authorAvatarUrl,
    super.authorClass,
    super.authorUsername,
  });

  factory TutorProfileWithAuthor.fromJson(Map<String, dynamic> json) {
    final base = TutorProfileModel.fromJson(json);
    return TutorProfileWithAuthor(
      id: base.id,
      userId: base.userId,
      bio: base.bio,
      subjects: base.subjects,
      pricePerHour: base.pricePerHour,
      availabilityDays: base.availabilityDays,
      timeSlot: base.timeSlot,
      whatsappPhone: base.whatsappPhone,
      instagramUsername: base.instagramUsername,
      rating: base.rating,
      totalReviews: base.totalReviews,
      isActive: base.isActive,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      authorName: base.authorName,
      authorAvatarUrl: base.authorAvatarUrl,
      authorClass: base.authorClass,
      authorUsername: base.authorUsername,
    );
  }
}
