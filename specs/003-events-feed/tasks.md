# Tasks: Events Feed (Instagram-Style Infinite Scroll)

**Input**: Design documents from `/specs/003-events-feed/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Tests are NOT explicitly requested in the specification, therefore test tasks are EXCLUDED from this task list. Testing will be done manually via quickstart.md integration scenarios.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Flutter feature-first clean architecture:
- Models: `nova/lib/features/events/data/models/`
- Repositories: `nova/lib/features/events/data/repositories/`
- Data sources: `nova/lib/features/events/data/data_sources/`
- Entities: `nova/lib/features/events/domain/entities/`
- Use cases: `nova/lib/features/events/domain/usecases/`
- Providers: `nova/lib/features/events/presentation/providers/`
- Screens: `nova/lib/features/events/presentation/screens/`
- Widgets: `nova/lib/features/events/presentation/widgets/`
- Shared widgets: `nova/lib/shared/widgets/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and feature structure

- [ ] T001 Create feature directory structure per plan.md in nova/lib/features/events/
- [ ] T002 [P] Add cached_network_image dependency to nova/pubspec.yaml
- [ ] T003 [P] Initialize Hive boxes for events cache and offline queue in nova/lib/main.dart
- [ ] T004 [P] Create Hive TypeAdapters: EventModelAdapter in nova/lib/features/events/data/models/event_model.dart
- [ ] T005 [P] Create Hive TypeAdapters: OfflineActionAdapter in nova/lib/features/events/domain/entities/offline_action.dart

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Database & RLS Policies

- [ ] T006 Execute RLS policies SQL from contracts/rls-policies.sql in Supabase SQL Editor
- [ ] T007 Create events table with indexes (event_date, status, created_at) via Supabase Dashboard
- [ ] T008 [P] Create users table with indexes (email, class) via Supabase Dashboard
- [ ] T009 [P] Create likes table with composite primary key (user_id, event_id) via Supabase Dashboard
- [ ] T010 [P] Create participations table with composite primary key (user_id, event_id) via Supabase Dashboard
- [ ] T011 [P] Create comments table with VARCHAR(500) constraint via Supabase Dashboard
- [ ] T012 [P] Create reports table via Supabase Dashboard
- [ ] T013 Enable Supabase Realtime on events and comments tables via Supabase Dashboard → Database → Publications

### Core Domain Entities

- [ ] T014 [P] Create Event entity in nova/lib/features/events/domain/entities/event.dart
- [ ] T015 [P] Create Comment entity in nova/lib/features/events/domain/entities/comment.dart
- [ ] T016 [P] Create UserProfile entity in nova/lib/features/events/domain/entities/user_profile.dart
- [ ] T017 [P] Create OfflineAction entity with Hive annotations in nova/lib/features/events/domain/entities/offline_action.dart

### Core Data Models (Hive + Supabase Serialization)

- [ ] T018 [P] Create EventModel with fromJson/toJson in nova/lib/features/events/data/models/event_model.dart
- [ ] T019 [P] Create CommentModel with fromJson/toJson in nova/lib/features/events/data/models/comment_model.dart
- [ ] T020 [P] Create LikeModel with fromJson/toJson in nova/lib/features/events/data/models/like_model.dart
- [ ] T021 [P] Create ParticipationModel with fromJson/toJson in nova/lib/features/events/data/models/participation_model.dart
- [ ] T022 [P] Create ReportModel with fromJson/toJson in nova/lib/features/events/data/models/report_model.dart

### Core Data Sources

- [ ] T023 [P] Implement EventsLocalDataSource (Hive cache operations) in nova/lib/features/events/data/data_sources/events_local_data_source.dart
- [ ] T024 [P] Implement EventsRemoteDataSource (Supabase queries) in nova/lib/features/events/data/data_sources/events_remote_data_source.dart
- [ ] T025 Create OfflineQueueRepository (exponential backoff, Hive queue) in nova/lib/features/events/data/repositories/offline_queue_repository.dart

### Shared Utilities

