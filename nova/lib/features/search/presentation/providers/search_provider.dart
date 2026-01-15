/// Search providers for Riverpod state management
///
/// Provides debounced search functionality with caching and offline support.
/// Uses StateNotifier pattern with AsyncValue for loading/error states.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/datasources/search_local_datasource.dart';
import '../../data/datasources/search_remote_datasource.dart';
import '../../data/repositories/search_repository.dart';
import '../../domain/entities/search_results.dart';

// ============================================================================
// DATA SOURCE PROVIDERS
// ============================================================================

/// Provider for SearchRemoteDataSource
final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>((ref) {
  return SearchRemoteDataSource(Supabase.instance.client);
});

/// Provider for SearchLocalDataSource
final searchLocalDataSourceProvider = Provider<SearchLocalDataSource>((ref) {
  return SearchLocalDataSource();
});

// ============================================================================
// REPOSITORY PROVIDER
// ============================================================================

/// Provider for SearchRepository
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(
    remoteDataSource: ref.read(searchRemoteDataSourceProvider),
    localDataSource: ref.read(searchLocalDataSourceProvider),
    connectivity: Connectivity(),
  );
});

// ============================================================================
// SEARCH STATE
// ============================================================================

/// State for search operations
class SearchState {
  final String query;
  final AsyncValue<SearchResults> results;
  final bool isOffline;

  SearchState({
    this.query = '',
    AsyncValue<SearchResults>? results,
    this.isOffline = false,
  }) : results = results ?? AsyncValue.data(SearchResults.empty());

  /// Initial empty state
  factory SearchState.initial() {
    return SearchState(
      query: '',
      results: AsyncValue.data(SearchResults.empty()),
      isOffline: false,
    );
  }

  SearchState copyWith({
    String? query,
    AsyncValue<SearchResults>? results,
    bool? isOffline,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

// ============================================================================
// SEARCH NOTIFIER
// ============================================================================

/// StateNotifier for search with 500ms debouncing
class SearchNotifier extends StateNotifier<SearchState> {
  final SearchRepository _repository;
  Timer? _debounceTimer;
  String? _lastSearchId;

  /// Debounce duration for live search
  static const Duration debounceDuration = Duration(milliseconds: 500);

  /// Minimum query length for search
  static const int minQueryLength = 2;

  SearchNotifier(this._repository) : super(SearchState.initial());

  /// Initialize repository (opens Hive boxes)
  Future<void> init() async {
    await _repository.init();
  }

  /// Update query and trigger debounced search
  void updateQuery(String query) {
    // Update query immediately (for UI)
    state = state.copyWith(query: query);

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Clear results if query too short
    if (query.trim().length < minQueryLength) {
      state = state.copyWith(
        results: AsyncValue.data(SearchResults.empty()),
      );
      return;
    }

    // Start debounce timer
    _debounceTimer = Timer(debounceDuration, () {
      _performSearch(query);
    });
  }

  /// Perform search immediately (bypasses debounce)
  Future<void> searchNow(String query) async {
    _debounceTimer?.cancel();
    state = state.copyWith(query: query);

    if (query.trim().length < minQueryLength) {
      state = state.copyWith(
        results: AsyncValue.data(SearchResults.empty()),
      );
      return;
    }

    await _performSearch(query);
  }

  /// Internal search execution with race condition handling
  Future<void> _performSearch(String query) async {
    // Generate unique search ID to prevent stale results
    final searchId = DateTime.now().millisecondsSinceEpoch.toString();
    _lastSearchId = searchId;

    // Set loading state
    state = state.copyWith(
      results: const AsyncValue.loading(),
    );

    try {
      // Check connectivity
      final isOnline = await _repository.isOnline();
      state = state.copyWith(isOffline: !isOnline);

      // Perform search
      final results = await _repository.search(query);

      // Only update if this is still the latest search
      if (_lastSearchId == searchId && mounted) {
        state = state.copyWith(
          results: AsyncValue.data(results),
        );
      }
    } catch (e, stack) {
      // Only update if this is still the latest search
      if (_lastSearchId == searchId && mounted) {
        state = state.copyWith(
          results: AsyncValue.error(e, stack),
        );
      }
    }
  }

  /// Clear search results and query
  void clear() {
    _debounceTimer?.cancel();
    _lastSearchId = null;
    state = SearchState.initial();
  }

  /// Refresh current search (invalidate cache)
  Future<void> refresh() async {
    if (state.query.trim().length < minQueryLength) return;

    await _repository.invalidateCache();
    await _performSearch(state.query);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// ============================================================================
// MAIN SEARCH PROVIDER
// ============================================================================

/// Main search provider with debounced search functionality
final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final repository = ref.watch(searchRepositoryProvider);
  final notifier = SearchNotifier(repository);

  // Initialize repository on first use
  notifier.init();

  return notifier;
});

// ============================================================================
// CONVENIENCE PROVIDERS
// ============================================================================

/// Provider for current search query
final searchQueryProvider = Provider<String>((ref) {
  return ref.watch(searchNotifierProvider).query;
});

/// Provider for search results
final searchResultsProvider = Provider<AsyncValue<SearchResults>>((ref) {
  return ref.watch(searchNotifierProvider).results;
});

/// Provider for offline status
final searchOfflineProvider = Provider<bool>((ref) {
  return ref.watch(searchNotifierProvider).isOffline;
});

/// Provider for checking if search has results
final hasSearchResultsProvider = Provider<bool>((ref) {
  final results = ref.watch(searchResultsProvider);
  return results.maybeWhen(
    data: (data) => data.hasResults,
    orElse: () => false,
  );
});
