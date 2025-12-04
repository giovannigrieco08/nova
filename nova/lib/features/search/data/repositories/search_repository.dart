/// Search repository
///
/// Business logic layer for search operations.
/// Combines remote and local data sources with caching and offline support.

import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/entities/search_results.dart';
import '../datasources/search_local_datasource.dart';
import '../datasources/search_remote_datasource.dart';
import '../models/search_results_cache.dart';

/// Repository for search operations with caching and offline support
class SearchRepository {
  final SearchRemoteDataSource _remoteDataSource;
  final SearchLocalDataSource _localDataSource;
  final Connectivity _connectivity;

  /// Cache TTL: 5 minutes
  static const Duration cacheTtl = Duration(minutes: 5);

  SearchRepository({
    required SearchRemoteDataSource remoteDataSource,
    required SearchLocalDataSource localDataSource,
    Connectivity? connectivity,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _connectivity = connectivity ?? Connectivity();

  /// Initialize local data source
  Future<void> init() async {
    await _localDataSource.init();
  }

  // ============================================================================
  // SEARCH OPERATIONS
  // ============================================================================

  /// Search events and profiles
  ///
  /// Strategy:
  /// 1. Check cache first (if valid within TTL)
  /// 2. If online, fetch from server and cache results
  /// 3. If offline, fallback to cached data or offline search
  Future<SearchResults> search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      return SearchResults.empty();
    }

    // Check cache first
    if (_localDataSource.isCacheValid(trimmedQuery, cacheTtl)) {
      final cached = _localDataSource.getCachedResults(trimmedQuery);
      if (cached != null) {
        return _cacheToSearchResults(cached, fromCache: true);
      }
    }

    // Check connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    if (isOnline) {
      // Fetch from server
      final results = await _remoteDataSource.searchAll(trimmedQuery);

      // Cache results
      await _cacheResults(results);

      return results;
    } else {
      // Offline: try cached data or offline search
      return searchOffline(trimmedQuery);
    }
  }

  /// Search offline using cached data
  ///
  /// Uses contains() matching on cached results when no network available.
  Future<SearchResults> searchOffline(String query) async {
    final trimmedQuery = query.trim().toLowerCase();
    if (trimmedQuery.length < 2) {
      return SearchResults.empty();
    }

    // First check if we have exact cached results
    final cached = _localDataSource.getCachedResults(trimmedQuery);
    if (cached != null) {
      return _cacheToSearchResults(cached, fromCache: true);
    }

    // Otherwise, search through all cached data
    final allCached = _localDataSource.getAllCachedResults();
    final matchingEvents = <EventSearchResult>[];
    final matchingProfiles = <ProfileSearchResult>[];

    for (final cache in allCached) {
      // Search in cached events
      for (final event in cache.events) {
        if (_matchesQuery(event.title, trimmedQuery) ||
            _matchesQuery(event.description, trimmedQuery) ||
            _matchesQuery(event.location, trimmedQuery)) {
          final result = EventSearchResult(
            id: event.id,
            title: event.title,
            description: event.description,
            location: event.location,
            eventDate: event.eventDate,
            imageUrl: event.imageUrl,
            creatorId: event.creatorId,
            rank: 1.0,
          );
          if (!matchingEvents.contains(result)) {
            matchingEvents.add(result);
          }
        }
      }

      // Search in cached profiles
      for (final profile in cache.profiles) {
        if (_matchesQuery(profile.fullName, trimmedQuery) ||
            _matchesQuery(profile.bio, trimmedQuery) ||
            _matchesQuery(profile.className, trimmedQuery)) {
          final result = ProfileSearchResult(
            id: profile.id,
            fullName: profile.fullName,
            bio: profile.bio,
            className: profile.className,
            avatarUrl: profile.avatarUrl,
            rank: 1.0,
          );
          if (!matchingProfiles.contains(result)) {
            matchingProfiles.add(result);
          }
        }
      }
    }

    return SearchResults(
      events: matchingEvents.take(20).toList(),
      profiles: matchingProfiles.take(20).toList(),
      query: query,
      timestamp: DateTime.now(),
      isFromCache: true,
    );
  }

  /// Check if device is online
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // ============================================================================
  // SEARCH HISTORY
  // ============================================================================

  /// Get recent search history
  List<String> getSearchHistory() {
    return _localDataSource.getSearchHistory();
  }

  /// Add query to search history
  Future<void> addToHistory(String query) async {
    await _localDataSource.addToHistory(query);
  }

  /// Remove query from history
  Future<void> removeFromHistory(String query) async {
    await _localDataSource.removeFromHistory(query);
  }

  /// Clear all search history
  Future<void> clearHistory() async {
    await _localDataSource.clearHistory();
  }

  // ============================================================================
  // CACHE MANAGEMENT
  // ============================================================================

  /// Invalidate all cached results
  ///
  /// Call this when feed is refreshed to ensure fresh search results.
  Future<void> invalidateCache() async {
    await _localDataSource.clearCache();
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    await _localDataSource.clearExpiredCache(cacheTtl);
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  /// Cache search results
  Future<void> _cacheResults(SearchResults results) async {
    final cache = SearchResultsCache(
      query: results.query,
      timestamp: results.timestamp,
      events: results.events
          .map((e) => CachedEventResult(
                id: e.id,
                title: e.title,
                description: e.description,
                location: e.location,
                eventDate: e.eventDate,
                imageUrl: e.imageUrl,
                creatorId: e.creatorId,
              ))
          .toList(),
      profiles: results.profiles
          .map((p) => CachedProfileResult(
                id: p.id,
                fullName: p.fullName,
                bio: p.bio,
                className: p.className,
                avatarUrl: p.avatarUrl,
              ))
          .toList(),
    );

    await _localDataSource.cacheResults(cache);
  }

  /// Convert cached results to SearchResults
  SearchResults _cacheToSearchResults(
    SearchResultsCache cache, {
    bool fromCache = false,
  }) {
    return SearchResults(
      events: cache.events
          .map((e) => EventSearchResult(
                id: e.id,
                title: e.title,
                description: e.description,
                location: e.location,
                eventDate: e.eventDate,
                imageUrl: e.imageUrl,
                creatorId: e.creatorId,
                rank: 1.0,
              ))
          .toList(),
      profiles: cache.profiles
          .map((p) => ProfileSearchResult(
                id: p.id,
                fullName: p.fullName,
                bio: p.bio,
                className: p.className,
                avatarUrl: p.avatarUrl,
                rank: 1.0,
              ))
          .toList(),
      query: cache.query,
      timestamp: cache.timestamp,
      isFromCache: fromCache,
    );
  }

  /// Check if text matches query (case-insensitive contains)
  bool _matchesQuery(String? text, String query) {
    if (text == null || text.isEmpty) return false;
    return text.toLowerCase().contains(query);
  }
}
