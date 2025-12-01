# Tasks: Sistema Profilo Utente

**Input**: Design documents from `/specs/006-user-profile/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, dependencies, and database schema

- [X] T001 Add Flutter dependencies to nova/pubspec.yaml (image_cropper ^5.0.1, flutter_image_compress ^2.1.0, go_router ^13.0.0)
- [X] T002 Run flutter pub get to install new dependencies
- [X] T003 [P] Configure image_cropper platform permissions in nova/android/app/src/main/AndroidManifest.xml (UCropActivity)
- [X] T004 [P] Configure image_cropper platform permissions in nova/ios/Runner/Info.plist (NSCameraUsageDescription, NSPhotoLibraryUsageDescription)
- [X] T005 Create Supabase migration file supabase/migrations/006_user_profile_system.sql
- [X] T006 Apply migration: Extend profiles table (full_name, username, class, bio, avatar_url, role, profile_visible, deleted_at columns)
- [X] T007 [P] Create indexes in migration (idx_profiles_username, idx_profiles_deleted_at)
- [X] T008 [P] Create Supabase Storage bucket 'avatars' with public read access in migration
- [X] T009 Create username generation function generate_unique_username(email) in migration (accent removal, collision handling)
- [X] T010 Create trigger set_username_on_signup() to auto-generate username on profile creation in migration
- [X] T011 Create bio sanitization function sanitize_bio() in migration (remove URLs, HTML tags, truncate 150 char)
- [X] T012 Create trigger trigger_sanitize_bio on profiles table in migration
- [X] T013 Create profile stats function get_profile_stats(user_id) in migration (returns events_created_count, participations_count)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T014 Create RLS policies for profiles table in migration (SELECT public profiles, SELECT own profile, UPDATE own profile, soft delete)
- [ ] T015 Create RLS policies for storage.objects (avatars bucket: owner write, public read, owner delete) in migration
- [ ] T016 Create Profile entity class in nova/lib/features/profile/domain/entities/profile.dart (id, email, full_name, username, class, bio, avatar_url, role, profile_visible, created_at, updated_at, deleted_at)
- [ ] T017 [P] Create ProfileStats entity in nova/lib/features/profile/domain/entities/profile_stats.dart (events_created_count, participations_count)
- [ ] T018 [P] Create ProfileModel in nova/lib/features/profile/data/models/profile_model.dart (extends Profile, JSON serialization fromJson/toJson)
- [ ] T019 [P] Create ProfileStatsModel in nova/lib/features/profile/data/models/profile_stats_model.dart (extends ProfileStats, JSON serialization)
- [ ] T020 Create ProfileRemoteDatasource in nova/lib/features/profile/data/datasources/profile_remote_datasource.dart (Supabase REST API: getProfile, updateProfile, getProfileStats)
- [ ] T021 [P] Create AvatarStorageDatasource in nova/lib/features/profile/data/datasources/avatar_storage_datasource.dart (Supabase Storage: uploadAvatar, deleteAvatar)
- [ ] T022 Create ProfileRepository in nova/lib/features/profile/data/repositories/profile_repository.dart (implements repository interface, uses remote datasource)
- [ ] T023 Create image compression utility in nova/lib/core/utils/image_compressor.dart (compressAvatar function: 2MB → 500KB WebP using flutter_image_compress)
- [ ] T024 Configure go_router deep link route /profile/:userId in nova/lib/core/router/app_router.dart (redirect to login if not authenticated)
- [ ] T025 Configure deep link intent filter in nova/android/app/src/main/AndroidManifest.xml (scheme: nova, host: profile)
- [ ] T026 Configure deep link CFBundleURLTypes in nova/ios/Runner/Info.plist (scheme: nova)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Visualizzazione e Completamento Profilo Proprio (Priority: P1) 🎯 MVP

**Goal**: Marco can view and complete his own profile (avatar upload + crop, name, class, bio). This is the core identity feature.

**Independent Test**: Create new account, open Profilo tab, edit profile (upload avatar, select class, add bio), save, verify changes persisted and displayed correctly.

### Implementation for User Story 1

- [ ] T027 [P] [US1] Create GetProfile usecase in nova/lib/features/profile/domain/usecases/get_profile.dart (loads profile by user_id)
- [ ] T028 [P] [US1] Create UpdateProfile usecase in nova/lib/features/profile/domain/usecases/update_profile.dart (updates full_name, class, bio, avatar_url)
- [ ] T029 [P] [US1] Create UploadAvatar usecase in nova/lib/features/profile/domain/usecases/upload_avatar.dart (crop + compress + upload flow)
- [ ] T030 [US1] Create ProfileProvider Riverpod provider in nova/lib/features/profile/presentation/providers/profile_provider.dart (manages current user profile state, uses GetProfile usecase)
- [ ] T031 [P] [US1] Create ProfileEditProvider Riverpod provider in nova/lib/features/profile/presentation/providers/profile_edit_provider.dart (manages edit form state, validation)
- [ ] T032 [P] [US1] Create AvatarUploadProvider Riverpod provider in nova/lib/features/profile/presentation/providers/avatar_upload_provider.dart (manages upload progress, compression state)
- [ ] T033 [US1] Create ProfileHeader widget in nova/lib/features/profile/presentation/widgets/profile_header.dart (displays avatar 96×96px, full_name, username, class, bio, moderator badge if role=moderator)
- [ ] T034 [P] [US1] Create ProfileStats widget in nova/lib/features/profile/presentation/widgets/profile_stats.dart (displays "X eventi creati | Y partecipazioni")
- [ ] T035 [P] [US1] Create ProfileBio widget in nova/lib/features/profile/presentation/widgets/profile_bio.dart (displays bio max 150 char with emoji support)
- [ ] T036 [P] [US1] Create ProfileTabs widget in nova/lib/features/profile/presentation/widgets/profile_tabs.dart (Eventi / Partecipazioni tabs, platform-adaptive: CupertinoSegmentedControl iOS, TabBar Android)
- [ ] T037 [P] [US1] Create EventsGrid widget in nova/lib/features/profile/presentation/widgets/events_grid.dart (grid 3 columns, lazy loading with ListView.builder)
- [ ] T038 [P] [US1] Create AvatarPicker widget in nova/lib/features/profile/presentation/widgets/avatar_picker.dart (image picker + circular crop using image_cropper, platform-adaptive action sheet)
- [ ] T039 [US1] Create ProfileScreen in nova/lib/features/profile/presentation/screens/profile_screen.dart (own profile view: header, stats, tabs, "Modifica Profilo" button, Settings icon)
- [ ] T040 [US1] Create EditProfileScreen in nova/lib/features/profile/presentation/screens/edit_profile_screen.dart (modal/screen: avatar picker, name field, class dropdown 38 classes + Altro, bio textarea with character counter 0/150, Salva/Annulla buttons)
- [ ] T041 [US1] Implement validation in EditProfileScreen (full_name min 2 words, class required, bio max 150 char, avatar max 2MB min 200×200px)
- [ ] T042 [US1] Implement save flow in EditProfileScreen (compress avatar client-side, upload to Storage, update profiles.avatar_url, show toast "Profilo aggiornato!")
- [ ] T043 [US1] Add "Profilo" tab to bottom navigation in nova/lib/shared/widgets/nova_bottom_nav_bar.dart (5th tab, icon: CupertinoIcons.person iOS, Icons.person Android)
- [ ] T044 [US1] Integrate ProfileScreen into main app navigation (bottom nav tap → navigate to ProfileScreen)
- [ ] T045 [US1] Add platform-adaptive UI components (Cupertino for iOS: CupertinoButton, CupertinoTextField, CupertinoActionSheet; Material for Android: FilledButton, TextField, ModalBottomSheet)
- [ ] T046 [US1] Implement avatar placeholder (iniziali on gradient brand if no avatar_url) in ProfileHeader widget
- [ ] T047 [US1] Implement optimistic UI for profile edit (show changes immediately, rollback on error)

**Checkpoint**: At this point, User Story 1 should be fully functional - Marco can complete his profile with avatar, class, bio

---

## Phase 4: User Story 2 - Visualizzazione Profilo Altri Utenti e Scoperta Eventi (Priority: P1)

**Goal**: Sofia can view Marco's profile (avatar, name, class, bio, stats, events created) by tapping creator name in event card. Privacy: no Partecipazioni tab visible to others.

**Independent Test**: Create two accounts (A and B), have A create event, login as B, tap creator name in feed → verify B can view A's profile with Eventi tab only (no Partecipazioni).

### Implementation for User Story 2

- [ ] T048 [P] [US2] Create OtherProfileProvider Riverpod provider in nova/lib/features/profile/presentation/providers/other_profile_provider.dart (loads profile by user_id, caches 1h)
- [ ] T049 [US2] Create OtherProfileScreen in nova/lib/features/profile/presentation/screens/other_profile_screen.dart (similar to ProfileScreen but: no "Modifica Profilo" button, no Partecipazioni tab, only Eventi tab visible)
- [ ] T050 [US2] Update EventCard widget (or event detail screen) to make creator name clickable (onTap → navigate to OtherProfileScreen with creator_id)
- [ ] T051 [US2] Implement RLS policy check in ProfileProvider (if profile_visible=false, show "Profilo non disponibile" message in OtherProfileScreen)
- [ ] T052 [US2] Implement "Profilo non disponibile" empty state in OtherProfileScreen (when profile hidden or deleted_at not null)
- [ ] T053 [US2] Add "Condividi Profilo" button in OtherProfileScreen header (for US4 prep, can be disabled until US4)

**Checkpoint**: At this point, User Stories 1 AND 2 work - users can view own profile and others' profiles with privacy

---

## Phase 5: User Story 3 - Gestione Privacy e GDPR Compliance (Priority: P2)

**Goal**: Marco can control privacy (toggle "Profilo visibile"), export all his data as JSON (GDPR Right to Access), and delete account with 30-day grace period (GDPR Right to Erasure).

**Independent Test**: Create account, generate data (events, comments, participations), export JSON and verify completeness, soft delete account and verify 30-day grace period, reactivate within 30 days.

### Implementation for User Story 3

- [ ] T054 [P] [US3] Create GDPRExportModel in nova/lib/features/profile/data/models/gdpr_export_model.dart (JSON schema: export_version, export_date, user_id, profile, events_created, participations, comments, chat_messages)
- [ ] T055 [P] [US3] Create GDPRExportDatasource in nova/lib/features/profile/data/datasources/gdpr_export_datasource.dart (calls Supabase Edge Function export-user-data, polls for completion)
- [ ] T056 [P] [US3] Create GDPRRepository in nova/lib/features/profile/data/repositories/gdpr_repository.dart (exportUserData, softDeleteAccount, reactivateAccount)
- [ ] T057 [P] [US3] Create ExportUserData usecase in nova/lib/features/profile/domain/usecases/export_user_data.dart (triggers export, returns download link)
- [ ] T058 [P] [US3] Create DeleteAccount usecase in nova/lib/features/profile/domain/usecases/delete_account.dart (soft delete: set deleted_at=NOW())
- [ ] T059 [US3] Create Supabase Edge Function supabase/functions/export-user-data/index.ts (queries profile, events, participations, comments, chat messages last 24h, generates JSON, uploads to Storage gdpr-exports/, returns signed URL 24h expiry)
- [ ] T060 [US3] Create GDPRExportProvider Riverpod provider in nova/lib/features/profile/presentation/providers/gdpr_export_provider.dart (manages export generation state, polling)
- [ ] T061 [US3] Create SettingsScreen in nova/lib/features/profile/presentation/screens/settings_screen.dart (sections: Account read-only, Privacy, Notifiche, Info, Moderazione if role=moderator)
- [ ] T062 [US3] Implement Account section in SettingsScreen (email read-only, username read-only, data iscrizione read-only)
- [ ] T063 [US3] Implement Privacy section in SettingsScreen (toggle "Profilo visibile", button "Scarica i tuoi dati", button "Elimina account" red)
- [ ] T064 [US3] Implement "Profilo visibile" toggle (updates profiles.profile_visible, if false → RLS hides profile to others)
- [ ] T065 [US3] Implement "Scarica i tuoi dati" button (calls ExportUserData usecase, shows loading "Generazione dati in corso...", target <10s, shows notification with download link)
- [ ] T066 [US3] Implement "Elimina account" flow (shows CupertinoAlertDialog iOS / AlertDialog Android: "Sei sicuro? Account eliminato dopo 30 giorni. Puoi annullare entro 30 giorni.", buttons "Annulla" and "Conferma eliminazione" red)
- [ ] T067 [US3] Implement soft delete on confirm (calls DeleteAccount usecase, sets deleted_at=NOW(), shows banner "Account eliminato. Hai 30 giorni per annullare.")
- [ ] T068 [US3] Implement reactivation flow (if user logs in with deleted_at not null and within 30 days, show dialog "Vuoi riattivare il tuo account?" → if yes, set deleted_at=NULL)
- [ ] T069 [US3] Create hard delete cron job in supabase/migrations/006_user_profile_system.sql (pg_cron or Edge Function scheduled: DELETE FROM profiles WHERE deleted_at < NOW() - INTERVAL '30 days', also delete avatar from Storage)
- [ ] T070 [US3] Update event creator display logic (if creator deleted_at not null, show "Utente eliminato" instead of creator name)
- [ ] T071 [US3] Add Settings icon (⚙️) in ProfileScreen header (top-right, navigate to SettingsScreen)
- [ ] T072 [US3] Implement Notifiche section in SettingsScreen (toggles: "Notifiche eventi" default ON, "Notifiche chat" default ON, "Notifiche moderazione" if role=moderator)

**Checkpoint**: At this point, User Stories 1, 2, AND 3 work - full GDPR compliance with export and delete

---

## Phase 6: User Story 4 - Condivisione Profilo e Deep Links (Priority: P2)

**Goal**: Sofia can share Marco's profile via deep link nova://profile/{user_id} in chat. Tapping link navigates directly to profile.

**Independent Test**: Create two accounts, share profile via "Condividi Profilo" → "Condividi in Chat", send message with link, tap link → verify navigates to profile.

### Implementation for User Story 4

- [ ] T073 [P] [US4] Create ShareService in nova/lib/core/services/share_service.dart (generates deep link nova://profile/{user_id}, handles clipboard copy, navigates to chat with pre-filled message)
- [ ] T074 [P] [US4] Create ShareProfileSheet widget in nova/lib/features/profile/presentation/widgets/share_profile_sheet.dart (bottom sheet: "Copia Link" 🔗, "Condividi in Chat" 💬, "Annulla", platform-adaptive)
- [ ] T075 [US4] Implement "Condividi Profilo" button functionality in OtherProfileScreen and ProfileScreen (tap → show ShareProfileSheet)
- [ ] T076 [US4] Implement "Copia Link" option (copy "nova://profile/{user_id}" to clipboard, show toast "Link copiato!", close sheet)
- [ ] T077 [US4] Implement "Condividi in Chat" option (navigate to Chat tab with pre-filled message: "Guarda il profilo di [Nome Completo]: nova://profile/{user_id}", cursor at end)
- [ ] T078 [US4] Update go_router configuration to handle deep link interception (route /profile/:userId already configured in T024, verify works end-to-end)
- [ ] T079 [US4] Implement auth check in deep link redirect (if not logged in, redirect to /login?redirect=/profile/{userId}, after login navigate to profile)
- [ ] T080 [US4] Implement error handling for invalid deep links (if user_id not found or deleted_at not null, show error screen "Profilo non trovato" with button "Torna al Feed")
- [ ] T081 [US4] Make chat messages with deep links clickable (if Chat screen not implemented yet, document integration point for future)

**Checkpoint**: At this point, User Stories 1-4 work - profile sharing via deep links functional

---

## Phase 7: User Story 5 - Visualizzazione Badge Moderatore e Credibilità (Priority: P3)

**Goal**: Anna (moderator) sees badge "Moderatore 🛡️" in her profile and others see it too. Avatar has gradient border viola→pink. Settings has extra "Moderazione" section.

**Independent Test**: Create account with role=moderator, verify badge visible in own profile and to others, verify gradient border on avatar, verify Settings has "Moderazione" section.

### Implementation for User Story 5

- [ ] T082 [P] [US5] Create ModeratorBadge widget in nova/lib/features/profile/presentation/widgets/moderator_badge.dart (badge "Moderatore 🛡️" with viola brand color, padding 4×8px, border-radius standard)
- [ ] T083 [US5] Update ProfileHeader widget to show ModeratorBadge under username if role=moderator (check profile.role === 'moderator')
- [ ] T084 [US5] Update ProfileHeader widget to show gradient border viola→pink (2px width) around avatar if role=moderator (use NovaColors gradient brand)
- [ ] T085 [US5] Implement "Moderazione" section in SettingsScreen (only visible if role=moderator, includes link "Dashboard Moderazione", shows stats "Review fatte: X | Tasso approval: Y%")
- [ ] T086 [US5] Fetch moderator stats from backend (create RPC function get_moderator_stats if needed, returns review count and approval rate)
- [ ] T087 [US5] Verify badge publicly visible in OtherProfileScreen (Sofia can see Anna's moderator badge when viewing her profile)

**Checkpoint**: All 5 user stories complete - full profile system with moderator transparency

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories, final validation

- [ ] T088 [P] Add loading states to all screens (ProfileScreen, EditProfileScreen, OtherProfileScreen, SettingsScreen: shimmer placeholders or CupertinoActivityIndicator/CircularProgressIndicator)
- [ ] T089 [P] Add error states to all screens (network errors, RLS permission errors, validation errors: show adaptive error messages)
- [ ] T090 [P] Implement pull-to-refresh in ProfileScreen and OtherProfileScreen (CupertinoSliverRefreshControl iOS, RefreshIndicator Android)
- [ ] T091 Add offline support (cache profile data 24h in Hive, avatar URL 7 days, show cached data if network unavailable)
- [ ] T092 Verify all colors use NovaColors design system (no hardcoded Color(0xFF...) hex codes, audit with grep)
- [ ] T093 Verify all spacing uses NovaSpacing constants (no hardcoded EdgeInsets, audit with grep)
- [ ] T094 Verify all typography uses NovaTypography (no hardcoded TextStyle with fontSize, audit with grep)
- [ ] T095 [P] Add analytics logging (profile view events, profile edit events, avatar upload events, GDPR export events - if analytics implemented)
- [ ] T096 Test avatar compression performance (benchmark 2MB → 500KB WebP on mid-range Android, verify <500ms target per research.md)
- [ ] T097 Test profile load performance (measure tap creator name → profile rendered, verify <1s target per SC-005)
- [ ] T098 Test avatar upload performance (measure tap Salva → toast "Profilo aggiornato!", verify <3s target per SC-010)
- [ ] T099 Test GDPR export performance (measure tap "Scarica dati" → notification ready, verify <10s target per SC-004)
- [ ] T100 Test scroll performance in EventsGrid 3 columns (use Flutter DevTools timeline, verify sustained 60fps, no dropped frames)
- [ ] T101 Run all quickstart.md scenarios manually (Scenario 1-6: complete profile, view other, share, GDPR export, delete account, moderator badge)
- [ ] T102 [P] Add accessibility labels (Semantics widgets for screen readers, contrast ratio check WCAG 2.1 AA)
- [ ] T103 [P] Security audit (verify RLS policies prevent unauthorized access, bio sanitization prevents XSS, avatar upload validates file types)
- [ ] T104 Update documentation (README if needed, inline code comments for complex logic like username generation collision handling)
- [ ] T105 Code cleanup and refactoring (remove TODOs, dead code, console.logs, ensure consistent formatting with dart format)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion (T001-T013) - BLOCKS all user stories
- **User Stories (Phases 3-7)**: All depend on Foundational phase completion (T014-T026)
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P1 → P2 → P2 → P3)
- **Polish (Phase 8)**: Depends on desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories (independent)
- **User Story 3 (P2)**: Can start after Foundational (Phase 2) - Integrates with US1 (Settings in ProfileScreen) but testable independently
- **User Story 4 (P2)**: Can start after Foundational (Phase 2) - Integrates with US2 (share button in OtherProfileScreen) but testable independently
- **User Story 5 (P3)**: Can start after Foundational (Phase 2) - Integrates with US1 (badge in ProfileHeader) but testable independently

### Within Each User Story

- Usecases/Providers before Screens
- Widgets before Screens that use them
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

**Setup Phase (T001-T013)**: Can run in parallel groups
- T003, T004 (platform configs)
- T007, T008 (indexes + storage bucket)

**Foundational Phase (T014-T026)**: Can run in parallel groups
- T016, T017, T018, T019 (entities + models)
- T020, T021 (datasources)
- T025, T026 (deep link configs)

**User Story 1 (T027-T047)**: Can run in parallel groups
- T027, T028, T029 (usecases)
- T030, T031, T032 (providers)
- T033, T034, T035, T036, T037, T038 (widgets)

**User Story 2 (T048-T053)**: Small story, T048 and T049 can run in parallel

**User Story 3 (T054-T072)**: Can run in parallel groups
- T054, T055, T056 (GDPR models + datasources)
- T057, T058 (usecases)

**User Story 5 (T082-T087)**: T082 can run independently

**Polish Phase (T088-T105)**: Many tasks can run in parallel
- T088, T089, T090 (loading/error/refresh states)
- T092, T093, T094 (design system audits)
- T096, T097, T098, T099, T100 (performance tests)
- T102, T103, T104 (accessibility, security, docs)

Once Foundational phase completes, ALL 5 user stories can start in parallel if team capacity allows.

---

## Parallel Example: User Story 1

```bash
# After Foundational phase complete, launch all usecases together:
Task T027: "Create GetProfile usecase in nova/lib/features/profile/domain/usecases/get_profile.dart"
Task T028: "Create UpdateProfile usecase in nova/lib/features/profile/domain/usecases/update_profile.dart"
Task T029: "Create UploadAvatar usecase in nova/lib/features/profile/domain/usecases/upload_avatar.dart"

