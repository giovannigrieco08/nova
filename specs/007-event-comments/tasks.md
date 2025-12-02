# Tasks: Event Comments System

**Input**: Design documents from `/specs/007-event-comments/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- Flutter project root: `c:\Users\grigi\nova_def\nova\`
- Feature module: `lib/features/comments/`
- Shared widgets: `lib/shared/widgets/`
- Database migrations: `c:\Users\grigi\nova_def\supabase/migrations/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and dependency configuration

- [x] T001 Add comment feature dependencies to nova/pubspec.yaml (rxdart for debouncing, flutter_hooks for reactive UI)
- [x] T002 [P] Run flutter pub get to install new dependencies
- [x] T003 [P] Create feature directory structure: lib/features/comments/{data,domain,presentation} per plan.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Database & Backend Setup

- [x] T004 Create Supabase migration file supabase/migrations/007_event_comments_system.sql
- [x] T005 Define comments table schema with RLS policies, triggers, indexes per data-model.md
- [x] T006 [P] Define comment_likes table schema with composite primary key and RLS policies
- [x] T007 [P] Define comment_reports table schema with unique constraint and RLS policies
- [x] T008 Create profanity filter PostgreSQL function with 150-word Italian list per research.md
- [x] T009 [P] Create rate limiting triggers (prevent_comment_spam, prevent_like_spam) per data-model.md
- [x] T010 [P] Create denormalized counter triggers (sync_comment_like_count, sync_comment_reply_count, sync_comment_report_count) per data-model.md
- [x] T011 Create auto-hide trigger embedded in update_comment_report_count (hides at 3+ reports)
- [ ] T012 Run supabase db push to apply migration to development database (PENDING: Apply via Supabase Dashboard)
- [ ] T013 Verify database schema and test RLS policies with psql commands (PENDING: Requires database access)

### Domain Layer (Entities & Repository Interface)

- [x] T014 [P] Create Comment entity in lib/features/comments/domain/entities/comment.dart with computed properties (isDeleted, isEdited, canEdit, displayText, relativeTimestamp)
- [x] T015 [P] Create CommentLike entity in lib/features/comments/domain/entities/comment_like.dart
- [x] T016 [P] Create CommentReport entity in lib/features/comments/domain/entities/comment_report.dart with enums (CommentReportReason, CommentReportStatus)
- [x] T017 Create CommentsRepositoryInterface in lib/features/comments/domain/repositories/comments_repository_interface.dart with all 18 methods per contracts/comments_repository_interface.md
- [x] T018 [P] Define exception hierarchy in lib/features/comments/domain/exceptions/ (NetworkException, ValidationException, RateLimitException, etc.) per contracts/comments_repository_interface.md

### Data Layer (Models & Data Sources)

- [x] T019 [P] Create CommentModel in lib/features/comments/data/models/comment_model.dart with fromJson/toJson and toEntity methods
- [x] T020 [P] Create CommentLikeModel in lib/features/comments/data/models/comment_like_model.dart with JSON serialization
- [x] T021 [P] Create CommentReportModel in lib/features/comments/data/models/comment_report_model.dart with JSON serialization
- [x] T022 Create CommentsRemoteDataSource in lib/features/comments/data/datasources/comments_remote_datasource.dart with Supabase client calls per contracts/supabase_api_spec.md
- [x] T023 [P] Create CommentsLocalDataSource in lib/features/comments/data/datasources/comments_local_datasource.dart with Hive cache methods (getCachedComments, cacheComments, 15-min TTL)
- [x] T024 Create CommentsRepository in lib/features/comments/data/repositories/comments_repository.dart implementing CommentsRepositoryInterface with error handling pattern per contracts/comments_repository_interface.md

### Shared Presentation Components

- [x] T025 [P] Create AdaptiveBottomSheet widget in lib/shared/widgets/adaptive/adaptive_bottom_sheet.dart (CupertinoModalPopup for iOS, ModalBottomSheet for Android) if not exists
- [x] T026 [P] Create AdaptiveDialog widget in lib/shared/widgets/adaptive/adaptive_dialog.dart for confirmation dialogs
- [x] T027 [P] Create AdaptiveTextField widget in lib/shared/widgets/adaptive/adaptive_text_field.dart for comment input
- [x] T028 Update EventModel in lib/features/events/data/models/event_model.dart to add comment_count field
- [x] T029 Update EventCard widget in lib/features/events/presentation/widgets/event_card.dart to add "💬 X commenti" button
- [x] T030 Extend NotificationService in lib/core/services/notification_service.dart to support comment notification types

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - View and Write Top-Level Comments (Priority: P1) 🎯 MVP

