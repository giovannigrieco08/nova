// Domain Repository Interface: EventRepository
// Feature: 004-event-creation-moderation
// Purpose: Abstract contract for event data operations
//
// This interface defines all event-related operations without specifying
// implementation details. Actual implementation will inject Supabase data sources.

import 'dart:io';
import '../../domain/entities/event.dart';

/// Abstract repository for event operations
///
/// Implementations must provide:
/// - Supabase remote data source (for network requests)
/// - Hive local data source (for offline drafts)
abstract class EventRepository {
  // =========================================================================
  // READ OPERATIONS (Query Methods)
  // =========================================================================

  /// Get all approved upcoming events for feed
  ///
  /// Query: `status=eq.approved&event_date=gte.{now}&order=created_at.desc`
  /// RLS Policy: users_view_approved_upcoming_events
  Future<List<Event>> getApprovedEvents();

  /// Get all events created by specific user (any status)
  ///
  /// Query: `creator_id=eq.{userId}&order=created_at.desc`
  /// RLS Policy: creators_view_own_events
  Future<List<Event>> getMyEvents(String userId);

  /// Get all pending events for moderation queue (moderators only)
  ///
  /// Query: `status=eq.pending&order=created_at.asc` (FIFO ordering)
  /// RLS Policy: moderators_view_all_events (requires is_moderator() = true)
  Future<List<Event>> getPendingEvents();

  /// Get events where user is co-organizer
  ///
  /// Query: `{userId}=any(co_organizers)&order=created_at.desc`
  /// RLS Policy: coorganizers_view_events
  Future<List<Event>> getCoOrganizedEvents(String userId);

  /// Get single event by ID
  ///
  /// RLS enforces access rules (creator, co-organizer, moderator, or approved)
  Future<Event?> getEventById(String eventId);

  // =========================================================================
  // WRITE OPERATIONS (Mutations)
  // =========================================================================

  /// Create new event (status defaults to 'pending')
  ///
  /// Steps:
  /// 1. Compress image (via ImageCompressor)
  /// 2. Upload compressed image to Supabase Storage bucket 'event-images'
  /// 3. Create event record in database with image_url
  /// 4. Delete draft from Hive (if exists)
  ///
  /// Returns created event with generated ID
  Future<Event> createEvent(Event event, {File? imageFile});

  /// Update existing event (triggers re-moderation if approved)
  ///
  /// RLS Policy: coorganizers_update_events (creator or co-organizer can update)
  /// Database Trigger: revert_status_on_content_change resets to 'pending' if modified
  Future<Event> updateEvent(String eventId, Map<String, dynamic> updates);

  /// Delete event (creator only)
  ///
  /// RLS Policy: users_delete_own_events
  /// Cascade deletes: likes, participations, comments, reports
  Future<void> deleteEvent(String eventId);

  // =========================================================================
  // MODERATION OPERATIONS (Moderators Only)
  // =========================================================================

  /// Approve event (moderators only)
  ///
  /// Updates:
  /// - status = 'approved'
  /// - moderated_by = {current_user_id}
  /// - moderated_at = NOW()
  ///
  /// Triggers notification to creator (event_approved channel)
  Future<void> approveEvent(String eventId);

  /// Reject event with reason (moderators only)
  ///
  /// Updates:
  /// - status = 'rejected'
  /// - rejection_reason = {reason} (min 10 chars)
  /// - moderated_by = {current_user_id}
  /// - moderated_at = NOW()
  ///
  /// Triggers notification to creator (event_rejected channel)
  Future<void> rejectEvent(String eventId, String rejectionReason);

  // =========================================================================
  // CO-ORGANIZER OPERATIONS
  // =========================================================================

  /// Add co-organizer to event (creator only, max 3 total)
  ///
  /// Updates: co_organizers array
  /// Triggers notification to added user (added_as_coorganizer channel)
  Future<void> addCoOrganizer(String eventId, String userId);

  /// Remove co-organizer from event (creator only)
  ///
  /// Updates: co_organizers array
  /// Triggers notification to removed user
  Future<void> removeCoOrganizer(String eventId, String userId);

  // =========================================================================
  // STORAGE OPERATIONS
  // =========================================================================

  /// Upload event image to Supabase Storage
  ///
  /// Bucket: event-images
  /// Path: {event_id}/{timestamp}.{ext}
  /// Returns public URL
  Future<String> uploadEventImage(File imageFile, String eventId);

  /// Delete event image from Supabase Storage
  Future<void> deleteEventImage(String imageUrl);
}
