# Research: Search Feature (010-search)

**Date**: 2025-01-30
**Status**: Complete

---

## 1. Debouncing Pattern (Existing)

### Decision: Reuse ProfileSearchNotifier Pattern

**Location**: `nova/lib/features/profile/presentation/providers/profile_search_provider.dart`

```dart
class ProfileSearchNotifier extends StateNotifier<AsyncValue<List<Profile>>> {
  Timer? _debounceTimer;
  String _currentQuery = '';

  void search(String query) {
    _currentQuery = query.trim();
    _debounceTimer?.cancel();

    if (_currentQuery.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();

    // 500ms debounce
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _performSearch(_currentQuery);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final results = await repository.searchProfiles(query);
      // Race condition prevention
      if (_currentQuery == query) {
        state = AsyncValue.data(results);
      }
    } catch (e, stack) {
      if (_currentQuery == query) {
        state = AsyncValue.error(e, stack);
      }
    }
  }
}
```

**Rationale**:
- Proven pattern in production
- Race condition handling built-in
- AsyncValue state management (loading, data, error)
- 500ms matches spec requirement

**Alternatives Considered**:
- RxDart debounce: More complex, adds dependency
- simple Timer without race check: Could show stale results

---

## 2. Full-Text Search Implementation

### Decision: GIN Full-Text Search with Generated Column

**Migration SQL** (011_search_feature.sql):

```sql
-- Add FTS column to events (generated, auto-updates)
ALTER TABLE events
ADD COLUMN IF NOT EXISTS fts tsvector
GENERATED ALWAYS AS (
  to_tsvector('italian',
    COALESCE(title, '') || ' ' ||
    COALESCE(description, '') || ' ' ||
    COALESCE(location, '')
  )
) STORED;

-- GIN index for fast queries
CREATE INDEX IF NOT EXISTS idx_events_fts
  ON events USING gin(fts)
  WHERE status = 'approved';

-- Same for profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS fts tsvector
GENERATED ALWAYS AS (
  to_tsvector('italian',
    COALESCE(full_name, '') || ' ' ||
    COALESCE(username, '') || ' ' ||
    COALESCE(class, '')
  )
) STORED;

CREATE INDEX IF NOT EXISTS idx_profiles_fts
  ON profiles USING gin(fts)
  WHERE deleted_at IS NULL AND profile_visible = TRUE;
```

**Dart Query Pattern**:

```dart
final events = await _supabase
    .from('events')
    .select('id, title, description, location, event_date, image_url, creator_id')
    .textSearch('fts', query, config: 'italian', type: TextSearchType.websearch)
    .eq('status', 'approved')
    .gte('event_date', DateTime.now().toIso8601String())
    .order('created_at', ascending: false)
    .limit(20);
```

**Rationale**:
- 3-5x faster than ILIKE queries
- Italian stemming (studentesse → student)
- websearch type: handles natural language safely
- Generated column: auto-updates, no triggers needed

**Alternatives Considered**:
- ILIKE with OR: 150-300ms vs 30-60ms for FTS
- External search (Algolia): Overkill, adds cost
- pg_trgm: Good for typos but slower for Italian

---

## 3. Hive Cache Strategy

### Decision: Two Separate Boxes

**Box 1: search_history** (Adapter ID: 8)
- Stores: List of recent search queries
- Max: 10 items (FIFO)
- TTL: Permanent (persists across sessions)
- Model: Simple String list (no custom adapter needed)

**Box 2: search_results_cache** (Adapter ID: 9)
- Stores: Map<query, SearchResultsModel>
- TTL: 5 minutes
- Max: 50 entries (LRU eviction)
- Model: Custom adapter for SearchResultsModel

**Implementation Pattern** (from main.dart):

```dart
// In main.dart - register new adapters
try {
  if (!Hive.isAdapterRegistered(8)) {
    Hive.registerAdapter(SearchResultsCacheAdapter());
  }
} catch (e) {
  debugPrint('SearchResultsCacheAdapter already registered: $e');
}

// Open boxes
await Hive.openBox<String>('search_history');
await Hive.openBox<SearchResultsCache>('search_results_cache');
```

**Rationale**:
- Separates concerns (history vs cache)
- String box for history = no adapter needed
- Cache with TTL prevents stale data

---

## 4. Offline Search Strategy

### Decision: Simple contains() Filter on Cached Data

```dart
Future<SearchResults> searchOffline(String query) async {
  final cachedEvents = await _eventsLocalDataSource.getCachedEvents();
  final cachedProfiles = await _profileLocalDataSource.getAllProfiles();

  final queryLower = query.toLowerCase();

  final filteredEvents = cachedEvents.where((e) =>
    e.title.toLowerCase().contains(queryLower) ||
    e.description.toLowerCase().contains(queryLower) ||
    e.location?.toLowerCase().contains(queryLower) == true
  ).take(20).toList();

  final filteredProfiles = cachedProfiles.where((p) =>
    p.fullName.toLowerCase().contains(queryLower) ||
    p.username.toLowerCase().contains(queryLower) ||
    p.classYear?.toLowerCase().contains(queryLower) == true
  ).take(20).toList();

  return SearchResults(
    events: filteredEvents,
    profiles: filteredProfiles,
    isOffline: true,
  );
}
```

