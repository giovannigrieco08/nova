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
  /// Uses upsert to handle duplicate participation attempts gracefully
  Future<void> participateInEvent({
    required String eventId,
    required String userId,
  }) async {
    await _supabase.from('participations').upsert(
      {
        'event_id': eventId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'event_id,user_id',
      ignoreDuplicates: true,
    );
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
  /// Uses two-query pattern since no direct FK exists between participations and profiles
  Future<List<Map<String, dynamic>>> getParticipants(String eventId) async {
    // Step 1: Get user_ids from participations
    final participationsResponse = await _supabase
        .from('participations')
        .select('user_id')
        .eq('event_id', eventId);

    final userIds = (participationsResponse as List)
        .map((p) => p['user_id'] as String)
        .toList();

    if (userIds.isEmpty) {
      return [];
    }

    // Step 2: Fetch profiles for those user_ids
    final profilesResponse = await _supabase
        .from('profiles')
        .select('user_id, full_name, avatar_url, class')
        .inFilter('user_id', userIds);

    return (profilesResponse as List)
        .map((p) => p as Map<String, dynamic>)
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
  // USER-SPECIFIC EVENTS QUERIES
  // ========================================================================

  /// Fetch events created by a specific user
  /// Used for profile "Eventi" tab
  Future<List<EventModel>> fetchEventsByCreator(String userId) async {
    final response = await _supabase
        .from('events')
        .select('*, creator:profiles!creator_id(user_id, full_name, avatar_url, class)')
        .eq('creator_id', userId)
        .order('event_date', ascending: false);

    return (response as List)
        .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch pending events created by a specific user
  /// Used for showing pending events banner at top of feed
  Future<List<EventModel>> fetchUserPendingEvents(String userId) async {
    final response = await _supabase
        .from('events')
        .select('*, creator:profiles!creator_id(user_id, full_name, avatar_url, class)')
        .eq('creator_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch events user is participating in
  /// Used for profile "Partecipazioni" tab
  Future<List<EventModel>> fetchEventsParticipating(String userId) async {
    // First get event IDs from participations
    final participationsResponse = await _supabase
        .from('participations')
        .select('event_id')
        .eq('user_id', userId);

    final eventIds = (participationsResponse as List)
        .map((p) => p['event_id'] as String)
        .toList();

    if (eventIds.isEmpty) {
      return [];
    }

    // Then fetch those events with creator info
    final eventsResponse = await _supabase
        .from('events')
        .select('*, creator:profiles!creator_id(user_id, full_name, avatar_url, class)')
        .inFilter('id', eventIds)
        .order('event_date', ascending: false);

    return (eventsResponse as List)
        .map((json) => EventModel.fromJson(json as Map<String, dynamic>))
        .toList();
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

  // ========================================================================
  // HELP REQUESTS OPERATIONS
  // ========================================================================

  /// Fetch help requests for an event
  Future<List<Map<String, dynamic>>> fetchHelpRequests(String eventId) async {
    final response = await _supabase
        .from('event_help_requests')
        .select()
        .eq('event_id', eventId)
        .order('created_at', ascending: true);

    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Create a help request for an event
  Future<Map<String, dynamic>> createHelpRequest({
    required String eventId,
    required String description,
  }) async {
    final response = await _supabase
        .from('event_help_requests')
        .insert({
          'event_id': eventId,
          'description': description,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return response;
  }

  /// Update a help request (mark as fulfilled)
  Future<Map<String, dynamic>> updateHelpRequest({
    required String requestId,
    required Map<String, dynamic> updates,
  }) async {
    final response = await _supabase
        .from('event_help_requests')
        .update({
          ...updates,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId)
        .select()
        .single();

    return response;
  }

  /// Delete a help request
  Future<void> deleteHelpRequest(String requestId) async {
    await _supabase
        .from('event_help_requests')
        .delete()
        .eq('id', requestId);
  }

  /// Fetch offers for a help request (with user profiles)
  Future<List<Map<String, dynamic>>> fetchHelpOffers(String requestId) async {
    final response = await _supabase
        .from('event_help_offers')
        .select('*, profile:profiles!user_id(user_id, full_name, avatar_url, class)')
        .eq('request_id', requestId)
        .order('created_at', ascending: true);

    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Create an offer to help
  Future<Map<String, dynamic>> createHelpOffer({
    required String requestId,
    required String userId,
    String? message,
  }) async {
    final response = await _supabase
        .from('event_help_offers')
        .insert({
          'request_id': requestId,
          'user_id': userId,
          'message': message,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select('*, profile:profiles!user_id(user_id, full_name, avatar_url, class)')
        .single();

    return response;
  }

  /// Update offer status (accept/decline)
  Future<Map<String, dynamic>> updateHelpOfferStatus({
    required String offerId,
    required String status,
  }) async {
    final response = await _supabase
        .from('event_help_offers')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', offerId)
        .select('*, profile:profiles!user_id(user_id, full_name, avatar_url, class)')
        .single();

    return response;
  }

  /// Delete an offer (withdraw)
  Future<void> deleteHelpOffer(String offerId) async {
    await _supabase
        .from('event_help_offers')
        .delete()
        .eq('id', offerId);
  }

  /// Check if user has already offered to help for a request
  Future<bool> hasUserOfferedHelp({
    required String requestId,
    required String userId,
  }) async {
    final response = await _supabase
        .from('event_help_offers')
        .select()
        .eq('request_id', requestId)
        .eq('user_id', userId) as List;

    return response.isNotEmpty;
  }

  // ========================================================================
  // EVENT REPORTS
  // ========================================================================

  /// Report an event (FR-049)
  Future<void> reportEvent({
    required String eventId,
    required String reporterId,
    required String reason,
    String? description,
  }) async {
    await _supabase.from('event_reports').insert({
      'event_id': eventId,
      'reporter_id': reporterId,
      'reason': reason,
      'description': description,
    });
  }

  /// Check if user has already reported an event
  Future<bool> hasUserReportedEvent({
    required String eventId,
    required String userId,
  }) async {
    final response = await _supabase
        .from('event_reports')
        .select('id')
        .eq('event_id', eventId)
        .eq('reporter_id', userId)
        .maybeSingle();

    return response != null;
  }

  // ========================================================================
  // EVENT INVITATIONS
  // ========================================================================

  /// Search users to invite (excluding already invited and self)
  Future<List<Map<String, dynamic>>> searchUsersToInvite({
    required String eventId,
    required String currentUserId,
    required String query,
    int limit = 20,
  }) async {
    // Get already invited user IDs
    final invitedResponse = await _supabase
        .from('event_invitations')
        .select('invitee_id')
        .eq('event_id', eventId);

    final invitedIds = (invitedResponse as List)
        .map((i) => i['invitee_id'] as String)
        .toList();

    // Get already participating user IDs
    final participatingResponse = await _supabase
        .from('participations')
        .select('user_id')
        .eq('event_id', eventId);

    final participatingIds = (participatingResponse as List)
        .map((p) => p['user_id'] as String)
        .toList();

    // Combine excluded IDs
    final excludedIds = {...invitedIds, ...participatingIds, currentUserId}.toList();

    // Search profiles
    var queryBuilder = _supabase
        .from('profiles')
        .select('user_id, full_name, avatar_url, class')
        .ilike('full_name', '%$query%')
        .limit(limit);

    if (excludedIds.isNotEmpty) {
      // Filter out excluded users by fetching all and filtering client-side
      // (Supabase doesn't have NOT IN filter directly)
      final response = await queryBuilder;
      return (response as List)
          .where((p) => !excludedIds.contains(p['user_id']))
          .take(limit)
          .cast<Map<String, dynamic>>()
          .toList();
    }

    final response = await queryBuilder;
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Send invitation to a user
  Future<Map<String, dynamic>> inviteUser({
    required String eventId,
    required String inviterId,
    required String inviteeId,
  }) async {
    final response = await _supabase
        .from('event_invitations')
        .insert({
          'event_id': eventId,
          'inviter_id': inviterId,
          'invitee_id': inviteeId,
        })
        .select('*, invitee:profiles!invitee_id(user_id, full_name, avatar_url, class)')
        .single();

    return response;
  }

  /// Get pending invitations for an event (sent by current user)
  Future<List<Map<String, dynamic>>> getEventInvitations(String eventId) async {
    final response = await _supabase
        .from('event_invitations')
        .select('*, invitee:profiles!invitee_id(user_id, full_name, avatar_url, class)')
        .eq('event_id', eventId)
        .order('created_at', ascending: false);

    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Get invitations received by user
  Future<List<Map<String, dynamic>>> getReceivedInvitations(String userId) async {
    final response = await _supabase
        .from('event_invitations')
        .select('''
          *,
          event:events!event_id(id, title, description, event_date, image_url),
          inviter:profiles!inviter_id(user_id, full_name, avatar_url, class)
        ''')
        .eq('invitee_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Respond to invitation (accept/decline)
  Future<void> respondToInvitation({
    required String invitationId,
    required String status,
  }) async {
    await _supabase
        .from('event_invitations')
        .update({
          'status': status,
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('id', invitationId);
  }

  /// Cancel a pending invitation
  Future<void> cancelInvitation(String invitationId) async {
    await _supabase
        .from('event_invitations')
        .delete()
        .eq('id', invitationId);
  }
}
