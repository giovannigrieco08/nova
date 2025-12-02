# Tasks: Push Notifications

**Input**: Design documents from `/specs/009-push-notifications/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Manual device testing required (iOS/Android physical devices). No automated tests specified.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Flutter App**: `nova/lib/`
- **Supabase Functions**: `supabase/functions/`
- **Supabase Migrations**: `supabase/migrations/`
- **iOS Config**: `nova/ios/`
- **Android Config**: `nova/android/`

---

## Phase 1: Setup (Database & Backend Infrastructure)

**Purpose**: Create database schema and Edge Function foundation for all push functionality

- [x] T001 Create migration file `supabase/migrations/009_push_notifications.sql` with fcm_tokens table schema
- [x] T002 Add RLS policies for fcm_tokens table (users can CRUD own tokens) in `supabase/migrations/009_push_notifications.sql`
- [x] T003 Add `push_enabled` column to profiles table in `supabase/migrations/009_push_notifications.sql`
- [x] T004 Create indexes for fcm_tokens table (user_id, last_used_at) in `supabase/migrations/009_push_notifications.sql`
- [x] T005 [P] Create Edge Function directory structure `supabase/functions/send-push-notification/index.ts`
- [x] T006 Implement Edge Function: parse webhook payload in `supabase/functions/send-push-notification/index.ts`
- [x] T007 Implement Edge Function: query fcm_tokens for recipient in `supabase/functions/send-push-notification/index.ts`
- [x] T008 Implement Edge Function: check push_enabled flag in `supabase/functions/send-push-notification/index.ts`
- [x] T009 Implement Edge Function: send FCM HTTP API call in `supabase/functions/send-push-notification/index.ts`
- [x] T010 Implement Edge Function: handle invalid token cleanup in `supabase/functions/send-push-notification/index.ts`
- [x] T011 Implement Edge Function: include badge_count in payload in `supabase/functions/send-push-notification/index.ts`
- [x] T012 Document webhook configuration in `specs/009-push-notifications/WEBHOOK_SETUP.md`

**Checkpoint**: Database schema ready, Edge Function deployable. Manual webhook configuration required in Supabase Dashboard.

---

## Phase 2: Foundational (Flutter FCM Infrastructure)

**Purpose**: Core FCM integration that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T013 Add `flutter_app_badger: ^1.6.0` dependency to `nova/pubspec.yaml`
- [x] T014 [P] Create `FcmToken` entity in `nova/lib/features/notifications/domain/entities/fcm_token.dart`
- [x] T015 [P] Create `PushPayload` entity in `nova/lib/features/notifications/domain/entities/push_payload.dart`
- [x] T016 [P] Create `NotificationPermissionState` enum in `nova/lib/features/notifications/domain/entities/notification_permission_state.dart`
- [x] T017 Create `FcmTokenModel` with JSON serialization in `nova/lib/features/notifications/data/models/fcm_token_model.dart`
- [x] T018 Create `FcmTokenRemoteDataSource` in `nova/lib/features/notifications/data/datasources/fcm_token_remote_datasource.dart`
- [x] T019 Create `PushRepository` interface in `nova/lib/features/notifications/domain/repositories/push_repository_interface.dart`
- [x] T020 Implement `PushRepositoryImpl` in `nova/lib/features/notifications/data/repositories/push_repository.dart`
- [x] T021 Create `PushNotificationService` in `nova/lib/core/services/push_notification_service.dart`
- [x] T022 Add background message handler function in `nova/lib/main.dart`
- [x] T023 Initialize FCM in app startup sequence in `nova/lib/main.dart`
- [x] T024 Create push notification Riverpod providers in `nova/lib/features/notifications/presentation/providers/push_providers.dart`

**Checkpoint**: Foundation ready - FCM initialized, entities defined, repository pattern established.

---

## Phase 3: User Story 1 - Ricevere Push con App Chiusa (Priority: P1) MVP

**Goal**: Students receive push notifications on their devices when the app is closed/backgrounded

**Independent Test**: Close app completely, have another user comment on your event, verify push arrives within 5 seconds

### Implementation for User Story 1

- [x] T025 [US1] Create `RegisterFcmToken` use case in `nova/lib/features/notifications/domain/usecases/register_fcm_token.dart`
- [x] T026 [US1] Create `RemoveFcmToken` use case in `nova/lib/features/notifications/domain/usecases/remove_fcm_token.dart`
- [x] T027 [US1] Implement token registration on login in `nova/lib/core/services/push_notification_service.dart`
- [x] T028 [US1] Implement token deletion on logout in `nova/lib/core/services/push_notification_service.dart`
- [x] T029 [US1] Implement token refresh handling in `nova/lib/core/services/push_notification_service.dart`
- [x] T030 [US1] Call registerFcmToken after successful auth in `nova/lib/features/auth/presentation/providers/auth_notifier.dart`
- [x] T031 [US1] Call removeFcmToken before signOut in `nova/lib/features/auth/presentation/providers/auth_notifier.dart`
- [x] T032 [US1] Store device platform (ios/android) with token in `nova/lib/features/notifications/data/datasources/fcm_token_remote_datasource.dart`
- [x] T033 [US1] Add device name to token registration (optional) in `nova/lib/features/notifications/data/datasources/fcm_token_remote_datasource.dart`

**Checkpoint**: Push notifications delivered to closed app. Token lifecycle managed correctly.

---

## Phase 4: User Story 2 - Navigazione da Push a Contenuto (Priority: P1)

**Goal**: Tapping a push notification navigates directly to the relevant content (event or comment)

**Independent Test**: Receive push with app closed, tap notification, verify app opens directly to target content

### Implementation for User Story 2

- [x] T034 [US2] Create `HandlePushTap` use case in `nova/lib/features/notifications/domain/usecases/handle_push_tap.dart`
- [x] T035 [US2] Implement `onMessageOpenedApp` handler for background state in `nova/lib/core/services/push_notification_service.dart`
- [x] T036 [US2] Implement `getInitialMessage` handler for terminated state in `nova/lib/core/services/push_notification_service.dart`
- [x] T037 [US2] Parse PushPayload from FCM RemoteMessage.data in `nova/lib/features/notifications/domain/entities/push_payload.dart`
- [x] T038 [US2] Implement navigation to event deep link in `nova/lib/main.dart`
- [x] T039 [US2] Implement navigation to comment deep link (event + scroll to comment) in `nova/lib/main.dart`
- [x] T040 [US2] Handle deleted content gracefully with error snackbar in `nova/lib/main.dart`
- [x] T041 [US2] Mark notification as read when opened via push in `nova/lib/features/notifications/domain/usecases/handle_push_tap.dart`

**Checkpoint**: All push taps navigate correctly. Deleted content shows appropriate error.

---

## Phase 5: User Story 3 - Gestione Permessi Notifiche (Priority: P1)

**Goal**: Clear permission request flow that explains value and handles denied state

**Independent Test**: Install app on new device, first login shows permission dialog with clear explanation

### Implementation for User Story 3

- [x] T042 [US3] Create `PushPermissionProvider` in `nova/lib/features/notifications/presentation/providers/push_permission_provider.dart`
- [x] T043 [US3] Create pre-permission explanation widget in `nova/lib/features/notifications/presentation/widgets/push_permission_dialog.dart`
- [x] T044 [US3] Implement iOS permission request with alert/badge/sound options in `nova/lib/core/services/push_notification_service.dart`
- [x] T045 [US3] Implement Android 13+ runtime permission request in `nova/lib/core/services/push_notification_service.dart`
- [x] T046 [US3] Store permission state in SharedPreferences in `nova/lib/features/notifications/presentation/providers/push_permission_provider.dart`
- [x] T047 [US3] Add "Enable notifications" link in settings screen in `nova/lib/features/profile/presentation/screens/settings_screen.dart`
- [x] T048 [US3] Implement openAppSettings() for denied users in `nova/lib/features/notifications/presentation/providers/push_permission_provider.dart`
- [x] T049 [US3] Show permission dialog on first login after profile setup in `nova/lib/features/profile/presentation/screens/profile_setup_screen.dart`

**Checkpoint**: Permission flow complete. Denied users can enable from settings.

---

## Phase 6: User Story 4 - Rispetto Preferenze Utente (Priority: P2)

**Goal**: Push notifications respect user channel preferences (disabled channels = no push)

**Independent Test**: Disable "Like agli eventi" preference, have someone like your event, verify NO push received

### Implementation for User Story 4

- [x] T050 [US4] Verify existing create_notification() checks preferences in `supabase/migrations/008_realtime_notifications.sql`
- [x] T051 [US4] Edge Function queries profiles.push_enabled before sending in `supabase/functions/send-push-notification/index.ts`
- [x] T052 [US4] Log skipped notifications (preference disabled) in Edge Function in `supabase/functions/send-push-notification/index.ts`
- [x] T053 [US4] Add global push toggle to notification preferences UI in `nova/lib/features/notifications/presentation/screens/notification_preferences_screen.dart`

**Checkpoint**: All preference channels respected. Global toggle works.

---

## Phase 7: User Story 5 - Notifiche in Foreground (Priority: P2)

**Goal**: Show in-app banner when notification arrives while app is open

**Independent Test**: With app open on events screen, have someone comment on your event, verify banner appears

### Implementation for User Story 5

- [x] T054 [US5] Create `InAppNotificationBanner` widget in `nova/lib/features/notifications/presentation/widgets/in_app_notification_banner.dart`
- [x] T055 [US5] Implement slide-in animation from top in `nova/lib/features/notifications/presentation/widgets/in_app_notification_banner.dart`
- [x] T056 [US5] Add auto-dismiss after 4 seconds in `nova/lib/features/notifications/presentation/widgets/in_app_notification_banner.dart`
- [x] T057 [US5] Implement `onMessage` handler for foreground state in `nova/lib/core/services/push_notification_service.dart`
- [x] T058 [US5] Show banner overlay on notification received in `nova/lib/main.dart`
- [x] T059 [US5] Handle banner tap for navigation in `nova/lib/features/notifications/presentation/widgets/in_app_notification_banner.dart`
- [x] T060 [US5] Handle banner swipe to dismiss in `nova/lib/features/notifications/presentation/widgets/in_app_notification_banner.dart`
- [x] T061 [US5] Apply design system styles (NovaColors, NovaSpacing) to banner in `nova/lib/features/notifications/presentation/widgets/in_app_notification_banner.dart`

**Checkpoint**: Foreground notifications show non-invasive banner.

---

## Phase 8: User Story 6 - Aggiornamento Badge Count (Priority: P3)

**Goal**: App icon badge shows unread notification count

**Independent Test**: Generate 3 notifications, verify badge shows "3", read all, verify badge clears

### Implementation for User Story 6

- [x] T062 [US6] Implement badge update on push received in `nova/lib/core/services/push_notification_service.dart`
- [x] T063 [US6] Implement badge clear when all notifications read in `nova/lib/features/notifications/presentation/providers/notification_providers.dart`
- [x] T064 [US6] Parse badge_count from FCM payload in `nova/lib/features/notifications/domain/entities/push_payload.dart`
- [x] T065 [US6] Call FlutterAppBadger.updateBadgeCount() in `nova/lib/core/services/push_notification_service.dart`
- [x] T066 [US6] Call FlutterAppBadger.removeBadge() when count is 0 in `nova/lib/features/notifications/presentation/providers/notification_providers.dart`
- [x] T067 [US6] Handle silent push for badge-only updates in `nova/lib/core/services/push_notification_service.dart`

**Checkpoint**: Badge count accurate on iOS and Android (best-effort).

---

## Phase 9: Platform Configuration (iOS)

**Purpose**: iOS-specific setup for push notifications

- [x] T068 [P] Add UIBackgroundModes with remote-notification to `nova/ios/Runner/Info.plist`
- [x] T069 [P] Verify GoogleService-Info.plist exists at `nova/ios/Runner/GoogleService-Info.plist`
- [x] T070 Document APNs key generation and Firebase upload in `specs/009-push-notifications/IOS_SETUP.md`

**Note**: APNs key must be manually generated in Apple Developer Portal and uploaded to Firebase Console.

---

## Phase 10: Platform Configuration (Android)

**Purpose**: Android-specific setup for push notifications

- [x] T071 [P] Verify POST_NOTIFICATIONS permission in `nova/android/app/src/main/AndroidManifest.xml`
- [x] T072 [P] Create notification channel for Android 8+ in `nova/lib/core/services/push_notification_service.dart`
- [x] T073 [P] Verify google-services.json exists at `nova/android/app/google-services.json`
- [x] T074 Add notification channel ID to FCM payload in `supabase/functions/send-push-notification/index.ts`

---

## Phase 11: Edge Cases & Polish

**Purpose**: Handle edge cases and cross-cutting concerns

- [x] T075 Handle token refresh edge case (old token cleanup) in `nova/lib/core/services/push_notification_service.dart`
- [x] T076 Add token cleanup on app reinstall detection in `nova/lib/core/services/push_notification_service.dart`
- [x] T077 Implement rate limiting (max 1 push per notification type per event per hour) in `supabase/functions/send-push-notification/index.ts`
- [x] T078 Implement stale token cleanup (30-day inactive) in Edge Function in `supabase/functions/send-push-notification/index.ts`
- [x] T079 Add logging for push delivery success/failure in Edge Function in `supabase/functions/send-push-notification/index.ts`
- [x] T080 Handle multi-device token management (same user, multiple devices) in `nova/lib/features/notifications/data/datasources/fcm_token_remote_datasource.dart`
- [x] T081 Add error handling for FCM API failures with retry in `supabase/functions/send-push-notification/index.ts`

---

## Phase 12: Testing & Validation

**Purpose**: Manual testing across all scenarios

- [ ] T082 Test push delivery with app terminated (cold start)
- [ ] T083 Test push delivery with app in background
- [ ] T084 Test push delivery with app in foreground
- [ ] T085 Test deep link navigation from push (event target)
- [ ] T086 Test deep link navigation from push (comment target)
- [ ] T087 Test navigation to deleted content (error handling)
- [ ] T088 Test multi-device scenario (same user, 2 devices)
- [ ] T089 Test preference respect (disabled channel = no push)
- [ ] T090 Test token cleanup on logout
- [ ] T091 Test badge count accuracy
- [ ] T092 Test permission flow on iOS
- [ ] T093 Test permission flow on Android 13+
- [ ] T094 Performance test: verify <5s delivery time
- [ ] T095 Run quickstart.md scenarios for validation

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup/Database) ───► Phase 2 (Foundational) ───┬──► Phase 3 (US1: Push Delivery)
                                                         │         │
                                                         │         ▼
                                                         │   Phase 4 (US2: Deep Link)
                                                         │         │
                                                         │         ▼
                                                         │   Phase 5 (US3: Permissions)
                                                         │         │
                                                         ├─────────┼──► Phase 6 (US4: Preferences)
                                                         │         │
                                                         │         ▼
                                                         │   Phase 7 (US5: Foreground)
                                                         │         │
                                                         │         ▼
                                                         └──────► Phase 8 (US6: Badge)

Phase 9 (iOS Config) ─────────┐
                              ├──► Phase 11 (Edge Cases) ───► Phase 12 (Testing)
Phase 10 (Android Config) ────┘
```

