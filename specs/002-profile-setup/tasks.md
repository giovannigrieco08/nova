# Tasks: Instagram-Style Profile Setup

**Input**: Design documents from `/specs/002-profile-setup/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Test tasks are included per constitution TESTING_REQUIREMENTS. Tests are written first (TDD approach) to ensure they fail before implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Flutter mobile app structure per plan.md:
- **Core**: `nova/lib/core/` (constants, theme, utils, widgets)
- **Features**: `nova/lib/features/profile/` (data/domain/presentation)
- **Shared**: `nova/lib/shared/widgets/`
- **Tests**: `nova/test/` and `nova/integration_test/`
- **Database**: `supabase/migrations/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, dependencies, and database schema

- [ ] T001 Add profile feature dependencies to nova/pubspec.yaml (shimmer ^2.0.0, image_picker ^1.0.4, image ^4.0.0, hive ^2.2.3, hive_flutter ^1.1.0, connectivity_plus ^5.0.0)
- [ ] T002 [P] Configure iOS permissions in nova/ios/Runner/Info.plist (NSPhotoLibraryUsageDescription, NSCameraUsageDescription)
- [ ] T003 [P] Configure Android permissions in nova/android/app/src/main/AndroidManifest.xml (CAMERA, READ_EXTERNAL_STORAGE)
- [ ] T004 Create Supabase migration script in supabase/migrations/002_create_profiles_table.sql (from data-model.md)
- [ ] T005 Run Supabase migration to create profiles table with RLS policies (execute 002_create_profiles_table.sql in Supabase Dashboard)
- [ ] T006 Create Supabase Storage bucket 'avatars' (private, 5MB limit, JPEG/PNG/WebP MIME types)
- [ ] T007 [P] Create feature directory structure in nova/lib/features/profile/ (data/models, data/repositories, data/datasources, domain/entities, domain/usecases, presentation/providers, presentation/screens, presentation/widgets)
- [ ] T008 [P] Run flutter pub get and build_runner to generate Hive adapters

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T009 Create SchoolClass data class with const list of 35 classes in nova/lib/core/constants/classes.dart (SCIENTIFICO 25 + CLASSICO 10, suffix format "3A Scientifico")
- [ ] T010 [P] Implement AvatarInitialsGenerator utility in nova/lib/core/utils/avatar_initials_generator.dart (Material Design 500 colors, A-Z mapping, initials extraction)
- [ ] T011 [P] Implement name/bio validators in nova/lib/core/utils/validators.dart (name regex, bio sanitization, trim whitespace)
- [ ] T012 [P] Create Profile domain entity in nova/lib/features/profile/domain/entities/profile.dart (immutable with freezed, all 8 fields)
- [ ] T013 [P] Create ProfileModel data model in nova/lib/features/profile/data/models/profile_model.dart (JSON serialization, Hive annotations, fromEntity/toEntity)
- [ ] T014 Run build_runner to generate ProfileModel Hive adapter in nova/lib/features/profile/data/models/profile_model.g.dart
- [ ] T015 [P] Implement ProfileRemoteDataSource in nova/lib/features/profile/data/datasources/profile_remote_datasource.dart (Supabase REST API calls: GET, POST, PATCH profiles)
- [ ] T016 [P] Implement ProfileLocalDataSource in nova/lib/features/profile/data/datasources/profile_local_datasource.dart (Hive box operations: save, load, delete)
- [ ] T017 Implement ProfileRepository in nova/lib/features/profile/data/repositories/profile_repository.dart (combines remote + local datasources, offline save with sync, implements domain repository interface)
- [ ] T018 [P] Create NovaToast widget in nova/lib/shared/widgets/nova_toast.dart (success/error toast, pill shape, 2s duration, bottom center)
- [ ] T019 [P] Create NovaBottomSheet wrapper widget in nova/lib/shared/widgets/nova_bottom_sheet.dart (DraggableScrollableSheet with glass effect, 70% initial, handle bar)
- [ ] T020 [P] Implement ConnectivityProvider in nova/lib/features/profile/presentation/providers/connectivity_provider.dart (Riverpod provider monitoring network status with connectivity_plus)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - First Time Profile Setup (Priority: P1) 🎯 MVP

