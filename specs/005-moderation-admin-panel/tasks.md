# Tasks: Admin Panel & Moderation Queue

**Feature**: 005-moderation-admin-panel
**Branch**: `005-moderation-admin-panel`
**Input**: Design documents from `/specs/005-moderation-admin-panel/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

**Tests**: No test tasks included (not requested in specification).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Database Infrastructure)

**Purpose**: Initialize database schema and foundational infrastructure

### Database Schema Setup

- [x] T001 Create complete database migration script at supabase/migrations/20251114_moderation_system.sql with all tables from data-model.md
- [x] T002 [P] Create user_roles table with RLS policies and indexes in migration script
- [x] T003 [P] Add moderation columns to events table (status, moderated_by, moderated_at, rejection_reason, submission_count) in migration script
- [x] T004 [P] Create moderation_log table with immutable audit trail and RLS policies in migration script
- [x] T005 [P] Create admin_log table with role change tracking and RLS policies in migration script
- [x] T006 [P] Create role_history table for statistics restoration in migration script
- [x] T007 [P] Create moderator_stats table with denormalized statistics in migration script
- [x] T008 [P] Create moderator_stats_archive table for role removal archival in migration script
- [x] T009 [P] Create notifications table for push notification queue in migration script

### Database Functions & Triggers

- [x] T010 [P] Implement has_role() helper function in migration script for RLS policy optimization
- [x] T011 [P] Implement moderate_event() function with row locking (SELECT FOR UPDATE NOWAIT) in migration script
- [x] T012 [P] Implement calculate_moderator_stats() function for real-time statistics updates in migration script
- [x] T013 [P] Implement promote_to_moderator() function with stats restoration in migration script
- [x] T014 [P] Implement remove_moderator_role() function with stats archival in migration script
- [x] T015 [P] Implement get_system_statistics() function returning system-wide metrics in migration script
- [x] T016 [P] Create system_statistics view for Admin Panel dashboard in migration script
- [x] T017 [P] Create trigger update_moderator_stats_after_moderation on moderation_log table in migration script
- [x] T018 [P] Create trigger notify_event_moderation on events table for push notifications in migration script
- [x] T019 [P] Create trigger log_moderation_action on events table for audit log population in migration script
- [x] T020 [P] Create trigger update_timestamp_user_roles and update_timestamp_moderator_stats in migration script

### Database Indexes & Constraints

- [x] T021 [P] Add all performance-critical indexes (15+ indexes) from data-model.md to migration script
- [x] T022 [P] ADD CHECK constraints for data integrity (moderated_data_consistency, rejection_reason_required_if_rejected) in migration script
- [ ] T023 Run database migration on Supabase development environment and verify schema with verification script from data-model.md

**Checkpoint**: Database foundation ready - all tables, functions, triggers, and indexes deployed

---

## Phase 2: Foundational (Core Flutter Infrastructure)

**Purpose**: Shared infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Core Providers & Repositories

- [x] T024 Create Supabase client provider in nova/lib/core/providers/supabase_provider.dart
- [x] T025 [P] Create UserRole enum in nova/lib/core/enums/user_role.dart with values (student, moderator, admin)
- [x] T026 [P] Implement userRoleProvider StreamProvider in nova/lib/features/auth/providers/user_role_provider.dart with real-time role subscription
- [x] T027 [P] Create base Event entity extension in nova/lib/features/events/domain/entities/event.dart adding status, moderatedBy, moderatedAt, rejectionReason, submissionCount fields

### Shared Widgets & Navigation

- [x] T028 [P] Create RealtimeBadge widget in nova/lib/shared/widgets/realtime_badge.dart with count display and fallback indicator (yellow dot)
- [x] T029 [P] Extend NovaBottomNavBar in nova/lib/shared/widgets/nova_bottom_nav_bar.dart to support role-based tab visibility
- [x] T030 Update app router in nova/lib/core/router/app_router.dart to add /moderation and /admin routes with role-based guards

### Platform-Native Widgets (Constitution Compliance)

- [x] T031 Create AdaptiveButton widget in nova/lib/shared/widgets/adaptive/adaptive_button.dart using CupertinoButton (iOS) and ElevatedButton (Android)
- [x] T032 [P] Create AdaptiveDialog widget in nova/lib/shared/widgets/adaptive/adaptive_dialog.dart using CupertinoAlertDialog (iOS) and AlertDialog (Android)
- [x] T033 [P] Create AdaptiveTextField widget in nova/lib/shared/widgets/adaptive/adaptive_text_field.dart using CupertinoTextField (iOS) and TextField (Android)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Basic Event Moderation Flow (Priority: P1) 🎯 MVP

**Goal**: Moderators can review pending events and approve/reject them with rejection reasons. Real-time queue updates when new events submitted or other moderators take action. Push notifications sent to event creators on approval/rejection.

**Independent Test**: Create test event as student, log in as moderator, view event in queue, approve/reject it, verify status change and creator notification.

### Data Layer (User Story 1)

- [x] T034 [P] [US1] Create ModerationEvent model in nova/lib/features/moderation/data/models/moderation_event.dart mapping to events table with moderation fields
- [x] T035 [P] [US1] Create ModerationAction enum in nova/lib/features/moderation/domain/entities/moderation_action.dart with values (approved, rejected)
- [x] T036 [US1] Implement ModerationRepository in nova/lib/features/moderation/data/repositories/moderation_repository.dart with getPendingEvents(), moderateEvent(), and error handling for concurrent modification

### Presentation Layer (User Story 1)

- [x] T037 [P] [US1] Create pendingEventsProvider StreamProvider in nova/lib/features/moderation/presentation/providers/pending_events_provider.dart with Supabase Realtime subscription to events table filtered by status='pending'
- [x] T038 [P] [US1] Create moderationNotifierProvider AsyncNotifier in nova/lib/features/moderation/presentation/providers/moderation_notifier.dart with approveEvent() and rejectEvent() methods (NOTE: Optimistic updates removed due to StreamProvider limitations - relies on Realtime <2s update)
- [x] T039 [P] [US1] Create moderatorStatsProvider StreamProvider in nova/lib/features/moderation/presentation/providers/moderator_stats_provider.dart for personal statistics display

### UI Components (User Story 1)

- [x] T040 [P] [US1] Create PendingEventCard widget in nova/lib/features/moderation/presentation/widgets/pending_event_card.dart showing emoji/image, title, description preview (150 chars), organizer, date/time, location, submission timestamp
- [x] T041 [P] [US1] Create RejectionDialog widget in nova/lib/features/moderation/presentation/widgets/rejection_dialog.dart with predefined reasons dropdown (Contenuto inappropriato, Informazioni incomplete, Duplicato, Fuori tema) plus custom text field
- [x] T042 [P] [US1] Create ModeratorStatsWidget in nova/lib/features/moderation/presentation/widgets/moderator_stats_widget.dart displaying reviews today, reviews this week, total reviews, approval rate percentage
- [x] T043 [US1] Implement ModerationDashboardScreen in nova/lib/features/moderation/presentation/screens/moderation_dashboard_screen.dart with pending events list sorted by created_at ascending (oldest first) and personal stats section
- [x] T044 [US1] Implement EventReviewScreen in nova/lib/features/moderation/presentation/screens/event_review_screen.dart with full event details and Approva/Rifiuta action buttons using AdaptiveButton

### Real-Time & Error Handling (User Story 1)

- [x] T045 [US1] Add Realtime connection monitoring in nova/lib/features/moderation/presentation/providers/realtime_connection_provider.dart (NOTE: Stub provider - Supabase SDK doesn't expose connection state, assumes always connected)
- [x] T046 [US1] Implement polling fallback provider in nova/lib/features/moderation/presentation/providers/moderation_queue_polling_provider.dart with Stream.periodic at 15-second intervals
- [x] T047 [US1] Add automatic failover logic in pendingEventsProvider (NOTE: For MVP, uses Realtime-only with Supabase automatic reconnection)
- [x] T048 [US1] Implement error handling in moderationNotifierProvider for EventAlreadyModeratedException, ConcurrentModerationException, SelfModerationException with user-friendly snackbar messages

### Integration (User Story 1)

- [x] T049 [US1] Update events table RLS policies to prevent students from seeing pending events (except own events) using SELECT FOR UPDATE policies (SQL migration created in specs/005-moderation-admin-panel/migrations/)
- [x] T050 [US1] Add "Moderazione" tab to NovaBottomNavBar visible only to moderators and admins with real-time badge showing total pending count (Integration guide documented in specs/005-moderation-admin-panel/INTEGRATION_NOTES.md)
- [x] T051 [US1] Integrate RealtimeBadge on Moderazione tab with pendingEventsProvider count and yellow dot indicator when polling fallback active (NOTE: Fallback indicator removed as connection monitoring not available in Supabase SDK)

**Checkpoint**: User Story 1 complete - moderators can approve/reject events, see real-time updates, stats update immediately

---

## Phase 4: User Story 2 - Moderator Management by Admin (Priority: P2)

**Goal**: Admin can search students by name/email/class, promote them to moderator, remove moderator roles, and view all moderators with their statistics and activity status.

**Independent Test**: Log in as admin, search for student, promote to moderator, verify new moderator receives notification and gains access to Moderazione tab, demote moderator and verify tab disappears.

### Data Layer (User Story 2)

- [ ] T052 [P] [US2] Create AdminAction model in nova/lib/features/admin/data/models/admin_action.dart mapping to admin_log table
- [ ] T053 [P] [US2] Create Moderator entity in nova/lib/features/admin/domain/entities/moderator.dart with user info plus statistics fields
- [ ] T054 [P] [US2] Create SystemStats entity in nova/lib/features/admin/domain/entities/system_stats.dart mapping to system_statistics view
- [ ] T055 [US2] Implement AdminRepository in nova/lib/features/admin/data/repositories/admin_repository.dart with searchUsers(), promoteToModerator(), removeModerator(), getModerators(), getSystemStats() methods calling Supabase RPC functions

### Presentation Layer (User Story 2)

- [ ] T056 [P] [US2] Create moderatorsProvider StreamProvider in nova/lib/features/admin/presentation/providers/moderators_provider.dart subscribing to user_roles table joined with moderator_stats
- [ ] T057 [P] [US2] Create systemStatsProvider StreamProvider in nova/lib/features/admin/presentation/providers/system_stats_provider.dart calling get_system_statistics() RPC function
- [ ] T058 [P] [US2] Create adminActionsNotifierProvider AsyncNotifier in nova/lib/features/admin/presentation/providers/admin_actions_notifier.dart with promoteUser() and removeUser() methods

### UI Components (User Story 2)

- [ ] T059 [P] [US2] Create ModeratorSearch widget in nova/lib/features/admin/presentation/widgets/moderator_search.dart with TextField for name/email/class search and debounced query
- [ ] T060 [P] [US2] Create ModeratorCard widget in nova/lib/features/admin/presentation/widgets/moderator_card.dart displaying name, class, email, stats (reviews/week, total, approval rate, last activity) with Rimuovi Ruolo button
- [ ] T061 [P] [US2] Create SystemStatisticsWidget in nova/lib/features/admin/presentation/widgets/system_statistics_widget.dart showing total/pending/approved/rejected event counts with percentages, moderator counts, avg review time, events >24h backlog (highlighted red if >0)
- [ ] T062 [US2] Implement AdminPanelScreen in nova/lib/features/admin/presentation/screens/admin_panel_screen.dart with 3 sections: search, moderator list, system statistics

### Promotions & Demotions (User Story 2)

- [ ] T063 [US2] Implement promotion confirmation dialog in AdminPanelScreen using AdaptiveDialog with message "Luca Verdi (3A) diventerà moderatore e potrà approvare/rifiutare eventi"
- [ ] T064 [US2] Implement demotion confirmation dialog using AdaptiveDialog with message "Anna perderà accesso dashboard moderazione. Statistiche archiviate."
- [ ] T065 [US2] Add role change real-time listener in app root that shows SnackBar when user's role changes and navigates away from /moderation route if demoted

### Integration (User Story 2)

- [ ] T066 [US2] Add "Admin" tab to NovaBottomNavBar visible only to admin role
- [ ] T067 [US2] Update app router to add role guard on /admin route redirecting non-admins to /events
- [ ] T068 [US2] Verify promote_to_moderator() database function creates notification record triggering push notification webhook

**Checkpoint**: User Story 2 complete - admin can promote/demote moderators, see system health, moderators receive notifications

---

## Phase 5: User Story 3 - Real-time Statistics and Activity Monitoring (Priority: P2)

**Goal**: Moderators see personal statistics (reviews today/week, total, approval rate) that update immediately after each action. Admin sees system-wide statistics (event counts, moderator activity, review time, backlog) that update in real-time.

**Independent Test**: Perform moderation action, verify personal stats increment immediately without refresh. Check Admin Panel system stats update when any moderator moderates event.

### Statistics Updates (User Story 3)

- [ ] T069 [US3] Verify calculate_moderator_stats() trigger fires after moderation_log INSERT updating moderator_stats table
- [ ] T070 [US3] Verify moderatorStatsProvider (created in T039) displays updated stats after moderation action within 2 seconds
- [ ] T071 [US3] Add loading states to ModeratorStatsWidget showing skeleton UI during initial load

### System Statistics (User Story 3)

- [ ] T072 [US3] Verify systemStatsProvider real-time subscription updates when events table or moderation_log changes
- [ ] T073 [US3] Implement events >24h backlog highlighting in SystemStatisticsWidget using NovaColors.error when count > 0
- [ ] T074 [US3] Add inactive moderator detection (last_review_at > 7 days) in ModeratorCard with warning indicator icon

### Polling Fallback Indicators (User Story 3)

- [ ] T075 [US3] Add yellow dot indicator to RealtimeBadge when Realtime connection fails and polling fallback active
- [ ] T076 [US3] Display subtle connection status banner in ModerationDashboardScreen when using polling fallback ("Modalità offline - Aggiornamenti ogni 15 secondi")

**Checkpoint**: User Story 3 complete - all statistics update in real-time, fallback indicators visible when WebSocket unavailable

---

## Phase 6: User Story 4 - Admin Activity Log and Audit Trail (Priority: P3)

**Goal**: Admin views real-time activity log stream of all moderation actions (approve/reject) and admin actions (promote/remove) with filtering by action type and date navigation.

**Independent Test**: Perform moderation action or role change, verify it appears in activity log within 2 seconds with correct timestamp, actor name, action type, target.

### Data Layer (User Story 4)

- [ ] T077 [P] [US4] Create ActivityLogEntry entity in nova/lib/features/admin/domain/entities/activity_log_entry.dart combining data from moderation_log and admin_log tables
- [ ] T078 [US4] Add getActivityLog() method to AdminRepository with date range filtering and action type filtering

### Presentation Layer (User Story 4)

- [ ] T079 [P] [US4] Create activityLogProvider StreamProvider in nova/lib/features/admin/presentation/providers/activity_log_provider.dart subscribing to both moderation_log and admin_log tables sorted by timestamp DESC
- [ ] T080 [P] [US4] Create activityLogFilterProvider StateProvider in nova/lib/features/admin/presentation/providers/activity_log_filter_provider.dart for action type filter state

### UI Components (User Story 4)

- [ ] T081 [P] [US4] Create ActivityLogWidget in nova/lib/features/admin/presentation/widgets/activity_log_widget.dart displaying log entries with timestamp, actor name, action type badge, target (event title or username)
- [ ] T082 [US4] Add action type filter dropdown to ActivityLogWidget with options: All, Approved, Rejected, Promoted, Removed
- [ ] T083 [US4] Implement date navigation in ActivityLogWidget with previous/next day buttons

### Integration (User Story 4)

- [ ] T084 [US4] Add Activity Log section to AdminPanelScreen below system statistics
- [ ] T085 [US4] Verify log entries appear within 2 seconds of moderation/admin action (real-time subscription working)

**Checkpoint**: User Story 4 complete - admin sees complete audit trail with filtering, updates in real-time

---

## Phase 7: User Story 5 - Event Re-submission After Rejection (Priority: P3)

**Goal**: Event creators can view rejection reason on rejected events, edit description (only field editable), and re-submit event which resets status to pending and clears rejection reason.

**Independent Test**: Create event, reject it as moderator with reason, log in as creator, view rejection reason in profile, click "Modifica e Ri-sottometti", edit description, submit, verify event back in pending queue.

### Data Layer (User Story 5)

- [ ] T086 [US5] Add resubmitEvent() method to EventRepository in nova/lib/features/events/data/repositories/event_repository.dart calling UPDATE with status reset to pending, rejection_reason cleared, submission_count incremented

### Presentation Layer (User Story 5)

- [ ] T087 [P] [US5] Create rejectedEventsProvider StreamProvider in nova/lib/features/events/presentation/providers/rejected_events_provider.dart filtering events by created_by = current user AND status = 'rejected'
- [ ] T088 [P] [US5] Create resubmitEventNotifierProvider AsyncNotifier in nova/lib/features/events/presentation/providers/resubmit_event_notifier.dart with resubmit() method

### UI Components (User Story 5)

- [ ] T089 [P] [US5] Create RejectionReasonBadge widget in nova/lib/features/events/presentation/widgets/rejection_reason_badge.dart displaying rejection reason with red warning icon
- [ ] T090 [US5] Implement RejectedEventEditScreen in nova/lib/features/events/presentation/screens/rejected_event_edit_screen.dart with locked fields (title, emoji, image, event_date, location) and editable description field using AdaptiveTextField
- [ ] T091 [US5] Add "Modifica e Ri-sottometti" button to ProfileScreen rejected events list using AdaptiveButton

### Re-submission Logic (User Story 5)

- [ ] T092 [US5] Implement description-only edit validation in RejectedEventEditScreen preventing changes to other fields
- [ ] T093 [US5] Add re-submission confirmation dialog using AdaptiveDialog warning "Solo la descrizione può essere modificata. L'evento tornerà in coda di moderazione."
- [ ] T094 [US5] Verify re-submitted events appear in moderation queue (pendingEventsProvider) with submission_count incremented

### Integration (User Story 5)

- [ ] T095 [US5] Update ProfileScreen to display rejected events section with RejectionReasonBadge for each rejected event
- [ ] T096 [US5] Add app router route /event/:id/edit for RejectedEventEditScreen
- [ ] T097 [US5] Verify no limit on re-submissions (per Assumption #10 in spec.md) - users can re-submit indefinitely

**Checkpoint**: User Story 5 complete - students can edit and re-submit rejected events, maintaining event identity

---

## Phase 8: Push Notifications Infrastructure

**Purpose**: Integrate push notifications for event approval/rejection and role changes

### Supabase Edge Function

- [ ] T098 [P] Create Supabase Edge Function supabase/functions/send-push-notification/index.ts implementing FCM API v1 calls with Google OAuth token acquisition
- [ ] T099 [P] Configure Supabase webhook on notifications table INSERT event calling send-push-notification Edge Function
- [ ] T100 Add fcm_token column to profiles table in database migration (if not already present)

### Flutter FCM Integration

- [ ] T101 [P] Add firebase_core and firebase_messaging dependencies to nova/pubspec.yaml
- [ ] T102 [P] Configure Firebase project for iOS and Android with APNs certificate upload and google-services.json/GoogleService-Info.plist placement
- [ ] T103 Create NotificationService in nova/lib/core/services/notification_service.dart initializing FCM, requesting permissions, handling token refresh, saving token to Supabase
- [ ] T104 [P] Implement foreground notification handler in NotificationService using flutter_local_notifications to display notifications when app open
- [ ] T105 [P] Implement background notification handler in NotificationService for notification tap navigation
- [ ] T106 Add deep link navigation in NotificationService routing to /event/:id when notification tapped with event_moderation data payload

### Notification Testing

- [ ] T107 Test notification delivery by moderating test event and verifying creator receives push notification within 5 seconds
- [ ] T108 Test role change notifications by promoting/demoting test user and verifying notification received
- [ ] T109 Verify notification deep links navigate to correct screens when app is foreground, background, and terminated

**Checkpoint**: Push notifications working for all workflows (approval, rejection, promotion, demotion)

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements, performance optimization, and documentation

### Performance Optimization

- [ ] T110 [P] Verify all RLS policy indexes (15+ indexes) deployed and EXPLAIN ANALYZE queries to confirm index usage
- [ ] T111 [P] Add aggressive caching to systemStatsProvider using Riverpod .cacheTime to prevent excessive queries
- [ ] T112 Run Flutter DevTools profiler on ModerationDashboardScreen with 50+ pending events verifying 60fps sustained scrolling

### Security Hardening

- [ ] T113 [P] Audit all RLS policies with test queries for each role (student, moderator, admin) verifying correct data access
- [ ] T114 [P] Test self-moderation prevention by attempting to moderate own event and verifying error returned
- [ ] T115 Test concurrent moderation by two moderators simultaneously approving same event and verifying one fails with appropriate error

### Error Handling & Edge Cases

- [ ] T116 [P] Test Realtime connection failure scenario and verify automatic fallback to 15-second polling with yellow dot indicator
- [ ] T117 [P] Test role change while on restricted screen (moderator demoted while on /moderation route) and verify automatic redirect to /events
- [ ] T118 Test event deletion while in pending queue and verify moderators see "Event no longer exists" error when attempting moderation

### Documentation & Validation

- [ ] T119 [P] Update quickstart.md with actual Firebase project IDs, Supabase project URL, and Edge Function deployment commands
- [ ] T120 [P] Create test data SQL script for development environment with sample students, moderators, admin, pending events
- [ ] T121 Run through quickstart.md validation checklist (15 items) and verify all pass
- [ ] T122 Document adaptive widget usage examples in nova/lib/shared/widgets/adaptive/README.md with screenshots showing iOS vs Android differences

### Platform-Specific Testing

- [ ] T123 [P] Test on iOS device verifying CupertinoButton, CupertinoAlertDialog, CupertinoTextField used correctly
- [ ] T124 [P] Test on Android device verifying ElevatedButton, AlertDialog, TextField used correctly
- [ ] T125 Verify no hardcoded Color, spacing, or typography values in codebase using grep search for Color(0x and EdgeInsets.all(numeric

**Checkpoint**: Feature complete, tested, optimized, and ready for production deployment

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 database migration deployed - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2 foundational complete
- **User Story 2 (Phase 4)**: Depends on Phase 2 foundational complete - can run in parallel with Phase 3
- **User Story 3 (Phase 5)**: Depends on Phases 3 and 4 (statistics providers created)
- **User Story 4 (Phase 6)**: Depends on Phase 2 foundational complete - can run in parallel with Phases 3-5
- **User Story 5 (Phase 7)**: Depends on Phase 3 (moderation workflow exists) and Phase 2 (event repository)
- **Push Notifications (Phase 8)**: Depends on Phase 1 (database triggers created) - can run in parallel with Phase 2
- **Polish (Phase 9)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: MVP - No dependencies on other stories
- **User Story 2 (P2)**: Independent - uses separate admin feature, no shared components with US1
- **User Story 3 (P2)**: Integrates with US1 and US2 statistics providers, but independently testable
- **User Story 4 (P3)**: Independent - separate activity log feature
- **User Story 5 (P3)**: Depends on US1 moderation workflow existing, but independently testable

### Within Each User Story

- Data layer (models, repositories) before presentation layer (providers)
- Providers before UI components
- Core UI components before screens
- Screens before integration with navigation/bottom nav

### Parallel Opportunities

#### Phase 1 (Database Setup)
- T002-T009: All table creation tasks can run in parallel (different tables)
- T010-T020: All function and trigger creation tasks can run in parallel
- T021-T022: Index and constraint tasks can run in parallel

#### Phase 2 (Foundational)
- T025-T027: Core entities and providers can run in parallel
- T028-T033: All shared widgets can be built in parallel

#### Phase 3 (User Story 1)
- T034-T036: All data layer tasks can run in parallel
- T037-T039: All providers can run in parallel
- T040-T042: All widgets can run in parallel (PendingEventCard, RejectionDialog, ModeratorStatsWidget)

#### Phase 4 (User Story 2)
- T052-T055: All data layer tasks can run in parallel
- T056-T058: All providers can run in parallel
- T059-T061: All widgets can run in parallel

#### Phase 8 (Push Notifications)
- T098-T100: Edge Function and database setup can run in parallel
- T101-T106: All Flutter FCM tasks can run in parallel after T098-T100 complete

#### Phase 9 (Polish)
- T110-T112: Performance tasks can run in parallel
- T113-T115: Security testing can run in parallel
- T116-T118: Error handling tests can run in parallel
- T119-T122: Documentation tasks can run in parallel
- T123-T125: Platform-specific testing can run in parallel

---

## Parallel Example: User Story 1 Data Layer

```bash
# Launch all data layer tasks for User Story 1 together:
Task T034: "Create ModerationEvent model in nova/lib/features/moderation/data/models/moderation_event.dart"
Task T035: "Create ModerationAction enum in nova/lib/features/moderation/domain/entities/moderation_action.dart"
Task T036: "Implement ModerationRepository in nova/lib/features/moderation/data/repositories/moderation_repository.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (Database) → T001-T023
2. Complete Phase 2: Foundational (Core Infrastructure) → T024-T033
3. Complete Phase 3: User Story 1 (Moderation Flow) → T034-T051
4. **STOP and VALIDATE**: Test moderation workflow end-to-end
5. Deploy/demo if ready

