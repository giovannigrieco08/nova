// Repository: EventsRepository
// Feature: 003-events-feed
// Purpose: Cache-first data access with offline-first pattern for events

import '../data_sources/events_local_data_source.dart';
import '../data_sources/events_remote_data_source.dart';
import '../../domain/entities/event.dart';

class EventsRepository {
  final EventsLocalDataSource _localDataSource;
  final EventsRemoteDataSource _remoteDataSource;

  EventsRepository({
    required EventsLocalDataSource localDataSource,
    required EventsRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  // ========================================================================
  // EVENTS FEED (CACHE-FIRST PATTERN)
  // ========================================================================

  /// Fetch events feed with cache-first strategy
  /// FR-001, FR-002, FR-003: Paginated, approved, upcoming events
  ///
  /// Cache-first pattern:
  /// 1. Try to fetch from remote (network)
  /// 2. If success, update cache and return fresh data
  /// 3. If network fails, return cached data (if available)
  /// 4. If cache also empty, rethrow network error
  Future<List<Event>> getEventsFeed({
    required int page,
    required int limit,
    bool forceRefresh = false,
  }) async {
    try {
      // Fetch from remote
      final remoteEvents = await _remoteDataSource.fetchEventsFeed(
        page: page,
        limit: limit,
      );

      // Update cache with fresh data (only for first page)
      if (page == 1) {
        await _localDataSource.saveEventsToCache(remoteEvents);
      }

      // Convert to domain entities
      return remoteEvents.map((model) => model.toEntity()).toList();
    } catch (e) {
      // Network failed, try cache (only for first page)
      if (page == 1) {
        final cachedEvents = await _localDataSource.getCachedEvents();
        if (cachedEvents.isNotEmpty) {
          return cachedEvents.map((model) => model.toEntity()).toList();
        }
      }

      // No cache available, rethrow error
      rethrow;
    }
  }

  /// Fetch single event by ID
  /// FR-011: Event detail screen
  ///
  /// Parameters:
  /// - [eventId]: ID of the event to fetch
  /// - [forceRefresh]: If true, bypasses cache and fetches from network
  ///
  /// Returns:
  /// - Event entity with fresh or cached data
  ///
  /// Throws:
  /// - Exception if network fails and no cache available
  Future<Event> getEventById(String eventId, {bool forceRefresh = false}) async {
    // If not forcing refresh, try cache first
    if (!forceRefresh) {
      final cachedEvent = await _localDataSource.getCachedEventById(eventId);
      if (cachedEvent != null) {
        return cachedEvent.toEntity();
      }
    }

    // Fetch from network
    try {
      final eventModel = await _remoteDataSource.fetchEventById(eventId);

      // Update cache with fresh data
      await _localDataSource.updateEventInCache(eventModel);

      return eventModel.toEntity();
    } catch (e) {
      // Network failed and forceRefresh was true - try cache as fallback
      if (forceRefresh) {
        final cachedEvent = await _localDataSource.getCachedEventById(eventId);
        if (cachedEvent != null) {
          return cachedEvent.toEntity();
        }
      }
      rethrow;
    }
  }

  /// Update event (creator only)
  /// FR-037: Edit event details
  Future<Event> updateEvent({
    required String eventId,
    required Map<String, dynamic> updates,
  }) async {
    final updatedEvent = await _remoteDataSource.updateEvent(
      eventId: eventId,
      updates: updates,
    );

    // Update cache
    await _localDataSource.updateEventInCache(updatedEvent);

    return updatedEvent.toEntity();
  }

  /// Delete event (creator only)
  /// FR-041: Delete event
  Future<void> deleteEvent(String eventId) async {
    await _remoteDataSource.deleteEvent(eventId);

    // Remove from cache
    await _localDataSource.removeEventFromCache(eventId);
  }

  /// Clear all cached events (useful for logout or force refresh)
  Future<void> clearCache() async {
    await _localDataSource.clearEventsCache();
  }

  // ========================================================================
  // LIKES OPERATIONS
  // ========================================================================

  /// Like event
  /// FR-015: Optimistic like with offline queue
  Future<void> likeEvent({
    required String eventId,
    required String userId,
  }) async {
    await _remoteDataSource.likeEvent(
      eventId: eventId,
      userId: userId,
    );
  }

  /// Unlike event
  /// FR-017: Optimistic unlike with offline queue
  Future<void> unlikeEvent({
    required String eventId,
    required String userId,
  }) async {
    await _remoteDataSource.unlikeEvent(
      eventId: eventId,
      userId: userId,
    );
  }

  /// Get like count for event
  /// FR-016: Display like count
  Future<int> getLikeCount(String eventId) async {
    return await _remoteDataSource.getLikeCount(eventId);
  }

  /// Check if user has liked event
  /// FR-015: Show liked state in UI
  Future<bool> hasUserLikedEvent({
    required String eventId,
    required String userId,
  }) async {
    return await _remoteDataSource.isEventLiked(
      eventId: eventId,
      userId: userId,
    );
  }

  // ========================================================================
  // PARTICIPATIONS OPERATIONS
  // ========================================================================

  /// Participate in event
  /// FR-022: RSVP to event
  Future<void> participateInEvent({
    required String eventId,
    required String userId,
  }) async {
    await _remoteDataSource.participateInEvent(
      eventId: eventId,
      userId: userId,
    );
  }

  /// Unparticipate from event
  /// FR-023: Cancel RSVP
  Future<void> unparticipateFromEvent({
    required String eventId,
    required String userId,
  }) async {
    await _remoteDataSource.unparticipateFromEvent(
      eventId: eventId,
      userId: userId,
    );
  }

  /// Get participation count
  /// FR-024: Display participant count
  Future<int> getParticipationCount(String eventId) async {
    return await _remoteDataSource.getParticipantCount(eventId);
  }

  /// Check if user is participating
  /// FR-022: Show participation state
  Future<bool> isUserParticipating({
    required String eventId,
    required String userId,
  }) async {
    return await _remoteDataSource.isParticipating(
      eventId: eventId,
      userId: userId,
    );
  }

  /// Get participants list for event
  /// FR-013: Display participants
  Future<List<Map<String, dynamic>>> getParticipants(String eventId) async {
    return await _remoteDataSource.getParticipants(eventId);
  }

  // ========================================================================
  // USER-SPECIFIC EVENTS
  // ========================================================================

  /// Get events created by user
  /// Used for profile "Eventi" tab
  Future<List<Event>> getEventsByCreator(String userId) async {
    final events = await _remoteDataSource.fetchEventsByCreator(userId);
    return events.map((model) => model.toEntity()).toList();
  }

  /// Get pending events created by user
  /// Used for showing pending events banner at top of feed
  Future<List<Event>> getUserPendingEvents(String userId) async {
    final events = await _remoteDataSource.fetchUserPendingEvents(userId);
    return events.map((model) => model.toEntity()).toList();
  }

  /// Get events user is participating in
  /// Used for profile "Partecipazioni" tab
  Future<List<Event>> getEventsParticipating(String userId) async {
    final events = await _remoteDataSource.fetchEventsParticipating(userId);
    return events.map((model) => model.toEntity()).toList();
  }

  // ========================================================================
  // COMMENTS OPERATIONS
  // ========================================================================

  /// Fetch comments for event
  /// FR-027: Load comments
  Future<List<dynamic>> getEventComments(String eventId) async {
    final comments = await _remoteDataSource.fetchComments(eventId);
    return comments;
  }

  /// Post comment on event
  /// FR-029: Post comment
  Future<dynamic> postComment({
    required String eventId,
    required String userId,
    required String content,
  }) async {
    return await _remoteDataSource.postComment(
      eventId: eventId,
      authorId: userId,
      text: content,
    );
  }

  // ========================================================================
  // REPORTS OPERATIONS
  // ========================================================================

  /// Submit report for event
  /// FR-049: Report inappropriate content
  Future<void> reportEvent({
    required String eventId,
    required String userId,
    required String reason,
    String? description,
  }) async {
    await _remoteDataSource.reportEvent(
      eventId: eventId,
      reporterId: userId,
      reason: reason,
      description: description,
    );
  }

  /// Check if user has already reported an event
  Future<bool> hasUserReportedEvent({
    required String eventId,
    required String userId,
  }) async {
    return await _remoteDataSource.hasUserReportedEvent(
      eventId: eventId,
      userId: userId,
    );
  }

  // ========================================================================
  // EVENT INVITATIONS
  // ========================================================================

  /// Search users to invite to an event
  Future<List<Map<String, dynamic>>> searchUsersToInvite({
    required String eventId,
    required String currentUserId,
    required String query,
  }) async {
    return await _remoteDataSource.searchUsersToInvite(
      eventId: eventId,
      currentUserId: currentUserId,
      query: query,
    );
  }

  /// Send invitation to a user
  Future<Map<String, dynamic>> inviteUser({
    required String eventId,
    required String inviterId,
    required String inviteeId,
  }) async {
    return await _remoteDataSource.inviteUser(
      eventId: eventId,
      inviterId: inviterId,
      inviteeId: inviteeId,
    );
  }

  /// Get invitations for an event
  Future<List<Map<String, dynamic>>> getEventInvitations(String eventId) async {
    return await _remoteDataSource.getEventInvitations(eventId);
  }

  /// Get invitations received by user
  Future<List<Map<String, dynamic>>> getReceivedInvitations(String userId) async {
    return await _remoteDataSource.getReceivedInvitations(userId);
  }

  /// Respond to invitation
  Future<void> respondToInvitation({
    required String invitationId,
    required String status,
  }) async {
    await _remoteDataSource.respondToInvitation(
      invitationId: invitationId,
      status: status,
    );
  }

  /// Cancel invitation
  Future<void> cancelInvitation(String invitationId) async {
    await _remoteDataSource.cancelInvitation(invitationId);
  }

  // ========================================================================
  // HELP REQUESTS OPERATIONS
  // ========================================================================

  /// Get help requests for an event
  Future<List<Map<String, dynamic>>> getHelpRequests(String eventId) async {
    return await _remoteDataSource.fetchHelpRequests(eventId);
  }

  /// Create a help request for an event
  Future<Map<String, dynamic>> createHelpRequest({
    required String eventId,
    required String description,
  }) async {
    return await _remoteDataSource.createHelpRequest(
      eventId: eventId,
      description: description,
    );
  }

  /// Update a help request
  Future<Map<String, dynamic>> updateHelpRequest({
    required String requestId,
    required Map<String, dynamic> updates,
  }) async {
    return await _remoteDataSource.updateHelpRequest(
      requestId: requestId,
      updates: updates,
    );
  }

  /// Mark a help request as fulfilled
  Future<Map<String, dynamic>> fulfillHelpRequest({
    required String requestId,
    required String fulfilledBy,
  }) async {
    return await _remoteDataSource.updateHelpRequest(
      requestId: requestId,
      updates: {
        'is_fulfilled': true,
        'fulfilled_by': fulfilledBy,
      },
    );
  }

  /// Delete a help request
  Future<void> deleteHelpRequest(String requestId) async {
    await _remoteDataSource.deleteHelpRequest(requestId);
  }

  /// Get offers for a help request
  Future<List<Map<String, dynamic>>> getHelpOffers(String requestId) async {
    return await _remoteDataSource.fetchHelpOffers(requestId);
  }

  /// Create an offer to help
  Future<Map<String, dynamic>> createHelpOffer({
    required String requestId,
    required String userId,
    String? message,
  }) async {
    return await _remoteDataSource.createHelpOffer(
      requestId: requestId,
      userId: userId,
      message: message,
    );
  }

  /// Accept a help offer
  Future<Map<String, dynamic>> acceptHelpOffer(String offerId) async {
    return await _remoteDataSource.updateHelpOfferStatus(
      offerId: offerId,
      status: 'accepted',
    );
  }

  /// Decline a help offer
  Future<Map<String, dynamic>> declineHelpOffer(String offerId) async {
    return await _remoteDataSource.updateHelpOfferStatus(
      offerId: offerId,
      status: 'declined',
    );
  }

  /// Withdraw an offer
  Future<void> withdrawHelpOffer(String offerId) async {
    await _remoteDataSource.deleteHelpOffer(offerId);
  }

  /// Check if user has already offered to help
  Future<bool> hasUserOfferedHelp({
    required String requestId,
    required String userId,
  }) async {
    return await _remoteDataSource.hasUserOfferedHelp(
      requestId: requestId,
      userId: userId,
    );
  }
}
