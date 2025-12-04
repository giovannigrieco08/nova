# Tasks: Sistema Ripetizioni

**Input**: Design documents from `/specs/012-tutoring-system/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/supabase-queries.md ✅
**Branch**: `012-tutoring-system`
**Date**: 2025-12-01

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story reference (US1-US8)
- File paths relative to `nova/lib/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database migration, dependencies, base entities

- [x] T001 Create database migration `supabase/migrations/013_tutor_profiles.sql` with tutor_profiles table, GIN index, RLS policies
- [x] T002 Add `url_launcher: ^6.2.1` dependency to `nova/pubspec.yaml`
- [x] T003 Run `flutter pub get` to install dependencies
- [x] T004 [P] Create Subject enum in `features/tutoring/domain/entities/subject.dart`
- [x] T005 [P] Create TutorProfile freezed entity in `features/tutoring/domain/entities/tutor_profile.dart`
- [x] T006 Create TutorProfileModel JSON serialization in `features/tutoring/data/models/tutor_profile_model.dart`
- [x] T007 Create feature barrel file `features/tutoring/tutoring.dart`

**Checkpoint**: Base entities and migration ready

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Data layer infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T008 Create TutorRemoteDatasource in `features/tutoring/data/datasources/tutor_remote_datasource.dart` with all Supabase queries
- [x] T009 Create TutorRepository in `features/tutoring/data/repositories/tutor_repository.dart` implementing repository pattern
- [x] T010 Create base Riverpod providers in `features/tutoring/presentation/providers/tutor_providers.dart`:
  - `tutorRepositoryProvider`
  - `tutorDatasourceProvider`
  - `currentTutorProfileProvider`
  - `otherTutorProfileProvider`
  - `tutorsBySubjectProvider`
- [ ] T011 Apply migration to Supabase: `psql` or Supabase Dashboard ⚠️ **REQUIRES MANUAL ACTION**

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1+2 - Cercare e Contattare Tutor (Priority: P1) 🎯 MVP

**Goal**: Students can browse tutors by subject and contact them via WhatsApp/Instagram

**Independent Test**: Open Ripetizioni → tap Matematica → see tutor list → tap tutor → contact sheet opens → tap WhatsApp → external app opens

### Implementation for US1 (Cercare Tutor)

- [x] T012 [P] [US1] Create SubjectCard widget in `features/tutoring/presentation/widgets/subject_card.dart`
- [x] T013 [P] [US1] Create TutorCard widget in `features/tutoring/presentation/widgets/tutor_card.dart`
- [x] T014 [US1] Create SubjectsScreen in `features/tutoring/presentation/screens/subjects_screen.dart` with 12-subject grid
- [x] T015 [US1] Create TutorsListScreen in `features/tutoring/presentation/screens/tutors_list_screen.dart` with pagination
- [x] T016 [US1] Add navigation routes for SubjectsScreen and TutorsListScreen ✅ Done (uses Navigator.push, not GoRouter)

### Implementation for US2 (Contattare Tutor)

- [x] T017 [US2] Create ContactTutorSheet bottom sheet in `features/tutoring/presentation/widgets/contact_tutor_sheet.dart`
- [x] T018 [US2] Implement WhatsApp deep link launcher (`https://wa.me/{phone}`) in ContactTutorSheet
- [x] T019 [US2] Implement Instagram deep link launcher (`https://instagram.com/{username}`) in ContactTutorSheet
- [x] T020 [US2] Add clipboard fallback for contact copy in ContactTutorSheet
- [x] T021 [US2] Wire TutorCard tap to show ContactTutorSheet

**Checkpoint**: US1+US2 complete - students can search tutors by subject and contact them

---

## Phase 4: User Story 3+4 - Diventare Tutor e Vedere Profilo (Priority: P1) 🎯 MVP

**Goal**: Students can register as tutors from their profile and view their tutor information

**Independent Test**: Open Profile → scroll to tutor section → tap "Vuoi dare ripetizioni?" → fill form → submit → see tutor info in profile

### Implementation for US3 (Diventare Tutor)

