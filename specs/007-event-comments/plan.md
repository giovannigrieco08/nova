# Implementation Plan: Event Comments System

**Branch**: `007-event-comments` | **Date**: 2025-01-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/007-event-comments/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement a comprehensive comment system for Nova events inspired by Instagram but adapted for school environment. Students can post comments (max 500 chars), reply with threading (1 level deep), like/unlike, report inappropriate content, and view real-time updates. Moderators have enhanced removal powers. System uses optimistic UI for instant feedback, Supabase Realtime for live updates, pagination (20 per page), and includes profanity filtering, rate limiting, and GDPR-compliant soft deletion. Technical approach: Flutter frontend with Riverpod state management, Supabase PostgreSQL backend with Row-Level Security, real-time subscriptions via WebSocket, platform-adaptive UI (Cupertino for iOS, Material for Android).

## Technical Context

**Language/Version**: Dart 3.x with Flutter SDK 3.x+ (mandated by constitution)
**Primary Dependencies**:
- Flutter SDK (cross-platform mobile framework)
- Riverpod 2.x (state management - constitutional requirement)
- Supabase Flutter client (BaaS: database, auth, realtime, storage)
- flutter_hooks (for reactive UI patterns)
- cached_network_image (image caching for avatars)
- intl (date formatting for relative timestamps)

**Storage**: Supabase PostgreSQL 15+ (cloud-hosted, EU Frankfurt region for GDPR)
- Tables: comments, comment_likes, comment_reports
- Row-Level Security (RLS) policies enforce student/moderator permissions
- Realtime subscriptions via Supabase Realtime (WebSocket)
- Soft-delete pattern (deleted_at timestamps) for GDPR compliance

**Testing**:
- flutter test (widget tests, unit tests)
- Integration tests for critical flows (post comment, reply, like, report)
- Flutter DevTools performance profiling (60fps validation)
- Supabase RLS policy security tests

**Target Platform**: iOS 15+ (Cupertino widgets) and Android 8.0+ (Material Design 3)
**Project Type**: Mobile (Flutter feature-first clean architecture)

**Performance Goals**:
- 60fps sustained UI scroll (zero jank frames >16ms)
- Initial 20 comments load: <1 second on 4G (p95)
- Real-time comment updates: <500ms latency from server to UI (p95)
- Like/unlike perceived response: <200ms (optimistic UI)
- Comment sheet open animation: smooth 300ms slide-up

**Constraints**:
- Offline-capable: cached comments viewable offline, queue writes for sync
- Comment text: min 1 char (trimmed), max 500 chars hard limit
- Threading: max 1 level deep (replies to replies become sibling replies)
- Pagination: 20 comments per page, infinite scroll with virtualized list
- Rate limiting: max 3 identical comments in 5 min, max 100 likes/hr per user
- Auto-hide threshold: 3+ reports from different users triggers moderation queue
- Network resilience: optimistic UI with rollback on server errors
- Platform-native widgets: Cupertino (iOS) + Material (Android) - no generic cross-platform widgets

**Scale/Scope**:
- Users: 810 students at Liceo Galilei Moro (ages 14-19)
- Expected volume: 50+ events/month, avg 10 comments per popular event
- Comment throughput: ~500 comments/day peak during event launches
- Concurrent users: ~100 simultaneous during school hours
- Data retention: soft-deleted comments retained 30 days (GDPR grace period), then hard-deleted

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle 1: STUDENTS_FIRST ✅ PASS

**Evaluation**: Feature directly serves student needs for event coordination and community discussion. Designed specifically for ages 14-19 with Instagram-inspired UX patterns they're familiar with. Comment system enables quick questions/answers about events ("Ci sono ancora posti?"), reducing friction in event participation. Emoji support, real-time updates, and smooth animations match teenage expectations for modern apps.

**Evidence**:
- User stories focus on student workflows (asking questions, sharing info, coordinating)
- Success criteria: 60%+ users comment weekly, 10+ comments per popular event
- UI optimized for speed: optimistic updates (<200ms perceived), instant feedback
- Language: Italian, informal tone ("Sii il primo a commentare!")

### Principle 2: PRIVACY_FOUNDATION ✅ PASS

