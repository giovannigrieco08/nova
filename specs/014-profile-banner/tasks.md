# Tasks: Profile Banner

**Input**: Design documents from `/specs/014-profile-banner/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/

**Tests**: Not explicitly requested - skipping test tasks.

**Organization**: Tasks grouped by user story for independent implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1, US2, US3, US4 (maps to spec.md user stories)
- Paths relative to repository root

---

## Phase 1: Setup

**Purpose**: Database and storage infrastructure

- [x] T001 Create database migration in supabase/migrations/037_add_profile_banner.sql
- [x] T002 Run migration to add banner_url column to profiles table (manual: supabase db push)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core data layer changes required by ALL user stories

**CRITICAL**: No UI work until this phase is complete

- [x] T003 Add bannerUrl field to Profile entity in nova/lib/features/profile/domain/entities/profile.dart
- [x] T004 [P] Add hasBanner extension method to ProfileExtensions in nova/lib/features/profile/domain/entities/profile.dart
- [x] T005 Add bannerUrl field with HiveField(12) to ProfileModel in nova/lib/features/profile/data/models/profile_model.dart
- [x] T006 Update ProfileModel constructor, copyWith, fromEntity, toEntity for bannerUrl in nova/lib/features/profile/data/models/profile_model.dart
- [x] T007 Run build_runner to regenerate Freezed and Hive code
- [x] T008 Create BannerUploadService with uploadBanner method in nova/lib/features/profile/data/services/banner_upload_service.dart
- [x] T009 Add deleteBanner and normalizeBannerUrl methods to BannerUploadService in nova/lib/features/profile/data/services/banner_upload_service.dart
- [x] T010 Add bannerUploadServiceProvider to nova/lib/features/profile/presentation/providers/profile_provider.dart

**Checkpoint**: Data layer ready - UI implementation can begin

---

## Phase 3: User Story 1 & 2 - Upload & View Banner (Priority: P1)

**Goal**: Users can upload a banner and see it displayed in their profile

**Independent Test**: Upload an image as banner, verify it appears in profile view with 3:1 aspect ratio

### Implementation

- [x] T011 [P] [US1] Create BannerCropper widget with 3:1 aspect ratio lock in nova/lib/features/profile/presentation/widgets/banner_cropper.dart
- [x] T012 [P] [US1] Create BannerPickerBottomSheet for camera/gallery selection in nova/lib/features/profile/presentation/widgets/banner_picker_bottom_sheet.dart
- [x] T013 [US2] Add _buildBanner method to ProfileHeader for banner display in nova/lib/features/profile/presentation/widgets/profile_header.dart
- [x] T014 [US2] Update ProfileHeader build method to include banner with avatar overlay in nova/lib/features/profile/presentation/widgets/profile_header.dart
- [x] T015 [US2] Add fallback gradient when bannerUrl is null in ProfileHeader in nova/lib/features/profile/presentation/widgets/profile_header.dart
- [x] T016 [US1] Add _bannerUrl and _selectedBannerFile state to EditProfileScreen in nova/lib/features/profile/presentation/screens/edit_profile_screen.dart
- [x] T017 [US1] Add _handleBannerPicker method for banner selection flow in nova/lib/features/profile/presentation/screens/edit_profile_screen.dart
- [x] T018 [US1] Add banner section UI above avatar in EditProfileScreen build method in nova/lib/features/profile/presentation/screens/edit_profile_screen.dart
- [x] T019 [US1] Update _saveProfile to include banner_url in profile update in nova/lib/features/profile/presentation/screens/edit_profile_screen.dart
- [x] T020 [US1] Add upload progress indicator for banner in EditProfileScreen in nova/lib/features/profile/presentation/screens/edit_profile_screen.dart

**Checkpoint**: Users can upload and view banners - core feature complete

---

## Phase 4: User Story 3 - Remove/Change Banner (Priority: P2)

**Goal**: Users can remove existing banner or replace it with a new one

**Independent Test**: With existing banner, tap remove and verify fallback gradient appears

### Implementation

- [x] T021 [US3] Add hasExistingBanner parameter and onRemoveBanner callback to BannerPickerBottomSheet in nova/lib/features/profile/presentation/widgets/banner_picker_bottom_sheet.dart
- [x] T022 [US3] Add "Rimuovi banner" option with confirmation dialog in BannerPickerBottomSheet in nova/lib/features/profile/presentation/widgets/banner_picker_bottom_sheet.dart
- [x] T023 [US3] Add _handleRemoveBanner method to EditProfileScreen in nova/lib/features/profile/presentation/screens/edit_profile_screen.dart
- [x] T024 [US3] Add deleteOldBanner call in uploadBanner to cleanup previous banner in nova/lib/features/profile/data/services/banner_upload_service.dart

**Checkpoint**: Banner management complete - users have full control

---

## Phase 5: User Story 4 - Preview Before Save (Priority: P2)

**Goal**: Users see a realistic preview of their banner before saving

**Independent Test**: After cropping, verify preview shows banner with avatar overlay matching final result

### Implementation

- [x] T025 [US4] Create _buildBannerPreview method showing banner with avatar in EditProfileScreen in nova/lib/features/profile/presentation/screens/edit_profile_screen.dart
- [x] T026 [US4] Update banner section to show preview after crop in EditProfileScreen in nova/lib/features/profile/presentation/screens/edit_profile_screen.dart
- [x] T027 [US4] Add visual feedback (shadow, border) to indicate preview state in EditProfileScreen in nova/lib/features/profile/presentation/screens/edit_profile_screen.dart

**Checkpoint**: Full preview experience implemented

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Error handling, edge cases, performance

- [x] T028 Add minimum dimension validation (600x200px) to BannerCropper in nova/lib/features/profile/presentation/widgets/banner_cropper.dart
- [x] T029 Add error handling for upload failures with retry option in EditProfileScreen in nova/lib/features/profile/presentation/screens/edit_profile_screen.dart
- [x] T030 Add cache eviction for old banner URL after upload in EditProfileScreen in nova/lib/features/profile/presentation/screens/edit_profile_screen.dart
- [x] T031 Add CachedNetworkImage with proper cacheKey for banner in ProfileHeader in nova/lib/features/profile/presentation/widgets/profile_header.dart
- [x] T032 Verify banner displays correctly in OtherProfileScreen in nova/lib/features/profile/presentation/screens/other_profile_screen.dart

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) ──> Phase 2 (Foundational) ──> Phase 3+ (User Stories)
                                              │
                                              ├──> Phase 3 (US1 & US2) ──> Phase 4 (US3)
                                              │                               │
                                              └──────────────────────────────>├──> Phase 5 (US4)
                                                                              │
                                                                              └──> Phase 6 (Polish)
```