- [x] T022 [P] [US3] Create BecomeTutorCard CTA widget in `features/tutoring/presentation/widgets/become_tutor_card.dart`
- [x] T023 [US3] Create BecomeTutorScreen form in `features/tutoring/presentation/screens/become_tutor_screen.dart`
- [x] T024 [US3] Implement subject multi-select (max 5) with chips in BecomeTutorScreen
- [x] T025 [US3] Implement availability day selector (checkboxes) in BecomeTutorScreen
- [x] T026 [US3] Implement form validation (bio ≤200 chars, ≥1 subject, ≥1 contact) in BecomeTutorScreen
- [x] T027 [US3] Create `createTutorProfile` mutation provider in `features/tutoring/presentation/providers/tutor_providers.dart`
- [x] T028 [US3] Wire form submission to create mutation with success snackbar

### Implementation for US4 (Vedere Proprio Profilo Tutor)

- [x] T029 [US4] Create TutorProfileSection widget in `features/tutoring/presentation/widgets/tutor_profile_section.dart`
- [x] T030 [US4] Integrate TutorProfileSection into ProfileScreen at line ~109 in `features/profile/presentation/screens/profile_screen.dart`
- [x] T031 [US4] Show BecomeTutorCard when `tutorProfile == null`, TutorProfileSection when exists
- [x] T032 [US4] Add "Modifica" button in TutorProfileSection for own profile

**Checkpoint**: US3+US4 complete - students can become tutors and see their tutor profile ✅

---

## Phase 5: User Story 5+6+7 - Filtri e Gestione Profilo (Priority: P2)

**Goal**: Enhanced filtering and tutor profile management capabilities

**Independent Test**: Filter tutors by price → edit tutor profile → deactivate → reactivate

### Implementation for US5 (Filtrare Lista Tutor)

- [x] T033 [US5] Add FilterChipsRow widget in TutorsListScreen with options: Tutti, Gratis, €1-15, €16-30
- [x] T034 [US5] Create `tutorsFilteredByPriceProvider` in `features/tutoring/presentation/providers/tutor_providers.dart`
- [x] T035 [US5] Wire filter chips to provider invalidation and query parameter

### Implementation for US6 (Modificare Profilo Tutor)

- [x] T036 [US6] Create EditTutorScreen in `features/tutoring/presentation/screens/edit_tutor_screen.dart`
- [x] T037 [US6] Pre-populate form fields with existing tutor profile data
- [x] T038 [US6] Create `updateTutorProfile` mutation provider in tutor_providers.dart
- [x] T039 [US6] Wire form submission to update mutation with success feedback

### Implementation for US7 (Attivare/Disattivare Profilo)

- [x] T040 [US7] Add "Disattiva Profilo" destructive button in EditTutorScreen
- [x] T041 [US7] Create confirmation dialog for deactivation action
- [x] T042 [US7] Create `toggleTutorActive` mutation provider in tutor_providers.dart
- [x] T043 [US7] Update TutorProfileSection to show inactive state with "Riattiva" button
- [x] T044 [US7] Ensure inactive profiles hidden from public queries (RLS handles this)

**Checkpoint**: US5+US6+US7 complete - full tutor profile management available ✅

---

## Phase 6: User Story 8 - Tutor su Profilo Altri (Priority: P3)

**Goal**: Students can see tutor information on other users' profiles and contact them

**Independent Test**: View another user's profile → see their tutor section → tap contact → sheet opens

### Implementation for US8

- [x] T045 [US8] Integrate TutorProfileSection into OtherProfileScreen at line ~114 in `features/profile/presentation/screens/other_profile_screen.dart`
- [x] T046 [US8] Pass `isOwnProfile: false` to TutorProfileSection for external profiles
- [x] T047 [US8] Show "Contatta per Ripetizioni" button instead of "Modifica" for other profiles
- [x] T048 [US8] Wire contact button to show ContactTutorSheet

**Checkpoint**: US8 complete - tutor profiles visible on other users' profiles ✅

---

## Phase 7: Settings Integration

**Goal**: Tutor management accessible from Settings screen

