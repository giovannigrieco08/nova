/// Remote data source for search feature
///
/// Handles Supabase FTS queries for events and profiles.
/// Uses PostgreSQL GIN Full-Text Search with Italian language configuration.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/search_results.dart';

/// Remote data source for search operations via Supabase
class SearchRemoteDataSource {
  final SupabaseClient _supabase;

  SearchRemoteDataSource(this._supabase);

  /// Search events using FTS
  ///
  /// Calls the `search_events` PostgreSQL function which uses
  /// websearch_to_tsquery with Italian language configuration.
  /// Returns max 20 results ranked by relevance.
  Future<List<EventSearchResult>> searchEvents(String query) async {
    if (query.trim().length < 2) {
      return [];
    }

    final response = await _supabase.rpc(
      'search_events',
      params: {
        'search_query': query.trim(),
        'result_limit': 20,
      },
    );

    return (response as List)
        .map((json) => EventSearchResult.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Search profiles using FTS
  ///
  /// Calls the `search_profiles` PostgreSQL function which uses
  /// websearch_to_tsquery with Italian language configuration.
  /// Only returns profiles with profile_visible = true.
  /// Returns max 20 results ranked by relevance.
  Future<List<ProfileSearchResult>> searchProfiles(String query) async {
    if (query.trim().length < 2) {
      return [];
    }

    final response = await _supabase.rpc(
      'search_profiles',
      params: {
        'search_query': query.trim(),
        'result_limit': 20,
      },
    );

    return (response as List)
        .map(
            (json) => ProfileSearchResult.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Search both events and profiles in parallel
  ///
  /// Returns combined SearchResults with both event and profile results.
  /// Queries run in parallel for better performance.
  Future<SearchResults> searchAll(String query) async {
    if (query.trim().length < 2) {
      return SearchResults.empty();
    }

    final results = await Future.wait([
      searchEvents(query),
      searchProfiles(query),
    ]);

    return SearchResults(
      events: results[0] as List<EventSearchResult>,
      profiles: results[1] as List<ProfileSearchResult>,
      query: query.trim(),
      timestamp: DateTime.now(),
      isFromCache: false,
    );
  }
}
