# Implementation Plan: Global Chat

**Branch**: `011-global-chat` | **Date**: 2025-11-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/011-global-chat/spec.md`

---

## Summary

Implement a school-wide real-time chat system for Liceo Galilei Moro students with ephemeral messaging (24-hour auto-delete), @mentions with notifications, emoji reactions, reply threading, typing indicators, and view-once media with screenshot protection.

**Technical Approach** (from [research.md](./research.md)):
- **Real-time**: Supabase Realtime with hybrid channel strategy (Postgres Changes + Presence + Broadcast)
- **Auto-delete**: pg_cron hourly job for 24-hour message cleanup
- **Screenshot protection**: FLAG_SECURE (Android) + detection with sender notification (iOS)
- **Rate limiting**: Database trigger with sliding window (10 msg/min)
- **Offline support**: Hive box for message queue with exponential backoff retry

---

## Technical Context

**Language/Version**: Dart 3.x (Flutter SDK 3.x+)
**Primary Dependencies**:
- `supabase_flutter: ^2.x` - Backend, auth, realtime, storage
- `flutter_riverpod: ^2.x` - State management
- `hive_flutter: ^1.x` - Offline queue
- `flutter_image_compress: ^2.x` - Image compression
- `video_compress: ^3.1.2` - Video compression (P3)
- `flutter_windowmanager: ^0.2.0` - Screenshot protection Android (P3)
- `screenshot_callback: ^3.0.2` - Screenshot detection iOS (P3)

**Storage**: PostgreSQL 15+ (Supabase Cloud), Supabase Storage (ephemeral-media bucket)
**Testing**: Flutter Test, Integration Tests
**Target Platform**: Android 6.0+ (API 23), iOS 13+
**Project Type**: Mobile (Flutter cross-platform)

**Performance Goals**:
- Message delivery: <1 second (real-time)
- UI response: <200ms (optimistic updates)
- Typing indicator: <500ms latency
- Feed rendering: 60fps sustained

**Constraints**:
- Max 500 characters per message
- Max 10 messages per minute per user
- Max 5 view-once media per day per user
- Max 10MB per media file
- 24-hour message retention (GDPR)

**Scale/Scope**:
- ~500 concurrent users
- ~50,000 messages/day estimated
- Single global chat room (no channels)

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Status |
|-----------|-------------|--------|
| 1. STUDENTS_FIRST | Age 14-19 appropriate | ✅ Modern UI, emoji reactions, view-once media |
| 2. PRIVACY_FOUNDATION | 24h auto-delete, no DMs | ✅ pg_cron job, single global room only |
| 3. SIMPLICITY_FIRST | Minimal viable feature | ✅ Core messaging + incremental P2/P3 features |
| 4. PERFORMANCE_FIRST | <1s load, 60fps | ✅ Supabase Realtime, optimistic UI |
| 5. SPEC_FIRST | Written spec before code | ✅ spec.md complete |
| 6. DESIGN_SYSTEM_STRICT | NovaColors, NovaSpacing | ✅ All UI from design system |
| 7. CONTENT_MODERATION | Report button, auto-hide | ✅ FR-012 to FR-016, 3 reports = hide |

**Anti-Goals Verification**:
- [x] Not a social network (no followers, no DMs)
- [x] No advertisements
- [x] No data selling
- [x] No addictive patterns (24h deletion discourages hoarding)
- [x] Not surveillance tool (no read receipts)

---

## Project Structure

### Documentation (this feature)

```text
specs/011-global-chat/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file
├── research.md          # Technical research & decisions (completed)
├── data-model.md        # PostgreSQL schema, RLS, triggers (completed)
├── quickstart.md        # Integration scenarios (completed)
├── contracts/           # API contracts
│   ├── supabase-api.yaml           # REST API spec
│   ├── realtime-subscriptions.md   # Realtime channels spec
│   └── storage-ephemeral-media.yaml # Storage bucket spec
├── checklists/
│   └── requirements.md  # Quality checklist (completed)
└── tasks.md             # Implementation tasks (to be generated)
```

### Source Code (repository root)

```text
nova/lib/
├── core/
│   └── theme/                    # Design system (existing)
│
├── features/
│   └── chat/                     # NEW: Global Chat feature
│       ├── data/
│       │   ├── datasources/
│       │   │   └── chat_remote_datasource.dart
│       │   ├── models/
│       │   │   ├── chat_message_model.dart
│       │   │   ├── chat_reaction_model.dart
│       │   │   ├── chat_report_model.dart
│       │   │   └── chat_media_model.dart
│       │   └── repositories/
│       │       └── chat_repository_impl.dart
│       │
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── chat_message.dart
│       │   │   ├── chat_reaction.dart
│       │   │   ├── chat_report.dart
│       │   │   └── chat_media.dart
│       │   └── repositories/
│       │       └── chat_repository.dart
│       │
│       └── presentation/
│           ├── providers/
│           │   ├── chat_providers.dart
│           │   ├── chat_realtime_provider.dart
│           │   └── typing_indicator_provider.dart
│           ├── screens/
│           │   ├── chat_screen.dart
│           │   └── media_viewer_screen.dart
│           └── widgets/
│               ├── chat_message_list.dart
│               ├── chat_message_tile.dart
│               ├── chat_compose_bar.dart
│               ├── chat_reply_preview.dart
│               ├── chat_reaction_picker.dart
│               ├── chat_reaction_row.dart
│               ├── chat_typing_indicator.dart
│               ├── mention_autocomplete.dart
│               └── view_once_badge.dart
│
└── shared/
    └── widgets/
        └── glass_container.dart  # Existing

