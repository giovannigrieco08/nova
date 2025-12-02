# Tasks: Global Chat

**Feature**: 011-global-chat
**Input**: Design documents from `/specs/011-global-chat/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not explicitly requested - tests will be added during Polish phase if needed.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Flutter app**: `nova/lib/features/chat/`
- **Database migrations**: `supabase/migrations/`
- **Edge functions**: `supabase/functions/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and feature structure

- [ ] T001 Create chat feature directory structure per plan.md in `nova/lib/features/chat/`
- [ ] T002 [P] Add new dependencies to `nova/pubspec.yaml` (video_compress, flutter_windowmanager, screenshot_callback)
- [ ] T003 [P] Create feature barrel exports in `nova/lib/features/chat/chat.dart`

---

## Phase 2: Foundational (Database & Core Entities)

**Purpose**: Database schema and core domain entities that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [ ] T004 Create database migration file `supabase/migrations/011_global_chat_system.sql` with all tables from data-model.md
- [ ] T005 [P] Create ChatMessage entity in `nova/lib/features/chat/domain/entities/chat_message.dart`
- [ ] T006 [P] Create MentionInfo entity in `nova/lib/features/chat/domain/entities/mention_info.dart`
- [ ] T007 [P] Create ChatReaction entity in `nova/lib/features/chat/domain/entities/chat_reaction.dart`
- [ ] T008 [P] Create ChatReport entity in `nova/lib/features/chat/domain/entities/chat_report.dart`
- [ ] T009 [P] Create ChatMediaInfo entity in `nova/lib/features/chat/domain/entities/chat_media_info.dart`
- [ ] T010 Create ChatRepository interface in `nova/lib/features/chat/domain/repositories/chat_repository.dart`
- [ ] T011 [P] Create ChatMessageModel with JSON serialization in `nova/lib/features/chat/data/models/chat_message_model.dart`
- [ ] T012 [P] Create ChatReactionModel in `nova/lib/features/chat/data/models/chat_reaction_model.dart`
- [ ] T013 [P] Create ChatReportModel in `nova/lib/features/chat/data/models/chat_report_model.dart`
- [ ] T014 [P] Create ChatMediaModel in `nova/lib/features/chat/data/models/chat_media_model.dart`
- [ ] T015 Create ChatRemoteDataSource with Supabase client in `nova/lib/features/chat/data/datasources/chat_remote_datasource.dart`
- [ ] T016 Create ChatRepositoryImpl in `nova/lib/features/chat/data/repositories/chat_repository_impl.dart`
- [ ] T017 Create base Riverpod providers in `nova/lib/features/chat/presentation/providers/chat_providers.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - View and Send Messages (Priority: P1)

**Goal**: Students can view a real-time message feed and send text messages up to 500 characters.

**Independent Test**: Login as student, navigate to Chat tab, send a message, verify it appears for all users within 1 second.

### Implementation for User Story 1

- [ ] T018 [US1] Implement getMessages() stream in ChatRemoteDataSource `nova/lib/features/chat/data/datasources/chat_remote_datasource.dart`
- [ ] T019 [US1] Implement sendMessage() in ChatRemoteDataSource with optimistic UI support
- [ ] T020 [US1] Setup Supabase Realtime subscription for chat_messages in `nova/lib/features/chat/presentation/providers/chat_realtime_provider.dart`
- [ ] T021 [US1] Create chatMessagesStreamProvider in `nova/lib/features/chat/presentation/providers/chat_providers.dart`
- [ ] T022 [P] [US1] Create ChatMessageTile widget in `nova/lib/features/chat/presentation/widgets/chat_message_tile.dart`
- [ ] T023 [P] [US1] Create ChatMessageList widget with reverse scroll in `nova/lib/features/chat/presentation/widgets/chat_message_list.dart`
- [ ] T024 [US1] Create ChatComposeBar widget with character counter (500 max) in `nova/lib/features/chat/presentation/widgets/chat_compose_bar.dart`
- [ ] T025 [US1] Create ChatScreen combining list and compose bar in `nova/lib/features/chat/presentation/screens/chat_screen.dart`
- [ ] T026 [US1] Add ChatScreen to bottom navigation in `nova/lib/shared/widgets/nova_bottom_nav_bar.dart`
- [ ] T027 [US1] Implement offline message queuing with Hive in `nova/lib/features/chat/data/datasources/chat_local_datasource.dart`
- [ ] T028 [US1] Add connection status indicator widget in ChatScreen
- [ ] T029 [US1] Handle rate limit error display ("Troppi messaggi. Attendi qualche secondo.")

**Checkpoint**: User Story 1 complete - students can send/receive messages in real-time

---

## Phase 4: User Story 2 - Report Inappropriate Messages (Priority: P1)

**Goal**: Students can report messages via long-press with 4 reason options. Auto-hide at 3 reports.

**Independent Test**: Long-press a message, tap "Segnala", select reason, verify confirmation appears.

### Implementation for User Story 2

- [ ] T030 [US2] Implement submitReport() in ChatRemoteDataSource `nova/lib/features/chat/data/datasources/chat_remote_datasource.dart`
- [ ] T031 [US2] Implement hasUserReported() check in ChatRemoteDataSource
- [ ] T032 [US2] Create ChatReportDialog widget with 4 reasons in `nova/lib/features/chat/presentation/widgets/chat_report_dialog.dart`
- [ ] T033 [US2] Add long-press context menu to ChatMessageTile with "Segnala" option
- [ ] T034 [US2] Show "Segnalazione inviata" confirmation snackbar
- [ ] T035 [US2] Handle duplicate report error ("Hai gia segnalato questo messaggio")

**Checkpoint**: User Story 2 complete - reporting works, auto-hide handled by database trigger

---

## Phase 5: User Story 3 - Automatic Message Deletion (Priority: P1)

**Goal**: Messages auto-delete after 24 hours via pg_cron job.

**Independent Test**: Query database for messages older than 24h - should return empty.

### Implementation for User Story 3

- [ ] T036 [US3] Verify pg_cron job exists in migration file for hourly 24h deletion
- [ ] T037 [US3] Handle "[Messaggio eliminato]" display for deleted reply references in ChatMessageTile
- [ ] T038 [US3] Ensure CASCADE delete works for reactions and reports in migration

**Checkpoint**: User Story 3 complete - GDPR compliance via automatic deletion

---

## Phase 6: User Story 4 - @Mention Other Students (Priority: P2)

**Goal**: Students can @mention others with autocomplete, mentions are highlighted, notifications sent.

**Independent Test**: Type "@mar" in compose, select "Mario Rossi" from dropdown, send, verify Mario gets notification.

### Implementation for User Story 4

- [ ] T039 [US4] Implement searchUsersForMention() RPC in ChatRemoteDataSource using pg_trgm
- [ ] T040 [US4] Create MentionAutocomplete overlay widget in `nova/lib/features/chat/presentation/widgets/mention_autocomplete.dart`
- [ ] T041 [US4] Implement mention parsing in ChatComposeBar (detect @, extract mentions array)
- [ ] T042 [US4] Create MentionHighlightText widget for purple highlighting in `nova/lib/features/chat/presentation/widgets/mention_highlight_text.dart`
- [ ] T043 [US4] Integrate MentionHighlightText into ChatMessageTile content display
- [ ] T044 [US4] Add 'chat_mention' notification type handling in existing notification system
- [ ] T045 [US4] Navigate to chat from mention notification tap

**Checkpoint**: User Story 4 complete - @mentions with autocomplete and notifications work

---

## Phase 7: User Story 5 - Reply to Specific Messages (Priority: P2)

**Goal**: Students can swipe-to-reply, see quoted preview, tap to scroll to original.

**Independent Test**: Swipe right on message, type reply, send, verify quote preview appears.

### Implementation for User Story 5

- [ ] T046 [US5] Create ChatReplyPreview widget in `nova/lib/features/chat/presentation/widgets/chat_reply_preview.dart`
- [ ] T047 [US5] Add swipe-to-reply gesture using flutter_slidable in ChatMessageTile
- [ ] T048 [US5] Add reply state to ChatComposeBar (show preview, X to cancel)
- [ ] T049 [US5] Include reply_to_id in sendMessage() call
- [ ] T050 [US5] Display quoted message preview in ChatMessageTile for replies
- [ ] T051 [US5] Implement scroll-to-original on quote tap in ChatMessageList
- [ ] T052 [US5] Handle "[Messaggio eliminato]" for deleted original messages

**Checkpoint**: User Story 5 complete - reply threading with 1-level depth works

---

## Phase 8: User Story 6 - React to Messages with Emoji (Priority: P2)

**Goal**: Students can add/remove 6 emoji reactions via long-press picker.

**Independent Test**: Long-press message, tap heart emoji, verify count appears. Tap again, verify removed.

### Implementation for User Story 6

- [ ] T053 [US6] Implement addReaction() and removeReaction() in ChatRemoteDataSource
- [ ] T054 [US6] Implement getReactionsForMessage() in ChatRemoteDataSource
- [ ] T055 [US6] Setup reaction broadcast channel in chat_realtime_provider.dart
- [ ] T056 [US6] Create ChatReactionPicker widget with 6 emoji in `nova/lib/features/chat/presentation/widgets/chat_reaction_picker.dart`
- [ ] T057 [US6] Create ChatReactionRow widget showing counts in `nova/lib/features/chat/presentation/widgets/chat_reaction_row.dart`
- [ ] T058 [US6] Add reaction picker to long-press context menu in ChatMessageTile
- [ ] T059 [US6] Display ChatReactionRow below message content in ChatMessageTile
- [ ] T060 [US6] Implement toggle logic (tap existing reaction to remove)
- [ ] T061 [US6] Create reaction detail sheet showing who reacted

**Checkpoint**: User Story 6 complete - emoji reactions with real-time updates work

---

## Phase 9: User Story 7 - See Typing Indicators (Priority: P3)

**Goal**: Students see who is typing above compose bar. Max 3 names shown.

**Independent Test**: User A types, User B sees "Mario sta scrivendo..." appear and disappear after 3s.

### Implementation for User Story 7

- [ ] T062 [US7] Setup Supabase Presence channel for typing in `nova/lib/features/chat/presentation/providers/typing_indicator_provider.dart`
- [ ] T063 [US7] Implement startTyping() and stopTyping() with 3-second auto-timeout
- [ ] T064 [US7] Create ChatTypingIndicator widget in `nova/lib/features/chat/presentation/widgets/chat_typing_indicator.dart`
- [ ] T065 [US7] Format indicator text ("Mario sta scrivendo...", "Mario e Giulia stanno scrivendo...", "Mario, Giulia e altri 2 stanno scrivendo...")
- [ ] T066 [US7] Integrate typing indicator above compose bar in ChatScreen
- [ ] T067 [US7] Add debouncing (300ms) to startTyping() calls from ChatComposeBar
- [ ] T068 [US7] Filter out current user from typing indicator display

**Checkpoint**: User Story 7 complete - typing indicators with presence channel work

---

## Phase 10: User Story 8 - Send View-Once Ephemeral Media (Priority: P3)

**Goal**: Students can send view-once images/videos with screenshot protection.

**Independent Test**: Send view-once image, other user taps to view, verify cannot re-open.

### Implementation for User Story 8

- [ ] T069 [US8] Create `ephemeral-media` storage bucket via Supabase Dashboard or migration
- [ ] T070 [US8] Implement uploadMedia() with compression in ChatRemoteDataSource
- [ ] T071 [US8] Implement getSignedMediaUrl() for 60-second URLs in ChatRemoteDataSource
- [ ] T072 [US8] Implement markMediaViewed() in ChatRemoteDataSource
- [ ] T073 [US8] Create MediaPickerButton widget in ChatComposeBar with "Visualizzazione singola" toggle
- [ ] T074 [US8] Create ViewOnceBadge widget for message indicator in `nova/lib/features/chat/presentation/widgets/view_once_badge.dart`
- [ ] T075 [US8] Create MediaViewerScreen in `nova/lib/features/chat/presentation/screens/media_viewer_screen.dart`
- [ ] T076 [US8] Implement Android screenshot protection with FLAG_SECURE in MediaViewerScreen
- [ ] T077 [US8] Implement iOS screenshot detection with screenshot_callback in MediaViewerScreen
- [ ] T078 [US8] Send screenshot notification to sender on iOS detection
- [ ] T079 [US8] Show "Visualizzato" state after media is viewed
- [ ] T080 [US8] Block re-opening of viewed media with error message
- [ ] T081 [US8] Implement daily limit check (5 media/day) with user-friendly error
- [ ] T082 [US8] Create cleanup-viewed-media Edge Function in `supabase/functions/cleanup-viewed-media/index.ts`

**Checkpoint**: User Story 8 complete - view-once media with screenshot protection works

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements across all user stories

- [ ] T083 [P] Add loading skeletons to ChatMessageList
- [ ] T084 [P] Add pull-to-refresh to manually reload messages
- [ ] T085 [P] Implement pagination for older messages on scroll up
- [ ] T086 Verify all UI uses NovaColors, NovaSpacing, NovaTypography constants
- [ ] T087 Add analytics events for key actions (send message, report, reaction)
- [ ] T088 Performance test: verify <1s message delivery
- [ ] T089 Run quickstart.md validation scenarios
- [ ] T090 Update main navigation to include Chat tab with appropriate icon

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-10)**: All depend on Foundational phase completion
  - P1 stories (US1, US2, US3) should complete before P2/P3
  - P2 stories (US4, US5, US6) can run in parallel after P1
  - P3 stories (US7, US8) can run in parallel after P1
- **Polish (Phase 11)**: Depends on all desired user stories being complete

### User Story Dependencies

| Story | Priority | Depends On | Independent Test |
|-------|----------|------------|------------------|
| US1 - View/Send | P1 | Foundational only | Send message, verify real-time |
| US2 - Report | P1 | US1 (messages exist) | Long-press → Report → Confirm |
| US3 - Auto-Delete | P1 | Foundational only | Query >24h messages = empty |
| US4 - @Mentions | P2 | US1 | Type @username → notification |
| US5 - Reply | P2 | US1 | Swipe → reply → quote shows |
| US6 - Reactions | P2 | US1 | Long-press → emoji → count |
| US7 - Typing | P3 | US1 | Type → other sees indicator |
| US8 - View-Once | P3 | US1, Storage bucket | Send image → view → blocked |

### Parallel Opportunities

**Within Foundational (Phase 2)**:
- T005-T009: All entity files can be created in parallel
- T011-T014: All model files can be created in parallel

**Within User Story 1**:
- T022, T023: Message tile and list widgets can be created in parallel

**Within User Story 6**:
- T056, T057: Picker and row widgets can be created in parallel

**Across User Stories** (after P1 complete):
- US4, US5, US6 can run in parallel (different features)
- US7, US8 can run in parallel (different features)

---

## Parallel Example: Foundational Phase

```bash
# Launch all entity files together:
Task T005: "Create ChatMessage entity in nova/lib/features/chat/domain/entities/chat_message.dart"
Task T006: "Create MentionInfo entity in nova/lib/features/chat/domain/entities/mention_info.dart"
Task T007: "Create ChatReaction entity in nova/lib/features/chat/domain/entities/chat_reaction.dart"
Task T008: "Create ChatReport entity in nova/lib/features/chat/domain/entities/chat_report.dart"
Task T009: "Create ChatMediaInfo entity in nova/lib/features/chat/domain/entities/chat_media_info.dart"
```

---

## Implementation Strategy

### MVP First (P1 User Stories Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1 (View/Send)
4. Complete Phase 4: User Story 2 (Report)
5. Complete Phase 5: User Story 3 (Auto-Delete)
6. **STOP and VALIDATE**: Test all P1 stories independently
7. Deploy/demo as MVP

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 (View/Send) → Test → Deploy (Basic Chat MVP!)
3. Add US2 (Report) → Test → Deploy (Safe Chat)
4. Add US3 (Auto-Delete) → Test → Deploy (GDPR Compliant)
5. Add US4-US6 (P2) → Test → Deploy (Engaging Chat)
6. Add US7-US8 (P3) → Test → Deploy (Advanced Chat)

---

## Summary

| Phase | Tasks | Focus |
|-------|-------|-------|
| 1. Setup | T001-T003 | Project structure |
| 2. Foundational | T004-T017 | Database + Core entities |
| 3. US1 View/Send | T018-T029 | Core messaging |
| 4. US2 Report | T030-T035 | Content moderation |
| 5. US3 Auto-Delete | T036-T038 | GDPR compliance |
| 6. US4 @Mentions | T039-T045 | Targeted communication |
| 7. US5 Reply | T046-T052 | Threading |
| 8. US6 Reactions | T053-T061 | Engagement |
| 9. US7 Typing | T062-T068 | Real-time awareness |
| 10. US8 View-Once | T069-T082 | Privacy media |
| 11. Polish | T083-T090 | Final touches |

**Total Tasks**: 90
**MVP Tasks (P1 only)**: 38 (Phases 1-5)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- Each user story is independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Database triggers handle: rate limiting, profanity filter, auto-hide, reaction counts