- [ ] T026 [P] Create DateFormatter utility (relative time + formatted dates) in nova/lib/features/events/presentation/utils/date_formatter.dart
- [ ] T027 [P] Create ImageOptimizer utility (WebP conversion, progressive loading) in nova/lib/features/events/presentation/utils/image_optimizer.dart

### Shared Widgets (Reusable Across Stories)

- [ ] T028 [P] Create OptimisticLikeButton widget in nova/lib/shared/widgets/optimistic_like_button.dart
- [ ] T029 [P] Create ParticipantBadge widget (green checkmark) in nova/lib/shared/widgets/participant_badge.dart
- [ ] T030 [P] Create OfflineBanner widget (dismissible) in nova/lib/features/events/presentation/widgets/offline_banner.dart

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - View Infinite Scroll Events Feed (Priority: P1) 🎯 MVP

**Goal**: Display paginated feed of approved events with offline-first caching and pull-to-refresh

**Independent Test**: Launch app → Events tab → See 20 events → Scroll to load more → Pull to refresh

### Implementation for User Story 1

- [ ] T031 [P] [US1] Create EventsRepository with cache-first pattern in nova/lib/features/events/data/repositories/events_repository.dart
- [ ] T032 [P] [US1] Create GetEventsFeedUseCase in nova/lib/features/events/domain/usecases/get_events_feed.dart
- [ ] T033 [US1] Create EventsFeedProvider (AsyncNotifier) with pagination in nova/lib/features/events/presentation/providers/events_feed_provider.dart
- [ ] T034 [P] [US1] Create EventCard widget (glassmorphic, 16:9 image) in nova/lib/features/events/presentation/widgets/event_card.dart
- [ ] T035 [US1] Create EventsFeedScreen (infinite scroll, pull-to-refresh) in nova/lib/features/events/presentation/screens/events_feed_screen.dart
- [ ] T036 [US1] Implement ScrollController with pagination trigger (within 3 items of bottom) in EventsFeedScreen
- [ ] T037 [US1] Implement RefreshIndicator with cache reload logic in EventsFeedScreen
- [ ] T038 [US1] Add empty state UI ("No events yet. Be the first to create one!") in EventsFeedScreen
- [ ] T039 [US1] Add loading indicators (centered for first page, bottom for pagination) in EventsFeedScreen
- [ ] T040 [US1] Integrate EventsFeedScreen into main navigation (update MainFeedScreen or create tab) in nova/lib/features/events/presentation/screens/main_feed_screen.dart

**Checkpoint**: At this point, User Story 1 should be fully functional - users can view and scroll through approved events with offline caching

---

## Phase 4: User Story 2 - View Event Detail Screen (Priority: P1)

**Goal**: Display full event details with image gallery, creator profile, participants, and pull-to-refresh

**Independent Test**: Tap any event card → See full details → Swipe images → Pull to refresh

### Implementation for User Story 2

- [ ] T041 [P] [US2] Create EventDetailProvider (AsyncNotifier) with Realtime event updates in nova/lib/features/events/presentation/providers/event_detail_provider.dart
- [ ] T042 [P] [US2] Create ImageGallery widget (swipeable with dot indicators) in nova/lib/features/events/presentation/widgets/image_gallery.dart
- [ ] T043 [P] [US2] Create ParticipantAvatars widget (max 5 + overflow) in nova/lib/features/events/presentation/widgets/participant_avatars.dart
- [ ] T044 [US2] Create EventDetailScreen with hero animation in nova/lib/features/events/presentation/screens/event_detail_screen.dart
- [ ] T045 [US2] Implement RefreshIndicator with event/comments/participants reload in EventDetailScreen
- [ ] T046 [US2] Add navigation from EventCard to EventDetailScreen with Hero tag
- [ ] T047 [US2] Add creator profile display (tappable for future feature) in EventDetailScreen
- [ ] T048 [US2] Add participant list display with "No participants yet. Be the first!" empty state in EventDetailScreen
- [ ] T049 [US2] Create ParticipantsModal widget (scrollable full list) in nova/lib/features/events/presentation/screens/participants_modal.dart
- [ ] T050 [US2] Add back navigation with scroll position preservation in EventsFeedScreen

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - users can browse feed and view full event details

