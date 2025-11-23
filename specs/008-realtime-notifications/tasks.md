# Tasks: Real-Time In-App Notifications System

**Input**: Design documents from `specs/008-realtime-notifications/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not requested in specification - implementation-only tasks

**Organization**: Tasks grouped by user story (8 total: 4 P1, 3 P2, 1 P3) to enable independent implementation and testing

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US8)
- All tasks include exact file paths per implementation plan

## Path Conventions

- **Mobile**: Feature-first architecture in `lib/features/notifications/`
- **Database**: Supabase migrations in `supabase/migrations/`
- **Shared**: Adaptive widgets in `lib/shared/widgets/adaptive/`
- **Core**: Extended utilities in `lib/core/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and dependency configuration

- [ ] T001 Add supabase_flutter ^2.0.0 dependency to nova/pubspec.yaml
- [ ] T002 Add timeago ^3.5.0 dependency to nova/pubspec.yaml
- [ ] T003 [P] Add flutter_slidable ^3.0.0 dependency to nova/pubspec.yaml
- [ ] T004 [P] Run flutter pub get to install new dependencies
- [ ] T005 [P] Create feature directory structure lib/features/notifications/ with data/, domain/, presentation/ subdirectories

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core database schema and infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Create database migration file supabase/migrations/008_realtime_notifications.sql
- [ ] T007 Add notification preference columns to profiles table in migration (eventi_moderati_enabled, nuovi_commenti_enabled, risposte_commenti_enabled, like_eventi_enabled, nuove_partecipazioni_enabled, coorganizer_updates_enabled - all BOOLEAN DEFAULT TRUE)
- [ ] T008 Create notifications table in migration with 11 columns (id, recipient_id, sender_id, type, title, description, target_type, target_id, metadata, is_read, created_at)
- [ ] T009 Add CHECK constraints to migration (type enum with 6 values, target_type enum with 2 values)
- [ ] T010 Create 3 performance indexes in migration (idx_notifications_recipient_created, idx_notifications_recipient_unread, idx_notifications_created_at)
- [ ] T011 Enable RLS on notifications table in migration
- [ ] T012 Create 4 RLS policies in migration (SELECT for own notifications, UPDATE for own notifications, DELETE for own notifications, INSERT blocked except SECURITY DEFINER)
- [ ] T013 Create create_notification() stored function in migration with preference checks and self-notification prevention
- [ ] T014 [P] Create trigger function trigger_event_moderation_notification() in migration for event approval/rejection
- [ ] T015 [P] Create trigger function trigger_comment_notification() in migration for new comments on events
- [ ] T016 [P] Create trigger function trigger_comment_reply_notification() in migration for comment replies
- [ ] T017 [P] Create trigger function trigger_event_like_notification() in migration for event likes
- [ ] T018 [P] Create trigger function trigger_event_participation_notification() in migration for event participations
- [ ] T019 [P] Create trigger function trigger_coorganizer_update_notification() in migration for event edits by primary organizer
- [ ] T020 Attach triggers to events table (event_moderation, coorganizer_update) in migration
- [ ] T021 [P] Attach trigger to comments table (comment_notification) in migration
- [ ] T022 [P] Attach trigger to comment_replies table (comment_reply_notification) in migration if exists, else add reply logic to comments trigger
- [ ] T023 [P] Attach trigger to likes table (event_like_notification) in migration
- [ ] T024 [P] Attach trigger to participations table (event_participation_notification) in migration
- [ ] T025 Enable pg_cron extension in migration
- [ ] T026 Schedule 90-day auto-deletion cron job in migration (DELETE FROM notifications WHERE created_at < NOW() - INTERVAL '90 days')
- [ ] T027 Apply migration to Supabase database using psql or Supabase CLI
- [ ] T028 [P] Create NotificationChannel enum in lib/features/notifications/domain/entities/notification_channel.dart with 6 values
- [ ] T029 [P] Create Notification entity in lib/features/notifications/domain/entities/notification.dart with 11 fields
- [ ] T030 [P] Create NotificationPreferences entity in lib/features/notifications/domain/entities/notification_preferences.dart with 6 boolean fields
- [ ] T031 [P] Create NotificationModel in lib/features/notifications/data/models/notification_model.dart with fromJson/toJson methods
- [ ] T032 [P] Create NotificationPreferencesModel in lib/features/notifications/data/models/notification_preferences_model.dart with fromJson/toJson methods
- [ ] T033 Create NotificationRepositoryInterface in lib/features/notifications/domain/repositories/notification_repository_interface.dart with abstract methods
- [ ] T034 [P] Create NotificationPreferencesRepositoryInterface in lib/features/notifications/domain/repositories/notification_preferences_repository_interface.dart with abstract methods
- [ ] T035 Create NotificationRemoteDatasource in lib/features/notifications/data/datasources/notification_remote_datasource.dart with Supabase fetch/update/delete methods
- [ ] T036 [P] Create NotificationRealtimeDatasource in lib/features/notifications/data/datasources/notification_realtime_datasource.dart with watchNotifications() stream method
- [ ] T037 [P] Create NotificationPreferencesRemoteDatasource in lib/features/notifications/data/datasources/notification_preferences_remote_datasource.dart with get/update methods
- [ ] T038 Implement NotificationRepository in lib/features/notifications/data/repositories/notification_repository.dart delegating to remote and realtime datasources
- [ ] T039 [P] Implement NotificationPreferencesRepository in lib/features/notifications/data/repositories/notification_preferences_repository.dart delegating to remote datasource

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Notification Center Access and Navigation (Priority: P1) 🎯 MVP

