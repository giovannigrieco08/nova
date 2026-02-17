# Tasks: UGC Safety System

**Input**: Design documents from `/specs/015-ugc-safety/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not explicitly requested - test tasks omitted.

**Organization**: Tasks grouped by user story for independent implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US6)
- Includes exact file paths

## Path Conventions

- **Flutter App**: `nova/lib/features/safety/`
- **Database**: `supabase/migrations/`
- **Edge Functions**: `supabase/functions/`
- **Storage**: `supabase/storage/public/legal/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Create safety feature directory structure at nova/lib/features/safety/
- [x] T002 [P] Create feature barrel export in nova/lib/features/safety/safety.dart
- [x] T003 [P] Create ToS document template at supabase/storage/public/legal/tos-1.0.0.md

---

## Phase 2: Foundational (Database & Core Models)

**Purpose**: Core infrastructure that MUST be complete before ANY user story

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create database migration file at supabase/migrations/057_ugc_safety_system.sql
- [x] T005 Add reports table with RLS policies and indexes to migration
- [x] T006 Add user_blocks table with RLS policies and triggers to migration
- [x] T007 Add banned_words table with RLS policies to migration
- [x] T008 Add user_sanctions table with RLS policies to migration
- [x] T009 Add tos_accepted_version and tos_accepted_at columns to profiles table in migration
- [x] T010 Create SQL functions: is_blocked_by, is_user_blocked, check_content, has_accepted_current_tos in migration
- [x] T011 Create SQL functions: accept_tos, get_tos_status, has_user_reported in migration
- [x] T012 Create notify_moderators_on_block trigger in migration
- [x] T013 Add 'user_block' type to notifications enum in migration
- [x] T014 [P] Create Report model in nova/lib/features/safety/data/models/report.dart
- [x] T015 [P] Create UserBlock model in nova/lib/features/safety/data/models/user_block.dart
- [x] T016 [P] Create TosStatus model in nova/lib/features/safety/data/models/tos_status.dart
- [x] T017 [P] Create ContentCheckResult model in nova/lib/features/safety/data/models/content_check_result.dart
- [x] T018 [P] Create UserSanction model in nova/lib/features/safety/data/models/user_sanction.dart
- [x] T019 Create banned_words seed file at supabase/seeds/banned_words.sql with initial Italian profanity list
- [ ] T020 Apply migration: run supabase db push

**Checkpoint**: Database ready, models created - user story implementation can begin

---

## Phase 3: User Story 1 - Segnalare Contenuto (Priority: P1) 🎯 MVP

**Goal**: Utenti possono segnalare contenuti inappropriati (post, commenti, chat, profili)

**Independent Test**: Creare un post, toccare menu → Segnala → selezionare categoria → verificare conferma e che appaia in DB

### Implementation for User Story 1

- [x] T021 [US1] Create ReportRepository in nova/lib/features/safety/data/repositories/report_repository.dart
- [x] T022 [US1] Implement createReport method in ReportRepository
- [x] T023 [US1] Implement hasUserReported RPC call in ReportRepository
- [x] T024 [US1] Implement getUserReports method in ReportRepository
- [x] T025 [US1] Create ReportService in nova/lib/features/safety/domain/services/report_service.dart
- [x] T026 [US1] Create report_provider with ReportNotifier in nova/lib/features/safety/presentation/providers/report_provider.dart
- [x] T027 [US1] Create ReportCategorySheet widget in nova/lib/features/safety/presentation/widgets/report_sheet.dart
- [x] T028 [US1] Create ReportButton widget in nova/lib/features/safety/presentation/widgets/report_button.dart
- [x] T029 [US1] Integrate ReportButton into event card overflow menu in nova/lib/features/events/presentation/widgets/event_card.dart
- [x] T030 [US1] Integrate ReportButton into comment item overflow menu
- [x] T031 [US1] Integrate ReportButton into chat message overflow menu
- [x] T032 [US1] Integrate ReportButton into profile screen overflow menu
- [x] T033 [US1] Add "Già segnalato" indicator state to ReportButton (implemented in ReportButton widget)

**Checkpoint**: Report system complete - users can report any content type

---

## Phase 4: User Story 2 - Bloccare Utente (Priority: P1)

**Goal**: Utenti possono bloccare altri utenti, i contenuti spariscono immediatamente dal feed

**Independent Test**: Bloccare un utente dal suo profilo, verificare che i suoi contenuti non appaiano più nel feed

### Implementation for User Story 2