---

## Phase 5: User Story 3 - Like/Unlike Events with Optimistic UI (Priority: P2)

**Goal**: Instant like/unlike interactions with offline queue and exponential backoff retry

**Independent Test**: Tap heart icon → See instant red/grey change → Go offline → Like → See sync when online

### Implementation for User Story 3

- [ ] T051 [P] [US3] Create InteractionsRepository (likes + participations with optimistic UI) in nova/lib/features/events/data/repositories/interactions_repository.dart
- [ ] T052 [P] [US3] Create LikeEventUseCase with rollback logic in nova/lib/features/events/domain/usecases/like_event.dart
- [ ] T053 [US3] Create InteractionsProvider (like state management) in nova/lib/features/events/presentation/providers/interactions_provider.dart
- [ ] T054 [US3] Integrate OptimisticLikeButton into EventCard widget
- [ ] T055 [US3] Integrate OptimisticLikeButton into EventDetailScreen widget
- [ ] T056 [US3] Implement offline action queueing in InteractionsRepository
- [ ] T057 [US3] Implement exponential backoff retry (1s, 2s, 4s) in OfflineQueueRepository
- [ ] T058 [US3] Add notification on sync failure after 3 retries using flutter_local_notifications in OfflineQueueRepository
- [ ] T059 [US3] Create OfflineSyncProvider (background sync status) in nova/lib/features/events/presentation/providers/offline_sync_provider.dart
- [ ] T060 [US3] Add connectivity listener to trigger sync on network restore in nova/lib/main.dart

**Checkpoint**: At this point, User Stories 1, 2, AND 3 should all work independently - users can like events with instant feedback

---

## Phase 6: User Story 4 - Participate/Unparticipate in Events (Priority: P2)

**Goal**: Instant RSVP interactions with participant list updates and capacity enforcement

**Independent Test**: Tap "Participate" button → See instant UI change → Avatar appears in participant list → Badge on feed card

### Implementation for User Story 4

- [ ] T061 [P] [US4] Create ParticipateEventUseCase with rollback logic in nova/lib/features/events/domain/usecases/participate_event.dart
- [ ] T062 [US4] Extend InteractionsProvider with participation state management
- [ ] T063 [US4] Create ParticipationButton widget (optimistic UI) in nova/lib/features/events/presentation/widgets/participation_button.dart
- [ ] T064 [US4] Integrate ParticipationButton into EventDetailScreen
- [ ] T065 [US4] Integrate ParticipantBadge into EventCard widget (green checkmark if participating)
- [ ] T066 [US4] Add capacity check logic in ParticipateEventUseCase
- [ ] T067 [US4] Add "Event is full" snackbar handling in ParticipationButton widget
- [ ] T068 [US4] Update ParticipantAvatars widget to include current user when participating

**Checkpoint**: User Stories 1, 2, 3, AND 4 all work independently - users can RSVP to events

---

## Phase 7: User Story 5 - View and Post Real-Time Comments (Priority: P2)

**Goal**: Real-time comment threads with 500 char limit, character counter, and Supabase Realtime updates

**Independent Test**: Scroll to comments → Type comment → See "X/500" counter → Tap Send → See comment instantly → Second device sees it <2s

### Implementation for User Story 5

- [ ] T069 [P] [US5] Create CommentsRepository with Realtime subscriptions in nova/lib/features/events/data/repositories/comments_repository.dart
- [ ] T070 [P] [US5] Create PostCommentUseCase with optimistic UI in nova/lib/features/events/domain/usecases/post_comment.dart
- [ ] T071 [US5] Create CommentsProvider (StreamProvider for Realtime) in nova/lib/features/events/presentation/providers/comments_provider.dart
- [ ] T072 [P] [US5] Create CommentListItem widget (avatar, name, text, timestamp) in nova/lib/features/events/presentation/widgets/comment_list_item.dart
- [ ] T073 [P] [US5] Create CommentInputField widget (sticky, character counter, disabled send button) in nova/lib/features/events/presentation/widgets/comment_input_field.dart
- [ ] T074 [US5] Integrate comments section into EventDetailScreen (below event details)
- [ ] T075 [US5] Implement 500 character limit validation in CommentInputField (client-side + server-side VARCHAR(500))
- [ ] T076 [US5] Implement live character counter ("X/500") in CommentInputField
- [ ] T077 [US5] Implement send button enable/disable logic in CommentInputField
- [ ] T078 [US5] Add optimistic comment posting with loading indicator
- [ ] T079 [US5] Add error handling with retry button for failed comments
- [ ] T080 [US5] Add comment pagination (load 50 initially, more on scroll to top)
- [ ] T081 [US5] Add "No comments yet. Start the conversation!" empty state