**Goal**: Students can open an event, view existing comments in a fullscreen sheet, and post new comments

**Independent Test**: Open any event, tap "💬 commenti" button, see comments list (or empty state), type a comment, tap send, see it appear immediately

### Implementation for User Story 1

- [ ] T031 [P] [US1] Create CommentsNotifier in lib/features/comments/presentation/providers/comments_notifier.dart extending AsyncNotifier<List<Comment>> with getCommentsForEvent method
- [ ] T032 [P] [US1] Create CommentInputNotifier in lib/features/comments/presentation/providers/comment_input_notifier.dart for input field state management
- [ ] T033 [US1] Implement GetCommentsForEvent use case in lib/features/comments/domain/usecases/get_comments_for_event.dart
- [ ] T034 [US1] Implement PostComment use case in lib/features/comments/domain/usecases/post_comment.dart with profanity/rate limit handling
- [ ] T035 [P] [US1] Create CommentsSheet screen in lib/features/comments/presentation/screens/comments_sheet.dart with adaptive bottom sheet, title "Commenti", comment count display
- [ ] T036 [P] [US1] Create CommentCard widget in lib/features/comments/presentation/widgets/comment_card.dart displaying avatar, name, timestamp, text, like count
- [ ] T037 [P] [US1] Create CommentInputField widget in lib/features/comments/presentation/widgets/comment_input_field.dart with sticky bottom positioning, 500-char limit, auto-expand (max 4 lines), send button
- [ ] T038 [P] [US1] Create EmptyCommentsState widget in lib/features/comments/presentation/widgets/empty_comments_state.dart with "💬" icon, "Nessun commento ancora", "Sii il primo a commentare!"
- [ ] T039 [US1] Wire CommentsSheet to EventDetailScreen or EventCard "💬 commenti" button with platform-adaptive navigation (CupertinoPageRoute vs MaterialPageRoute)
- [ ] T040 [US1] Implement optimistic UI for posting comment (instant local update, server sync, rollback on error) per research.md optimistic UI pattern
- [ ] T041 [US1] Add validation: disable send button if text empty/whitespace, show character counter approaching 500-char limit
- [ ] T042 [US1] Add accessibility: semantic labels for screen readers (VoiceOver/TalkBack) on all interactive elements per clarifications (FR-078)

**Checkpoint**: At this point, students can view and post comments on events. This is the MVP core functionality.

---

## Phase 4: User Story 2 - Like Comments and View Engagement (Priority: P1)

**Goal**: Students can like/unlike comments, see like counts with animations, and view engagement

**Independent Test**: View any comment, tap ❤️ icon, see pop animation + purple color + counter update, tap again to unlike

### Implementation for User Story 2

- [ ] T043 [P] [US2] Create CommentLikesNotifier in lib/features/comments/presentation/providers/comment_likes_notifier.dart for optimistic like state management
- [ ] T044 [US2] Implement LikeComment use case in lib/features/comments/domain/usecases/like_comment.dart (idempotent, handles rate limit)
- [ ] T045 [US2] Implement UnlikeComment use case in lib/features/comments/domain/usecases/unlike_comment.dart (idempotent)
- [ ] T046 [P] [US2] Create LikeButton widget in lib/features/comments/presentation/widgets/like_button.dart with animated heart icon (gray ↔ purple Nova brand color), pop scale effect
- [ ] T047 [US2] Integrate LikeButton into CommentCard widget with like count display (show only when >0, abbreviate as "1K+" for >999)
- [ ] T048 [US2] Implement optimistic UI for like/unlike (instant visual update, server sync, rollback on network error) with <200ms perceived response time
- [ ] T049 [US2] Add error handling: show toast on like failure with rollback to previous state
- [ ] T050 [US2] Implement rate limit countdown toast per clarifications (Q3): "Hai raggiunto il limite. Riprova tra 3m 24s" with live 1-second interval countdown

**Checkpoint**: At this point, students can like and unlike comments with instant feedback. Engagement mechanism is functional.

---

## Phase 5: User Story 3 - Reply to Comments with Threading (Priority: P1)

**Goal**: Students can reply to specific comments, creating 1-level threaded conversations with visual indentation

