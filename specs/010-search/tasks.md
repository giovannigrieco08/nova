# Tasks: Search (Cerca)

**Input**: Design documents from `/specs/010-search/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not explicitly requested - omitted.

**Organization**: Tasks grouped by user story priority (P1 → P2 → P3) to enable incremental delivery.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US11)
- Include exact file paths in descriptions

## Path Conventions

- **Flutter mobile**: `nova/lib/features/search/`
- **Database**: `supabase/migrations/`
- **Existing files**: `nova/lib/main.dart`, `nova/lib/features/events/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create feature directory structure and database migration

- [ ] T001 Create feature directory structure at `nova/lib/features/search/` per plan.md
- [ ] T002 [P] Create database migration `supabase/migrations/011_search_feature.sql` with FTS columns and GIN indexes
- [ ] T003 [P] Create domain entity `nova/lib/features/search/domain/entities/search_results.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core data layer that MUST be complete before ANY user story UI

**⚠️ CRITICAL**: No user story UI work can begin until this phase is complete

- [ ] T004 Create SearchRemoteDataSource in `nova/lib/features/search/data/datasources/search_remote_datasource.dart` with FTS queries for events and profiles
- [ ] T005 [P] Create SearchLocalDataSource in `nova/lib/features/search/data/datasources/search_local_datasource.dart` for Hive history and cache
- [ ] T006 [P] Create SearchResultsCache Hive model in `nova/lib/features/search/data/models/search_results_cache.dart`
- [ ] T007 Run `flutter pub run build_runner build` to generate `search_results_cache.g.dart` adapter
- [ ] T008 Create SearchRepository in `nova/lib/features/search/data/repositories/search_repository.dart` with search(), searchOffline(), caching logic
- [ ] T009 Register SearchResultsCacheAdapter (typeId: 8) and open Hive boxes in `nova/lib/main.dart`
- [ ] T010 Create search providers in `nova/lib/features/search/presentation/providers/search_provider.dart` (searchNotifierProvider, searchRepositoryProvider, etc.)

**Checkpoint**: Data layer ready - UI implementation can now begin

---

## Phase 3: User Stories 1-5 - Core Search (Priority: P1) 🎯 MVP

**Goal**: Basic search functionality: events + profiles, live search, two sections, navigation

**Independent Test**: Search "basket", see events and profiles in separate sections, tap to navigate

### US1-2: Search Events & Profiles

- [ ] T011 [P] [US1] Create EventSearchTile widget in `nova/lib/features/search/presentation/widgets/event_search_tile.dart`
- [ ] T012 [P] [US2] Create ProfileSearchTile widget in `nova/lib/features/search/presentation/widgets/profile_search_tile.dart`

### US3: Live Search with Debouncing

- [ ] T013 [US3] Create SearchNotifier StateNotifier with 500ms debouncing in `nova/lib/features/search/presentation/providers/search_provider.dart` (extend T010)
- [ ] T014 [P] [US3] Create AdaptiveSearchBar widget in `nova/lib/features/search/presentation/widgets/adaptive_search_bar.dart` (CupertinoSearchTextField / Material SearchBar)

### US4: Separate Sections

- [ ] T015 [US4] Create SearchResultsSection widget in `nova/lib/features/search/presentation/widgets/search_results_section.dart` with header "Eventi (N)" / "Utenti (N)"

### US5: Navigation + Screen Assembly

- [ ] T016 [US5] Create SearchScreen in `nova/lib/features/search/presentation/screens/search_screen.dart` assembling all widgets
- [ ] T017 [US5] Add search icon to MainFeedScreen AppBar in `nova/lib/features/events/presentation/screens/main_feed_screen.dart`
- [ ] T018 [US5] Implement navigation from EventSearchTile to EventDetailScreen (platform-adaptive)
- [ ] T019 [US5] Implement navigation from ProfileSearchTile to OtherProfileScreen (platform-adaptive)

**Checkpoint**: Core search MVP complete - search events/profiles, see results in sections, navigate to details

---

## Phase 4: User Stories 6-8 - Enhanced UX (Priority: P2)

**Goal**: Search history, text highlighting, clear UI states

**Independent Test**: See recent searches as chips, highlighted text in results, shimmer loading

### US6: Search History

- [ ] T020 [US6] Create SearchHistoryNotifier in `nova/lib/features/search/presentation/providers/search_history_provider.dart`
- [ ] T021 [US6] Create RecentSearchesWidget in `nova/lib/features/search/presentation/widgets/recent_searches_widget.dart` with chips
- [ ] T022 [US6] Integrate RecentSearchesWidget into SearchScreen, save searches on execution

### US7: Text Highlighting

- [ ] T023 [US7] Create highlightText() helper function for case-insensitive bold highlighting
- [ ] T024 [US7] Apply highlighting to EventSearchTile title
- [ ] T025 [US7] Apply highlighting to ProfileSearchTile name

### US8: UI States

- [ ] T026 [P] [US8] Create SearchEmptyState widget in `nova/lib/features/search/presentation/widgets/search_empty_state.dart` (initial + no results)
- [ ] T027 [P] [US8] Create SearchLoadingSkeleton widget in `nova/lib/features/search/presentation/widgets/search_loading_skeleton.dart` (shimmer)
- [ ] T028 [US8] Integrate empty/loading/error states into SearchScreen

**Checkpoint**: Enhanced UX complete - history, highlighting, clear states

---

## Phase 5: User Stories 9-11 - Optimization (Priority: P3)

**Goal**: Offline search, result caching, smooth animations

**Independent Test**: Search offline shows cached results, repeat search is instant, 60fps scroll

### US9: Offline Search

- [ ] T029 [US9] Implement searchOffline() method in SearchRepository using contains() on cached data
- [ ] T030 [US9] Add offline detection in SearchNotifier using connectivity_plus
- [ ] T031 [US9] Show "Ricerca offline" banner in SearchScreen when offline

### US10: Results Cache

- [ ] T032 [US10] Implement cache check with 5-min TTL in SearchRepository.search()
- [ ] T033 [US10] Cache results after successful search
- [ ] T034 [US10] Add cache invalidation on feed refresh

### US11: Animations

- [ ] T035 [P] [US11] Add staggered fade-in animation to search results list
- [ ] T036 [US11] Ensure 60fps scroll performance with ListView.builder optimization

**Checkpoint**: All optimizations complete - offline, cache, smooth animations

---

## Phase 6: Polish & Integration

**Purpose**: Final integration, edge cases, verification

- [ ] T037 Handle edge cases: empty query, <2 chars, special characters
- [ ] T038 Verify design system compliance (NovaColors, NovaSpacing, NovaTextStyles, NovaRadius)
- [ ] T039 Test Italian FTS stemming with real queries ("studentesse", "conferenze", etc.)
- [ ] T040 Run quickstart.md validation scenarios
- [ ] T041 Verify platform-adaptive behavior on iOS and Android

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1: Setup           → No dependencies
Phase 2: Foundational    → Depends on Setup (T001-T003)
Phase 3: P1 User Stories → Depends on Foundational (T004-T010)
Phase 4: P2 User Stories → Depends on Phase 3 MVP
Phase 5: P3 User Stories → Depends on Phase 4
Phase 6: Polish          → Depends on desired phases complete
```