### User Story Dependencies

| Story | Depends On | Can Start After |
|-------|------------|-----------------|
| US1 & US2 (P1) | Foundational | Phase 2 complete |
| US3 (P2) | US1 | Phase 3 complete |
| US4 (P2) | US1 | Phase 3 complete |

### Parallel Opportunities

**Within Phase 2 (Foundational):**
```
T003 + T004 (Profile entity changes) can run in parallel
Then T005 + T006 (ProfileModel changes)
Then T007 (build_runner)
Then T008 + T009 + T010 (service + provider)
```

**Within Phase 3 (US1 & US2):**
```
T011 + T012 can run in parallel (new widgets, different files)
T013 + T014 + T015 (ProfileHeader) - sequential, same file
T016 through T020 (EditProfileScreen) - sequential, same file
```

---

## Implementation Strategy

### MVP First (User Stories 1 & 2 Only)

1. Complete Phase 1: Setup (migration)
2. Complete Phase 2: Foundational (entity, model, service)
3. Complete Phase 3: US1 & US2 (upload + display)
4. **STOP and VALIDATE**: Test upload and display independently
5. Deploy/demo if ready - core feature complete!

### Incremental Delivery

1. Setup + Foundational → Data layer ready
2. Add US1 & US2 → Upload and view banners (MVP!)
3. Add US3 → Remove/change banners
4. Add US4 → Preview before save
5. Polish → Error handling, caching

---

## Summary

| Phase | Tasks | Purpose |
|-------|-------|---------|
| Setup | 2 | Database migration |
| Foundational | 8 | Entity, model, service |
| US1 & US2 (P1) | 10 | Upload and display |
| US3 (P2) | 4 | Remove/change |
| US4 (P2) | 3 | Preview |
| Polish | 5 | Error handling, caching |
| **Total** | **32** | |

---

## Notes

- No test tasks included (not explicitly requested)
- US1 and US2 combined in Phase 3 (tightly coupled - upload needs display)
- ProfileHeader modifications in US2 enable display for all scenarios
- EditProfileScreen is main integration point for upload flow
- BannerUploadService mirrors AvatarUploadService patterns
