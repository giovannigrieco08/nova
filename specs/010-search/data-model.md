# Data Model: Search Feature (010-search)

**Date**: 2025-01-30
**Status**: Complete

---

## 1. Core Entities

### SearchResults

Represents the combined results from a search query.

```dart
class SearchResults {
  final List<EventModel> events;
  final List<ProfileModel> profiles;
  final String query;
  final bool isOffline;
  final DateTime timestamp;

  const SearchResults({
    required this.events,
    required this.profiles,
    required this.query,
    this.isOffline = false,
    required this.timestamp,
  });

  bool get isEmpty => events.isEmpty && profiles.isEmpty;
  int get totalCount => events.length + profiles.length;

  factory SearchResults.empty(String query) => SearchResults(
    events: [],
    profiles: [],
    query: query,
    timestamp: DateTime.now(),
  );
}
```

| Field | Type | Description |
|-------|------|-------------|
| events | List<EventModel> | Matched events (max 20) |
| profiles | List<ProfileModel> | Matched profiles (max 20) |
| query | String | Original search query |
| isOffline | bool | True if results from local cache |
| timestamp | DateTime | When results were fetched (for cache TTL) |

---

### SearchResultsCache

Hive-cached version of SearchResults for 5-minute TTL caching.

```dart
@HiveType(typeId: 8)
class SearchResultsCache extends HiveObject {
  @HiveField(0)
  final String query;

  @HiveField(1)
  final List<String> eventIds;

  @HiveField(2)
  final List<String> profileIds;

  @HiveField(3)
  final DateTime timestamp;

  SearchResultsCache({
    required this.query,
    required this.eventIds,
    required this.profileIds,
    required this.timestamp,
  });

  bool get isExpired {
    final ttl = Duration(minutes: 5);
    return DateTime.now().difference(timestamp) > ttl;
  }
}
```

| Field | Type | Hive ID | Description |
|-------|------|---------|-------------|
| query | String | 0 | Normalized query (lowercase, trimmed) |
| eventIds | List<String> | 1 | UUIDs of matched events |
| profileIds | List<String> | 2 | UUIDs of matched profiles |
| timestamp | DateTime | 3 | Cache creation time |

---

### SearchHistoryItem

Simple model for search history (stored as plain strings in Hive).

```dart
// No custom model needed - use List<String> directly
// Hive box: Box<String>('search_history')

// Operations:
// - Add: box.add(query.toLowerCase().trim())
// - Get all: box.values.toList().reversed.take(10)
// - Remove: box.deleteAt(index)
// - Clear: box.clear()
```

---

## 2. Database Schema Changes

### Events Table - FTS Column

```sql
-- Add to existing events table
ALTER TABLE events
ADD COLUMN IF NOT EXISTS fts tsvector
GENERATED ALWAYS AS (
  to_tsvector('italian',
    COALESCE(title, '') || ' ' ||
    COALESCE(description, '') || ' ' ||
    COALESCE(location, '')
  )
) STORED;

-- GIN index with partial condition (only approved events)
CREATE INDEX IF NOT EXISTS idx_events_fts
  ON events USING gin(fts)
  WHERE status = 'approved';
```

### Profiles Table - FTS Column

```sql
-- Add to existing profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS fts tsvector
GENERATED ALWAYS AS (
  to_tsvector('italian',
    COALESCE(full_name, '') || ' ' ||
    COALESCE(username, '') || ' ' ||
    COALESCE(class, '')
  )
) STORED;

-- GIN index with partial condition (visible, non-deleted profiles)
CREATE INDEX IF NOT EXISTS idx_profiles_fts
  ON profiles USING gin(fts)
  WHERE deleted_at IS NULL AND profile_visible = TRUE;
```

---

## 3. Entity Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                      SEARCH DOMAIN                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  SearchResults ──────┬───── List<EventModel>                │
│       │              │            │                          │
│       │              │            └── Existing model         │
│       │              │                (no changes)           │
│       │              │                                       │
│       │              └───── List<ProfileModel>              │
│       │                           │                          │
│       │                           └── Existing model         │
│       │                               (no changes)           │
│       │                                                      │
│       └───────────────────── SearchResultsCache             │
│                                    │                         │
│                                    └── Stores IDs only       │
│                                        (lightweight)         │
│                                                              │
│  SearchHistory ────────────────── List<String>              │
│       │                                │                     │
│       └────────────────────────────────└── Simple strings   │
│                                            (no adapter)      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Validation Rules

