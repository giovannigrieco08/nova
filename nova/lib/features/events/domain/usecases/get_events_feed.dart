// Use Case: GetEventsFeed
// Feature: 003-events-feed
// Purpose: Business logic for fetching paginated events feed

import '../../data/repositories/events_repository.dart';
import '../entities/event.dart';

class GetEventsFeed {
  final EventsRepository _repository;

  GetEventsFeed({required EventsRepository repository})
      : _repository = repository;

  /// Execute use case: Fetch paginated events feed
  ///
  /// Parameters:
  /// - [page]: Page number (1-indexed)
  /// - [limit]: Number of events per page (default: 20)
  /// - [forceRefresh]: Skip cache and fetch from network
  ///
  /// Returns: List of Event entities
  ///
  /// Throws:
  /// - SupabaseException if network request fails and no cache available
  /// - Exception for other unexpected errors
  Future<List<Event>> execute({
    required int page,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    // Validate page number
    if (page < 1) {
      throw ArgumentError('Page number must be >= 1');
    }

    // Validate limit
    if (limit < 1 || limit > 100) {
      throw ArgumentError('Limit must be between 1 and 100');
    }

    // Fetch events from repository
    return await _repository.getEventsFeed(
      page: page,
      limit: limit,
      forceRefresh: forceRefresh,
    );
  }
}
