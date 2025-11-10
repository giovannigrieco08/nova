// Data Source: EventsRemoteDataSource
// Feature: 003-events-feed
// Purpose: Supabase-based remote data source for events API calls

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import '../models/comment_model.dart';
import '../models/report_model.dart';

class EventsRemoteDataSource {
  final SupabaseClient _supabase;

  EventsRemoteDataSource({required SupabaseClient supabase})
      : _supabase = supabase;

  // ========================================================================
  // EVENTS QUERIES
  // ========================================================================

  /// Fetch paginated events feed (approved, upcoming, with creator profile)
  /// FR-001, FR-002, FR-003: Paginated, approved only, upcoming only
  Future<List<EventModel>> fetchEventsFeed({
    required int page,
    required int limit,
  }) async {
    final offset = (page - 1) * limit;

    final response = await _supabase
        .from('events')
        .select('*, creator:profiles!creator_id(user_id, full_name, avatar_url, class)') // Changed users→profiles, id→user_id, name→full_name
        .eq('status', 'approved')
        .gte('event_date', DateTime.now().toIso8601String().split('T')[0]) // >= today
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch single event by ID (with creator profile)
  /// FR-011: Full event details
  Future<EventModel> fetchEventById(String eventId) async {
    final response = await _supabase
        .from('events')
        .select('*, creator:profiles!creator_id(user_id, full_name, avatar_url, class)') // Changed users→profiles, id→user_id, name→full_name
        .eq('id', eventId)
        .single();

    return EventModel.fromJson(response);
  }

  /// Update event (creator only, enforced by RLS)
  /// FR-037: Edit event details
  Future<EventModel> updateEvent({
    required String eventId,
    required Map<String, dynamic> updates,
  }) async {
    final response = await _supabase
        .from('events')
        .update({
          ...updates,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', eventId)
        .select('*, creator:profiles!creator_id(user_id, full_name, avatar_url, class)') // Changed users→profiles, id→user_id, name→full_name
        .single();

    return EventModel.fromJson(response);
  }

  /// Delete event (creator only, enforced by RLS)
  /// FR-041: Delete event
  Future<void> deleteEvent(String eventId) async {
    await _supabase.from('events').delete().eq('id', eventId);
  }

  // ========================================================================
  // LIKES OPERATIONS
  // ========================================================================

  /// Like event (create like record)
  /// FR-015: Like event
  Future<void> likeEvent({
    required String eventId,
    required String userId,
  }) async {
    await _supabase.from('likes').insert({
      'event_id': eventId,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Unlike event (delete like record)
  /// FR-017: Unlike event
  Future<void> unlikeEvent({
    required String eventId,
    required String userId,
  }) async {
    await _supabase
        .from('likes')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  /// Get like count for event
  /// FR-016: Display like count
  Future<int> getLikeCount(String eventId) async {
    final response = await _supabase
        .from('likes')
        .select()
        .eq('event_id', eventId) as List;

    return response.length;
  }

  /// Check if user has liked event
  /// FR-015: Check like state
  Future<bool> isEventLiked({
    required String eventId,
    required String userId,
  }) async {
    final response = await _supabase
        .from('likes')
        .select()
        .eq('event_id', eventId)
        .eq('user_id', userId) as List;

    return response.isNotEmpty;
  }

  // ========================================================================
  // PARTICIPATIONS OPERATIONS
  // ========================================================================

  /// Participate in event (create participation record)
  /// FR-022: RSVP to event
  Future<void> participateInEvent({
    required String eventId,
    required String userId,
  }) async {
    await _supabase.from('participations').insert({
      'event_id': eventId,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Unparticipate from event (delete participation record)
  /// FR-023: Cancel RSVP
  Future<void> unparticipateFromEvent({
    required String eventId,
    required String userId,
  }) async {
    await _supabase
        .from('participations')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  /// Get participants for event (with user profiles)
  /// FR-013: Display participants
  Future<List<Map<String, dynamic>>> getParticipants(String eventId) async {
    final response = await _supabase
        .from('participations')
        .select('user:users!user_id(id, name, avatar_url, class)')
        .eq('event_id', eventId);

    return (response as List)
        .map((item) => item['user'] as Map<String, dynamic>)
        .toList();
  }

  /// Get participant count for event
  /// FR-013: Display participant count
  Future<int> getParticipantCount(String eventId) async {
    final response = await _supabase
        .from('participations')
        .select()
        .eq('event_id', eventId) as List;

    return response.length;
  }

  /// Check if user is participating in event
  /// FR-022: Check participation state
  Future<bool> isParticipating({
    required String eventId,
    required String userId,
  }) async {
    final response = await _supabase
        .from('participations')
        .select()
        .eq('event_id', eventId)
        .eq('user_id', userId) as List;

    return response.isNotEmpty;
  }

  // ========================================================================
  // COMMENTS OPERATIONS
  // ========================================================================

  /// Fetch comments for event (with author profiles, sorted chronologically)
  /// FR-027: Display comments
  Future<List<CommentModel>> fetchComments(String eventId) async {
    final response = await _supabase
        .from('comments')
        .select('*, author:users!author_id(id, name, avatar_url, class)')
        .eq('event_id', eventId)
        .order('created_at', ascending: true); // Oldest first (chronological)

    return (response as List)
        .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Post comment (with character limit validation)
  /// FR-029: Post comment (max 500 chars)
  Future<CommentModel> postComment({
    required String eventId,
    required String authorId,
    required String text,
  }) async {
    // Client-side validation (server also validates via VARCHAR(500) and RLS)
    if (text.trim().isEmpty) {
      throw Exception('Comment text cannot be empty');
    }
    if (text.length > 500) {
      throw Exception('Comment text must be 500 characters or less');
    }

    final response = await _supabase
        .from('comments')
        .insert({
          'event_id': eventId,
          'author_id': authorId,
          'text': text,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('*, author:users!author_id(id, name, avatar_url, class)')
        .single();

    return CommentModel.fromJson(response);
  }

  /// Delete comment (author only, enforced by RLS)
  /// FR-034: Delete own comment
  Future<void> deleteComment(String commentId) async {
    await _supabase.from('comments').delete().eq('id', commentId);
  }

  /// Get comment count for event
  /// FR-027: Display comment count
  Future<int> getCommentCount(String eventId) async {
    final response = await _supabase
        .from('comments')
        .select()
        .eq('event_id', eventId) as List;

    return response.length;
  }

  // ========================================================================
  // REPORTS OPERATIONS
  // ========================================================================

  /// Submit report for event
  /// FR-049: Report inappropriate content
  Future<void> submitReport({
    required String eventId,
    required String reporterId,
    required String reason,
    required String explanation,
  }) async {
    // Validate reason
    if (!ReportModel.isValidReason(reason)) {
      throw Exception(
        'Invalid report reason. Must be one of: inappropriate, spam, harassment, other',
      );
    }

    await _supabase.from('reports').insert({
      'event_id': eventId,
      'reporter_id': reporterId,
      'reason': reason,
      'explanation': explanation,
      'created_at': DateTime.now().toIso8601String(),
      'reviewed': false,
    });
  }
}
