/// Search history provider
///
/// Manages recent search queries stored locally in Hive.
/// Privacy-compliant: no server tracking, local-only storage.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/search_repository.dart';
import 'search_provider.dart';

/// Provider for search history state
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  final repository = ref.watch(searchRepositoryProvider);
  return SearchHistoryNotifier(repository);
});

/// StateNotifier for managing search history
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  final SearchRepository _repository;

  SearchHistoryNotifier(this._repository) : super([]) {
    _loadHistory();
  }

  /// Load history from local storage
  void _loadHistory() {
    state = _repository.getSearchHistory();
  }

  /// Add a query to history
  Future<void> addQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;

    await _repository.addToHistory(trimmed);
    _loadHistory();
  }

  /// Remove a query from history
  Future<void> removeQuery(String query) async {
    await _repository.removeFromHistory(query);
    _loadHistory();
  }

  /// Clear all history
  Future<void> clearHistory() async {
    await _repository.clearHistory();
    state = [];
  }

  /// Reload history from storage
  void reload() {
    _loadHistory();
  }
}