**Independent Test**: Tap "💬 Rispondi" on any comment, type reply with auto-prefilled @mention, send, see it appear indented below parent

### Implementation for User Story 3

- [ ] T051 [P] [US3] Create ReplyModeNotifier in lib/features/comments/presentation/providers/reply_mode_notifier.dart to track reply state (null = normal mode, CommentID = replying to that comment)
- [ ] T052 [US3] Implement ReplyToComment use case in lib/features/comments/domain/usecases/reply_to_comment.dart (enforces 1-level max threading server-side)
- [ ] T053 [US3] Implement GetRepliesForComment use case in lib/features/comments/domain/usecases/get_replies_for_comment.dart
- [ ] T054 [P] [US3] Create CommentThread widget in lib/features/comments/presentation/widgets/comment_thread.dart displaying parent comment + indented replies (48px left indent, vertical line connector)
- [ ] T055 [US3] Update CommentsSheet to support reply mode: show purple header "Rispondi a [Name]" with close button (✕), pre-fill input with "@[Username] "
- [ ] T056 [US3] Update CommentCard to add "💬 Rispondi" button that triggers reply mode (sets ReplyModeNotifier state)
- [ ] T057 [US3] Add thread indicator "└─ X risposte" below reply button when comment has replies
- [ ] T058 [US3] Implement reply collapse/expand: default collapse if >3 replies, tap to toggle expansion with smooth animation
- [ ] T059 [US3] Send notification to parent comment author when reply is posted: "Marco ha risposto al tuo commento" with deep link
- [ ] T060 [US3] Add accessibility: announce reply mode state change to screen readers

**Checkpoint**: At this point, students can create threaded discussions. Conversation structure is functional.

---

## Phase 6: User Story 4 - Report Inappropriate Comments (Priority: P1)

**Goal**: Students can report comments for moderation (spam, inappropriate, bullying), triggering auto-hide at 3+ reports

**Independent Test**: Long-press (Android) or swipe-left (iOS) on comment, tap "🚩 Segnala", choose reason, submit, moderators see report in dashboard

### Implementation for User Story 4

- [ ] T061 [US4] Implement ReportComment use case in lib/features/comments/domain/usecases/report_comment.dart with duplicate report prevention
- [ ] T062 [P] [US4] Create ReportDialog widget in lib/features/comments/presentation/widgets/report_dialog.dart with title "Perché segnali questo commento?", reason checkboxes (Spam, Contenuto inappropriato, Bullismo/molestie, Off-topic, Altro with optional text field)
- [ ] T063 [P] [US4] Create CommentActionsMenu widget in lib/features/comments/presentation/widgets/comment_actions_menu.dart with platform-specific gestures (long-press for Android, swipe-left for iOS)
- [ ] T064 [US4] Update CommentCard to integrate CommentActionsMenu with actions: "💬 Rispondi", "🚩 Segnala", "📋 Copia testo" (more actions added in later stories)
- [ ] T065 [US4] Wire ReportDialog to show when "🚩 Segnala" tapped, submit report, show confirmation "Segnalazione inviata"
- [ ] T066 [US4] Implement server-side auto-hide logic (already in database trigger, verify it works): comment hidden at 3+ reports, placed in moderation queue
- [ ] T067 [US4] Add notification to moderators when comment auto-hidden: "Commento auto-nascosto da 3+ segnalazioni"
- [ ] T068 [US4] Handle ConflictException when user tries to report same comment twice: show toast "Hai già segnalato questo commento"

**Checkpoint**: At this point, students can report inappropriate comments and moderators are notified. Safety mechanism is functional.

---

## Phase 7: User Story 5 - Delete Own Comments (Priority: P1)

**Goal**: Students can delete their own comments (soft delete), preserving replies if they exist

**Independent Test**: Post a comment, long-press it, select "🗑️ Elimina", confirm, see it removed or replaced with "[Commento eliminato]" placeholder

### Implementation for User Story 5

