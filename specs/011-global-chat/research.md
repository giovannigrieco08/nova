# Technical Research: Global Chat

**Feature**: 011-global-chat
**Date**: 2025-11-30
**Status**: Complete

---

## Research Summary

This document consolidates technical research and decisions for the Global Chat feature implementation.

---

## 1. Real-Time Messaging Architecture

### Decision: Supabase Realtime with Hybrid Channel Strategy

**Rationale**: Supabase Realtime is mandated by constitution (Technical Constraints). We use a hybrid approach:
- **Postgres Changes** for message persistence and delivery (INSERT triggers broadcast)
- **Presence Channel** for typing indicators (ephemeral state, no database)
- **Broadcast Channel** for reactions (low-latency updates)

**Alternatives Considered**:
- Firebase Realtime Database: Rejected (constitution mandates Supabase)
- Socket.io custom server: Rejected (adds infrastructure complexity, violates Supabase-only backend rule)
- Polling: Rejected (fails <100ms latency requirement)

**Implementation Pattern**:
```dart
// Message subscription pattern (from 008-realtime-notifications)
final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  return supabase
    .from('chat_messages')
    .stream(primaryKey: ['id'])
    .order('created_at', ascending: false)
    .map((data) => data.map((json) => ChatMessage.fromJson(json)).toList());
});
```

---

## 2. Screenshot Protection for View-Once Media

### Decision: Platform-Specific Implementation with Best-Effort Guarantee

**Android Solution**: `FLAG_SECURE` via `flutter_windowmanager`
- Blocks screenshots, screen recording, and screen mirroring
- 100% effective on non-rooted devices
- Package: `flutter_windowmanager: ^0.2.0`

**iOS Solution**: Detection + Notification (WhatsApp-style)
- Cannot prevent screenshots due to iOS limitations
- Detect via `UIApplication.userDidTakeScreenshotNotification`
- Notify sender immediately when screenshot detected
- Package: `screenshot_callback: ^3.0.2` or platform channel

**Rationale**: WhatsApp uses similar approach (screenshot detection on iOS, prevention on Android). This is industry standard for ephemeral media.

**Alternatives Considered**:
- DRM-based protection: Rejected (requires enterprise licensing, overkill for school app)
- Secure enclave rendering: Rejected (iOS-only, complex implementation)
- No protection: Rejected (user expectation from spec requires protection)

**User Communication**:
- Show disclaimer: "La protezione screenshot e best-effort. Su iOS, il mittente verra notificato se fai screenshot."
- Design decision: Users accept this limitation when sending view-once media

---

## 3. 24-Hour Message Auto-Deletion

### Decision: pg_cron Job with Hourly Execution

**Rationale**: pg_cron runs inside PostgreSQL (zero network latency), is reliable, and handles cascade deletion automatically.

**Implementation**:
```sql
-- Scheduled deletion job
SELECT cron.schedule(
  'chat-auto-delete-24h',
  '0 * * * *',  -- Every hour at minute 0
  $$DELETE FROM chat_messages WHERE created_at < NOW() - INTERVAL '24 hours'$$
);
```

**Alternatives Considered**:
- Supabase Edge Function (scheduled): More complex, network overhead
- Client-side filtering only: Rejected (data still in DB, privacy violation)
- TTL column with database trigger: More complex, same outcome

**Cascade Behavior**:
- `chat_reactions` → ON DELETE CASCADE
- `chat_reports` → ON DELETE CASCADE
- `chat_media` → ON DELETE CASCADE + Storage cleanup via trigger

---

## 4. @Mention Autocomplete

### Decision: Trigram Index with ILIKE Search

**Rationale**: PostgreSQL pg_trgm extension provides fast fuzzy search for usernames. Already used in existing features.

**Implementation**:
```sql
-- Enable extension
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create index for fast autocomplete
CREATE INDEX idx_profiles_username_trgm ON profiles
  USING gin(LOWER(full_name) gin_trgm_ops);

-- Autocomplete query
SELECT user_id, full_name, avatar_url, class
FROM profiles
WHERE LOWER(full_name) LIKE '%' || LOWER($search) || '%'
ORDER BY
  CASE WHEN LOWER(full_name) LIKE LOWER($search) || '%' THEN 0 ELSE 1 END,
  full_name
LIMIT 5;
```

**Alternatives Considered**:
- Full-text search (tsvector): Overkill for name search
- Exact prefix match only: Poor UX for typos
- Client-side filtering: Doesn't scale with user count

---

## 5. Typing Indicator Implementation

### Decision: Supabase Presence Channel with Debouncing

**Rationale**: Presence channels are designed for ephemeral presence state. No database storage needed.

**Implementation Pattern**:
```dart
class TypingIndicatorService {
  late RealtimeChannel _presenceChannel;

  void initialize(SupabaseClient supabase) {
    _presenceChannel = supabase.channel('global-chat:presence');
    _presenceChannel
      .onPresenceSync((payload) {
        final presences = _presenceChannel.presenceState();
        // Filter to typing users, update UI
      })
      .subscribe();
  }

  void startTyping() {
    _presenceChannel.track({'user_id': userId, 'name': name, 'is_typing': true});
    // Auto-stop after 3 seconds
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 3), stopTyping);
  }
}
```