**Goal**: Students can view all notifications, see badge counts, tap to navigate to events/comments, and delete notifications

**Independent Test**: Tap bell icon in app bar, view notification list with mock data, tap notification, verify navigation to event detail screen and notification marked as read

### Implementation for User Story 1

- [ ] T040 [P] [US1] Create NotificationBellIcon widget in lib/features/notifications/presentation/widgets/notification_bell_icon.dart with platform-adaptive icon (CupertinoIcons.bell on iOS, Icons.notifications on Android)
- [ ] T041 [P] [US1] Create NotificationBadge widget in lib/features/notifications/presentation/widgets/notification_badge.dart with red circular badge and "9+" cap logic
- [ ] T042 [P] [US1] Create NotificationListItem widget in lib/features/notifications/presentation/widgets/notification_list_item.dart with avatar, title, description, timestamp, unread dot
- [ ] T043 [P] [US1] Create NotificationEmptyState widget in lib/features/notifications/presentation/widgets/notification_empty_state.dart with crossed-out bell icon and Italian text
- [ ] T044 [US1] Create notificationsProvider (StreamProvider) in lib/features/notifications/presentation/providers/notifications_provider.dart wrapping watchNotifications() stream
- [ ] T045 [US1] Create notificationBadgeCountProvider (StreamProvider) in lib/features/notifications/presentation/providers/notification_badge_provider.dart computing unread count from notifications stream
- [ ] T046 [US1] Create notificationActionsProvider (AsyncNotifierProvider) in lib/features/notifications/presentation/providers/notification_actions_provider.dart with markAsRead() and delete() methods with optimistic updates
- [ ] T047 [US1] Create NotificationCenterScreen in lib/features/notifications/presentation/screens/notification_center_screen.dart with platform-adaptive scaffold (CupertinoPageScaffold on iOS, Scaffold on Android)
- [ ] T048 [US1] Implement platform-adaptive notification list in NotificationCenterScreen (CustomScrollView with CupertinoSliverNavigationBar on iOS, ListView with AppBar on Android)
- [ ] T049 [US1] Add pull-to-refresh gesture to NotificationCenterScreen (RefreshIndicator on Android, CupertinoSliverRefreshControl on iOS)
- [ ] T050 [US1] Add swipe-to-delete functionality to NotificationListItem using flutter_slidable package (Dismissible on Android, CupertinoContextMenu on iOS)
- [ ] T051 [US1] Integrate timeago package for relative timestamps in NotificationListItem (format with locale: 'it')
- [ ] T052 [US1] Add NotificationBellIcon to app bar in lib/features/events/presentation/screens/main_feed_screen.dart (top-right corner)
- [ ] T053 [US1] Add NotificationBellIcon to app bar in lib/features/events/presentation/screens/event_detail_screen.dart
- [ ] T054 [US1] Extend DeepLinkHandler in lib/core/utils/deep_link_handler.dart with handleNotificationTap() method supporting event and comment target types
- [ ] T055 [US1] Add notification navigation routes to lib/core/router/app_router.dart (go_router configuration with /notifications path)
- [ ] T056 [US1] Implement optimistic mark-as-read logic in notificationActionsProvider with rollback on server error
- [ ] T057 [US1] Add error handling for deleted target content in handleNotificationTap() (show "Evento non disponibile" dialog)