- [ ] T069 [US5] Implement DeleteComment use case in lib/features/comments/domain/usecases/delete_comment.dart (soft delete: sets deleted_at, text = "[Commento eliminato]")
- [ ] T070 [P] [US5] Create DeleteConfirmationDialog widget in lib/features/comments/presentation/widgets/delete_confirmation_dialog.dart with "Sei sicuro di voler eliminare questo commento?" message, [Annulla] and [Elimina] buttons (destructive color)
- [ ] T071 [US5] Update CommentActionsMenu to add "🗑️ Elimina" option (only visible for own comments, check Comment.userId == currentUserId)
- [ ] T072 [US5] Wire DeleteConfirmationDialog to show when "🗑️ Elimina" tapped, handle confirmation, execute delete
- [ ] T073 [US5] Implement soft delete logic: if comment has 0 replies → remove completely, if comment has replies → replace text with "[Commento eliminato]", preserve comment structure
- [ ] T074 [US5] Update CommentCard to render deleted state: show "[Commento eliminato]" with "Utente Eliminato" author, gray styling
- [ ] T075 [US5] Add real-time sync: other users see deleted state immediately via Supabase Realtime

**Checkpoint**: At this point, students can delete their own comments with GDPR-compliant soft deletion. User autonomy is functional.

---

## Phase 8: User Story 6 - Moderator Comment Removal (Priority: P1)

**Goal**: Moderators can hard-delete inappropriate comments instantly with action logging

**Independent Test**: Moderator account long-presses any comment, selects "🛡️ Rimuovi commento", sees it hard-deleted with logged action

### Implementation for User Story 6

- [ ] T076 [US6] Implement ModeratorRemoveComment use case in lib/features/comments/domain/usecases/moderator_remove_comment.dart (hard hide: sets hidden_at, hidden_reason, moderator_id)
- [ ] T077 [US6] Update CommentActionsMenu to add moderator-only actions: "🛡️ Rimuovi commento" and "⚠️ Avvisa utente" (only visible if currentUser.role == 'moderator')
- [ ] T078 [US6] Implement hard-delete logic: set hidden_at = NOW(), hidden_reason = 'moderator_removed', moderator_id = currentUserId, comment disappears from student views
- [ ] T079 [US6] Add action logging to moderation dashboard: "Moderatore Anna ha rimosso commento ID 123" with timestamp
- [ ] T080 [US6] Implement moderator removal notification per clarifications (Q4): send in-app notification to comment author with reason: "Il tuo commento è stato rimosso: [Linguaggio inappropriato]"
- [ ] T081 [US6] Create notification input dialog for moderator to provide removal reason (required field, max 500 chars)
- [ ] T082 [US6] Implement ModeratorRestoreComment use case in lib/features/comments/domain/usecases/moderator_restore_comment.dart (for reversing auto-hide false positives: sets hidden_at = NULL)

**Checkpoint**: At this point, moderators have full comment removal powers with accountability. Moderation tools are functional.

---

## Phase 9: User Story 7 - Real-Time Comment Updates (Priority: P1)

**Goal**: Students see new comments, replies, and likes appear in real-time without refreshing (<500ms latency)

**Independent Test**: Two devices open same event's comments, post from one, see it appear on the other within 500ms

### Implementation for User Story 7

- [ ] T083 [US7] Implement SubscribeToRealtime use case in lib/features/comments/domain/usecases/subscribe_to_realtime.dart with event-scoped Supabase Realtime subscription per research.md
- [ ] T084 [US7] Integrate Supabase Realtime subscription into CommentsNotifier: activate on CommentsSheet open, dispose on sheet close
- [ ] T085 [US7] Add debouncing with rxdart StreamTransformer (100ms window) to prevent UI thrashing on rapid updates per research.md
- [ ] T086 [US7] Implement efficient diffing: compare incoming realtime data with local state, update only changed items
- [ ] T087 [US7] Handle realtime events: INSERT (add new comment to list), UPDATE (update existing comment), DELETE (remove comment)
- [ ] T088 [US7] Add connection health monitoring: detect WebSocket disconnection, show banner per clarifications (Q2): "Aggiornamenti in tempo reale non disponibili. Usa pull-to-refresh"
- [ ] T089 [US7] Implement fallback to pull-to-refresh when realtime unavailable: disable auto-updates, show manual refresh banner
- [ ] T090 [US7] Add visual feedback for realtime updates: brief highlight animation on newly appeared comments

**Checkpoint**: At this point, students see live updates without refreshing. Real-time engagement is functional.

---

## Phase 10: User Story 8 - Pull-to-Refresh and Pagination (Priority: P1)

**Goal**: Students can manually refresh comments and scroll through long threads with automatic pagination (20 per page)

**Independent Test**: Open event with 50+ comments, scroll to bottom to trigger pagination, pull down from top to refresh

### Implementation for User Story 8