### User Story Dependencies

- **User Story 1 (P1)**: Requires Phase 1 + 2. No dependencies on other stories.
- **User Story 2 (P1)**: Requires US1 complete (token must be registered to receive push)
- **User Story 3 (P1)**: Can run in parallel with US1 (permission before token registration)
- **User Story 4 (P2)**: Independent - tests existing preference system
- **User Story 5 (P2)**: Requires US1 complete (must receive pushes to show banner)
- **User Story 6 (P3)**: Requires US1 complete (must receive pushes to update badge)

### Parallel Opportunities

**Phase 1 (Setup)**:
```
T005 Create Edge Function structure  [P] - can run with database migration
```

**Phase 2 (Foundational)**:
```
T014 Create FcmToken entity         [P]
T015 Create PushPayload entity      [P]
T016 Create PermissionState enum    [P]
```

**Phase 9 + 10 (Platform Config)**:
```
T068-T070 (iOS)     [P]
T071-T074 (Android) [P]
```

---

## Implementation Strategy

### MVP First (User Stories 1-3 Only)

1. Complete Phase 1: Database + Edge Function
2. Complete Phase 2: Foundational Flutter setup
3. Complete Phase 3: US1 - Push delivery working
4. Complete Phase 4: US2 - Deep links working
5. Complete Phase 5: US3 - Permissions working
6. Complete Phase 9-10: Platform config
7. **STOP and VALIDATE**: Test all P1 stories on physical devices
8. Deploy MVP

### Incremental Delivery

1. MVP (US1-3) → Core push functionality
2. Add US4 → Preference respect verified
3. Add US5 → Foreground banner polish
4. Add US6 → Badge count polish
5. Complete Phase 11-12 → Edge cases and full testing

---

## Summary

| Metric | Count |
|--------|-------|
| **Total Tasks** | 95 |
| **Phase 1 (Setup)** | 12 |
| **Phase 2 (Foundational)** | 12 |
| **Phase 3 (US1)** | 9 |
| **Phase 4 (US2)** | 8 |
| **Phase 5 (US3)** | 8 |
| **Phase 6 (US4)** | 4 |
| **Phase 7 (US5)** | 8 |
| **Phase 8 (US6)** | 6 |
| **Phase 9-10 (Platform)** | 7 |
| **Phase 11 (Edge Cases)** | 7 |
| **Phase 12 (Testing)** | 14 |
| **Parallel Opportunities** | 8 tasks |
| **MVP Scope** | US1 + US2 + US3 (37 tasks) |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Manual webhook configuration required in Supabase Dashboard after Phase 1
- Physical iOS device required for push testing (simulator doesn't support)
- APNs key must be manually configured in Apple Developer Portal + Firebase Console
