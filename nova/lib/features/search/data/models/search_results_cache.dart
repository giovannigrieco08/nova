/// Hive model for caching search results
///
/// Stores serialized search results with timestamp for TTL validation.
/// TypeId: 8 (registered in main.dart)

import 'package:hive_flutter/hive_flutter.dart';

part 'search_results_cache.g.dart';

@HiveType(typeId: 8)
class SearchResultsCache extends HiveObject {
  @HiveField(0)
  final String query;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final List<CachedEventResult> events;

  @HiveField(3)
  final List<CachedProfileResult> profiles;

  SearchResultsCache({
    required this.query,
    required this.timestamp,
    required this.events,
    required this.profiles,
  });

  /// Check if cache entry has expired
  bool isExpired(Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }

  /// Total number of results
  int get totalCount => events.length + profiles.length;
}

@HiveType(typeId: 9)
class CachedEventResult extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final String? location;

  @HiveField(4)
  final DateTime? eventDate;

  @HiveField(5)
  final String? imageUrl;

  @HiveField(6)
  final String creatorId;

  CachedEventResult({
    required this.id,
    required this.title,
    this.description,
    this.location,
    this.eventDate,
    this.imageUrl,
    required this.creatorId,
  });
}

@HiveType(typeId: 10)
class CachedProfileResult extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String fullName;

  @HiveField(2)
  final String? bio;

  @HiveField(3)
  final String? className;

  @HiveField(4)
  final String? avatarUrl;

  CachedProfileResult({
    required this.id,
    required this.fullName,
    this.bio,
    this.className,
    this.avatarUrl,
  });
}