**Goal**: New user completes magic link authentication, lands on profile setup, provides name (auto-populated) + class (required), optionally uploads avatar/pronouns/bio, taps "Salva e inizia", and is redirected to Feed with replace navigation.

**Independent Test**: Create new account via magic link → Complete profile setup with name + class → Verify redirection to Feed. User can now view events and participate.

### Implementation for User Story 1

- [ ] T021 [P] [US1] Create CreateProfile use case in nova/lib/features/profile/domain/usecases/create_profile.dart (calls repository.createProfile, validates name + class required)
- [ ] T022 [P] [US1] Create CheckProfileComplete use case in nova/lib/features/profile/domain/usecases/check_profile_complete.dart (returns true if name AND class exist)
- [ ] T023 [US1] Create ProfileProvider (Riverpod StateNotifier) in nova/lib/features/profile/presentation/providers/profile_provider.dart (manages profile state, loads current user profile, handles create/update)
- [ ] T024 [P] [US1] Create SkeletonAvatar widget in nova/lib/features/profile/presentation/widgets/skeleton_avatar.dart (150px circle with shimmer effect using shimmer package, NFR-001a)
- [ ] T025 [P] [US1] Create AvatarInitials widget in nova/lib/features/profile/presentation/widgets/avatar_initials.dart (150px circle, deterministic Material Design 500 color, white text 48px weight 700)
- [ ] T026 [P] [US1] Create ClassPickerBottomSheet widget in nova/lib/features/profile/presentation/widgets/class_picker_bottom_sheet.dart (DraggableScrollableSheet, search bar, SCIENTIFICO/CLASSICO sections, single selection with check icon)
- [ ] T027 [US1] Implement ProfileSetupScreen in nova/lib/features/profile/presentation/screens/profile_setup_screen.dart (name field auto-populated from email, class picker, "Salva e inizia" disabled until class selected, "Skip per ora" top-right, skeleton loading on init)
- [ ] T028 [US1] Integrate email parsing: call Supabase RPC function parse_name_from_email in ProfileSetupScreen initState to auto-populate name field
- [ ] T029 [US1] Implement save profile flow in ProfileSetupScreen: validate name + class, call CreateProfile use case, show toast "Profilo aggiornato ✓", Navigator.pushReplacement to FeedScreen (FR-009d)
- [ ] T030 [US1] Add ProfileSetupScreen route to app navigation (redirect from auth completion if profile incomplete)

**Checkpoint**: At this point, User Story 1 should be fully functional - new users can complete profile setup and access Feed

---

## Phase 4: User Story 2 - Avatar Upload & Management (Priority: P2)

**Goal**: User uploads custom avatar from camera/gallery with auto-crop to square, or sees colored initials fallback. Avatar stored in Supabase Storage with signed URLs (1-hour expiry). User can also delete avatar.

**Independent Test**: Complete P1 setup → Upload avatar from gallery → Verify it appears in profile. Delete avatar → Verify colored initials appear. Delivers standalone value: visual personalization.

### Implementation for User Story 2

- [ ] T031 [P] [US2] Create UploadAvatar use case in nova/lib/features/profile/domain/usecases/upload_avatar.dart (crop to square using image package, upload to Supabase Storage /avatars/{user_id}/{timestamp}.jpg, generate signed URL, update profile.avatar_url)
- [ ] T032 [US2] Create AvatarUploadProvider (Riverpod StateNotifier) in nova/lib/features/profile/presentation/providers/avatar_upload_provider.dart (manages upload state, handles ImagePicker, calls UploadAvatar use case, shows toast on success/error)
- [ ] T033 [US2] Implement AvatarPicker widget in nova/lib/features/profile/presentation/widgets/avatar_picker.dart (150px circle, camera icon overlay bottom-right 40px, bottom sheet with "Scatta foto"/"Scegli da galleria"/"Rimuovi foto", loading spinner during upload, shows AvatarInitials if no avatar_url)
- [ ] T034 [US2] Integrate AvatarPicker into ProfileSetupScreen (replace skeleton avatar with AvatarPicker widget)
- [ ] T035 [US2] Implement avatar delete functionality in AvatarPicker: delete from Supabase Storage, set avatar_url = null, show toast "Avatar rimosso ✓", update UI to show AvatarInitials

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - users can set up profiles with custom avatars or colored initials