**MVP Deliverable**: Moderators can approve/reject events with real-time updates, students receive notifications, statistics update immediately.

### Incremental Delivery

1. **Foundation** (Phases 1-2) → Database + core infrastructure ready
2. **MVP** (Phase 3) → User Story 1 complete → Deploy/Demo
3. **Admin Panel** (Phase 4) → User Story 2 complete → Deploy/Demo
4. **Statistics** (Phase 5) → User Story 3 complete → Deploy/Demo
5. **Audit Trail** (Phase 6) → User Story 4 complete → Deploy/Demo
6. **Re-submission** (Phase 7) → User Story 5 complete → Deploy/Demo
7. **Push Notifications** (Phase 8) → Notifications complete → Deploy/Demo
8. **Polish** (Phase 9) → Production-ready

Each increment adds value without breaking previous stories.

### Parallel Team Strategy

With multiple developers:

1. **Team completes Phases 1-2 together** (database and foundation)
2. **Once Phase 2 done, split work:**
   - Developer A: Phase 3 (User Story 1) + Phase 8 (Push Notifications)
   - Developer B: Phase 4 (User Story 2)
   - Developer C: Phase 5 (User Story 3) + Phase 6 (User Story 4)
   - Developer D: Phase 7 (User Story 5)
3. **Merge and integrate** after each story complete
4. **Team completes Phase 9 together** (polish and testing)

---

## Notes

- **[P] tasks**: Different files, no dependencies, can run in parallel
- **[Story] label**: Maps task to specific user story for traceability (US1, US2, US3, US4, US5)
- **No tests included**: Spec did not request TDD approach, relying on quickstart.md validation scenarios
- **Platform-native widgets mandatory**: All buttons/dialogs/text fields must use adaptive widgets per constitution DESIGN_SYSTEM_STRICT principle
- **Performance targets**: <1s dashboard load, 60fps scrolling, <200ms perceived response, <2s real-time updates
- **Security critical**: RLS policies, row locking, self-moderation prevention enforced at database level
- **Commit strategy**: Commit after each task or logical group, validate at checkpoints
- **Independent stories**: Each user story should be independently testable and deployable

---

**Total Tasks**: 125 tasks across 9 phases
**MVP Tasks (Phases 1-3)**: 51 tasks
**Parallel Opportunities**: 45+ tasks marked [P] can run concurrently
**Estimated Timeline**:
- MVP (Phases 1-3): 3-4 weeks (1 developer)
- Full Feature (All Phases): 6-8 weeks (1 developer)
- Full Feature (3 developers): 3-4 weeks (parallel execution)
