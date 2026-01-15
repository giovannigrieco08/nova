// Data Source: TutorRemoteDataSource
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: Supabase REST API integration for peer-to-peer tutoring system

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tutor_profile_model.dart';

/// Remote data source for tutor profile operations using Supabase
///
/// Database schema: supabase/migrations/013_tutor_profiles.sql
/// RLS policies:
/// - Active profiles publicly readable
/// - Owner can read/write their own profile (even if inactive)
class TutorRemoteDataSource {
  final SupabaseClient _supabase;

  TutorRemoteDataSource(this._supabase);

  // ==========================================================================
  // READ OPERATIONS
  // ==========================================================================

  /// Get tutor profile by user ID
  /// Returns null if user is not a tutor
  Future<TutorProfileModel?> getTutorProfile(String userId) async {
    try {
      final response = await _supabase
          .from('tutor_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return TutorProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return null; // No profile found
      }
      rethrow;
    }
  }

  /// Get tutors by subject with joined profile data
  /// Only returns active tutors (RLS enforced)
  /// Sorted by rating (desc), then created_at (desc)
  Future<List<TutorProfileWithAuthor>> getTutorsBySubject(
    String subject, {
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from('tutor_profiles')
          .select('''
            *,
            profiles:user_id (
              full_name,
              avatar_url,
              class,
              username
            )
          ''')
          .contains('subjects', [subject])
          .eq('is_active', true)
          .order('rating', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => TutorProfileWithAuthor.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw TutorQueryException('Failed to fetch tutors for $subject: ${e.message}');
    }
  }

  /// Get tutors filtered by price range
  /// priceFilter: 'free' | '1-15' | '16-30' | null (all)
  Future<List<TutorProfileWithAuthor>> getTutorsFiltered(
    String subject, {
    String? priceFilter,
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      var query = _supabase
          .from('tutor_profiles')
          .select('''
            *,
            profiles:user_id (
              full_name,
              avatar_url,
              class,
              username
            )
          ''')
          .contains('subjects', [subject])
          .eq('is_active', true);

      // Apply price filter
      if (priceFilter == 'free') {
        query = query.eq('price_per_hour', 0);
      } else if (priceFilter == '1-15') {
        query = query.gte('price_per_hour', 1).lte('price_per_hour', 15);
      } else if (priceFilter == '16-30') {
        query = query.gte('price_per_hour', 16).lte('price_per_hour', 30);
      }

      final response = await query
          .order('rating', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => TutorProfileWithAuthor.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw TutorQueryException('Failed to fetch filtered tutors: ${e.message}');
    }
  }

  /// Check if user is already a tutor
  Future<bool> isTutor(String userId) async {
    final profile = await getTutorProfile(userId);
    return profile != null;
  }

  // ==========================================================================
  // WRITE OPERATIONS
  // ==========================================================================

  /// Create new tutor profile
  /// Throws TutorAlreadyExistsException if user already has a tutor profile
  Future<TutorProfileModel> createTutorProfile({
    required String userId,
    String? bio,
    required List<String> subjects,
    double pricePerHour = 0.0,
    List<String> availabilityDays = const [],
    String? timeSlot,
    String? whatsappPhone,
    String? instagramUsername,
  }) async {
    try {
      final insertData = {
        'user_id': userId,
        'bio': bio,
        'subjects': subjects,
        'price_per_hour': pricePerHour,
        'availability_days': availabilityDays,
        'time_slot': timeSlot,
        'whatsapp_phone': whatsappPhone,
        'instagram_username': instagramUsername,
      };

      final response = await _supabase
          .from('tutor_profiles')
          .insert(insertData)
          .select()
          .single();

      return TutorProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw TutorAlreadyExistsException('Hai già un profilo tutor');
      }
      if (e.code == '23514') {
        // Check constraint violation
        if (e.message.contains('contact_required') == true) {
          throw TutorValidationException('Inserisci almeno un contatto');
        }
        if (e.message.contains('bio') == true) {
          throw TutorValidationException('La bio non può superare 200 caratteri');
        }
        if (e.message.contains('subjects') == true) {
          throw TutorValidationException('Seleziona da 1 a 5 materie');
        }
      }
      rethrow;
    }
  }

  /// Update existing tutor profile
  Future<TutorProfileModel> updateTutorProfile(
    String userId, {
    String? bio,
    List<String>? subjects,
    double? pricePerHour,
    List<String>? availabilityDays,
    String? timeSlot,
    String? whatsappPhone,
    String? instagramUsername,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (bio != null) updates['bio'] = bio;
      if (subjects != null) updates['subjects'] = subjects;
      if (pricePerHour != null) updates['price_per_hour'] = pricePerHour;
      if (availabilityDays != null) updates['availability_days'] = availabilityDays;
      if (timeSlot != null) updates['time_slot'] = timeSlot;
      if (whatsappPhone != null) updates['whatsapp_phone'] = whatsappPhone;
      if (instagramUsername != null) updates['instagram_username'] = instagramUsername;
      if (isActive != null) updates['is_active'] = isActive;

      final response = await _supabase
          .from('tutor_profiles')
          .update(updates)
          .eq('user_id', userId)
          .select()
          .single();

      return TutorProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw TutorNotFoundException('Profilo tutor non trovato');
      }
      if (e.code == '23514') {
        // Check constraint violation
        if (e.message.contains('contact_required') == true) {
          throw TutorValidationException('Inserisci almeno un contatto');
        }
      }
      rethrow;
    }
  }

  /// Deactivate tutor profile (hides from public listings)
  Future<TutorProfileModel> deactivateTutorProfile(String userId) async {
    return updateTutorProfile(userId, isActive: false);
  }

  /// Reactivate tutor profile (shows in public listings)
  Future<TutorProfileModel> reactivateTutorProfile(String userId) async {
    return updateTutorProfile(userId, isActive: true);
  }

  /// Delete tutor profile permanently
  Future<void> deleteTutorProfile(String userId) async {
    try {
      await _supabase
          .from('tutor_profiles')
          .delete()
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw TutorDeletionException('Impossibile eliminare il profilo tutor: ${e.message}');
    }
  }
}

// ==========================================================================
// CUSTOM EXCEPTIONS
// ==========================================================================

class TutorNotFoundException implements Exception {
  final String message;
  TutorNotFoundException(this.message);

  @override
  String toString() => 'TutorNotFoundException: $message';
}

class TutorAlreadyExistsException implements Exception {
  final String message;
  TutorAlreadyExistsException(this.message);

  @override
  String toString() => 'TutorAlreadyExistsException: $message';
}

class TutorValidationException implements Exception {
  final String message;
  TutorValidationException(this.message);

  @override
  String toString() => 'TutorValidationException: $message';
}

class TutorQueryException implements Exception {
  final String message;
  TutorQueryException(this.message);

  @override
  String toString() => 'TutorQueryException: $message';
}

class TutorDeletionException implements Exception {
  final String message;
  TutorDeletionException(this.message);

  @override
  String toString() => 'TutorDeletionException: $message';
}