**Rationale**:
- No FTS offline (no PostgreSQL available)
- Simple but effective for cached data
- Shows "Risultati offline" indicator

**Alternatives Considered**:
- SQLite FTS: Too complex for mobile
- Client-side Fuzzy search: Overkill for MVP

---

## 5. UI Pattern Selection

### Decision: Dedicated SearchScreen with Two Sections

**Layout**:
```
┌─────────────────────────────────────┐
│ ← Cerca                             │  AppBar
├─────────────────────────────────────┤
│ [🔍 Cerca eventi e studenti...]     │  AdaptiveSearchBar
├─────────────────────────────────────┤
│ [basket] [festa] [marco]            │  RecentSearchesChips
├─────────────────────────────────────┤
│ ▼ Eventi (5)                        │  SectionHeader
│ ┌─────────────────────────────────┐ │
│ │ 🖼️ Torneo Basket                │ │  EventSearchTile
│ │    📅 15 Feb • 📍 Palestra      │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ ▼ Utenti (2)                        │  SectionHeader
│ ┌─────────────────────────────────┐ │
│ │ 👤 Marco Rossi                  │ │  ProfileSearchTile
│ │    4A                           │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Rationale**:
- Matches user expectation (brainstorming decision)
- Clear separation of result types
- Reuses existing tile patterns from feed

---

## 6. Platform-Adaptive Search Bar

### Decision: AdaptiveSearchBar Widget

```dart
class AdaptiveSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoSearchTextField(
        controller: controller,
        placeholder: placeholder,
        onChanged: onChanged,
        onSuffixTap: onClear,
      );
    }

    return SearchBar(
      controller: controller,
      hintText: placeholder,
      onChanged: onChanged,
      trailing: [
        if (controller.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: onClear,
          ),
      ],
    );
  }
}
```

**Rationale**:
- Native look on each platform
- CupertinoSearchTextField for iOS
- Material SearchBar for Android
- Follows Principle 6 (DESIGN_SYSTEM_STRICT)

---

## 7. Provider Architecture

### Decision: Layered Riverpod Providers

```dart
// 1. Remote datasource
final searchRemoteDataSourceProvider = Provider((ref) {
  return SearchRemoteDataSource(ref.watch(supabaseClientProvider));
});

// 2. Local datasource (history + cache)
final searchLocalDataSourceProvider = Provider((ref) {
  return SearchLocalDataSource(
    Hive.box<String>('search_history'),
    Hive.box<SearchResultsCache>('search_results_cache'),
  );
});

// 3. Repository
final searchRepositoryProvider = Provider((ref) {
  return SearchRepository(
    ref.watch(searchRemoteDataSourceProvider),
    ref.watch(searchLocalDataSourceProvider),
    ref.watch(eventsLocalDataSourceProvider),
    ref.watch(profileLocalDataSourceProvider),
    Connectivity(),
  );
});

// 4. Search state (debounced)
final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, AsyncValue<SearchResults>>((ref) {
  return SearchNotifier(ref);
});

// 5. Search history
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier(ref.watch(searchLocalDataSourceProvider));
});
```

**Rationale**:
- Follows existing Nova architecture
- Dependency injection via ref.watch
- Separation of concerns (remote, local, repository, UI state)

---

## 8. Performance Benchmarks

| Operation | Target | Expected |
|-----------|--------|----------|
| FTS Query (events) | <100ms | ~30-50ms |
| FTS Query (profiles) | <100ms | ~20-40ms |
| Parallel queries | <100ms | ~50-60ms (max of both) |
| Cache hit | <10ms | ~1-5ms |
| Offline search | <50ms | ~10-30ms |
| Debounce delay | 500ms | 500ms (fixed) |

---

## 9. Existing Code to Reuse

| Component | Source | Reuse Type |
|-----------|--------|------------|
| Debounce pattern | `profile_search_provider.dart` | Copy & adapt |
| ILIKE query | `profile_remote_datasource.dart:247` | Replace with FTS |
| Chip UI | `user_search_widget.dart` | Direct reuse |
| Hive setup | `main.dart:76-171` | Extend pattern |
| AsyncValue handling | Throughout codebase | Standard pattern |
| Platform detection | `PlatformUtils.isIOS` | Direct reuse |

---

## 10. Migration Checklist

- [ ] Create `011_search_feature.sql` migration
- [ ] Add FTS column to events table
- [ ] Add FTS column to profiles table
- [ ] Create GIN indexes
- [ ] Test Italian stemming works
- [ ] Verify RLS policies allow FTS queries

---

## Summary

All technical decisions have been made based on:
1. Existing Nova patterns (debouncing, Hive, providers)
2. Supabase FTS best practices (GIN, Italian config, websearch type)
3. Constitution requirements (privacy, performance, design system)
4. Brainstorming decisions (offline, cache, two sections)

No NEEDS CLARIFICATION items remain.