- [ ] T091 [P] [US8] Implement platform-specific refresh controls in CommentsSheet: CupertinoSliverRefreshControl for iOS, Material RefreshIndicator for Android
- [ ] T092 [P] [US8] Implement cursor-based pagination in CommentsNotifier: getCommentsForEvent with cursorCreatedAt parameter, 20 per page limit
- [ ] T093 [US8] Add infinite scroll logic: detect scroll position near bottom (80% threshold), automatically load next page
- [ ] T094 [US8] Add pagination state management: hasMore boolean, nextCursor DateTime, loading indicator at list bottom
- [ ] T095 [US8] Handle end-of-list: stop pagination when hasMore == false, hide loading indicator
- [ ] T096 [US8] Implement pull-to-refresh: clear local cache, re-fetch first page, merge with realtime updates, show smooth insertion animation
- [ ] T097 [US8] Add performance optimization: virtualized list rendering with ListView.builder to maintain 60fps with hundreds of comments

**Checkpoint**: At this point, students can refresh and paginate through any size comment thread. Scalability is functional.

---

## Phase 11: User Story 9 - Sort Comments by Recenti vs Popolari (Priority: P2)

**Goal**: Students can toggle between "Recenti" (most recent first) and "Popolari" (most liked first) sorting

**Independent Test**: Open event with multiple comments, tap sort toggle (iOS: CupertinoSegmentedControl, Android: Chip selector), see list re-order

### Implementation for User Story 9

- [ ] T098 [P] [US9] Create CommentSortToggle widget in lib/features/comments/presentation/widgets/comment_sort_toggle.dart with platform-specific controls (CupertinoSegmentedControl for iOS, Chip selector for Android)
- [ ] T099 [US9] Add sort state to CommentsNotifier: sortOrder enum (recent, popular), default = recent
- [ ] T100 [US9] Update getCommentsForEvent to support sortOrder parameter: recent = created_at DESC, popular = like_count DESC + created_at DESC
- [ ] T101 [US9] Integrate CommentSortToggle into CommentsSheet below title
- [ ] T102 [US9] Implement sort toggle handler: update sortOrder state, re-fetch comments with new order, animate list re-order, reset scroll to top
- [ ] T103 [US9] Add visual feedback: show loading indicator during re-sort

**Checkpoint**: At this point, students can discover popular comments easily. Sorting is functional.

---

## Phase 12: User Story 10 - Edit Comments Within 5-Minute Window (Priority: P2)

**Goal**: Students can edit their own comments within 5 minutes to fix typos, show "(modificato)" indicator after edit

**Independent Test**: Post comment, immediately long-press, select "✏️ Modifica", change text, save, see updated text with "(modificato)" label

### Implementation for User Story 10

- [ ] T104 [US10] Implement EditComment use case in lib/features/comments/domain/usecases/edit_comment.dart with 5-min window validation, profanity check
- [ ] T105 [US10] Update CommentActionsMenu to add "✏️ Modifica" option (only visible for own comments AND created_at within 5 min of NOW)
- [ ] T106 [US10] Create edit mode UI in CommentsSheet: pre-fill input with current text, show character counter, replace send button with save button
- [ ] T107 [US10] Implement save handler: validate <500 chars, submit to server, update local state, exit edit mode
- [ ] T108 [US10] Add server-side validation: check edit window (NOW() - created_at <= 5 minutes), check profanity, reject if violations
- [ ] T109 [US10] Update CommentCard to show "(modificato)" indicator per clarifications (Q5): display next to timestamp when updated_at != created_at (e.g., "5 min fa (modificato)")
- [ ] T110 [US10] Handle edit errors: show toast "Il commento contiene linguaggio inappropriato" or "Tempo scaduto per modifica (>5 min)" and preserve original text

**Checkpoint**: At this point, students can fix typos quickly with transparency. Edit functionality is complete.

---

## Phase 13: User Story 11 - Tap Mentions to View Profiles (Priority: P2)

**Goal**: Students can tap @mentions in comments to navigate to mentioned user's profile

**Independent Test**: View comment with @mention (e.g., "@Marco Sì!"), tap highlighted mention, see Marco's profile open

### Implementation for User Story 11