**Checkpoint**: User Stories 1-5 all work independently - users can view feed, details, like, participate, and comment

---

## Phase 8: User Story 6 - Edit Own Events (Priority: P3)

**Goal**: Allow creators to edit their event text fields with Realtime broadcast to all viewers

**Independent Test**: View my event → Tap Edit → Change title/description → Save → See update instantly → Second device sees update

### Implementation for User Story 6

- [ ] T082 [P] [US6] Create UpdateEventUseCase in nova/lib/features/events/domain/usecases/update_event.dart
- [ ] T083 [US6] Create EditEventScreen with pre-filled form (text fields only, images display-only) in nova/lib/features/events/presentation/screens/edit_event_screen.dart
- [ ] T084 [US6] Add "Edit" button to EventDetailScreen (visible only to creator, check creator_id == auth.uid())
- [ ] T085 [US6] Implement form validation (title, description, date, time, location) in EditEventScreen
- [ ] T086 [US6] Add "Cancel" button with unsaved changes confirmation dialog in EditEventScreen
- [ ] T087 [US6] Add "Save" button with loading indicator in EditEventScreen
- [ ] T088 [US6] Implement event update broadcast via Supabase Realtime in EventDetailProvider
- [ ] T089 [US6] Add "Event updated successfully" snackbar and navigation back to detail screen

**Checkpoint**: User Stories 1-6 all work independently - creators can edit their events

---

## Phase 9: User Story 7 - Delete Own Events (Priority: P3)

**Goal**: Allow creators to permanently delete events with cascade behavior and participant notification warning

**Independent Test**: View my event → Tap "..." menu → Delete Event → Confirm → See event removed from feed

### Implementation for User Story 7

- [ ] T090 [P] [US7] Create DeleteEventUseCase in nova/lib/features/events/domain/usecases/delete_event.dart
- [ ] T091 [US7] Add "..." menu button to EventDetailScreen (visible only to creator)
- [ ] T092 [US7] Add "Delete Event" option with red destructive style in menu
- [ ] T093 [US7] Implement confirmation dialog ("Are you sure? This action cannot be undone.")
- [ ] T094 [US7] Add participant count check and warning ("X students are participating. They will be notified of the cancellation.")
- [ ] T095 [US7] Implement event deletion with cascade (likes, participations, comments, reports)
- [ ] T096 [US7] Add "Event deleted" snackbar and navigation back to feed
- [ ] T097 [US7] Remove deleted event from feed cache and UI immediately

**Checkpoint**: User Stories 1-7 all work independently - creators can delete their events

---

## Phase 10: User Story 8 - Report Inappropriate Events (Priority: P3)

**Goal**: Allow students to flag inappropriate content for moderator review

**Independent Test**: View event (not mine) → Tap "..." menu → Report Event → Select reason → Submit → See confirmation

### Implementation for User Story 8

- [ ] T098 [P] [US8] Create ReportsRepository in nova/lib/features/events/data/repositories/reports_repository.dart
- [ ] T099 [P] [US8] Create SubmitReportUseCase in nova/lib/features/events/domain/usecases/submit_report.dart
- [ ] T100 [US8] Add "Report Event" option to "..." menu (visible when creator_id != auth.uid())
- [ ] T101 [US8] Create ReportDialog widget with reason selection (Inappropriate, Spam, Harassment, Other) in nova/lib/features/events/presentation/widgets/report_dialog.dart
- [ ] T102 [US8] Add explanation text field (required) in ReportDialog
- [ ] T103 [US8] Implement report submission to reports table
- [ ] T104 [US8] Add "Report submitted. Moderators will review within 24 hours" snackbar
- [ ] T105 [US8] Keep event visible after reporting (not auto-hidden)

