# Quickstart: Search Feature (010-search)

**Date**: 2025-01-30

---

## 1. Quick Setup

### Prerequisites

Before implementing Search, ensure:
- [ ] Supabase project running
- [ ] Events and Profiles tables exist
- [ ] Hive initialized in main.dart
- [ ] EventModel and ProfileModel adapters registered

### Migration

Run in Supabase SQL Editor:

```sql
-- 011_search_feature.sql

-- Events FTS
ALTER TABLE events
ADD COLUMN IF NOT EXISTS fts tsvector
GENERATED ALWAYS AS (
  to_tsvector('italian',
    COALESCE(title, '') || ' ' ||
    COALESCE(description, '') || ' ' ||
    COALESCE(location, '')
  )
) STORED;

CREATE INDEX IF NOT EXISTS idx_events_fts
  ON events USING gin(fts)
  WHERE status = 'approved';

-- Profiles FTS
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

---

## 2. Integration Scenarios

### Scenario 1: Basic Search Flow

**User Action**: Open search, type "basket", wait 500ms

**Expected Flow**:
1. User taps search icon in MainFeedScreen AppBar
2. SearchScreen opens with empty state
3. User types "basket"
4. After 500ms debounce, search executes
5. Results show in two sections: Events (N), Utenti (M)
6. User taps on event → navigates to EventDetailScreen

**Test Code**:
```dart
// Widget test
testWidgets('search shows results after debounce', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...],
      child: SearchScreen(),
    ),
  );

  // Find search bar and enter text
  await tester.enterText(find.byType(TextField), 'basket');

  // Wait for debounce (500ms) + API call
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();

  // Verify results sections appear
  expect(find.text('Eventi'), findsOneWidget);
  expect(find.text('Utenti'), findsOneWidget);
});
```

---

### Scenario 2: Search History

**User Action**: Search "festa", close search, reopen

**Expected Flow**:
1. User searches "festa", sees results
2. User navigates away or closes search
3. User reopens SearchScreen
4. "festa" appears as chip in recent searches
5. User taps chip → search "festa" executes

**Test Code**:
```dart
testWidgets('search history persists', (tester) async {
  // First search
  await tester.enterText(find.byType(TextField), 'festa');
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();

  // Navigate away and back
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.search));
  await tester.pumpAndSettle();

  // Verify history chip
  expect(find.text('festa'), findsOneWidget);
  expect(find.byType(Chip), findsWidgets);
});
```

---

### Scenario 3: Offline Search

**User Action**: Go offline, search "basket"

**Expected Flow**:
1. Device loses network
2. User searches "basket"
3. Results from local cache appear
4. Banner shows "Ricerca offline - risultati limitati"
5. Results are filtered with simple contains()

**Test Code**:
```dart
testWidgets('offline search uses cached data', (tester) async {
  // Mock offline state
  when(mockConnectivity.checkConnectivity())
      .thenAnswer((_) async => [ConnectivityResult.none]);

  // Pre-populate cache
  final eventsBox = Hive.box<EventModel>('events_cache');
  eventsBox.addAll([mockEvent1, mockEvent2]);

  await tester.enterText(find.byType(TextField), 'basket');
  await tester.pumpAndSettle();

  // Verify offline banner
  expect(find.text('Ricerca offline'), findsOneWidget);

  // Verify results from cache
  expect(find.byType(EventSearchTile), findsWidgets);
});
```

---

### Scenario 4: Cache Hit

**User Action**: Search "basket", wait 1 min, search "basket" again

**Expected Flow**:
1. First search "basket" → API call, results cached
2. Wait <5 minutes
3. Search "basket" again
4. Results appear instantly from cache (no loading)
5. No API call made

**Test Code**:
```dart
test('cache returns results without API call', () async {
  final repo = SearchRepository(...);

  // First search - API call
  await repo.search('basket');
  verify(mockRemoteDataSource.searchEvents('basket')).called(1);

  // Second search - should hit cache
  await repo.search('basket');
  verifyNever(mockRemoteDataSource.searchEvents('basket'));
});
```

---

### Scenario 5: Empty Results

**User Action**: Search "xyz123abc"

**Expected Flow**:
1. User searches non-matching query
2. After debounce, search executes
3. Empty state shows: "Nessun risultato per 'xyz123abc'"
4. Suggestion: "Prova con termini diversi"

---

### Scenario 6: Navigation from Results

**User Action**: Tap on event result, then back

**Expected Flow**:
1. User searches, sees results
2. User taps EventSearchTile
3. EventDetailScreen opens with event details
4. User presses back
5. SearchScreen restored with same query and results

---

## 3. File Structure

```
lib/features/search/
├── data/
│   ├── datasources/
│   │   ├── search_remote_datasource.dart
│   │   └── search_local_datasource.dart
│   ├── models/
│   │   └── search_results_cache.dart
│   │   └── search_results_cache.g.dart (generated)
│   └── repositories/
│       └── search_repository.dart
├── domain/
│   └── entities/
│       └── search_results.dart
└── presentation/
    ├── providers/
    │   ├── search_provider.dart
    │   └── search_history_provider.dart
    ├── screens/
    │   └── search_screen.dart
    └── widgets/
        ├── adaptive_search_bar.dart
        ├── search_results_section.dart
        ├── event_search_tile.dart
        ├── profile_search_tile.dart
        ├── recent_searches_widget.dart
        ├── search_empty_state.dart
        └── search_loading_skeleton.dart