**Evaluation**: Comments are intentionally public (transparency prevents cyberbullying via private messages). No new data collection beyond comment text (already within constitutional limits). GDPR-compliant soft deletion preserves thread context while respecting Right to Erasure. No third-party tracking or analytics added.

**Evidence**:
- FR-075: Comments soft-deleted on account deletion, display as "[Commento eliminato]"
- FR-076: Hard delete after 30-day grace period (GDPR compliance)
- FR-077: Comments included in GDPR data export (Right to Access)
- No analytics SDKs, no tracking pixels, no data sharing
- Public-only comments (constitutional alignment with anti-surveillance principle)

### Principle 3: SIMPLICITY_FIRST ✅ PASS

**Evaluation**: Feature has clear, focused scope: text-only comments with basic interactions. Deliberately excludes media attachments, GIF reactions, complex formatting to avoid feature bloat. 500-character limit enforces brevity. Threading limited to 1 level prevents complex nested discussions.

**Evidence**:
- Out of scope (spec section): no media, no autocomplete mentions, no bookmark, no complex reactions
- User stories prioritized P1 (MVP) vs P2 (nice-to-have) - edit and sort are P2
- Functional requirements: 77 total but most are variations of core actions (post, reply, like, report, delete)
- Complexity justified: real-time needed for coordination, moderation needed for safety

### Principle 4: PERFORMANCE_FIRST ✅ PASS

**Evaluation**: Explicit performance targets defined and measurable. Optimistic UI prevents perceived lag. Pagination and virtualized scrolling handle scale. Offline support with queue-sync pattern. Performance budget enforced via success criteria.

**Evidence**:
- SC-013: Initial 20 comments load <1s (p95)
- SC-014: Real-time updates <500ms latency (p95)
- SC-015: 60fps sustained scroll (zero jank >16ms)
- SC-016: Like button <200ms perceived (p99)
- FR-071-074: Performance requirements with measurable targets
- Technical constraints: pagination 20/page, virtualized list, optimistic UI

### Principle 5: SPEC_FIRST ✅ PASS

**Evaluation**: Comprehensive spec created before implementation with 13 user stories (8 P1, 5 P2), 77 functional requirements, 22 success criteria. All requirements testable with clear acceptance scenarios. Spec reviewed and approved via quality checklist before planning phase.

**Evidence**:
- Spec file: specs/007-event-comments/spec.md (100% complete, no NEEDS CLARIFICATION markers)
- Quality checklist: specs/007-event-comments/checklists/requirements.md (all items passed)
- User scenarios: Given-When-Then format with independent test descriptions
- Functional requirements: FR-001 to FR-077 with clear pass/fail criteria

### Principle 6: DESIGN_SYSTEM_STRICT ✅ PASS

**Evaluation**: Platform-adaptive UI enforced throughout spec. iOS uses Cupertino widgets (CupertinoTextField, CupertinoButton, CupertinoActionSheet), Android uses Material Design 3 (TextField, IconButton, ModalBottomSheet). No hardcoded colors - references "Nova brand purple", "secondary gray" from design system. No magic numbers for spacing (references 48px indent, 40px avatar, etc. which will map to NovaSpacing constants).

**Evidence**:
- FR-002: Platform-specific bottom sheet (CupertinoModalPopup vs ModalBottomSheet)
- FR-009: Platform-specific input fields (CupertinoTextField vs TextField Material)
- FR-028: Platform-specific gestures (swipe-left iOS vs long-press Android)
- FR-051: Platform-specific refresh controls (CupertinoSliverRefreshControl vs RefreshIndicator)
- FR-060: Platform-specific sort toggle (CupertinoSegmentedControl vs Chip selector)
- Spec avoids hex codes, uses color names ("purple brand", "gray secondary")

### Principle 7: CONTENT_MODERATION ✅ PASS

**Evaluation**: Human moderation mandatory via moderator actions and review queue. Profanity filter (server-side, Italian language) prevents inappropriate content before save. Report system with auto-hide at 3+ reports ensures community flagging. Moderator accountability via action logging. 24-hour SLA for report review (SC-008). NO shadow-banning (FR-037: explicit error messages).