nova/test/
├── features/
│   └── chat/
│       ├── data/
│       │   └── chat_repository_test.dart
│       ├── domain/
│       │   └── chat_message_test.dart
│       └── presentation/
│           ├── chat_screen_test.dart
│           └── widgets/
│               └── chat_message_tile_test.dart
└── integration/
    └── chat_flow_test.dart

supabase/
├── migrations/
│   └── 011_global_chat_system.sql  # NEW: Database schema
└── functions/
    └── cleanup-viewed-media/        # NEW: Edge function (P3)
        └── index.ts
```

**Structure Decision**: Feature-first clean architecture following existing patterns from `events`, `comments`, and `notifications` features. Chat is a self-contained module with data/domain/presentation layers.

---

## Implementation Phases

### Phase 1: Foundation (P1 - MVP Core)

**Database & Backend**:
- [ ] Create `011_global_chat_system.sql` migration
- [ ] Setup `chat_messages`, `chat_reactions`, `chat_reports` tables
- [ ] Configure RLS policies
- [ ] Create triggers (rate limit, profanity, counters, auto-hide)
- [ ] Schedule pg_cron job for 24h deletion

**Data Layer**:
- [ ] Create domain entities (ChatMessage, ChatReaction, ChatReport)
- [ ] Create data models with JSON serialization
- [ ] Implement ChatRemoteDataSource
- [ ] Implement ChatRepositoryImpl

**Presentation Layer**:
- [ ] Create ChatScreen with message list
- [ ] Create ChatMessageTile widget
- [ ] Create ChatComposeBar widget
- [ ] Setup Riverpod providers for state
- [ ] Integrate Supabase Realtime

### Phase 2: Engagement Features (P2)

**@Mentions**:
- [ ] Implement MentionAutocomplete widget
- [ ] Add mention parsing logic
- [ ] Create mention notification trigger
- [ ] Highlight mentions in message display

**Reply/Quote**:
- [ ] Add swipe-to-reply gesture
- [ ] Create ChatReplyPreview widget
- [ ] Implement reply_to_id linking
- [ ] Handle deleted reply references

**Emoji Reactions**:
- [ ] Create ChatReactionPicker widget
- [ ] Create ChatReactionRow widget
- [ ] Implement reaction broadcast channel
- [ ] Add toggle reaction logic

### Phase 3: Advanced Features (P3)

**Typing Indicators**:
- [ ] Setup Presence channel
- [ ] Create TypingIndicatorProvider
- [ ] Create ChatTypingIndicator widget
- [ ] Implement debouncing logic

**View-Once Media**:
- [ ] Create `ephemeral-media` storage bucket
- [ ] Implement media compression
- [ ] Create MediaViewerScreen with screenshot protection
- [ ] Add screenshot detection (iOS)
- [ ] Create cleanup Edge Function

---

## Dependencies Between Phases

```
Phase 1 (P1) ───────────────────────────────────────►
    │
    ├── Database schema (required for all)
    ├── Domain entities (required for data layer)
    ├── Repository (required for UI)
    └── Basic UI (required for testing)

Phase 2 (P2) ───────────────────────────────────────►
    │   (Can run in parallel after Phase 1 complete)
    │
    ├── Mentions (independent)
    ├── Reactions (independent)
    └── Replies (independent)

Phase 3 (P3) ───────────────────────────────────────►
    │   (Can run in parallel after Phase 1 complete)
    │
    ├── Typing indicators (independent)
    └── View-once media (depends on storage bucket)
```

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| iOS screenshot protection incomplete | High | Medium | Document as best-effort, notify sender on detection |
| High message volume causes lag | Medium | High | Implement message batching, cursor pagination |
| Supabase free tier limits | Low | High | Monitor usage, upgrade plan if needed |
| pg_cron not available | Low | High | Fallback to Supabase Edge Function scheduled |
| View-once media storage costs | Medium | Medium | Limit 5/day/user, aggressive compression |

---

## Success Criteria Alignment

From spec.md:

| Criteria | How Verified |
|----------|--------------|
| SC-001: <1s message delivery | Stopwatch test across devices |
| SC-002: 100% 24h deletion | Query for messages >24h old (should be 0) |
| SC-003: <200ms perceived response | Optimistic UI implementation |
| SC-004: Moderation <24h | Moderation queue dashboard metric |
| SC-005: 500 concurrent users | Load testing (future) |
| SC-006: <5s send flow | Manual timing test |
| SC-007: View-once enforcement | Tap viewed media, verify blocked |
| SC-008: Android screenshot blocked | Attempt screenshot, verify black |
| SC-009: iOS screenshot notified | Take screenshot, verify notification |

---

## Complexity Tracking

No constitution violations. All complexity is justified by spec requirements.

| Complexity | Justification |
|------------|---------------|
| 4 database tables | Required for messages, reactions, reports, media (P3) |
| 3 realtime channels | Messages (Postgres), Typing (Presence), Reactions (Broadcast) |
| Screenshot protection | Explicit user requirement for view-once media privacy |
| pg_cron job | GDPR 24h deletion requirement, no simpler alternative |

---

**Status**: Plan Complete
**Next Step**: Run `/speckit.tasks` to generate tasks.md
