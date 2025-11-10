// Data Source: EventRemoteDataSource
// Feature: 004-event-creation-moderation
// Purpose: Supabase REST API client for event operations
//
// All queries respect Row-Level Security (RLS) policies defined in migration 005.
// Supabase client automatically includes auth token in headers.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import '../../domain/entities/event.dart';

/// Remote data source for event operations via Supabase REST API
class EventRemoteDataSource {
  final SupabaseClient _supabase;

  EventRemoteDataSource(this._supabase);

  // =========================================================================
  // READ OPERATIONS
  // =========================================================================

  /// Fetch approved upcoming events for feed
  ///
  /// RLS: users_view_approved_upcoming_events policy
  Future<List<EventModel>> getApprovedEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('status', 'approved')
          .gte('event_date', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => EventModel.fromJson(json))
          .toList();
    } catch (e) {
      throw RemoteDataSourceException('Failed to fetch approved events: $e');
    }
  }

  /// Fetch events created by user (any status)
  ///
  /// RLS: creators_view_own_events policy
  Future<List<EventModel>> getMyEvents(String userId) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('creator_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => EventModel.fromJson(json))
          .toList();
    } catch (e) {
      throw RemoteDataSourceException('Failed to fetch my events: $e');
    }
  }

  /// Fetch pending events for moderation (moderators only)
  ///
  /// RLS: moderators_view_all_events policy (requires is_moderator() = true)
  Future<List<EventModel>> getPendingEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: true); // FIFO ordering

      return (response as List)
          .map((json) => EventModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // RLS policy violation - user is not a moderator
        throw RemoteDataSourceException('Access denied: not a moderator');
      }
      throw RemoteDataSourceException('Failed to fetch pending events: $e');
    } catch (e) {
      throw RemoteDataSourceException('Failed to fetch pending events: $e');
    }
  }

  /// Fetch events where user is co-organizer
  ///
  /// RLS: coorganizers_view_events policy
  Future<List<EventModel>> getCoOrganizedEvents(String userId) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .contains('co_organizers', [userId])
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => EventModel.fromJson(json))
          .toList();
    } catch (e) {
      throw RemoteDataSourceException('Failed to fetch co-organized events: $e');
    }
  }

  /// Fetch single event by ID
  ///
  /// RLS: Multiple policies (creator, co-organizer, moderator, or approved)
  Future<EventModel?> getEventById(String eventId) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('id', eventId)
          .maybeSingle();

      if (response == null) return null;
      return EventModel.fromJson(response);
    } catch (e) {
      throw RemoteDataSourceException('Failed to fetch event by ID: $e');
    }
  }

  // =========================================================================
  // WRITE OPERATIONS
  // =========================================================================

  /// Create new event (status defaults to 'pending')
  ///
  /// RLS: users_create_events policy
  Future<EventModel> createEvent(EventModel event) async {
    try {
      final response = await _supabase
          .from('events')
          .insert(event.toJson())
          .select()
          .single();

      return EventModel.fromJson(response);
    } catch (e) {
      throw RemoteDataSourceException('Failed to create event: $e');
    }
  }

  /// Update existing event
  ///
  /// RLS: coorganizers_update_events policy
  /// Trigger: revert_status_on_content_change may reset status to 'pending'
  Future<EventModel> updateEvent(
    String eventId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _supabase
          .from('events')
          .update(updates)
          .eq('id', eventId)
          .select()
          .single();

      return EventModel.fromJson(response);
    } catch (e) {
      throw RemoteDataSourceException('Failed to update event: $e');
    }
  }

  /// Delete event
  ///
  /// RLS: users_delete_own_events policy
  Future<void> deleteEvent(String eventId) async {
    try {
      await _supabase.from('events').delete().eq('id', eventId);
    } catch (e) {
      throw RemoteDataSourceException('Failed to delete event: $e');
    }
  }

  // =========================================================================
  // MODERATION OPERATIONS
  // =========================================================================

  /// Approve event (moderators only)
  ///
  /// RLS: moderators_update_event_status policy
  Future<void> approveEvent(String eventId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw RemoteDataSourceException('User not authenticated');

      await _supabase.from('events').update({
        'status': 'approved',
        'moderated_by': userId,
        'moderated_at': DateTime.now().toIso8601String(),
        'rejection_reason': null, // Clear rejection reason if re-approving
      }).eq('id', eventId);
    } catch (e) {
      throw RemoteDataSourceException('Failed to approve event: $e');
    }
  }

  /// Reject event with reason (moderators only)
  ///
  /// RLS: moderators_update_event_status policy
  Future<void> rejectEvent(String eventId, String rejectionReason) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw RemoteDataSourceException('User not authenticated');

      // Validate rejection reason (min 10 chars)
      if (rejectionReason.trim().length < 10) {
        throw RemoteDataSourceException(
          'Rejection reason must be at least 10 characters',
        );
      }

      await _supabase.from('events').update({
        'status': 'rejected',
        'rejection_reason': rejectionReason,
        'moderated_by': userId,
        'moderated_at': DateTime.now().toIso8601String(),
      }).eq('id', eventId);
    } catch (e) {
      throw RemoteDataSourceException('Failed to reject event: $e');
    }
  }

  // =========================================================================
  // CO-ORGANIZER OPERATIONS
  // =========================================================================

  /// Add co-organizer (creator only, max 3 total)
  Future<void> addCoOrganizer(String eventId, String coOrganizerId) async {
    try {
      // Fetch current event to get existing co-organizers
      final event = await getEventById(eventId);
      if (event == null) {
        throw RemoteDataSourceException('Event not found');
      }

      // Validate max 3 co-organizers
      if (event.coOrganizers.length >= 3) {
        throw RemoteDataSourceException('Maximum 3 co-organizers allowed');
      }

      // Add to array (PostgreSQL array_append function)
      final updatedCoOrganizers = [...event.coOrganizers, coOrganizerId];

      await _supabase.from('events').update({
        'co_organizers': updatedCoOrganizers,
      }).eq('id', eventId);
    } catch (e) {
      throw RemoteDataSourceException('Failed to add co-organizer: $e');
    }
  }

  /// Remove co-organizer (creator only)
  Future<void> removeCoOrganizer(String eventId, String coOrganizerId) async {
    try {
      // Fetch current event
      final event = await getEventById(eventId);
      if (event == null) {
        throw RemoteDataSourceException('Event not found');
      }

      // Remove from array
      final updatedCoOrganizers = event.coOrganizers
          .where((id) => id != coOrganizerId)
          .toList();

      await _supabase.from('events').update({
        'co_organizers': updatedCoOrganizers,
      }).eq('id', eventId);
    } catch (e) {
      throw RemoteDataSourceException('Failed to remove co-organizer: $e');
    }
  }
}

/// Exception thrown when remote data source operation fails
class RemoteDataSourceException implements Exception {
  final String message;

  RemoteDataSourceException(this.message);

  @override
  String toString() => 'RemoteDataSourceException: $message';
}