**Evidence**:
- FR-036: Server-side profanity filter with explicit rejection messages
- FR-028-032: Report system with checkboxes (Spam, Inappropriate, Bullying, Off-topic)
- FR-031: Auto-hide at 3+ reports (community moderation)
- FR-033-035: Moderator tools ("Rimuovi commento", "Avvisa utente") with action logging
- SC-007: <1% comments reported (low inappropriate content)
- SC-008: 90%+ reports reviewed in 24h (moderation SLA)
- SC-009: 80%+ auto-hide accuracy (false positive <20%)

### Summary

**GATE STATUS: ✅ PASS**

All 7 constitutional principles satisfied. Feature aligns with Nova's mission of safe, privacy-respecting, student-first event platform. Moderation ensures school-appropriate content (ages 14-19). Performance targets prevent user frustration. Simplicity focus avoids feature bloat. Platform-native UI matches constitutional design system requirements.

**Zero violations requiring justification.**

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

**Flutter Feature-First Clean Architecture** (constitutional requirement)

```text
lib/
├── core/
│   ├── theme/
│   │   └── nova_colors.dart          # Existing - color constants (no changes)
│   └── services/
│       └── notification_service.dart  # Existing - extend for comment notifications
│
├── features/
│   ├── events/
│   │   ├── data/
│   │   │   └── models/
│   │   │       └── event_model.dart   # Existing - add comment_count field
│   │   └── presentation/
│   │       └── widgets/
│           └── event_card.dart        # Existing - add "💬 X commenti" button
│   │
│   └── comments/                      # NEW feature module
│       ├── data/
│       │   ├── datasources/
│       │   │   ├── comments_local_datasource.dart   # Hive cache for offline
│       │   │   └── comments_remote_datasource.dart  # Supabase API calls
│       │   ├── models/
│       │   │   ├── comment_model.dart              # JSON serialization
│       │   │   ├── comment_like_model.dart         # Like tracking
│       │   │   └── comment_report_model.dart       # Report data
│       │   └── repositories/
│       │       └── comments_repository.dart        # Implements domain interface
│       │
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── comment.dart                    # Business entity
│       │   │   ├── comment_like.dart               # Like entity
│       │   │   └── comment_report.dart             # Report entity
│       │   ├── repositories/
│       │   │   └── comments_repository_interface.dart  # Abstract contract
│       │   └── usecases/
│       │       ├── get_comments_for_event.dart     # Fetch with pagination
│       │       ├── post_comment.dart               # Create new comment
│       │       ├── reply_to_comment.dart           # Create threaded reply
│       │       ├── like_comment.dart               # Add like
│       │       ├── unlike_comment.dart             # Remove like
│       │       ├── report_comment.dart             # Submit report
│       │       ├── delete_comment.dart             # Soft delete own comment
│       │       ├── edit_comment.dart               # Edit within 5-min window
│       │       ├── moderator_remove_comment.dart   # Hard delete (mod only)
│       │       └── subscribe_to_realtime.dart      # Supabase Realtime stream
│       │
│       └── presentation/
│           ├── providers/
│           │   ├── comments_notifier.dart          # Riverpod AsyncNotifier
│           │   ├── comment_likes_notifier.dart     # Optimistic like state
│           │   ├── comment_input_notifier.dart     # Input field state
│           │   └── reply_mode_notifier.dart        # Reply mode state
│           ├── screens/
│           │   └── comments_sheet.dart             # Fullscreen bottom sheet
│           └── widgets/
│               ├── comment_card.dart               # Single comment UI
│               ├── comment_input_field.dart        # Sticky bottom input
│               ├── comment_thread.dart             # Indented replies
│               ├── comment_actions_menu.dart       # Long-press/swipe actions
│               ├── report_dialog.dart              # Report reason picker
│               ├── delete_confirmation_dialog.dart # Delete confirmation
│               ├── empty_comments_state.dart       # Zero comments UI
│               ├── comment_sort_toggle.dart        # Recenti/Popolari toggle
│               └── like_button.dart                # Animated heart icon
│
└── shared/
    └── widgets/
        └── adaptive/                  # Existing - reuse for platform detection
            ├── adaptive_bottom_sheet.dart    # Existing - may need comments variant
            ├── adaptive_dialog.dart          # Existing - reuse for confirmations
            └── adaptive_text_field.dart      # Existing - reuse for input
```

