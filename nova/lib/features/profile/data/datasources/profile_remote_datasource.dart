// Data Source: ProfileRemoteDataSource
// Feature: 002-profile-setup
// Purpose: Supabase REST API integration for profile operations

import 'dart:async';
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

      // Fetch user role from user_roles table (separate query since profiles doesn't have role column)
      final roleData = await _getUserRole(userId);

      // Merge role into profile data
      final profileWithRole = Map<String, dynamic>.from(response);
      profileWithRole['role'] = roleData;

      return ProfileModel.fromJson(profileWithRole);
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

      // Fetch user role from user_roles table
      final roleData = await _getUserRole(userId);

      // Merge role into profile data
      final profileWithRole = Map<String, dynamic>.from(response);
      profileWithRole['role'] = roleData;

      return ProfileModel.fromJson(profileWithRole);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw ProfileNotFoundException('Profile not found for user $userId');
      }
      rethrow;
    }
  }

  /// Get user's highest role from user_roles table
  /// Returns 'admin' > 'moderator' > 'student' (hierarchy)
  Future<String> _getUserRole(String userId) async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', userId);

      final rolesList = response as List;
      if (rolesList.isEmpty) {
        return 'student'; // Default role
      }

      // Get highest role (admin > moderator > student)
      final roles = rolesList.map((r) => r['role'] as String).toList();

      if (roles.contains('admin')) {
        return 'admin';
      } else if (roles.contains('moderator')) {
        return 'moderator';
      }
      return 'student';
    } catch (e) {
      // On error, default to student
      return 'student';
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

  /// Check if username is available (case-insensitive)
  /// Returns true if username is available, false if already taken
  Future<bool> isUsernameAvailable(String username) async {
    final result = await _supabase.rpc(
      'check_username_available',
      params: {'p_username': username},
    );

    return result as bool;
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

  /// Watch for changes that affect profile stats (events created, participations)
  /// Returns a stream that emits whenever relevant changes occur
  Stream<void> watchStatsChanges(String userId) {
    // Merge streams from events table (created_by) and event_participants table (user_id)
    final eventsChannel = _supabase
        .channel('events_stats_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'created_by',
            value: userId,
          ),
          callback: (_) {},
        )
        .subscribe();

    final participantsChannel = _supabase
        .channel('participants_stats_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'participations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) {},
        )
        .subscribe();

    // Create a combined stream controller
    final controller = StreamController<void>.broadcast();

    // Set up listeners on both channels
    _supabase.channel('events_stats_$userId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'events',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'creator_id',
        value: userId,
      ),
      callback: (_) => controller.add(null),
    );

    _supabase.channel('participants_stats_$userId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'participations',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) => controller.add(null),
    );

    controller.onCancel = () {
      _supabase.removeChannel(eventsChannel);
      _supabase.removeChannel(participantsChannel);
    };

    return controller.stream;
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