**Checkpoint**: User Story 1 complete - notification center fully functional with badge, list, navigation, and delete

---

## Phase 4: User Story 2 - Notification Preferences Management (Priority: P1)

**Goal**: Students can toggle individual notification channels on/off in Settings, changes persist across app restarts

**Independent Test**: Navigate to Settings → Notifiche, toggle "Like agli eventi" off, restart app, verify preference preserved and no like notifications generated

### Implementation for User Story 2

- [ ] T058 [P] [US2] Create NotificationPreferencesScreen in lib/features/notifications/presentation/screens/notification_preferences_screen.dart with platform-adaptive scaffold
- [ ] T059 [P] [US2] Create notificationPreferencesProvider (AsyncNotifierProvider) in lib/features/notifications/presentation/providers/notification_preferences_provider.dart with get/update methods
- [ ] T060 [US2] Implement 6 platform-adaptive toggle switches in NotificationPreferencesScreen (CupertinoSwitch on iOS, Switch on Android) for each notification channel
- [ ] T061 [US2] Add Italian labels to preference toggles ("Eventi moderati", "Nuovi commenti", "Risposte commenti", "Like agli eventi", "Nuove partecipazioni", "Co-organizer updates")
- [ ] T062 [US2] Implement optimistic preference updates with rollback on server error in notificationPreferencesProvider
- [ ] T063 [US2] Add notification preferences route to lib/core/router/app_router.dart (/settings/notifications path)
- [ ] T064 [US2] Add "Notifiche" navigation item to existing Settings screen (lib/features/profile/presentation/screens/settings_screen.dart or equivalent)
- [ ] T065 [US2] Verify all preference switches use NovaColors for switch colors and NovaSpacing for padding (constitutional design system compliance)

**Checkpoint**: User Story 2 complete - notification preferences fully functional with persistence and UI feedback

---

## Phase 5: User Story 3 - Event Moderation Status Notifications (Priority: P1)

**Goal**: Event creators receive real-time notifications when moderators approve or reject their events

**Independent Test**: Create test event, have moderator approve it, verify creator receives "Evento Approvato! 🎉" notification within 1 second

### Implementation for User Story 3

- [ ] T066 [US3] Verify trigger_event_moderation_notification() function created in migration (completed in T014)
- [ ] T067 [US3] Test event approval notification generation by approving test event and querying notifications table
- [ ] T068 [US3] Test event rejection notification generation by rejecting test event with reason and querying notifications table
- [ ] T069 [US3] Verify deep link navigation for approved event notifications routes to EventDetailScreen
- [ ] T070 [US3] Verify deep link navigation for rejected event notifications routes to EventEditScreen (or RejectedEventEditScreen if exists)
- [ ] T071 [US3] Test real-time notification delivery using Supabase Realtime subscription (measure latency <1s)
- [ ] T072 [US3] Add emoji support verification for "Evento Approvato! 🎉" title in notification display

**Checkpoint**: User Story 3 complete - moderation notifications working with real-time delivery and proper navigation

---

## Phase 6: User Story 4 - New Comment Notifications (Priority: P1)

**Goal**: Event creators receive notifications when users comment on their events, with comment preview and navigation to comment thread

**Independent Test**: Create event, have another user comment on it, verify creator receives notification with commenter name and comment preview

### Implementation for User Story 4