### Query Validation

| Rule | Constraint | Action |
|------|------------|--------|
| Minimum length | >= 2 characters | Don't execute search |
| Maximum length | <= 100 characters | Truncate |
| Empty/whitespace | trim().isEmpty | Clear results |
| Special characters | SQL-unsafe chars | Escaped by Supabase SDK |

### Results Validation

| Rule | Constraint | Action |
|------|------------|--------|
| Max events | 20 | Limit in query |
| Max profiles | 20 | Limit in query |
| Event status | 'approved' only | Filter in query |
| Event date | >= now | Filter in query |
| Profile visibility | profile_visible = true | Filter in query |
| Profile deleted | deleted_at IS NULL | Filter in query |

---

## 5. State Transitions

### Search State Machine

```
┌─────────┐
│  Idle   │ ◄─────────────────────────────────────┐
└────┬────┘                                        │
     │ user types                                  │
     ▼                                             │
┌─────────┐                                        │
│Debounce │ (500ms timer running)                  │
└────┬────┘                                        │
     │ timer fires                                 │
     ▼                                             │
┌─────────┐                                        │
│ Loading │ (API call in progress)                 │
└────┬────┘                                        │
     │                                             │
     ├───────────────────┐                         │
     │ success           │ error                   │
     ▼                   ▼                         │
┌─────────┐        ┌─────────┐                     │
│ Results │        │  Error  │                     │
└────┬────┘        └────┬────┘                     │
     │                   │                         │
     │ user clears       │ user retries            │
     │ or new search     │                         │
     └───────────────────┴─────────────────────────┘
```

### AsyncValue States

```dart
sealed class SearchState {}

// Initial state - no search performed
class SearchStateIdle extends SearchState {}

// Loading state - debounce timer active or API call in progress
class SearchStateLoading extends SearchState {}

// Results state - search completed successfully
class SearchStateResults extends SearchState {
  final SearchResults results;
  SearchStateResults(this.results);
}

// Empty state - search completed but no results
class SearchStateEmpty extends SearchState {
  final String query;
  SearchStateEmpty(this.query);
}

// Error state - search failed
class SearchStateError extends SearchState {
  final String message;
  final String query;
  SearchStateError(this.message, this.query);
}

// Using AsyncValue (simpler):
// AsyncValue.loading() → Loading
// AsyncValue.data(SearchResults.empty()) → Empty
// AsyncValue.data(SearchResults(...)) → Results
// AsyncValue.error(e, stack) → Error
```

---

## 6. Hive Adapter Registration

```dart
// In main.dart, add after existing adapters:

// Adapter ID 8: SearchResultsCache
try {
  if (!Hive.isAdapterRegistered(8)) {
    Hive.registerAdapter(SearchResultsCacheAdapter());
  }
} catch (e) {
  debugPrint('SearchResultsCacheAdapter already registered: $e');
}

// Open boxes
try {
  await Hive.openBox<String>('search_history');
} catch (e) {
  debugPrint('⚠️ Corrupted search_history, clearing: $e');
  await Hive.deleteBoxFromDisk('search_history');
  await Hive.openBox<String>('search_history');
}

try {
  await Hive.openBox<SearchResultsCache>('search_results_cache');
} catch (e) {
  debugPrint('⚠️ Corrupted search_results_cache, clearing: $e');
  await Hive.deleteBoxFromDisk('search_results_cache');
  await Hive.openBox<SearchResultsCache>('search_results_cache');
}
```

---

## 7. Privacy Considerations

| Data | Storage | Retention | GDPR Basis |
|------|---------|-----------|------------|
| Search queries (history) | Local only (Hive) | Until user clears | Legitimate interest (UX) |
| Search results (cache) | Local only (Hive) | 5 minutes TTL | Legitimate interest (performance) |
| FTS queries | Not logged on server | N/A | N/A |

**Privacy Compliance**:
- No search query tracking on server
- History stored locally, never synced
- User can clear history anytime
- Cache auto-expires (5 min TTL)
