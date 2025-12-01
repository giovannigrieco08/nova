// Data Source: ProfileRemoteDataSource
// Feature: 002-profile-setup
// Purpose: Supabase REST API integration for profile operations

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../../domain/entities/profile_stats.dart';

/// Remote data source for profile operations using Supabase
class ProfileRemoteDataSource {
  final SupabaseClient _supabase;

  ProfileRemoteDataSource(this._supabase);

  /// Get current user's profile
  /// Throws [PostgrestException] on error
  Future<ProfileModel> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      return ProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // No rows returned - profile doesn't exist
        throw ProfileNotFoundException('Profile not found for user $userId');
      }
      rethrow;
    }
  }

  /// Get another user's profile (for viewing event creators, comments, etc.)
  /// Requires authenticated @galileimoro.edu.it student
  /// Throws [PostgrestException] on error
  Future<ProfileModel> getProfileById(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      return ProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw ProfileNotFoundException('Profile not found for user $userId');
      }
      rethrow;
    }
  }

  /// Create new profile (first-time setup)
  /// Throws [PostgrestException] on error (e.g., duplicate key if profile already exists)
  Future<ProfileModel> createProfile(ProfileModel profile) async {
    try {
      final response = await _supabase
          .from('profiles')
          .insert(profile.toJson())
          .select()
          .single();

      return ProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Unique constraint violation - profile already exists
        throw ProfileAlreadyExistsException(
            'Profile already exists for user ${profile.userId}');
      }
      rethrow;
    }
  }

  /// Update existing profile (partial updates supported)
  /// Only sends changed fields to minimize bandwidth
  /// Throws [PostgrestException] on error
  Future<ProfileModel> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _supabase
          .from('profiles')
          .update(updates)
          .eq('user_id', userId)
          .select()
          .single();

      return ProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw ProfileNotFoundException('Profile not found for user $userId');
      }
      rethrow;
    }
  }

  /// Delete profile (GDPR Right to Erasure)
  /// Cascade deletes handled by database (ON DELETE CASCADE)
  /// Throws [PostgrestException] on error
  Future<void> deleteProfile(String userId) async {
    await _supabase.from('profiles').delete().eq('user_id', userId);
  }

  /// Check if profile is complete (has class)
  /// Uses Supabase RPC function
  Future<bool> isProfileComplete(String userId) async {
    final result = await _supabase.rpc(
      'is_profile_complete',
      params: {'p_user_id': userId},
    );

    return result as bool;
  }

  /// Parse name from email using Supabase RPC function
  /// Example: "giovanni.rossi@galileimoro.edu.it" → "Giovanni Rossi"
  /// Returns null if email format is not firstname.lastname
  Future<String?> parseNameFromEmail(String email) async {
    final result = await _supabase.rpc(
      'parse_name_from_email',
      params: {'email': email},
    );

    return result as String?;
  }

  /// Get profile statistics (events created, participations)
  /// Uses Supabase RPC function
  Future<ProfileStats> getProfileStats(String userId) async {
    try {
      final result = await _supabase.rpc(
        'get_profile_stats',
        params: {'p_user_id': userId},
      );

      if (result == null || (result as List).isEmpty) {
        return ProfileStats.empty();
      }

      return ProfileStats.fromJson(result[0] as Map<String, dynamic>);
    } catch (e) {
      // Return empty stats on error
      return ProfileStats.empty();
    }
  }
}

/// Custom exceptions for better error handling

class ProfileNotFoundException implements Exception {
  final String message;
  ProfileNotFoundException(this.message);

  @override
  String toString() => 'ProfileNotFoundException: $message';
}

class ProfileAlreadyExistsException implements Exception {
  final String message;
  ProfileAlreadyExistsException(this.message);

  @override
  String toString() => 'ProfileAlreadyExistsException: $message';
}