- [ ] T073 [US4] Verify trigger_comment_notification() function created in migration (completed in T015)
- [ ] T074 [US4] Test comment notification generation by posting comment on test event and querying notifications table
- [ ] T075 [US4] Verify notification title includes commenter name ("[Commenter name] ha commentato sul tuo evento")
- [ ] T076 [US4] Verify notification description includes comment preview (first 100 characters)
- [ ] T077 [US4] Extend handleNotificationTap() to support scrollToComments query parameter for EventDetailScreen deep linking
- [ ] T078 [US4] Verify EventDetailScreen accepts scrollToComments and highlightCommentId parameters (may require extending existing screen)
- [ ] T079 [US4] Test no notification generated when user has "Nuovi commenti" preference disabled
- [ ] T080 [US4] Test no self-notification when user comments on their own event

**Checkpoint**: User Story 4 complete - comment notifications working with preview and deep linking to comment thread

---

## Phase 7: User Story 5 - Comment Reply Notifications (Priority: P2)

**Goal**: Users who comment receive notifications when others reply to their comments

**Independent Test**: Post comment on event, have another user reply to that comment, verify original commenter receives notification

### Implementation for User Story 5

- [ ] T081 [US5] Verify trigger_comment_reply_notification() function created in migration (completed in T016)
- [ ] T082 [US5] Verify comments table or comment_replies table has parent_comment_id or reply_to_id field for threading
- [ ] T083 [US5] Test comment reply notification generation by posting reply to existing comment and querying notifications table
- [ ] T084 [US5] Verify notification title includes replier name ("[Replier name] ha risposto al tuo commento")
- [ ] T085 [US5] Verify deep link navigation scrolls to reply and highlights it in EventDetailScreen
- [ ] T086 [US5] Test no notification generated when user has "Risposte commenti" preference disabled

**Checkpoint**: User Story 5 complete - comment reply notifications working with threading support

---

## Phase 8: User Story 6 - Event Like Notifications (Priority: P2)

**Goal**: Event creators receive notifications when users like their events

**Independent Test**: Create event, have another user like it, verify creator receives notification

### Implementation for User Story 6

- [ ] T087 [US6] Verify trigger_event_like_notification() function created in migration (completed in T017)
- [ ] T088 [US6] Verify likes table exists with event_id and user_id fields
- [ ] T089 [US6] Test event like notification generation by liking test event and querying notifications table
- [ ] T090 [US6] Verify notification title includes liker name ("[Liker name] ha messo like al tuo evento")
- [ ] T091 [US6] Verify deep link navigation routes to EventDetailScreen
- [ ] T092 [US6] Test no notification generated when user has "Like agli eventi" preference disabled (common opt-out to reduce noise)

**Checkpoint**: User Story 6 complete - like notifications working with proper filtering

---

## Phase 9: User Story 7 - Event Participation Notifications (Priority: P2)

**Goal**: Event creators receive notifications when users join their events as participants

**Independent Test**: Create event, have another user join as participant, verify creator receives notification

### Implementation for User Story 7

- [ ] T093 [US7] Verify trigger_event_participation_notification() function created in migration (completed in T018)
- [ ] T094 [US7] Verify participations table exists with event_id and user_id fields
- [ ] T095 [US7] Test participation notification generation by joining test event and querying notifications table
- [ ] T096 [US7] Verify notification title includes participant name ("[Participant name] parteciperà al tuo evento")
- [ ] T097 [US7] Verify deep link navigation routes to EventDetailScreen with updated participant list
- [ ] T098 [US7] Test no notification generated when user has "Nuove partecipazioni" preference disabled

**Checkpoint**: User Story 7 complete - participation notifications working for event creators

---

## Phase 10: User Story 8 - Co-Organizer Update Notifications (Priority: P3)

**Goal**: Co-organizers receive notifications when primary organizer edits event details

**Independent Test**: Add user as co-organizer to event, edit event details, verify co-organizer receives notification

### Implementation for User Story 8

- [ ] T099 [US8] Verify trigger_coorganizer_update_notification() function created in migration (completed in T019)
- [ ] T100 [US8] Verify events table has co_organizer_ids array field or co_organizers junction table
- [ ] T101 [US8] Test co-organizer update notification generation by editing event with co-organizers and querying notifications table
- [ ] T102 [US8] Verify notification title includes editor name ("[Organizer name] ha modificato [event name]")
- [ ] T103 [US8] Verify notification NOT sent to the editor themselves (only other co-organizers)
- [ ] T104 [US8] Verify deep link navigation routes to EventDetailScreen with updated event details
- [ ] T105 [US8] Test no notification generated when user has "Co-organizer updates" preference disabled