# Then launch all providers together:
Task T030: "Create ProfileProvider in nova/lib/features/profile/presentation/providers/profile_provider.dart"
Task T031: "Create ProfileEditProvider in nova/lib/features/profile/presentation/providers/profile_edit_provider.dart"
Task T032: "Create AvatarUploadProvider in nova/lib/features/profile/presentation/providers/avatar_upload_provider.dart"

# Then launch all independent widgets together:
Task T033: "Create ProfileHeader widget"
Task T034: "Create ProfileStats widget"
Task T035: "Create ProfileBio widget"
Task T036: "Create ProfileTabs widget"
Task T037: "Create EventsGrid widget"
Task T038: "Create AvatarPicker widget"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2 Only - Both P1)

1. Complete Phase 1: Setup (T001-T013)
2. Complete Phase 2: Foundational (T014-T026) - CRITICAL: blocks all stories
3. Complete Phase 3: User Story 1 (T027-T047) - Own profile view + edit
4. Complete Phase 4: User Story 2 (T048-T053) - View other profiles
5. **STOP and VALIDATE**: Test US1 and US2 independently with quickstart.md Scenarios 1 and 2
6. Deploy/demo MVP (students can create and view profiles)

### Incremental Delivery (Recommended)

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 + 2 (both P1) → Test independently → Deploy/Demo (MVP!)
3. Add User Story 3 (P2 - GDPR) → Test independently → Deploy/Demo (GDPR compliant!)
4. Add User Story 4 (P2 - Share) → Test independently → Deploy/Demo (viral growth enabled!)
5. Add User Story 5 (P3 - Badge) → Test independently → Deploy/Demo (moderator transparency!)
6. Polish Phase → Final validation → Production ready

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (T001-T026)
2. Once Foundational is done:
   - Developer A: User Story 1 (T027-T047)
   - Developer B: User Story 2 (T048-T053)
   - Developer C: User Story 3 (T054-T072)
   - Developer D: User Story 4 (T073-T081)
   - Developer E: User Story 5 (T082-T087)