**Tests** (feature-specific):

```text
nova/
└── test/
    ├── features/
    │   └── comments/
    │       ├── data/
    │       │   ├── datasources/
    │       │   │   └── comments_remote_datasource_test.dart
    │       │   ├── models/
    │       │   │   └── comment_model_test.dart
    │       │   └── repositories/
    │       │       └── comments_repository_test.dart
    │       ├── domain/
    │       │   └── usecases/
    │       │       ├── post_comment_test.dart
    │       │       ├── like_comment_test.dart
    │       │       └── reply_to_comment_test.dart
    │       └── presentation/
    │           ├── providers/
    │           │   └── comments_notifier_test.dart
    │           └── widgets/
    │               ├── comment_card_test.dart
    │               └── comment_input_field_test.dart
    └── integration/
        └── comments_flow_test.dart    # End-to-end: post → reply → like → delete
```

**Backend** (Supabase):

```text
supabase/
└── migrations/
    └── 007_event_comments_system.sql  # DDL for comments, comment_likes, comment_reports tables
                                       # RLS policies, triggers, indexes, profanity filter function
```

**Structure Decision**: Mobile feature-first clean architecture (Option 3 pattern). Nova is a Flutter app with Supabase backend-as-a-service. New `comments/` feature module follows existing `events/` and `profile/` module patterns. Clean architecture layers: data (datasources, models, repositories) → domain (entities, usecases, interfaces) → presentation (providers, screens, widgets). Riverpod provides dependency injection and state management. Supabase migration file handles all backend schema.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations to justify.** Constitution Check passed with zero complexity concerns.

---

## Phase 0: Research & Technical Decisions

**Status**: ✅ Complete
**Output**: [research.md](research.md)

### Key Technical Decisions