### User Story Dependencies

| Story | Depends On | Can Parallel With |
|-------|------------|-------------------|
| US1 (Events) | Foundational | US2, US3, US4 |
| US2 (Profiles) | Foundational | US1, US3, US4 |
| US3 (Debounce) | Foundational | US1, US2, US4 |
| US4 (Sections) | US1, US2 | - |
| US5 (Navigation) | US1, US2, US4 | - |
| US6 (History) | Phase 3 complete | US7, US8 |
| US7 (Highlight) | US1, US2 | US6, US8 |
| US8 (States) | Phase 3 complete | US6, US7 |
| US9 (Offline) | Phase 4 complete | US10, US11 |
| US10 (Cache) | Phase 4 complete | US9, US11 |
| US11 (Animation) | Phase 4 complete | US9, US10 |

### Parallel Opportunities

**Phase 2 (can run in parallel):**
```
T004, T005, T006 → All datasources/models in different files
```

**Phase 3 (can run in parallel):**
```
T011, T012 → EventSearchTile and ProfileSearchTile
T014 → AdaptiveSearchBar (independent widget)
```

**Phase 4 (can run in parallel):**
```
T026, T027 → Empty state and Loading skeleton
```

**Phase 5 (can run in parallel):**
```
T029-T031 (US9) || T032-T034 (US10) || T035-T036 (US11)
```

---

## Implementation Strategy

### MVP First (P1 Only) - Recommended

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T010)
3. Complete Phase 3: P1 User Stories (T011-T019)
4. **STOP and VALIDATE**: Test search with real data
5. Deploy if MVP is sufficient

### Incremental Delivery

1. **MVP**: Setup + Foundational + P1 → Working search
2. **Enhanced**: Add P2 (T020-T028) → History, highlighting, states
3. **Optimized**: Add P3 (T029-T036) → Offline, cache, animations
4. **Polished**: Add Phase 6 (T037-T041) → Edge cases, verification

### Effort by Phase

| Phase | Tasks | Estimated |
|-------|-------|-----------|
| Phase 1: Setup | 3 | 1h |
| Phase 2: Foundational | 7 | 3-4h |
| Phase 3: P1 (MVP) | 9 | 4-5h |
| Phase 4: P2 | 9 | 3-4h |
| Phase 5: P3 | 8 | 2-3h |
| Phase 6: Polish | 5 | 1-2h |
| **Total** | **41** | **~15-18h** |

---

## Notes

- [P] tasks = different files, no dependencies
- [USx] label maps task to specific user story
- Each phase can be tested independently
- Stop at any checkpoint to validate
- Database migration (T002) requires running on Supabase before testing FTS
- Commit after each task or logical group
