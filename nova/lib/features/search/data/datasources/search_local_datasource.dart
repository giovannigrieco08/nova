/// Local data source for search feature
///
/// Handles Hive storage for search history and results cache.
/// History is stored locally only (GDPR compliant - no server tracking).

import 'package:hive_flutter/hive_flutter.dart';
import '../models/search_results_cache.dart';

/// Local data source for search history and cache
class SearchLocalDataSource {
  static const String _historyBoxName = 'search_history';
  static const String _cacheBoxName = 'search_cache';
  static const int _maxHistoryItems = 10;

  late Box<String> _historyBox;
  late Box<SearchResultsCache> _cacheBox;

  /// Initialize Hive boxes
  Future<void> init() async {
    _historyBox = await Hive.openBox<String>(_historyBoxName);
    _cacheBox = await Hive.openBox<SearchResultsCache>(_cacheBoxName);
  }

  /// Check if boxes are initialized
  bool get isInitialized =>
      Hive.isBoxOpen(_historyBoxName) && Hive.isBoxOpen(_cacheBoxName);

  // ============================================================================
  // SEARCH HISTORY
  // ============================================================================

  /// Get recent search queries
  ///
  /// Returns up to [_maxHistoryItems] most recent searches.
  /// Most recent first.
  List<String> getSearchHistory() {
    return _historyBox.values.toList().reversed.toList();
  }

  /// Add a search query to history
  ///
  /// Removes duplicates and keeps max [_maxHistoryItems].
  Future<void> addToHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;

    // Remove if already exists (will be re-added at end)
    final existing = _historyBox.values.toList();
    final index = existing.indexOf(trimmed);
    if (index != -1) {
      await _historyBox.deleteAt(index);
    }

    // Add to end (most recent)
    await _historyBox.add(trimmed);

    // Trim to max items
    while (_historyBox.length > _maxHistoryItems) {
      await _historyBox.deleteAt(0);
    }
  }

  /// Remove a specific query from history
  Future<void> removeFromHistory(String query) async {
    final existing = _historyBox.values.toList();
    final index = existing.indexOf(query);
    if (index != -1) {
      await _historyBox.deleteAt(index);
    }
  }

  /// Clear all search history
  Future<void> clearHistory() async {
    await _historyBox.clear();
  }

  // ============================================================================
  // SEARCH RESULTS CACHE
  // ============================================================================

  /// Get cached results for a query
  ///
  /// Returns null if not cached or expired.
  SearchResultsCache? getCachedResults(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    return _cacheBox.get(normalizedQuery);
  }

  /// Cache search results
  Future<void> cacheResults(SearchResultsCache cache) async {
    final normalizedQuery = cache.query.trim().toLowerCase();
    await _cacheBox.put(normalizedQuery, cache);
  }

  /// Check if cache is valid (not expired)
  bool isCacheValid(String query, Duration ttl) {
    final cache = getCachedResults(query);
    if (cache == null) return false;
    return !cache.isExpired(ttl);
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache(Duration ttl) async {
    final keysToDelete = <String>[];

    for (final key in _cacheBox.keys) {
      final cache = _cacheBox.get(key);
      if (cache != null && cache.isExpired(ttl)) {
        keysToDelete.add(key as String);
      }
    }

    for (final key in keysToDelete) {
      await _cacheBox.delete(key);
    }
  }

  /// Clear all cached results
  Future<void> clearCache() async {
    await _cacheBox.clear();
  }

  /// Get all cached queries (for offline search)
  List<SearchResultsCache> getAllCachedResults() {
    return _cacheBox.values.toList();
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  /// Close all boxes
  Future<void> close() async {
    await _historyBox.close();
    await _cacheBox.close();
  }
}