**Checkpoint**: User Story 8 complete - all 8 user stories implemented and functional

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements affecting multiple user stories and production readiness

- [ ] T106 [P] Verify all notification widgets use NovaColors constants (no hardcoded Color(0xFF...) values) - constitutional compliance check
- [ ] T107 [P] Verify all notification widgets use NovaSpacing constants (no magic number padding/margins) - constitutional compliance check
- [ ] T108 [P] Verify all notification widgets use NovaTypography constants (no inline TextStyle definitions) - constitutional compliance check
- [ ] T109 [P] Verify NotificationListItem uses GlassContainer widget for glassmorphism effect - constitutional design system requirement
- [ ] T110 [P] Test notification list scroll performance with 100+ notifications (verify sustained 60fps using Flutter DevTools)
- [ ] T111 [P] Test notification badge count accuracy with concurrent notification generation (verify 99%+ accuracy)
- [ ] T112 [P] Test Realtime subscription reconnection after network interruption (verify automatic recovery)
- [ ] T113 [P] Verify 90-day auto-deletion cron job scheduled correctly (SELECT * FROM cron.job WHERE jobname = 'delete-old-notifications')
- [ ] T114 [P] Test notification generation respects user preferences across all 6 channels
- [ ] T115 [P] Test no self-notifications generated across all notification types
- [ ] T116 Add error logging for notification generation failures (use constitutional logging rules - IDs only, no PII)
- [ ] T117 [P] Add error handling for Realtime subscription failures with exponential backoff
- [ ] T118 [P] Verify RLS policies prevent users from seeing other users' notifications (security test)
- [ ] T119 [P] Run quickstart.md integration scenarios to validate all 5 scenarios work end-to-end
- [ ] T120 Final code review for constitutional compliance (all 7 principles), design system adherence, and performance targets

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - **BLOCKS all user stories**
- **User Stories (Phase 3-10)**: All depend on Foundational phase completion
  - US1-US4 (P1 priority) should complete first
  - US5-US7 (P2 priority) can start after Foundational, independent of P1 stories
  - US8 (P3 priority) can start after Foundational, independent of other stories
- **Polish (Phase 11)**: Depends on all user stories being complete

### User Story Independence

- **US1 (Notification Center)**: Foundation for all stories - completed first as MVP
- **US2 (Preferences)**: Independent, no dependencies on other stories
- **US3 (Event Moderation)**: Independent, depends only on Foundational database triggers
- **US4 (New Comments)**: Independent, depends only on Foundational database triggers
- **US5 (Comment Replies)**: Independent, requires comment threading in comments table
- **US6 (Event Likes)**: Independent, depends only on Foundational database triggers
- **US7 (Event Participations)**: Independent, depends only on Foundational database triggers
- **US8 (Co-Organizer Updates)**: Independent, requires co-organizer field in events table

### Within Each User Story

- Models/entities created in parallel [P]
- Providers depend on repositories
- Screens depend on providers and widgets
- Deep link integration depends on screens being complete

### Parallel Opportunities

**Phase 1 (Setup)**: T002, T003, T004, T005 can run in parallel after T001

**Phase 2 (Foundational)**:
- Migration tasks T007-T026 are sequential within migration file
- Entity creation T028-T030 can run in parallel
- Model creation T031-T032 can run in parallel after entities
- Repository interface creation T033-T034 can run in parallel
- Datasource creation T035-T037 can run in parallel
- Repository implementation T038-T039 can run in parallel after datasources

**Phase 3 (US1)**: T040-T043 (all widgets) can run in parallel

**Phase 4 (US2)**: T058-T059 can run in parallel

**User Stories**: After Foundational completes, ALL user stories (US1-US8) can be worked on in parallel by different team members