---

## Phase 5: User Story 3 - Skip Setup Flow (Priority: P2)

**Goal**: User can tap "Skip per ora" to browse Feed immediately, but protected actions (create event, comment, chat) are blocked until profile completed (name + class). Completion modal prompts user to finish setup.

**Independent Test**: Skip setup → Browse feed successfully → Attempt to create event → See completion prompt → Complete profile. Delivers standalone value: exploration without commitment.

### Implementation for User Story 3

- [ ] T036 [P] [US3] Create ProfileCompletionModal widget in nova/lib/features/profile/presentation/widgets/profile_completion_modal.dart (modal dialog "Completa il tuo profilo" / "Per creare eventi devi selezionare la tua classe" / [Completa ora] button redirects to setup)
- [ ] T037 [US3] Implement skip setup flow in ProfileSetupScreen: "Skip per ora" button calls CreateProfile with class = null, Navigator.pushReplacement to FeedScreen
- [ ] T038 [US3] Add profile completion check to EventCreateScreen: before allowing event creation, call CheckProfileComplete use case, if false show ProfileCompletionModal
- [ ] T039 [P] [US3] Add profile completion check to CommentWidget: before allowing comment submission, call CheckProfileComplete, if false show ProfileCompletionModal
- [ ] T040 [P] [US3] Add profile completion check to ChatScreen: before allowing chat access, call CheckProfileComplete, if false show ProfileCompletionModal
- [ ] T041 [US3] Add profile completion banner to SettingsScreen: if profile incomplete, show banner "Completa il tuo profilo per creare eventi" with tap to navigate to setup

**Checkpoint**: At this point, skip flow works - users can explore Feed but must complete profile for protected actions

---

## Phase 6: User Story 4 - Edit Profile (Priority: P2)

**Goal**: Returning user can edit profile from Settings. Same UI as first-time setup but pre-filled. Changes auto-save after 500ms (bio debounce) or instantly (selections). No "Skip per ora" button.

**Independent Test**: Edit profile → Change class from 3A to 4A → Verify auto-save toast and persistence. Delivers standalone value: profile updates without manual save actions.

### Implementation for User Story 4

- [ ] T042 [P] [US4] Create UpdateProfile use case in nova/lib/features/profile/domain/usecases/update_profile.dart (calls repository.updateProfile with partial fields, handles optimistic UI, rollback on error)
- [ ] T043 [US4] Implement ProfileEditScreen in nova/lib/features/profile/presentation/screens/profile_edit_screen.dart (reuses ProfileSetupScreen UI, pre-filled with current profile data, no "Skip per ora" button, "X" icon top-left to go back)
- [ ] T044 [US4] Implement auto-save logic in ProfileProvider: updateBio with 500ms Timer debounce, updateClass/updatePronouns/updateAvatar instant save, optimistic UI updates, toast on success/error, local save on offline (FR-009)
- [ ] T045 [US4] Add ProfileEditScreen route to SettingsScreen: "Modifica profilo" button navigates to ProfileEditScreen
- [ ] T046 [US4] Implement offline save with sync: on network offline, save to Hive ProfileLocalDataSource, auto-sync when connectivity returns via ConnectivityProvider listener, show toast "Profilo salvato offline, sincronizzazione in corso..." (FR-009c)

**Checkpoint**: At this point, edit profile works with auto-save - users can update their profiles seamlessly

