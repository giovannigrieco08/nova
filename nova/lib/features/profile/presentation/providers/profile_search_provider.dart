// Provider: ProfileSearchProvider
// Feature: 004-event-creation-moderation (Phase 7 - Co-Organizers)
// Purpose: Riverpod providers for profile search functionality

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/profile.dart';
import 'profile_provider.dart';

/// Profile search state notifier
///
/// Manages profile search with debouncing (500ms) to reduce API calls
/// Usage in widgets:
/// ```dart
/// final notifier = ref.read(profileSearchProvider.notifier);
/// notifier.search('Giovanni'); // Triggers search after 500ms
/// ```
class ProfileSearchNotifier extends StateNotifier<AsyncValue<List<Profile>>> {
  final Ref _ref;
  Timer? _debounceTimer;
  String _currentQuery = '';

  ProfileSearchNotifier(this._ref) : super(const AsyncValue.data([]));

  /// Search profiles by name or class
  /// Debounced 500ms to reduce API calls
  void search(String query) {
    _currentQuery = query.trim();

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Empty query = clear results immediately
    if (_currentQuery.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    // Set loading state
    state = const AsyncValue.loading();

    // Debounce search (500ms)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _performSearch(_currentQuery);
    });
  }

  /// Perform actual search
  Future<void> _performSearch(String query) async {
    try {
      final repository = _ref.read(profileRepositoryProvider);
      final results = await repository.searchProfiles(query);

      // Only update if query hasn't changed
      if (_currentQuery == query) {
        state = AsyncValue.data(results);
      }
    } catch (e, stack) {
      // Only update if query hasn't changed
      if (_currentQuery == query) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  /// Clear search results
  void clear() {
    _debounceTimer?.cancel();
    _currentQuery = '';
    state = const AsyncValue.data([]);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Profile search provider
///
/// Provides ProfileSearchNotifier for co-organizer selection
/// Usage:
/// ```dart
/// // Read results
/// final searchResults = ref.watch(profileSearchProvider);
///
/// // Trigger search
/// ref.read(profileSearchProvider.notifier).search('Giovanni');
/// ```
final profileSearchProvider =
    StateNotifierProvider<ProfileSearchNotifier, AsyncValue<List<Profile>>>(
        (ref) {
  return ProfileSearchNotifier(ref);
});