- [ ] T111 [US11] Implement @mention detection and parsing in comment text: regex pattern to find @Username patterns
- [ ] T112 [US11] Update CommentCard to render @mentions as tappable RichText with purple Nova brand color highlight
- [ ] T113 [US11] Add tap handler for @mentions: extract username, look up user_id from profiles table, navigate to ProfileScreen
- [ ] T114 [US11] Handle invalid mentions: if user doesn't exist (deleted account), show toast "Profilo non trovato" and don't navigate
- [ ] T115 [US11] Support multiple mentions in one comment: all are independently tappable
- [ ] T116 [US11] Add server-side validation when posting comment: verify all @mentions reference valid users (optional: auto-strip invalid mentions)

**Checkpoint**: At this point, students can explore participants in discussions. Mention navigation is functional.

---

## Phase 14: User Story 12 - Copy Comment Text to Clipboard (Priority: P2)

**Goal**: Students can copy comment text to clipboard for sharing outside the app

**Independent Test**: Long-press any comment, select "📋 Copia testo", paste into Notes app, see plain text

### Implementation for User Story 12

- [ ] T117 [US12] Update CommentActionsMenu to add "📋 Copia testo" option for all comments
- [ ] T118 [US12] Implement clipboard copy handler: extract comment.text (plain text, no author/timestamp/likes), use Clipboard.setData
- [ ] T119 [US12] Preserve emoji and @mentions in copied text (e.g., "Ottimo evento! Ci sono anche i tornei 3v3? 🏀")
- [ ] T120 [US12] Handle deleted comments: if comment.text == "[Commento eliminato]", copy that text (don't allow copying original deleted content)
- [ ] T121 [US12] Show confirmation toast after copy: "Testo copiato" with brief duration (2 seconds)

**Checkpoint**: At this point, students can share comment text externally. Clipboard functionality is complete.

---

## Phase 15: User Story 13 - Receive Notifications for Comments and Replies (Priority: P2)

**Goal**: Event creators receive notifications when someone comments, comment authors receive notifications when someone replies

**Independent Test**: Post comment on someone else's event, verify they receive notification, tap notification to see it deep-links to specific comment

### Implementation for User Story 13

- [ ] T122 [US13] Extend NotificationService to create comment notification: "Sofia ha commentato il tuo evento 'Torneo Basket'" with deep link nova://event/{event_id}/comment/{comment_id}
- [ ] T123 [US13] Trigger notification when top-level comment posted: check if currentUserId != event.created_by_user_id, send notification to event creator
- [ ] T124 [US13] Create reply notification: "Marco ha risposto al tuo commento" with deep link to specific reply
- [ ] T125 [US13] Trigger notification when reply posted: check if currentUserId != parent_comment.user_id, send notification to parent author
- [ ] T126 [US13] Implement deep link handling: parse nova://event/{event_id}/comment/{comment_id}, navigate to EventDetailScreen, open CommentsSheet, scroll to and highlight specific comment with fade animation
- [ ] T127 [US13] Add notification preferences: Settings → Privacy → toggle "Notifiche commenti" (default: ON), respect toggle when sending notifications
- [ ] T128 [US13] Handle edge cases: don't send notification if user is currently viewing the comments sheet (already sees it in realtime), don't send duplicate notifications for same action

**Checkpoint**: At this point, students stay engaged with event discussions via notifications. Notification system is complete.

---

## Phase 16: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and final validation

### Performance & Optimization

- [ ] T129 [P] Run Flutter DevTools performance profiling on CommentsSheet: verify 60fps sustained scroll with 100+ comments
- [ ] T130 [P] Optimize image loading: use cached_network_image for avatars in CommentCard with placeholder
- [ ] T131 [P] Reduce bundle size: analyze dependencies, remove unused imports, run flutter build apk --release and verify <50MB per constitution
- [ ] T132 Optimize Supabase queries: add composite indexes if needed based on query performance analysis

### Accessibility & Quality

- [ ] T133 [P] Validate accessibility: test all screens with iOS VoiceOver and Android TalkBack, verify semantic labels work per clarifications (FR-078)
- [ ] T134 [P] Add platform-specific haptic feedback: light impact on like button tap (iOS), medium impact on delete confirmation (Android)
- [ ] T135 [P] Verify design system compliance: audit all widgets for NovaColors, NovaSpacing, NovaTypography usage, remove any hardcoded hex colors or magic numbers

### Testing & Validation

- [ ] T136 Run through all acceptance scenarios from spec.md for P1 user stories (US1-US8): verify each Given-When-Then passes
- [ ] T137 [P] Run through quickstart.md integration scenarios: Scenario 1 (View and Post), Scenario 2 (Like and Unlike), Scenario 3 (Reply Threading), Scenario 4 (Report Inappropriate), Scenario 5 (Real-Time Updates)
- [ ] T138 Test offline queue sync: turn off network, post comment, turn on network, verify comment syncs from offline queue
- [ ] T139 Test profanity filter: attempt to post comment with Italian profanity, verify rejection with error "Il commento contiene linguaggio inappropriato"
- [ ] T140 Test rate limiting: post 3 identical comments within 5 min, verify 4th is rejected with countdown toast per clarifications (Q3)

### Documentation

- [ ] T141 [P] Update README.md with comment feature overview and setup instructions
- [ ] T142 [P] Document new environment variables if any (e.g., SUPABASE_REALTIME_ENABLED)
- [ ] T143 Add inline code documentation for complex logic (optimistic UI, debouncing, pagination cursor)

### Final Validation

- [ ] T144 Run flutter analyze and fix all warnings/errors
- [ ] T145 Run flutter test (if tests were written) and verify all pass
- [ ] T146 Create test event with 50+ comments and verify: pagination works, realtime updates work, scroll performance is 60fps
- [ ] T147 Verify constitution compliance: all 7 principles pass (STUDENTS_FIRST, PRIVACY_FOUNDATION, SIMPLICITY_FIRST, PERFORMANCE_FIRST, SPEC_FIRST, DESIGN_SYSTEM_STRICT, CONTENT_MODERATION)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories P1 (Phase 3-10)**: All depend on Foundational phase completion
  - User stories can proceed in parallel (if staffed) or sequentially in order (US1 → US2 → ... → US8)
- **User Stories P2 (Phase 11-15)**: All depend on Foundational phase completion
  - Some depend on P1 stories being complete (e.g., US9 sorting depends on US1 viewing, US10 editing depends on US1 posting)
- **Polish (Phase 16)**: Depends on all desired user stories being complete

### User Story Dependencies

**P1 Stories (MVP - Independent after Foundational):**
- **US1 (View and Write)**: Foundation → US1 ✅ MVP Ready
- **US2 (Like Comments)**: Foundation → US2 (integrates with US1 CommentCard)
- **US3 (Reply Threading)**: Foundation → US3 (integrates with US1 CommentCard and CommentsSheet)
- **US4 (Report Comments)**: Foundation → US4 (integrates with US1 CommentCard via actions menu)
- **US5 (Delete Own)**: Foundation → US5 (integrates with US1 CommentCard via actions menu)
- **US6 (Moderator Removal)**: Foundation → US6 (integrates with US4 actions menu)
- **US7 (Real-Time Updates)**: Foundation → US7 (enhances US1 CommentsNotifier)
- **US8 (Pull-to-Refresh)**: Foundation → US8 (enhances US1 CommentsSheet)

**P2 Stories (Nice-to-have - Depend on P1 baseline):**
- **US9 (Sort Comments)**: US1 → US9 (adds sorting to existing view)
- **US10 (Edit Comments)**: US1, US5 → US10 (edit requires post and delete actions)
- **US11 (Tap Mentions)**: US1 → US11 (adds navigation to existing comment display)
- **US12 (Copy Text)**: US1 → US12 (adds copy action to existing actions menu)
- **US13 (Notifications)**: US1, US3 → US13 (notifications for post and reply actions)

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- Models/entities before services
- Use cases before providers
- Widgets before integration
- Core implementation before polish

### Parallel Opportunities

**Phase 1 (Setup):**
- T002 and T003 can run in parallel

**Phase 2 (Foundational):**
- T006, T007, T009, T010 (database tables/triggers) can run in parallel
- T014, T015, T016 (domain entities) can run in parallel
- T019, T020, T021 (data models) can run in parallel
- T025, T026, T027 (shared widgets) can run in parallel

**Phase 3-10 (P1 User Stories):**
- All P1 user stories (US1-US8) can start in parallel AFTER Phase 2 completes (if team capacity allows)
- Within each story: tasks marked [P] can run in parallel

**Phase 11-15 (P2 User Stories):**
- Most P2 stories can run in parallel AFTER their P1 dependencies are met

**Phase 16 (Polish):**
- T129, T130, T131 (performance) can run in parallel
- T133, T134, T135 (accessibility/quality) can run in parallel
- T137, T141, T142 (testing/docs) can run in parallel

---

## Parallel Example: User Story 1 (MVP)

```bash
# After Phase 2 (Foundational) completes, these US1 tasks can launch together:

# Providers (different files, no dependencies):
Task T031: "Create CommentsNotifier in lib/features/comments/presentation/providers/comments_notifier.dart"
Task T032: "Create CommentInputNotifier in lib/features/comments/presentation/providers/comment_input_notifier.dart"

# Widgets (different files, no dependencies):
Task T035: "Create CommentsSheet screen in lib/features/comments/presentation/screens/comments_sheet.dart"
Task T036: "Create CommentCard widget in lib/features/comments/presentation/widgets/comment_card.dart"
Task T037: "Create CommentInputField widget in lib/features/comments/presentation/widgets/comment_input_field.dart"
Task T038: "Create EmptyCommentsState widget in lib/features/comments/presentation/widgets/empty_comments_state.dart"

# Then, these integration tasks run sequentially after widgets complete:
Task T039: "Wire CommentsSheet to EventDetailScreen"
Task T040: "Implement optimistic UI for posting comment"
Task T041: "Add validation and character counter"
Task T042: "Add accessibility semantic labels"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. ✅ Complete Phase 1: Setup (T001-T003)
2. ✅ Complete Phase 2: Foundational (T004-T030) - **CRITICAL GATE**
3. ✅ Complete Phase 3: User Story 1 (T031-T042) - **MVP READY**
4. **STOP and VALIDATE**:
   - Open any event
   - Tap "💬 commenti" button
   - See comments list or empty state
   - Post a new comment
   - See it appear immediately
   - Verify: optimistic UI works, profanity filter works, 500-char limit enforced
5. Deploy/demo if ready

### Incremental Delivery (Recommended)

1. ✅ Phase 1 + Phase 2 → **Foundation Ready**
2. ✅ + Phase 3 (US1) → **MVP: Students can view and post comments** 🎯
3. ✅ + Phase 4 (US2) → **v1.1: Students can like comments for engagement**
4. ✅ + Phase 5 (US3) → **v1.2: Students can create threaded discussions**
5. ✅ + Phase 6 (US4) → **v1.3: Students can report inappropriate content**
6. ✅ + Phase 7 (US5) → **v1.4: Students can delete their own comments**
7. ✅ + Phase 8 (US6) → **v1.5: Moderators can remove comments**
8. ✅ + Phase 9 (US7) → **v1.6: Real-time updates enabled**
9. ✅ + Phase 10 (US8) → **v1.7: Pagination and manual refresh**
10. ✅ + Phase 11-15 (US9-US13) → **v2.0: All P2 features (sorting, editing, mentions, copy, notifications)**
11. ✅ + Phase 16 → **v2.1: Polished and production-ready**

Each increment is independently testable and deployable.

### Parallel Team Strategy

With 3 developers after Phase 2 completes:

**Week 1: P1 Core Features**
- Developer A: US1 (View/Post) + US2 (Like) → Days 1-3
- Developer B: US3 (Reply) + US4 (Report) → Days 1-3
- Developer C: US5 (Delete) + US6 (Moderator) → Days 1-3
- All: US7 (Realtime) + US8 (Pagination) → Days 4-5

**Week 2: P2 Enhancements**
- Developer A: US9 (Sort) + US10 (Edit) → Days 1-2
- Developer B: US11 (Mentions) + US12 (Copy) → Days 1-2
- Developer C: US13 (Notifications) → Days 1-2
- All: Phase 16 (Polish) → Days 3-5

---

## Notes

- **[P] tasks** = different files, no dependencies, safe to parallelize
- **[Story] label** maps task to specific user story for traceability
- Each user story is independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- **MVP = Phase 1 + Phase 2 + Phase 3 (US1)** - approximately 42 tasks
- **Full P1 MVP = Phases 1-10** - approximately 97 tasks
- **Complete Feature = Phases 1-16** - approximately 147 tasks
- Avoid: vague tasks, same-file conflicts, cross-story dependencies that break independence

---

**Total Tasks**: 147
**P1 User Stories**: 8 (US1-US8)
**P2 User Stories**: 5 (US9-US13)
**Parallel Opportunities**: ~40 tasks marked [P] across all phases
**MVP Scope**: Phase 1 + Phase 2 + Phase 3 (T001-T042) = 42 tasks
**Estimated MVP Time**: 3-5 days for experienced Flutter developer

**Next Step**: Run `/speckit.implement` to begin execution starting from T001