3. Stories complete and integrate independently
4. Team merges to main, tests integration, runs Polish phase together

---

## Notes

- **[P] tasks**: Different files, no dependencies, can run in parallel
- **[Story] label**: Maps task to specific user story for traceability (US1-US5)
- **Each user story** should be independently completable and testable
- **No tests included**: Feature spec doesn't explicitly request TDD, tests optional per template
- **Commit often**: Commit after each task or logical group
- **Stop at checkpoints**: Validate each story independently before proceeding
- **Platform-adaptive UI**: All screens/widgets must use Cupertino (iOS) or Material (Android) components per FR-036
- **Design system strict**: Zero hardcoded colors/spacing/typography per Principle 6 (audit in Polish phase T092-T094)
- **Performance targets**: Profile load <1s, avatar upload <3s, GDPR export <10s, 60fps scroll (validate in Polish phase T096-T100)

---

**Total Tasks**: 105
- Phase 1 (Setup): 13 tasks
- Phase 2 (Foundational): 13 tasks
- Phase 3 (US1 - P1): 21 tasks
- Phase 4 (US2 - P1): 6 tasks
- Phase 5 (US3 - P2): 19 tasks
- Phase 6 (US4 - P2): 9 tasks
- Phase 7 (US5 - P3): 6 tasks
- Phase 8 (Polish): 18 tasks

**Estimated MVP Scope** (US1 + US2): 26 foundational tasks + 27 user story tasks = 53 tasks

**Parallel Opportunities**: ~40% of tasks can run in parallel within phases