---

## Phase 7: User Story 5 - Bio with Live Character Counter (Priority: P3)

**Goal**: User can write bio (max 150 chars) with live counter that changes color: 0-139 gray, 140-150 orange, 151+ red. Counter blocks typing over 150 and saves successfully at 150 exactly.

**Independent Test**: Write bio with exactly 150 characters → Verify counter turns red and save works. Write 151 characters → Verify save is blocked. Delivers standalone value: self-expression with clear limits.

### Implementation for User Story 5

- [ ] T047 [P] [US5] Create BioTextField widget in nova/lib/features/profile/presentation/widgets/bio_text_field.dart (TextFormField with maxLength 150, live character counter, color coding 0-139 gray #6B7280, 140-150 orange #F59E0B, 151+ red #EF4444 with border, multiline auto-expand, placeholder "Scrivi qualcosa su di te...")
- [ ] T048 [US5] Integrate BioTextField into ProfileSetupScreen and ProfileEditScreen (replace plain TextFormField with BioTextField)
- [ ] T049 [US5] Implement bio validation: client-side maxLength 150 enforced, server-side truncate to 150 if bypassed, sanitization strip HTML/URLs, regex validation (FR-008, SEC-002)
- [ ] T050 [US5] Connect bio field to ProfileProvider auto-save: on change trigger 500ms debounce, optimistic UI update, toast on save success/error

**Checkpoint**: Bio field works with live character counter and color coding - users can write expressive bios with clear limits

---

## Phase 8: User Story 6 - Pronouns Selection (Priority: P3)

**Goal**: User can optionally set pronouns via bottom sheet picker. Default "Non specificato" (stored as NULL). Options: Lui, Lei, They, Altro, Preferisco non dire. Saves instantly.

**Independent Test**: Select pronouns "They" → Verify it saves and displays in profile. Delivers standalone value: gender expression support.

### Implementation for User Story 6

- [ ] T051 [P] [US6] Create PronounsPickerBottomSheet widget in nova/lib/features/profile/presentation/widgets/pronouns_picker_bottom_sheet.dart (DraggableScrollableSheet, title "Seleziona pronomi", 6 options: Non specificato, Lui, Lei, They, Altro, Preferisco non dire, single selection with check icon)
- [ ] T052 [US6] Integrate PronounsPickerBottomSheet into ProfileSetupScreen and ProfileEditScreen (pronouns field tap opens bottom sheet, displays selected value or "Non specificato")
- [ ] T053 [US6] Connect pronouns selection to ProfileProvider: instant save (no debounce), optimistic UI update, store NULL for "Non specificato", toast "Profilo aggiornato ✓"
- [ ] T054 [US6] Implement RLS policy enforcement: pronouns visible only to authenticated @galileimoro.edu.it students (verify in Supabase RLS policies from migration)

**Checkpoint**: Pronouns selection works - users can express gender identity optionally

---

## Phase 9: Integration Tests & Validation

**Purpose**: End-to-end testing of complete user flows across all user stories

- [ ] T055 [P] Write integration test for complete profile setup flow in nova/integration_test/profile_setup_flow_test.dart (auth → setup → name + class → save → Feed, verify replace navigation, verify cannot go back)
- [ ] T056 [P] Write integration test for avatar upload flow in nova/integration_test/avatar_upload_flow_test.dart (pick from gallery → crop → upload → verify appears, delete → verify initials appear)
- [ ] T057 [P] Write integration test for skip setup flow in nova/integration_test/skip_setup_flow_test.dart (skip → browse feed → create event blocked → completion modal → complete profile)
- [ ] T058 [P] Write integration test for edit profile flow in nova/integration_test/edit_profile_flow_test.dart (Settings → Edit → change class → auto-save → verify persistence)
- [ ] T059 Run all integration tests and verify they pass (flutter test integration_test/)

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories, final validation

- [ ] T060 [P] Add unit tests for AvatarInitialsGenerator in nova/test/features/profile/domain/avatar_initials_test.dart (test initials extraction "Giovanni Rossi" → "GR", deterministic color mapping, same name → same color)
- [ ] T061 [P] Add unit tests for ProfileRepository offline save in nova/test/features/profile/data/profile_repository_test.dart (test local save when offline, auto-sync when online, pending queue behavior)
- [ ] T062 [P] Add widget test for ProfileSetupScreen in nova/test/features/profile/presentation/screens/profile_setup_screen_test.dart (test save button disabled when class not selected, enabled after selection)
- [ ] T063 [P] Verify all UI values use design system constants: audit ProfileSetupScreen, ProfileEditScreen, all widgets for NovaColors/NovaSpacing/NovaTextStyles/NovaRadius (zero hardcoded values per DESIGN_SYSTEM_STRICT)
- [ ] T064 [P] Performance profiling with Flutter DevTools: verify setup screen loads <500ms, avatar upload <2s p95, 60fps sustained animations (NFR-001, NFR-002, NFR-004)
- [ ] T065 [P] Accessibility audit: verify all tap targets ≥44x44px, color contrast >4.5:1, screen reader labels present (NFR-006, NFR-007, NFR-008)
- [ ] T066 Run quickstart.md validation: execute all integration scenarios from quickstart.md, verify results match expected behavior
- [ ] T067 [P] Update CLAUDE.md with profile setup implementation notes (add to context for future features)
- [ ] T068 Create pull request with reference to spec.md, verify all acceptance criteria met, CI tests pass

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion (T001-T008) - BLOCKS all user stories
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion (T009-T020)
  - User stories can proceed in parallel (if team capacity allows)
  - Or sequentially in priority order: P1 → P2 → P2 → P2 → P3 → P3
- **Integration Tests (Phase 9)**: Depends on desired user stories being complete
- **Polish (Phase 10)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories ✅
- **User Story 2 (P2)**: Can start after Foundational - Integrates with US1 (AvatarPicker in ProfileSetupScreen) but independently testable
- **User Story 3 (P2)**: Can start after Foundational - Integrates with US1 (skip button, completion checks) but independently testable
- **User Story 4 (P2)**: Can start after Foundational - Reuses US1 UI but independently testable
- **User Story 5 (P3)**: Can start after Foundational - Integrates with US1/US4 (bio field) but independently testable
- **User Story 6 (P3)**: Can start after Foundational - Integrates with US1/US4 (pronouns field) but independently testable

### Within Each User Story

- Models before use cases
- Use cases before providers
- Providers before screens/widgets
- Core widgets before screen integration
- Story complete before moving to next priority

### Parallel Opportunities

**Setup Phase (Phase 1)**:
- T002 (iOS permissions) + T003 (Android permissions) in parallel
- T007 (directory structure) can run alongside T002, T003

**Foundational Phase (Phase 2)**:
- T010 (AvatarInitialsGenerator) + T011 (validators) + T012 (Profile entity) + T013 (ProfileModel) in parallel
- T015 (ProfileRemoteDataSource) + T016 (ProfileLocalDataSource) in parallel
- T018 (NovaToast) + T019 (NovaBottomSheet) + T020 (ConnectivityProvider) in parallel

**User Story 1 (Phase 3)**:
- T021 (CreateProfile use case) + T022 (CheckProfileComplete use case) in parallel
- T024 (SkeletonAvatar) + T025 (AvatarInitials) + T026 (ClassPickerBottomSheet) in parallel

**User Story 2 (Phase 4)**:
- All implementation can start in parallel with US3, US4, US5, US6 if team capacity allows

**User Story 3 (Phase 5)**:
- T038 (EventCreateScreen check) + T039 (CommentWidget check) + T040 (ChatScreen check) in parallel

**Integration Tests (Phase 9)**:
- All 5 integration tests (T055-T059) can run in parallel

**Polish (Phase 10)**:
- All unit tests (T060-T062) + audits (T063-T065) can run in parallel

---

## Parallel Example: User Story 1

```bash
# After Foundational phase completes, launch User Story 1 tasks in parallel:

# Use cases (can run in parallel):
Task T021: "Create CreateProfile use case in nova/lib/features/profile/domain/usecases/create_profile.dart"
Task T022: "Create CheckProfileComplete use case in nova/lib/features/profile/domain/usecases/check_profile_complete.dart"

# Widgets (can run in parallel after use cases):
Task T024: "Create SkeletonAvatar widget in nova/lib/features/profile/presentation/widgets/skeleton_avatar.dart"
Task T025: "Create AvatarInitials widget in nova/lib/features/profile/presentation/widgets/avatar_initials.dart"
Task T026: "Create ClassPickerBottomSheet widget in nova/lib/features/profile/presentation/widgets/class_picker_bottom_sheet.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T008)
2. Complete Phase 2: Foundational (T009-T020) - CRITICAL
3. Complete Phase 3: User Story 1 (T021-T030)
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Run integration test (T055)
6. Deploy/demo if ready

**Minimum Viable Product**: User Story 1 delivers core value - new users can complete profile setup and participate in Nova. All other stories are enhancements.

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready (T001-T020)
2. Add User Story 1 (T021-T030) → Test independently → Deploy/Demo (MVP! ✅)
3. Add User Story 2 (T031-T035) → Test independently → Deploy/Demo (Visual personalization)
4. Add User Story 3 (T036-T041) → Test independently → Deploy/Demo (Skip flow flexibility)
5. Add User Story 4 (T042-T046) → Test independently → Deploy/Demo (Edit profile capability)
6. Add User Story 5 (T047-T050) → Test independently → Deploy/Demo (Bio self-expression)
7. Add User Story 6 (T051-T054) → Test independently → Deploy/Demo (Pronouns inclusivity)
8. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers (after Foundational phase complete):

1. **Team completes Setup + Foundational together** (T001-T020)
2. Once Foundational is done:
   - **Developer A**: User Story 1 (T021-T030) - MVP priority
   - **Developer B**: User Story 2 (T031-T035) - Visual features
   - **Developer C**: User Story 3 + 4 (T036-T046) - Flows
   - **Developer D**: User Story 5 + 6 (T047-T054) - Optional fields
3. Stories complete and integrate independently
4. Integration tests run when stories ready (T055-T059)
5. Polish phase completes all stories (T060-T068)

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [Story] label maps task to specific user story for traceability (US1, US2, US3, US4, US5, US6)
- Each user story should be independently completable and testable
- Tests included per constitution TESTING_REQUIREMENTS (mandatory for critical paths)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- All file paths are absolute from nova/ root (Flutter app structure per plan.md)
- Database schema created in Phase 1 (T004-T005) before any code runs
- Design system constants enforced via audit in Phase 10 (T063)
- Constitution compliance validated: all 7 principles aligned per plan.md Constitution Check

---

## Summary Statistics

- **Total Tasks**: 68
- **Setup Tasks**: 8 (T001-T008)
- **Foundational Tasks**: 12 (T009-T020)
- **User Story 1 Tasks**: 10 (T021-T030) - MVP
- **User Story 2 Tasks**: 5 (T031-T035)
- **User Story 3 Tasks**: 6 (T036-T041)
- **User Story 4 Tasks**: 5 (T042-T046)
- **User Story 5 Tasks**: 4 (T047-T050)
- **User Story 6 Tasks**: 4 (T051-T054)
- **Integration Test Tasks**: 5 (T055-T059)
- **Polish Tasks**: 9 (T060-T068)
- **Parallel Opportunities**: 34 tasks marked [P]
- **MVP Scope**: Phase 1 + Phase 2 + Phase 3 (30 tasks) delivers core value
- **Full Feature**: All 68 tasks delivers complete Instagram-style profile setup

---

**Tasks Generated**: 2025-11-01
**Ready for**: `/speckit.implement` execution or manual implementation starting from T001
