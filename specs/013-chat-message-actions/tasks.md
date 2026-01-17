# Tasks: Chat Message Actions (Edit & Delete)

**Input**: Design documents from `/specs/013-chat-message-actions/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/
**Branch**: `013-chat-message-actions`

**Tests**: Not explicitly requested in specification - test tasks NOT included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Mobile (Flutter)**: `nova/lib/features/chat/` for Dart code
- **Database**: `supabase/migrations/` for SQL migrations

---

## Phase 1: Setup (Database Migration)

**Purpose**: Create database schema changes required for soft delete functionality

- [x] T001 Create migration file `supabase/migrations/036_soft_delete_messages.sql` with soft delete fields (deleted_at, deleted_by_user)
- [x] T002 Add partial index on deleted_at in `supabase/migrations/036_soft_delete_messages.sql`
- [x] T003 Drop old hard-delete RLS policy and create soft delete RLS policy in `supabase/migrations/036_soft_delete_messages.sql`

**Checkpoint**: Migration ready to apply. Run `supabase db push` to apply changes.

---

## Phase 2: Foundational (Domain & Data Layer)

**Purpose**: Core model and data layer changes that ALL user stories depend on

**⚠️ CRITICAL**: No user story UI work can begin until this phase is complete

- [x] T004 Add `deletedAt` and `deletedByUser` fields to `ChatMessageModel` in `nova/lib/features/chat/data/models/chat_message_model.dart`
- [x] T005 Update `ChatMessageModel.fromJson()` to parse deleted_at and deleted_by_user in `nova/lib/features/chat/data/models/chat_message_model.dart`
- [x] T006 Update `ChatMessageModel.toJson()` to serialize deleted_at and deleted_by_user in `nova/lib/features/chat/data/models/chat_message_model.dart`
- [x] T007 Add `deletedAt` and `deletedByUser` fields to `ChatMessage` domain entity in `nova/lib/features/chat/domain/entities/chat_message.dart`
- [x] T008 Add `isDeleted` getter to `ChatMessage` in `nova/lib/features/chat/domain/entities/chat_message.dart`
- [x] T009 Add `displayContent` getter that returns "Messaggio eliminato" when deleted in `nova/lib/features/chat/domain/entities/chat_message.dart`
- [x] T010 Update `toDomain()` method in `ChatMessageModel` to map deleted fields to `ChatMessage` in `nova/lib/features/chat/data/models/chat_message_model.dart`

**Checkpoint**: Foundation ready - data models support soft delete. User story implementation can now begin.

---

## Phase 3: User Story 1 - Delete Own Message (Priority: P1) 🎯 MVP

**Goal**: Users can delete their own messages at any time. Deleted messages show "Messaggio eliminato" placeholder to all participants.

**Independent Test**: Send a message, delete it, verify "Messaggio eliminato" appears and other users see the placeholder in realtime.

### Implementation for User Story 1

- [x] T011 [US1] Update `canDelete` getter to always return true (remove 30-min time check) in `nova/lib/features/chat/domain/entities/chat_message.dart`
- [x] T012 [US1] Update `deleteMessage()` in `ChatRemoteDataSource` to use soft delete (UPDATE with deleted_at) instead of hard delete in `nova/lib/features/chat/data/datasources/chat_remote_datasource.dart`
- [x] T013 [US1] Update `deleteMessage()` in `ChatRepositoryImpl` to delete associated media files before soft delete in `nova/lib/features/chat/data/repositories/chat_repository_impl.dart`
- [x] T014 [US1] Remove time-based validation from `deleteMessage()` in `ChatRepositoryImpl` in `nova/lib/features/chat/data/repositories/chat_repository_impl.dart`
- [x] T015 [US1] Add validation to prevent deleting already-deleted messages in `ChatRepositoryImpl` in `nova/lib/features/chat/data/repositories/chat_repository_impl.dart`
- [x] T016 [US1] Update `ChatMessageTile` to render "Messaggio eliminato" placeholder when `isDeleted` is true in `nova/lib/features/chat/presentation/widgets/chat_message_tile.dart`
- [x] T017 [US1] Style deleted message placeholder with grey background, italic text, and block icon in `nova/lib/features/chat/presentation/widgets/chat_message_tile.dart`
- [x] T018 [US1] Hide edit/delete context menu options for deleted messages in `nova/lib/features/chat/presentation/widgets/chat_message_context_overlay.dart`

**Checkpoint**: User Story 1 complete. Users can delete messages and see "Messaggio eliminato" placeholder. Realtime updates work via existing Postgres Changes subscription.

---

## Phase 4: User Story 2 - Edit Own Message Within Time Limit (Priority: P2)

**Goal**: Users can edit their messages within 15 minutes. Edited messages show "Modificato" indicator.

**Independent Test**: Send a message, edit it within 15 minutes, verify updated content and "Modificato" indicator appear. Try to edit after 15 minutes and verify it's disabled.

### Implementation for User Story 2

- [x] T019 [US2] Update `canEdit` getter to use 15 minutes instead of 5 minutes in `nova/lib/features/chat/domain/entities/chat_message.dart`
- [x] T020 [US2] Add constant `editWindowMinutes = 15` to `ChatMessage` in `nova/lib/features/chat/domain/entities/chat_message.dart`
- [x] T021 [US2] Update `editWindowMinutesRemaining` getter to use 15 minutes in `nova/lib/features/chat/domain/entities/chat_message.dart`
- [x] T022 [US2] Add validation to prevent editing deleted messages in `editMessage()` in `ChatRepositoryImpl` in `nova/lib/features/chat/data/repositories/chat_repository_impl.dart`
- [x] T023 [US2] Update error message for expired edit window to mention 15 minutes in `ChatRepositoryImpl` in `nova/lib/features/chat/data/repositories/chat_repository_impl.dart`
- [x] T024 [US2] Update countdown timer constant from 5 to 15 minutes in `nova/lib/features/chat/presentation/widgets/edit_message_dialog.dart`
- [x] T025 [US2] Ensure "Modifica" option is hidden for deleted messages in context overlay in `nova/lib/features/chat/presentation/widgets/chat_message_context_overlay.dart`

**Checkpoint**: User Story 2 complete. Edit window extended to 15 minutes. Edited messages show "Modificato" indicator (existing functionality).

---

## Phase 5: User Story 3 - Visual Feedback and Confirmation (Priority: P3)

**Goal**: Users see confirmation dialog before deleting. Clear feedback during edit with time remaining indicator.

**Independent Test**: Tap delete on a message, verify confirmation dialog appears with "Annulla" and "Elimina" options. Edit a message and verify time remaining countdown is visible.

### Implementation for User Story 3

- [x] T026 [P] [US3] Create `DeleteMessageConfirmationDialog` widget in `nova/lib/features/chat/presentation/widgets/delete_message_confirmation_dialog.dart`
- [x] T027 [US3] Implement dialog UI with title "Elimina messaggio", descriptive text, "Annulla" and "Elimina" buttons in `nova/lib/features/chat/presentation/widgets/delete_message_confirmation_dialog.dart`
- [x] T028 [US3] Style "Elimina" button with error color in `nova/lib/features/chat/presentation/widgets/delete_message_confirmation_dialog.dart`
- [x] T029 [US3] Update context overlay to show confirmation dialog before calling delete in `nova/lib/features/chat/presentation/widgets/chat_message_context_overlay.dart`
- [x] T030 [US3] Ensure edit dialog shows warning when time remaining is <= 2 minutes in `nova/lib/features/chat/presentation/widgets/edit_message_dialog.dart`
- [x] T031 [US3] Add export for `DeleteMessageConfirmationDialog` in chat widgets barrel file (if exists) or update imports

**Checkpoint**: User Story 3 complete. Confirmation dialog prevents accidental deletion. Edit time indicator provides clear feedback.

---

## Phase 6: Polish & Integration

**Purpose**: Final validation and cleanup

- [ ] T032 Verify realtime updates propagate delete/edit changes to other users (manual test)
- [ ] T033 Test edge case: delete message with media attachment (manual test)
- [ ] T034 Test edge case: edit message then delete it (manual test)
- [x] T035 Run `flutter analyze` to check for any linting issues
- [x] T036 Update any related documentation if needed

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) → Phase 2 (Foundational) → Phase 3-5 (User Stories) → Phase 6 (Polish)
```