**Phase 11 (Polish)**: T106-T119 (all verification tasks) can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all widgets for User Story 1 together:
Task T040: "Create NotificationBellIcon widget in lib/features/notifications/presentation/widgets/notification_bell_icon.dart"
Task T041: "Create NotificationBadge widget in lib/features/notifications/presentation/widgets/notification_badge.dart"
Task T042: "Create NotificationListItem widget in lib/features/notifications/presentation/widgets/notification_list_item.dart"
Task T043: "Create NotificationEmptyState widget in lib/features/notifications/presentation/widgets/notification_empty_state.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (5 tasks)
2. Complete Phase 2: Foundational (34 tasks) - **CRITICAL foundation**
3. Complete Phase 3: User Story 1 (18 tasks) - **MVP deliverable**
4. **STOP and VALIDATE**: Test notification center independently with mock data
5. Deploy/demo if ready

**MVP Value**: Students can see all notifications, badge counts, tap to navigate, and delete notifications - complete notification experience

### Incremental Delivery

1. Setup + Foundational → Foundation ready (39 tasks)
2. Add US1 (Notification Center) → Test independently → Deploy/Demo (**MVP!**)
3. Add US2 (Preferences) → Test independently → Deploy/Demo
4. Add US3 (Event Moderation) → Test independently → Deploy/Demo
5. Add US4 (New Comments) → Test independently → Deploy/Demo
6. Add US5-US8 (P2/P3 features) → Test independently → Deploy/Demo
7. Complete Polish phase → Production ready

**Each story adds value without breaking previous stories**

### Parallel Team Strategy

With multiple developers after Foundational phase completes:

1. Team completes Setup + Foundational together (39 tasks)
2. Once Foundational is done:
   - **Developer A**: US1 Notification Center (18 tasks) - **MVP priority**
   - **Developer B**: US2 Preferences (8 tasks)
   - **Developer C**: US3 Event Moderation (7 tasks)
   - **Developer D**: US4 New Comments (8 tasks)
3. After P1 stories complete:
   - **Developer A**: US5 Comment Replies (6 tasks)
   - **Developer B**: US6 Event Likes (6 tasks)
   - **Developer C**: US7 Event Participations (6 tasks)
   - **Developer D**: US8 Co-Organizer Updates (7 tasks)
4. All developers: Polish phase together (15 tasks)

---

## Task Statistics

**Total Tasks**: 120

**Breakdown by Phase**:
- Phase 1 (Setup): 5 tasks
- Phase 2 (Foundational): 34 tasks (⚠️ BLOCKING)
- Phase 3 (US1 - Notification Center): 18 tasks
- Phase 4 (US2 - Preferences): 8 tasks
- Phase 5 (US3 - Event Moderation): 7 tasks
- Phase 6 (US4 - New Comments): 8 tasks
- Phase 7 (US5 - Comment Replies): 6 tasks
- Phase 8 (US6 - Event Likes): 6 tasks
- Phase 9 (US7 - Event Participations): 6 tasks
- Phase 10 (US8 - Co-Organizer Updates): 7 tasks
- Phase 11 (Polish): 15 tasks

**Parallelizable Tasks**: 58 tasks marked with [P]

**Critical Path** (sequential dependencies):
1. Setup (Phase 1): 5 tasks
2. Foundational database migration: 20 sequential SQL tasks
3. US1 core providers and screen: 8 sequential tasks after widgets
4. Deep linking integration: 2 sequential tasks after screen
Total critical path: ~35 sequential tasks

**MVP Scope** (US1 only): 57 tasks (Setup + Foundational + US1)

**Estimated Effort**:
- MVP (US1): 2-3 developer days
- All P1 features (US1-US4): 4-5 developer days
- Complete implementation (all US): 6-8 developer days
- With parallel team (4 developers): 2-3 developer days for complete implementation

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [US#] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Database migration tasks (T006-T027) MUST be completed sequentially within the migration file
- All notification generation testing requires events, comments, likes, and participations tables to exist
- Commit after each logical task group or checkpoint
- Stop at any checkpoint to validate story independently before continuing
- Constitutional compliance verified in Phase 11 (design system, performance, privacy)
- Deep linking depends on existing EventDetailScreen and routing infrastructure
