/// Domain entities for Search feature
///
/// Contains unified search result types for events and profiles.
/// Used across data and presentation layers.

import 'package:flutter/foundation.dart';

/// Represents a single event in search results
@immutable
class EventSearchResult {
  final String id;
  final String title;
  final String? description;
  final String? location;
  final DateTime? eventDate;
  final String? imageUrl;
  final String creatorId;
  final double rank;

  const EventSearchResult({
    required this.id,
    required this.title,
    this.description,
    this.location,
    this.eventDate,
    this.imageUrl,
    required this.creatorId,
    required this.rank,
  });

  factory EventSearchResult.fromJson(Map<String, dynamic> json) {
    return EventSearchResult(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      eventDate: json['event_date'] != null
          ? DateTime.parse(json['event_date'] as String)
          : null,
      imageUrl: json['image_url'] as String?,
      creatorId: json['creator_id'] as String,
      rank: (json['rank'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventSearchResult &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Represents a single profile in search results
@immutable
class ProfileSearchResult {
  final String id;
  final String fullName;
  final String? bio;
  final String? className;
  final String? avatarUrl;
  final double rank;

  const ProfileSearchResult({
    required this.id,
    required this.fullName,
    this.bio,
    this.className,
    this.avatarUrl,
    required this.rank,
  });

  factory ProfileSearchResult.fromJson(Map<String, dynamic> json) {
    return ProfileSearchResult(
      id: json['user_id'] as String,
      fullName: json['full_name'] as String,
      bio: json['bio'] as String?,
      className: json['class_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      rank: (json['rank'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileSearchResult &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Combined search results containing both events and profiles
@immutable
class SearchResults {
  final List<EventSearchResult> events;
  final List<ProfileSearchResult> profiles;
  final String query;
  final DateTime timestamp;
  final bool isFromCache;

  const SearchResults({
    required this.events,
    required this.profiles,
    required this.query,
    required this.timestamp,
    this.isFromCache = false,
  });

  /// Creates empty search results
  factory SearchResults.empty() => SearchResults(
        events: const [],
        profiles: const [],
        query: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        isFromCache: false,
      );

  /// Total number of results (events + profiles)
  int get totalCount => events.length + profiles.length;

  /// Whether there are any results
  bool get hasResults => totalCount > 0;

  /// Whether this result is stale (older than TTL)
  bool isStale(Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }

  /// Creates a copy with cache flag
  SearchResults copyWithCacheFlag(bool fromCache) {
    return SearchResults(
      events: events,
      profiles: profiles,
      query: query,
      timestamp: timestamp,
      isFromCache: fromCache,
    );
  }
}
