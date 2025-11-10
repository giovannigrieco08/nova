// Data Source: EventsLocalDataSource
// Feature: 003-events-feed
// Purpose: Hive-based local cache for offline-first events feed

import 'package:hive/hive.dart';
import '../models/event_model.dart';
import '../../domain/entities/offline_action.dart';

class EventsLocalDataSource {
  final Box<EventModel> _eventsBox;
  final Box<OfflineAction> _offlineActionsBox;

  EventsLocalDataSource({
    required Box<EventModel> eventsBox,
    required Box<OfflineAction> offlineActionsBox,
  })  : _eventsBox = eventsBox,
        _offlineActionsBox = offlineActionsBox;

  // ========================================================================
  // EVENTS CACHE OPERATIONS
  // ========================================================================

  /// Get all cached events (sorted by created_at DESC)
  Future<List<EventModel>> getCachedEvents() async {
    final events = _eventsBox.values.toList();

    // Sort by created_at descending (newest first)
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return events;
  }

  /// Get paginated cached events (for infinite scroll)
  Future<List<EventModel>> getCachedEventsPaginated({
    required int page,
    required int limit,
  }) async {
    final allEvents = await getCachedEvents();
    final offset = (page - 1) * limit;

    // Return empty if offset exceeds cache size
    if (offset >= allEvents.length) {
      return [];
    }

    // Calculate end index
    final end = offset + limit;
    final actualEnd = end > allEvents.length ? allEvents.length : end;

    return allEvents.sublist(offset, actualEnd);
  }

  /// Save events to cache (replaces existing cache)
  Future<void> saveEventsToCache(List<EventModel> events) async {
    await _eventsBox.clear();

    // Limit cache to last 100 events (FR-058, performance optimization)
    final eventsToCache = events.length > 100 ? events.sublist(0, 100) : events;

    for (final event in eventsToCache) {
      await _eventsBox.put(event.id, event);
    }
  }

  /// Update or add single event in cache (for real-time updates)
  Future<void> updateEventInCache(EventModel event) async {
    await _eventsBox.put(event.id, event);
  }

  /// Remove event from cache (for deletions)
  Future<void> removeEventFromCache(String eventId) async {
    await _eventsBox.delete(eventId);
  }

  /// Get single cached event by ID
  Future<EventModel?> getCachedEventById(String eventId) async {
    return _eventsBox.get(eventId);
  }

  /// Check if event is cached
  Future<bool> isEventCached(String eventId) async {
    return _eventsBox.containsKey(eventId);
  }

  /// Get cache size (number of cached events)
  Future<int> getCacheSize() async {
    return _eventsBox.length;
  }

  /// Clear all cached events
  Future<void> clearEventsCache() async {
    await _eventsBox.clear();
  }

  // ========================================================================
  // OFFLINE ACTIONS QUEUE OPERATIONS
  // ========================================================================

  /// Add action to offline queue
  Future<void> queueOfflineAction(OfflineAction action) async {
    await _offlineActionsBox.put(action.id, action);
  }

  /// Get all queued offline actions (sorted by queuedAt ASC - oldest first)
  Future<List<OfflineAction>> getQueuedActions() async {
    final actions = _offlineActionsBox.values.toList();

    // Sort by queuedAt ascending (process oldest first)
    actions.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

    return actions;
  }

  /// Get actions that need retry (haven't exceeded max retries)
  Future<List<OfflineAction>> getRetryableActions() async {
    final actions = await getQueuedActions();
    return actions.where((action) => !action.hasExceededMaxRetries).toList();
  }

  /// Get actions that exceeded max retries (for manual retry)
  Future<List<OfflineAction>> getFailedActions() async {
    final actions = await getQueuedActions();
    return actions.where((action) => action.hasExceededMaxRetries).toList();
  }

  /// Update action in queue (for retry count updates)
  Future<void> updateOfflineAction(OfflineAction action) async {
    await _offlineActionsBox.put(action.id, action);
  }

  /// Remove action from queue (after successful sync)
  Future<void> removeOfflineAction(String actionId) async {
    await _offlineActionsBox.delete(actionId);
  }

  /// Get queue size (number of queued actions)
  Future<int> getQueueSize() async {
    return _offlineActionsBox.length;
  }

  /// Clear all queued actions
  Future<void> clearOfflineQueue() async {
    await _offlineActionsBox.clear();
  }

  /// Check if there are pending offline actions
  Future<bool> hasPendingActions() async {
    return _offlineActionsBox.isNotEmpty;
  }

  // ========================================================================
  // OPTIMISTIC UI HELPERS
  // ========================================================================

  /// Set like state for event (optimistic UI)
  /// Stores like state in memory (not persisted to Hive - just for UI consistency)
  final Map<String, Set<String>> _likeCache = {}; // eventId -> Set of userIds

  /// Add like to optimistic cache
  void setLikeState(String eventId, String userId, {required bool liked}) {
    if (liked) {
      _likeCache[eventId] ??= {};
      _likeCache[eventId]!.add(userId);
    } else {
      _likeCache[eventId]?.remove(userId);
      if (_likeCache[eventId]?.isEmpty ?? false) {
        _likeCache.remove(eventId);
      }
    }
  }

  /// Check if user has liked event (optimistic cache)
  bool isEventLiked(String eventId, String userId) {
    return _likeCache[eventId]?.contains(userId) ?? false;
  }

  /// Set participation state for event (optimistic UI)
  final Map<String, Set<String>> _participationCache = {}; // eventId -> Set of userIds

  /// Add participation to optimistic cache
  void setParticipationState(String eventId, String userId, {required bool participating}) {
    if (participating) {
      _participationCache[eventId] ??= {};
      _participationCache[eventId]!.add(userId);
    } else {
      _participationCache[eventId]?.remove(userId);
      if (_participationCache[eventId]?.isEmpty ?? false) {
        _participationCache.remove(eventId);
      }
    }
  }

  /// Check if user is participating in event (optimistic cache)
  bool isEventParticipating(String eventId, String userId) {
    return _participationCache[eventId]?.contains(userId) ?? false;
  }

  /// Clear optimistic caches (after successful sync or app restart)
  void clearOptimisticCaches() {
    _likeCache.clear();
    _participationCache.clear();
  }
}