**Checkpoint**: All 8 user stories are now independently functional - complete feature set

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T106 [P] Add pull-to-refresh wrapper for EventsFeedScreen (FR-006a, FR-006b, FR-006c)
- [ ] T107 [P] Add pull-to-refresh wrapper for EventDetailScreen (FR-014a, FR-014b, FR-014c)
- [ ] T108 [P] Verify design system compliance (zero hardcoded colors, spacing, typography, radius) across all widgets
- [ ] T109 [P] Optimize image loading with cached_network_image blur-up effect across EventCard and ImageGallery
- [ ] T110 [P] Add reconnection indicator for Supabase Realtime disconnect/reconnect
- [ ] T111 Performance profiling with Flutter DevTools Timeline (verify 60fps scrolling)
- [ ] T112 Verify RLS policies in Supabase Dashboard (all tables protected, creator-only edit/delete)
- [ ] T113 Run quickstart.md integration scenarios (6 scenarios from quickstart.md)
- [ ] T114 [P] Add error logging (non-sensitive data only, no emails/IPs per FR-074)
- [ ] T115 [P] Add accessibility labels (semantic labels for screen readers)
- [ ] T116 Validate all images served via HTTPS Supabase Storage CDN (FR-075)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-10)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Phase 11)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - **No dependencies on other stories**
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) - Requires US1 navigation integration (T046, T050) but independently testable
- **User Story 3 (P2)**: Can start after Foundational (Phase 2) - Integrates with US1 (EventCard) and US2 (EventDetailScreen) but independently testable
- **User Story 4 (P2)**: Can start after Foundational (Phase 2) - Integrates with US1 (EventCard) and US2 (EventDetailScreen) but independently testable
- **User Story 5 (P2)**: Can start after Foundational (Phase 2) - Integrates with US2 (EventDetailScreen) but independently testable
- **User Story 6 (P3)**: Can start after Foundational (Phase 2) - Integrates with US2 (EventDetailScreen) but independently testable
- **User Story 7 (P3)**: Can start after Foundational (Phase 2) - Integrates with US2 (EventDetailScreen) and US1 (feed removal) but independently testable
- **User Story 8 (P3)**: Can start after Foundational (Phase 2) - Integrates with US2 (EventDetailScreen) but independently testable

### Within Each User Story

- Models before repositories
- Repositories before use cases
- Use cases before providers
- Providers before screens/widgets
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- **Phase 1 (Setup)**: All tasks marked [P] can run in parallel (T002, T003, T004, T005)
- **Phase 2 (Foundational)**:
  - Database tasks can run in parallel (T007-T013)
  - Entity tasks can run in parallel (T014-T017)
  - Model tasks can run in parallel (T018-T022)
  - Data source tasks can run in parallel (T023, T024)
  - Utility tasks can run in parallel (T026, T027)
  - Shared widget tasks can run in parallel (T028, T029, T030)
- **Once Foundational completes**: All user stories (US1-US8) can start in parallel if team capacity allows
- **Within each user story**: Tasks marked [P] can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch parallel tasks for User Story 1:
Task T031: "Create EventsRepository with cache-first pattern"
Task T032: "Create GetEventsFeedUseCase"

# Then after repositories/use cases are done:
Task T034: "Create EventCard widget"

# Then integrate into screens (sequential):
Task T033: "Create EventsFeedProvider"
Task T035: "Create EventsFeedScreen"
```

---

## Parallel Example: User Story 5

```bash
# Launch parallel tasks for User Story 5:
Task T069: "Create CommentsRepository with Realtime subscriptions"
Task T070: "Create PostCommentUseCase with optimistic UI"
Task T072: "Create CommentListItem widget"
Task T073: "Create CommentInputField widget"