- **Setup (Phase 1)**: No dependencies - database migration
- **Foundational (Phase 2)**: Depends on Setup - model changes
- **User Stories (Phase 3-5)**: All depend on Foundational completion
- **Polish (Phase 6)**: Depends on all user stories

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories ✅ MVP
- **User Story 2 (P2)**: Can start after Foundational - Independent of US1
- **User Story 3 (P3)**: Can start after US1 (needs delete action to show dialog)

### Within Each Phase

1. Database changes first (Phase 1)
2. Data models before domain entities (Phase 2)
3. Domain logic before repository implementation
4. Repository before UI widgets
5. Core functionality before polish

### Parallel Opportunities

**Phase 2 (Foundational):**
- T004-T006 (ChatMessageModel) and T007-T009 (ChatMessage entity) can be done by different developers
- T010 depends on both being complete

**Phase 3-4 (User Stories 1-2):**
- US1 and US2 can run in parallel after Foundational is complete
- US3 should wait for US1 (delete functionality)

---

## Parallel Example: Foundational Phase

```bash
# Developer A: Data Model
Task: T004 Add deletedAt and deletedByUser fields to ChatMessageModel
Task: T005 Update ChatMessageModel.fromJson()
Task: T006 Update ChatMessageModel.toJson()

# Developer B: Domain Entity (in parallel)
Task: T007 Add deletedAt and deletedByUser fields to ChatMessage
Task: T008 Add isDeleted getter
Task: T009 Add displayContent getter

# Then together:
Task: T010 Update toDomain() mapping
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (migration)
2. Complete Phase 2: Foundational (models)
3. Complete Phase 3: User Story 1 (delete)
4. **STOP and VALIDATE**: Test delete functionality independently
5. Deploy if ready - users can delete messages

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add User Story 1 → Test → Deploy (MVP: Delete works!)
3. Add User Story 2 → Test → Deploy (Edit window = 15 min)
4. Add User Story 3 → Test → Deploy (Confirmation dialogs)
5. Each story adds value without breaking previous stories

---

## Summary

| Phase | Tasks | Purpose |
|-------|-------|---------|
| Phase 1: Setup | T001-T003 | Database migration |
| Phase 2: Foundational | T004-T010 | Data/Domain layer |
| Phase 3: US1 (P1) | T011-T018 | Delete functionality |
| Phase 4: US2 (P2) | T019-T025 | Edit 15-min window |
| Phase 5: US3 (P3) | T026-T031 | Confirmation UX |
| Phase 6: Polish | T032-T036 | Final validation |

**Total Tasks**: 36
**Files Modified**: 6
**Files Created**: 2 (migration + confirmation dialog)
**Estimated LOC**: ~200

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Realtime already handles UPDATE events - no new subscription needed