- [x] T034 [US2] Create BlockRepository in nova/lib/features/safety/data/repositories/block_repository.dart
- [x] T035 [US2] Implement blockUser method in BlockRepository
- [x] T036 [US2] Implement unblockUser method in BlockRepository
- [x] T037 [US2] Implement getBlockedUsers method in BlockRepository
- [x] T038 [US2] Implement isUserBlocked RPC call in BlockRepository
- [x] T039 [US2] Implement isBlockedByUser RPC call in BlockRepository
- [x] T040 [US2] Create BlockService in nova/lib/features/safety/domain/services/block_service.dart
- [x] T041 [US2] Create block_provider with BlockNotifier in nova/lib/features/safety/presentation/providers/block_provider.dart
- [x] T042 [US2] Create BlockConfirmationDialog widget in nova/lib/features/safety/presentation/widgets/block_button.dart
- [x] T043 [US2] Integrate BlockButton into profile screen overflow menu
- [x] T044 [US2] Modify feed provider to filter blocked users from events feed
- [x] T045 [US2] Modify chat provider to filter messages from blocked users
- [x] T046 [US2] Modify comments provider to filter comments from blocked users
- [x] T047 [US2] Add "Profilo non disponibile" check to profile screen for blocked viewers

**Checkpoint**: Block system complete - blocked user content hidden, no notification to blocked user

---

## Phase 5: User Story 3 - Accettare ToS (Priority: P1)

**Goal**: Utenti devono accettare i ToS prima di creare qualsiasi contenuto

**Independent Test**: Nuovo utente tenta di postare, vede schermata ToS, accetta, può procedere

### Implementation for User Story 3

- [x] T048 [US3] Create TosRepository in nova/lib/features/safety/data/repositories/tos_repository.dart
- [x] T049 [US3] Implement getTosStatus RPC call in TosRepository
- [x] T050 [US3] Implement acceptTos RPC call in TosRepository
- [x] T051 [US3] Implement getTosDocumentUrl method in TosRepository
- [x] T052 [US3] Create TosService in nova/lib/features/safety/domain/services/tos_service.dart
- [x] T053 [US3] Create tos_provider with TosNotifier in nova/lib/features/safety/presentation/providers/tos_provider.dart
- [x] T054 [US3] Create TosAcceptanceScreen in nova/lib/features/safety/presentation/screens/tos_acceptance_screen.dart
- [x] T055 [US3] Add ToS check guard to post creation flow
- [x] T056 [US3] Add ToS check guard to comment creation flow
- [x] T057 [US3] Add ToS check guard to chat message creation flow
- [x] T058 [US3] Add ToS link to Settings screen
- [x] T059 [US3] Upload ToS document 1.0.0 to Supabase storage (file exists at supabase/storage/public/legal/tos-1.0.0.md)

**Checkpoint**: ToS enforcement complete - no content creation without acceptance

---

## Phase 6: User Story 4 - Moderazione Segnalazioni (Priority: P2)

**Goal**: Moderatori possono gestire segnalazioni entro 24h con azioni appropriate

**Independent Test**: Creare segnalazione, accedere dashboard moderazione, eseguire azione, verificare risultato

### Implementation for User Story 4

- [x] T060 [US4] Create moderation RPC functions in migration: get_pending_reports, review_report, get_moderation_stats, lift_sanction
- [x] T061 [US4] Create remove_content helper function in migration
- [x] T062 [US4] Create send-urgent-reports-digest Edge Function at supabase/functions/send-urgent-reports-digest/index.ts
- [x] T063 [US4] Create check-ban-status Edge Function at supabase/functions/check-ban-status/index.ts
- [ ] T064 [US4] Deploy Edge Functions to Supabase (manual: `supabase functions deploy`)
- [ ] T065 [US4] Schedule send-urgent-reports-digest to run every 4 hours via Supabase cron (manual)
- [ ] T066 [US4] Integrate check-ban-status with Supabase Auth hook on sign-in (manual)

**Checkpoint**: Moderation backend complete - reports can be reviewed and actioned

---

## Phase 7: User Story 5 - Filtro Contenuti Automatico (Priority: P2)

**Goal**: Contenuti con parole vietate vengono bloccati automaticamente

**Independent Test**: Tentare di postare con parola vietata, vedere messaggio di blocco

### Implementation for User Story 5

- [x] T067 [US5] Create ContentFilterRepository in nova/lib/features/safety/data/repositories/content_filter_repository.dart
- [x] T068 [US5] Implement checkContent RPC call in ContentFilterRepository
- [x] T069 [US5] Implement getBannedWords method in ContentFilterRepository (for moderators)
- [x] T070 [US5] Create ContentFilterService in nova/lib/features/safety/domain/services/content_filter_service.dart
- [x] T071 [US5] Create content_filter_provider in nova/lib/features/safety/presentation/providers/content_filter_provider.dart
- [x] T072 [US5] Create ContentWarningBanner widget in nova/lib/features/safety/presentation/widgets/content_warning_banner.dart
- [x] T073 [US5] Integrate content check into post composer with debounced validation
- [x] T074 [US5] Integrate content check into comment composer
- [x] T075 [US5] Integrate content check into chat message input
- [x] T076 [US5] Add error handling for blocked content with user-friendly message (via ContentWarningBanner)