```

---

## 4. Key Implementation Points

### 1. Add Search Icon to MainFeedScreen

```dart
// In MainFeedScreen AppBar
actions: [
  IconButton(
    icon: const Icon(Icons.search),
    onPressed: () => Navigator.push(
      context,
      PlatformUtils.isIOS
          ? CupertinoPageRoute(builder: (_) => const SearchScreen())
          : MaterialPageRoute(builder: (_) => const SearchScreen()),
    ),
  ),
  // ... other actions
],
```

### 2. Register Hive Adapters

```dart
// In main.dart, after existing adapters
if (!Hive.isAdapterRegistered(8)) {
  Hive.registerAdapter(SearchResultsCacheAdapter());
}

// Open boxes
await Hive.openBox<String>('search_history');
await Hive.openBox<SearchResultsCache>('search_results_cache');
```

### 3. Provider Setup

```dart
// search_provider.dart
final searchNotifierProvider = StateNotifierProvider<
    SearchNotifier, AsyncValue<SearchResults>>((ref) {
  return SearchNotifier(ref);
});

final searchHistoryProvider = StateNotifierProvider<
    SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier(ref.watch(searchLocalDataSourceProvider));
});
```

---

## 5. Testing Checklist

### Unit Tests
- [ ] SearchRepository.search() returns combined results
- [ ] SearchRepository handles offline correctly
- [ ] Cache TTL expires after 5 minutes
- [ ] History limited to 10 items

### Widget Tests
- [ ] SearchScreen renders initial state
- [ ] Debouncing works (500ms)
- [ ] Results sections display correctly
- [ ] Navigation works from tiles
- [ ] History chips are tappable

### Integration Tests
- [ ] Full search flow (type → results → tap → detail → back)
- [ ] Offline flow with cached data
- [ ] Cache invalidation works

---

## 6. Common Issues

### Issue: FTS not finding results

**Check**:
1. Migration applied? `SELECT * FROM events WHERE fts IS NOT NULL LIMIT 1;`
2. Italian config exists? `SELECT * FROM pg_ts_config WHERE cfgname = 'italian';`
3. GIN index created? `SELECT * FROM pg_indexes WHERE indexname LIKE '%fts%';`

### Issue: Slow queries

**Check**:
1. GIN index being used? Run `EXPLAIN ANALYZE` on query
2. Partial index condition matches query filters?

### Issue: Cache not working

**Check**:
1. Hive box opened in main.dart?
2. Adapter registered with correct typeId (8)?
3. TTL calculation using UTC time?