**Debouncing Strategy**:
- Start typing event: Immediate
- Stop typing: 3 seconds after last keystroke
- Max displayed: 3 names ("Mario, Giulia e altri 2 stanno scrivendo...")

---

## 6. Rate Limiting Strategy

### Decision: Database Trigger with Sliding Window

**Rationale**: Server-side enforcement prevents circumvention. Sliding window is fairer than fixed buckets.

**Implementation**:
```sql
CREATE OR REPLACE FUNCTION check_chat_rate_limit()
RETURNS TRIGGER AS $$
DECLARE recent_count INT;
BEGIN
  SELECT COUNT(*) INTO recent_count
  FROM chat_messages
  WHERE user_id = NEW.user_id
    AND created_at > NOW() - INTERVAL '1 minute';

  IF recent_count >= 10 THEN
    RAISE EXCEPTION 'Rate limit exceeded: max 10 messages per minute'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Client-Side UX**:
- Show countdown timer when rate limited
- Queue messages locally if user keeps typing
- Italian message: "Troppi messaggi. Attendi X secondi."

---

## 7. Media Compression Strategy

### Decision: Client-Side Compression Before Upload

**Rationale**: Reduces bandwidth, speeds up upload, saves storage costs.

**Image Compression** (existing pattern from avatar upload):
```dart
// Use flutter_image_compress (already in pubspec)
final compressedImage = await FlutterImageCompress.compressWithFile(
  file.path,
  minWidth: 1280,
  minHeight: 1280,
  quality: 80,
  format: CompressFormat.webp,
);
```

**Video Compression**:
- Package: `video_compress: ^3.1.2`
- Max duration: 30 seconds (validated before compression)
- Target quality: MediumQuality (720p)
- Max file size: 10MB after compression

**Storage Bucket**: `ephemeral-media` (private, signed URLs required)

---

## 8. Offline Message Queue

### Decision: Hive Box with Retry Logic

**Rationale**: Follows existing pattern from events offline queue. Hive is already in pubspec.

**Implementation**:
```dart
@HiveType(typeId: 10)
class PendingChatMessage {
  @HiveField(0) final String localId;
  @HiveField(1) final String content;
  @HiveField(2) final String? replyToId;
  @HiveField(3) final List<String> mentions;
  @HiveField(4) final DateTime queuedAt;
  @HiveField(5) final int retryCount;
}
```

**Retry Strategy**:
- Exponential backoff: 1s, 2s, 4s
- Max retries: 3
- After 3 failures: Mark as failed, notify user

---

## 9. Reaction Storage Strategy

### Decision: Separate Table with Denormalized Count

**Rationale**: Allows per-user reaction tracking (GDPR deletion), efficient queries, real-time updates.

**Trade-off Analysis**:
| Approach | Pros | Cons |
|----------|------|------|
| Separate table (chosen) | FK constraints, GDPR deletion, individual tracking | Extra JOIN for display |
| JSONB on message | Single query | No FK, complex GDPR, write contention |

**Denormalization**:
- `reaction_count` on `chat_messages` for fast display
- Updated via trigger on INSERT/DELETE to `chat_reactions`

---

## 10. Flutter Package Decisions

### New Dependencies Required

| Package | Version | Purpose | License |
|---------|---------|---------|---------|
| `flutter_windowmanager` | ^0.2.0 | Screenshot protection (Android) | MIT |
| `screenshot_callback` | ^3.0.2 | Screenshot detection (iOS) | MIT |
| `video_compress` | ^3.1.2 | Video compression for view-once | MIT |
| `video_player` | ^2.8.0 | Video playback for view-once | BSD-3 |

### Existing Dependencies Used
- `flutter_image_compress` - Image compression (already in pubspec)
- `hive` / `hive_flutter` - Offline queue (already in pubspec)
- `supabase_flutter` - Backend (already in pubspec)
- `flutter_riverpod` - State management (already in pubspec)
- `timeago` - Relative timestamps (already in pubspec)
- `flutter_slidable` - Swipe actions (already in pubspec)

---

## 11. Constitution Alignment Verification

| Principle | Requirement | How Chat Complies |
|-----------|-------------|-------------------|
| STUDENTS_FIRST | Age 14-19 design | Modern UI, emoji reactions, ephemeral media |
| PRIVACY_FOUNDATION | 24h auto-delete, no private DMs | pg_cron deletion, single global room only |
| SIMPLICITY_FIRST | MVP with 5 features | Chat is 1 of 5 core features |
| PERFORMANCE_FIRST | <1s load, <100ms realtime | Supabase Realtime, optimistic UI |
| SPEC_FIRST | Written spec before code | This research + spec.md complete |
| DESIGN_SYSTEM_STRICT | NovaColors, NovaSpacing | All UI from design system |
| CONTENT_MODERATION | Report button, auto-hide | FR-012 to FR-016, 3 reports = hide |

---

## Research Conclusion

All technical decisions align with:
- Nova constitution (v1.1.0)
- Existing codebase patterns (events, comments, notifications)
- Flutter/Supabase best practices
- GDPR requirements for minors

**No blockers identified. Ready for Phase 1 (data model and contracts).**