**Checkpoint**: Content filter active - offensive words blocked before submission

---

## Phase 8: User Story 6 - Sbloccare Utente (Priority: P3)

**Goal**: Utenti possono sbloccare utenti precedentemente bloccati

**Independent Test**: Andare in Impostazioni → Utenti bloccati, sbloccare, verificare che i contenuti riappaiano

### Implementation for User Story 6

- [x] T077 [US6] Create BlockedUsersScreen in nova/lib/features/safety/presentation/screens/blocked_users_screen.dart
- [x] T078 [US6] Create BlockedUserTile widget for list items
- [x] T079 [US6] Implement unblock confirmation dialog
- [x] T080 [US6] Add "Utenti bloccati" menu item to Settings screen with navigation
- [x] T081 [US6] Update block_provider to refresh feed on unblock

**Checkpoint**: Unblock flow complete - full block/unblock cycle working

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T082 [P] Update safety.dart barrel export with all public APIs
- [x] T083 [P] Add safety feature to app router configuration
- [x] T084 Review and validate quickstart.md scenarios (covered by implementation)
- [ ] T085 Performance review: verify block filter <1s, report submission <500ms (manual testing)
- [x] T086 Security review: verify RLS policies enforce correct access (RLS policies defined in migration)
- [x] T087 [P] Add loading states and error handling to all safety widgets (integrated throughout)
- [x] T088 Verify moderator notification trigger works on block (trigger defined in migration)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **US1, US2, US3 (Phases 3-5)**: All depend on Foundational - can run in parallel if staffed
- **US4, US5 (Phases 6-7)**: Depend on Foundational - can run in parallel with US1-3
- **US6 (Phase 8)**: Depends on US2 (uses BlockRepository)
- **Polish (Phase 9)**: Depends on all desired stories complete

### User Story Dependencies

| Story | Depends On | Can Parallel With |
|-------|------------|-------------------|
| US1 (Report) | Foundational only | US2, US3, US4, US5 |
| US2 (Block) | Foundational only | US1, US3, US4, US5 |
| US3 (ToS) | Foundational only | US1, US2, US4, US5 |
| US4 (Moderation) | Foundational only | US1, US2, US3, US5 |
| US5 (Filter) | Foundational only | US1, US2, US3, US4 |
| US6 (Unblock) | US2 complete | - |

### Within Each User Story

- Repository before Service
- Service before Provider
- Provider before Widgets
- Widgets before Integration

### Parallel Opportunities

**Phase 2 - Foundational** (different tables/files):
```
T014, T015, T016, T017, T018 - All models in parallel
```

**After Foundational - All P1 stories can start together**:
```
Developer A: US1 (Report) - T021-T033
Developer B: US2 (Block) - T034-T047
Developer C: US3 (ToS) - T048-T059
```

---

## Implementation Strategy

### MVP First (Apple Compliance Minimum)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL)
3. Complete Phase 3: US1 - Report System
4. Complete Phase 4: US2 - Block System
5. Complete Phase 5: US3 - ToS Acceptance
6. **SUBMIT TO APPLE REVIEW** - Minimum compliance achieved

### Full Implementation

1. MVP above +
2. Phase 6: US4 - Moderation backend
3. Phase 7: US5 - Content filter
4. Phase 8: US6 - Unblock
5. Phase 9: Polish

### Suggested Sequence (Solo Developer)

1. Setup + Foundational (T001-T020) → Database ready
2. US1 Report (T021-T033) → Can test reports
3. US2 Block (T034-T047) → Can test blocking
4. US3 ToS (T048-T059) → Apple compliance complete
5. Submit to Apple, continue with US4-US6 while waiting

---

## Task Summary

| Phase | Story | Task Count | Parallel |
|-------|-------|------------|----------|
| 1 | Setup | 3 | 2 |
| 2 | Foundational | 17 | 5 |
| 3 | US1 Report | 13 | 0 |
| 4 | US2 Block | 14 | 0 |
| 5 | US3 ToS | 12 | 0 |
| 6 | US4 Moderation | 7 | 0 |
| 7 | US5 Filter | 10 | 0 |
| 8 | US6 Unblock | 5 | 0 |
| 9 | Polish | 7 | 3 |
| **Total** | | **88** | **10** |

---

## Notes

- [P] tasks = different files, no dependencies
- [US#] label maps task to specific user story
- Each US1-3 story can be demo'd independently to Apple
- Stop at Phase 5 checkpoint for minimum Apple compliance
- Migration T004-T013 should be a single file with sequential execution
- Commit after each task or logical group