- [x] T049 Add "Tutor" section header in SettingsScreen at line ~100 in `features/profile/presentation/screens/settings_screen.dart`
- [x] T050 Add "Gestisci Profilo Tutor" tile that navigates to EditTutorScreen (if is tutor)
- [x] T051 Add "Diventa Tutor" tile that navigates to BecomeTutorScreen (if not tutor)
- [x] T052 Conditional rendering based on `currentTutorProfileProvider` state

**Checkpoint**: Settings integration complete ✅

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Error handling, loading states, edge cases

- [ ] T053 [P] Add skeleton loading states to SubjectsScreen (deferred - basic loading works)
- [ ] T054 [P] Add skeleton loading states to TutorsListScreen (deferred - basic loading works)
- [x] T055 [P] Add empty state widget "Nessun tutor per questa materia" in TutorsListScreen
- [x] T056 [P] Add error state widgets with retry button across all screens
- [x] T057 Add pull-to-refresh on TutorsListScreen
- [ ] T058 Implement infinite scroll pagination (20 items per page) on TutorsListScreen (deferred - MVP loads all)
- [x] T059 Add form error messages with Italian localization
- [x] T060 Add success snackbars for create/update/toggle operations
- [x] T061 Handle deep link failures with clipboard fallback + error snackbar
- [ ] T062 Run quickstart.md validation scenarios ⚠️ **REQUIRES MANUAL TESTING**

**Checkpoint**: Feature complete and polished ✅ (skeleton/pagination deferred)

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational) ← BLOCKS ALL USER STORIES
    ↓
┌───────────────────────────────────────────────┐
│ Phase 3 (US1+US2) ──→ Phase 4 (US3+US4)      │
│         ↓                    ↓                │
│ Phase 5 (US5-7) ←────────────┘                │
│         ↓                                     │
│ Phase 6 (US8)                                 │
│         ↓                                     │
│ Phase 7 (Settings)                            │
└───────────────────────────────────────────────┘
    ↓
Phase 8 (Polish)
```

### Task Dependencies

| Task | Depends On | Blocks |
|------|-----------|--------|
| T006 | T004, T005 | T008 |
| T008 | T001, T006 | T009 |
| T009 | T008 | T010 |
| T010 | T009 | All US tasks |
| T014 | T012 | T015, T016 |
| T015 | T013, T014 | T017 |
| T021 | T017 | - |
| T023 | T022 | T024-T028 |
| T030 | T029 | T031 |
| T036 | T029, T023 | T037-T044 |
| T045 | T029 | T046-T048 |

### Parallel Opportunities

**Phase 1:**
```
T004 (Subject enum) ─┬─ parallel
T005 (TutorProfile) ─┘
```

**Phase 3:**
```
T012 (SubjectCard) ─┬─ parallel
T013 (TutorCard)   ─┘
```

**Phase 8:**
```
T053 (Skeleton SubjectsScreen)  ─┬─ parallel
T054 (Skeleton TutorsListScreen)─┤
T055 (Empty state)              ─┤
T056 (Error states)             ─┘
```

---

## Implementation Strategy

### MVP First (US1-US4)

1. Complete Phase 1: Setup (T001-T007)
2. Complete Phase 2: Foundational (T008-T011)
3. Complete Phase 3: US1+US2 (T012-T021) → **Testable: search & contact**
4. Complete Phase 4: US3+US4 (T022-T032) → **Testable: become tutor**
5. **STOP and VALIDATE**: Test all P1 scenarios from quickstart.md

### Full Feature

6. Complete Phase 5: US5-US7 (T033-T044) → Enhanced management
7. Complete Phase 6: US8 (T045-T048) → Other profile integration
8. Complete Phase 7: Settings (T049-T052) → Settings access
9. Complete Phase 8: Polish (T053-T062) → Production ready

---

## Notes

- All UI must use NovaColors, NovaSpacing, NovaTypography, NovaRadius constants
- Platform-adaptive widgets required (CupertinoButton vs ElevatedButton)
- WhatsApp phone format: `393201234567` (no +, no spaces)
- Instagram username: no @ prefix
- Max 5 subjects per tutor (enforced in DB + UI)
- Bio max 200 characters (enforced in DB + UI)
- At least one contact method required (WhatsApp OR Instagram)
- RLS policies ensure only active tutors visible in public queries
- Owner can always see their own profile (active or inactive)