| Area | Decision | Rationale | Trade-offs |
|------|----------|-----------|------------|
| **Real-time** | Supabase Realtime with event-scoped subscriptions, debounced updates | <500ms latency, automatic reconnection, RLS filtering | WebSocket connections count toward Supabase limits (5000 on Pro) |
| **Optimistic UI** | Three-phase updates (local → server → rollback) via Riverpod AsyncNotifier | <200ms perceived response, data integrity preserved | Brief inconsistency during rollback if real-time update arrives |
| **Profanity Filter** | PostgreSQL function with 150-word Italian list, whole-word boundaries | Server-side enforcement, <10ms validation, reduces false positives | Leet speak bypasses filter (manual moderation backstop) |
| **Rate Limiting** | Client 500ms debounce + server PostgreSQL checks (3 dupes/5min, 100 likes/hr) | Prevents spam without complex infrastructure (Redis not needed) | Limits are global per-user, not per-event |
| **Platform UI** | Adaptive widgets (Cupertino/Material) with platform-specific gestures | Authentic iOS/Android feel, constitutional requirement | Increased widget count (~15 adaptive wrappers needed) |
| **Threading** | Flat list rendering, max 1-level deep enforced server-side | 60fps performance (ListView recycling works), simple mental model | Slightly confusing when replying to reply (becomes sibling) |
| **Offline** | Hive cache (15min TTL) + offline queue with sync on reconnect | Read offline, no lost writes, transparent pending state | Stale cache for 15 minutes, potential duplicate comments if queue syncs twice |
| **GDPR** | Soft delete with 30-day grace period, JSON export, CRON hard delete | Balances Right to Erasure with thread structure preservation | Deleted users still visible as "[Commento eliminato]" author |
| **Pagination** | Cursor-based with `created_at`, infinite scroll, 20 per page | O(1) query time, seamless UX | Cannot jump to arbitrary page (accepted - infinite scroll doesn't need it) |
| **Security** | Supabase parameterized queries + Flutter Text widget auto-escape | Secure defaults, zero custom sanitization | Cannot support rich text formatting (accepted per simplicity principle) |

### Research Artifacts

1. **[research.md](research.md)** - Comprehensive technical research covering:
   - Supabase Realtime integration patterns
   - Optimistic UI implementation strategies
   - Italian profanity filtering approaches
   - Rate limiting server-side and client-side
   - Platform-adaptive widget patterns
   - Threading/reply implementation (1-level max)
   - Offline support with Hive cache and queue sync
   - GDPR compliance (soft delete, data export, hard delete)
   - Pagination strategies (cursor-based vs offset-based)
   - Security best practices (SQL injection, XSS prevention)

---

## Phase 1: Data Model & API Contracts

**Status**: ✅ Complete
**Outputs**: [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

### Database Schema Summary

**Tables Created** (via migration `007_event_comments_system.sql`):

1. **`comments`** - Stores comments and replies with soft-delete support
   - Primary key: `id` (UUID)
   - Foreign keys: `event_id`, `user_id`, `parent_comment_id` (self-referencing)
   - Denormalized counters: `like_count`, `reply_count`, `report_count`
   - Soft delete: `deleted_at`, `deleted_by_user_id`
   - Moderation: `hidden_at`, `hidden_reason`, `moderator_id`
   - Audit: `created_at`, `updated_at`

2. **`comment_likes`** - Many-to-many relationship between users and comments
   - Composite primary key: `(comment_id, user_id)` prevents duplicate likes
   - Soft delete: `deleted_at` (preserves like_count accuracy for GDPR)

3. **`comment_reports`** - User-submitted reports for inappropriate content
   - Primary key: `id` (UUID)
   - Foreign keys: `comment_id`, `reporter_user_id`
   - Report workflow: `status` (pending/reviewed/dismissed), `reviewed_by_moderator_id`, `reviewed_at`
   - Unique constraint: `(comment_id, reporter_user_id)` prevents duplicate reports

**Indexes** (11 total):
- `idx_comments_event_top_level` - Top-level comments for event (cursor pagination)
- `idx_comments_parent_replies` - Replies for parent comment (threading)
- `idx_comments_user` - User's comment history
- `idx_comments_moderation_queue` - Hidden comments for moderators
- `idx_comments_text_search` - Full-text search (future enhancement)
- `idx_comments_pending_hard_delete` - Soft-deleted comments for CRON cleanup
- `idx_comment_likes_user` - User's like history
- `idx_comment_likes_rate_limit` - Recent likes for rate limiting
- `idx_comment_likes_pending_hard_delete` - Soft-deleted likes for CRON cleanup
- `idx_comment_reports_pending` - Pending reports for moderation queue
- `idx_comment_reports_comment` - Reports for specific comment

**Triggers** (9 total):
- Profanity filter: `check_profanity_on_insert`, `check_profanity_on_update`
- Rate limiting: `prevent_comment_spam`, `prevent_like_spam`
- Denormalized counters: `sync_comment_like_count`, `sync_comment_reply_count`, `sync_comment_report_count`, `sync_event_comment_count`
- Auto-hide: Embedded in `update_comment_report_count` (hides comment at 3+ reports)

**Row-Level Security Policies** (13 total):
- Comments: 6 policies (students view/insert/edit/delete, moderators view all/remove)
- Likes: 3 policies (view/insert/delete)
- Reports: 4 policies (users view own/submit, moderators view all/review)

### Domain Entities

**Flutter Domain Layer**:

1. **`Comment`** - Business entity with computed properties
   - Fields: id, eventId, userId, parentCommentId, text, counters, timestamps
   - Computed: `isDeleted`, `isHidden`, `isReply`, `isEdited`, `canEdit`, `displayText`, `relativeTimestamp`
   - Related: `author` (UserProfile), `isLikedByCurrentUser` (bool), `replies` (List<Comment>?)

2. **`CommentLike`** - Simple like entity
   - Fields: commentId, userId, createdAt

3. **`CommentReport`** - Report entity with enums
   - Fields: id, commentId, reporterUserId, reason (enum), details, status (enum), moderation fields
   - Enums: `CommentReportReason` (spam, inappropriate, bullying, off_topic), `CommentReportStatus` (pending, reviewed, dismissed)

### API Contracts

**Repository Interface** ([contracts/comments_repository_interface.md](contracts/comments_repository_interface.md)):

**Query Operations** (4 methods):
- `getCommentsForEvent` - Paginated top-level comments with sorting
- `getRepliesForComment` - All replies for parent comment
- `getCommentById` - Single comment fetch (for real-time updates)
- `getUserComments` - User's comment history (profile view)

**Mutation Operations** (5 methods):
- `postComment` - Create top-level comment
- `replyToComment` - Create reply (1-level threading enforced)
- `editComment` - Edit own comment (5-min window)
- `deleteComment` - Soft delete own comment

**Like Operations** (2 methods):
- `likeComment` - Add like (idempotent)
- `unlikeComment` - Remove like (idempotent)

**Report Operations** (1 method):
- `reportComment` - Submit inappropriate content report

**Moderation Operations** (2 methods, moderator-only):
- `moderatorRemoveComment` - Hard hide comment
- `moderatorRestoreComment` - Restore auto-hidden comment

**Real-Time Operations** (1 method):
- `subscribeToComments` - WebSocket stream of updates

**Offline Operations** (4 methods):
- `getCachedComments` - Fetch from Hive cache
- `cacheComments` - Store in Hive cache
- `queueOfflineAction` - Queue action for sync
- `syncOfflineQueue` - Sync queued actions

**Exception Hierarchy** (8 custom exceptions):
- `NetworkException`, `UnauthorizedException`, `ForbiddenException`
- `ValidationException`, `RateLimitException`
- `NotFoundException`, `ConflictException`
- `ServerException`, `CacheException`

**Supabase API Spec** ([contracts/supabase_api_spec.md](contracts/supabase_api_spec.md)):

**Concrete Supabase Client Calls** (11 operations):
1. Fetch top-level comments (SELECT with join on profiles)
2. Fetch replies (SELECT with parent_comment_id filter)
3. Check if user liked comment (SELECT from comment_likes)
4. Post new comment (INSERT with profanity/rate limit triggers)
5. Like comment (INSERT with idempotency handling)
6. Unlike comment (DELETE)
7. Edit comment (UPDATE with 5-min window check)
8. Soft delete comment (UPDATE text → "[Commento eliminato]")
9. Report comment (INSERT with auto-hide trigger)
10. Moderator remove comment (UPDATE hidden fields)
11. Moderator restore comment (UPDATE hidden_at → NULL)

**Real-Time Subscription**:
- WebSocket stream via Supabase Realtime
- Event types: INSERT, UPDATE, DELETE
- Payload includes full comment JSON

**Error Handling**:
- Error code mapping: PostgreSQL codes → Domain exceptions
- Rate limit detection: Parse P0001 custom exception messages
- Idempotent operations: Ignore 23505 unique constraint violations

### Integration & Testing

**Quickstart Guide** ([quickstart.md](quickstart.md)):

**5 Integration Scenarios**:
1. **View and Post Comments** - Open sheet, load comments, post new comment
2. **Like and Unlike** - Optimistic UI with animation, server sync, rollback on error
3. **Reply Threading** - Reply mode, indented rendering, 1-level enforcement
4. **Report Inappropriate** - Report dialog, auto-hide at 3+ reports, moderation queue
5. **Real-Time Updates** - WebSocket subscription, instant updates <500ms

**Testing Checklist**:
- Unit tests: 6 model tests, 6 repository tests
- Widget tests: 5 component tests
- Integration tests: 7 end-to-end flows
- Performance tests: 4 metrics (load time, scroll fps, perceived response, real-time latency)

---

## Next Steps

**Status**: ✅ Planning Complete - Ready for Task Generation

The planning phase is now complete with all artifacts generated:

- ✅ **plan.md** - This file (summary, technical context, constitution check, project structure)
- ✅ **research.md** - Technical decisions and rationale for 10 key areas
- ✅ **data-model.md** - Complete database schema, entities, RLS policies, triggers
- ✅ **contracts/** - Repository interface and Supabase API specifications
- ✅ **quickstart.md** - Integration scenarios and testing guides

**To proceed with implementation, run**:

```
/speckit.tasks
```

This will generate `tasks.md` with dependency-ordered implementation tasks organized by user story priority (P1 → P2).