# Then integrate (sequential):
Task T071: "Create CommentsProvider"
Task T074: "Integrate comments section into EventDetailScreen"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 1: Setup (5 tasks)
2. Complete Phase 2: Foundational (25 tasks) - **CRITICAL BLOCKER**
3. Complete Phase 3: User Story 1 (10 tasks)
4. Complete Phase 4: User Story 2 (10 tasks)
5. **STOP and VALIDATE**: Test US1 + US2 independently (browse feed + view details)
6. Deploy/demo if ready - **This is the true MVP**

### Incremental Delivery (Recommended)

1. Complete Setup + Foundational → Foundation ready (30 tasks)
2. Add User Story 1 → Test independently → Deploy/Demo (40 tasks total) - **Feed browsing works**
3. Add User Story 2 → Test independently → Deploy/Demo (50 tasks total) - **Full event viewing works**
4. Add User Story 3 → Test independently → Deploy/Demo (60 tasks total) - **Likes work**
5. Add User Story 4 → Test independently → Deploy/Demo (68 tasks total) - **RSVP works**
6. Add User Story 5 → Test independently → Deploy/Demo (81 tasks total) - **Comments work**
7. Add User Story 6 → Test independently → Deploy/Demo (89 tasks total) - **Edit works**
8. Add User Story 7 → Test independently → Deploy/Demo (97 tasks total) - **Delete works**
9. Add User Story 8 → Test independently → Deploy/Demo (105 tasks total) - **Reporting works**
10. Complete Polish phase → Final validation → Production deployment (116 tasks total)

Each user story adds value without breaking previous stories.

### Parallel Team Strategy

With multiple developers:

1. **Team completes Setup + Foundational together** (Phases 1-2, 30 tasks)
2. **Once Foundational is done**, split into parallel tracks:
   - **Developer A**: User Story 1 (Feed)
   - **Developer B**: User Story 2 (Detail Screen)
   - **Developer C**: User Story 3 (Likes)
   - **Developer D**: User Story 4 (Participations)
   - **Developer E**: User Story 5 (Comments)
3. **P3 stories** (US6, US7, US8) can be added incrementally after P1+P2 complete

---

## Task Summary

**Total Tasks**: 116
- **Phase 1 (Setup)**: 5 tasks
- **Phase 2 (Foundational)**: 25 tasks (BLOCKS all user stories)
- **Phase 3 (US1 - Feed)**: 10 tasks
- **Phase 4 (US2 - Detail)**: 10 tasks
- **Phase 5 (US3 - Likes)**: 10 tasks
- **Phase 6 (US4 - Participate)**: 8 tasks
- **Phase 7 (US5 - Comments)**: 13 tasks
- **Phase 8 (US6 - Edit)**: 8 tasks
- **Phase 9 (US7 - Delete)**: 8 tasks
- **Phase 10 (US8 - Report)**: 8 tasks
- **Phase 11 (Polish)**: 11 tasks

**Parallel Opportunities**: 47 tasks marked [P] can run in parallel within their phases

**Independent Test Criteria**:
- **US1**: Browse feed, scroll to load more, pull to refresh, see cached events offline
- **US2**: Tap event card, view full details, swipe gallery, see participants, pull to refresh
- **US3**: Tap like button, see instant feedback, go offline and like, see sync when online
- **US4**: Tap participate button, see instant feedback, see avatar in participant list, see badge on feed card
- **US5**: Type comment, see character counter, tap send, see comment instantly, second device sees it <2s
- **US6**: Edit my event, change title/description, save, see update instantly
- **US7**: Delete my event, confirm, see event removed from feed
- **US8**: Report event, select reason, submit, see confirmation

**Suggested MVP Scope**: User Stories 1 + 2 (Phases 1-4, 50 tasks total) - Provides complete browsing experience

---

## Notes

- [P] tasks = different files, no dependencies within phase
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Tests are NOT included (not explicitly requested in specification)
- Manual testing via quickstart.md scenarios (Task T113)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence

---

**Tasks Status**: ✅ Ready for `/speckit.implement` - All 116 tasks documented with exact file paths and dependencies
