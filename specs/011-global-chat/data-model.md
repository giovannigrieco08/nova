# Data Model: Global Chat System

**Feature**: Global Chat
**Branch**: `011-global-chat`
**Created**: 2025-11-30
**Phase**: Phase 1 (Data Model & Schema Design)

## Overview

This document defines the complete data model for the Global Chat system, including PostgreSQL schema, Row-Level Security (RLS) policies, indexes, triggers, pg_cron jobs for 24-hour auto-deletion, and domain entities for Flutter.

---

## Database Schema (PostgreSQL)

### 1. `chat_messages` Table

Stores all messages in the global chat. Messages are ephemeral (24-hour auto-delete).

```sql
CREATE TABLE chat_messages (
  -- Identity
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relationships
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  reply_to_id UUID REFERENCES chat_messages(id) ON DELETE SET NULL,

  -- Content
  content TEXT NOT NULL CHECK (char_length(trim(content)) BETWEEN 1 AND 500),
  mentions JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of {user_id, username}

  -- Denormalized counters (for performance)
  reaction_count INT NOT NULL DEFAULT 0 CHECK (reaction_count >= 0),
  reply_count INT NOT NULL DEFAULT 0 CHECK (reply_count >= 0),
  report_count INT NOT NULL DEFAULT 0 CHECK (report_count >= 0),

  -- Moderation
  hidden_at TIMESTAMPTZ, -- Auto-hidden at 3+ reports
  hidden_reason TEXT, -- "auto_hide_reports" or "moderator_removed"
  moderator_id UUID REFERENCES profiles(user_id),

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT replies_one_level_only
    CHECK (
      reply_to_id IS NULL OR
      reply_to_id IN (
        SELECT id FROM chat_messages WHERE reply_to_id IS NULL
      )
    ), -- Enforce max 1-level threading

  CONSTRAINT mentions_is_array
    CHECK (jsonb_typeof(mentions) = 'array')
);

-- Indexes for performance
CREATE INDEX idx_chat_messages_feed
  ON chat_messages(created_at DESC)
  WHERE hidden_at IS NULL;

CREATE INDEX idx_chat_messages_user
  ON chat_messages(user_id, created_at DESC);

CREATE INDEX idx_chat_messages_replies
  ON chat_messages(reply_to_id, created_at ASC)
  WHERE reply_to_id IS NOT NULL;

CREATE INDEX idx_chat_messages_moderation_queue
  ON chat_messages(created_at DESC)
  WHERE hidden_at IS NOT NULL;

-- Index for 24-hour deletion job
CREATE INDEX idx_chat_messages_auto_delete
  ON chat_messages(created_at)
  WHERE created_at < NOW() - INTERVAL '24 hours';

-- Trigram index for @mention autocomplete
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_profiles_fullname_trgm
  ON profiles USING gin(LOWER(full_name) gin_trgm_ops);
```

---

### 2. `chat_reactions` Table

Stores emoji reactions to messages. Limited to 6 emoji types.

```sql
CREATE TABLE chat_reactions (
  -- Composite primary key (one reaction type per user per message)
  message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  emoji VARCHAR(10) NOT NULL,

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (message_id, user_id, emoji),

  -- Allowed emoji whitelist
  CONSTRAINT valid_emoji CHECK (
    emoji IN ('❤️', '👍', '😂', '😮', '😢', '🔥')
  )
);

-- Indexes
CREATE INDEX idx_chat_reactions_message
  ON chat_reactions(message_id);

CREATE INDEX idx_chat_reactions_user
  ON chat_reactions(user_id, created_at DESC);
```

---

### 3. `chat_reports` Table

Stores user-submitted reports for inappropriate messages.

```sql
CREATE TABLE chat_reports (
  -- Identity
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relationships
  message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
  reporter_user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,

  -- Report details
  reason TEXT NOT NULL CHECK (reason IN ('spam', 'inappropriate', 'bullying', 'off_topic')),

  -- Moderation workflow
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
  reviewed_by_moderator_id UUID REFERENCES profiles(user_id),
  reviewed_at TIMESTAMPTZ,
  moderator_notes TEXT,

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Prevent duplicate reports from same user
  CONSTRAINT unique_user_report_per_chat_message UNIQUE (message_id, reporter_user_id)
);

-- Indexes
CREATE INDEX idx_chat_reports_pending
  ON chat_reports(created_at DESC)
  WHERE status = 'pending';

CREATE INDEX idx_chat_reports_message
  ON chat_reports(message_id, created_at DESC);
```

---

### 4. `chat_media` Table (P3 - View-Once Media)

Stores metadata for view-once ephemeral media. Actual files in Supabase Storage.

```sql
CREATE TABLE chat_media (
  -- Identity
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relationships
  message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
  uploader_user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,

  -- Storage
  storage_path TEXT NOT NULL, -- Path in 'ephemeral-media' bucket
  media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
  file_size_bytes INT NOT NULL CHECK (file_size_bytes > 0 AND file_size_bytes <= 10485760), -- Max 10MB

  -- View-once state
  is_viewed BOOLEAN NOT NULL DEFAULT FALSE,
  viewed_at TIMESTAMPTZ,
  viewed_by_user_id UUID REFERENCES profiles(user_id),

  -- Screenshot detection (iOS)
  screenshot_detected_at TIMESTAMPTZ,
  screenshot_notified BOOLEAN NOT NULL DEFAULT FALSE,

  -- Expiration (24h from creation)
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Only one media per message
  CONSTRAINT one_media_per_message UNIQUE (message_id)
);

-- Indexes
CREATE INDEX idx_chat_media_pending_view
  ON chat_media(message_id)
  WHERE is_viewed = FALSE;

CREATE INDEX idx_chat_media_expired
  ON chat_media(expires_at)
  WHERE is_viewed = FALSE;

CREATE INDEX idx_chat_media_uploader
  ON chat_media(uploader_user_id, created_at DESC);
```

---

## Row-Level Security (RLS) Policies

### `chat_messages` Table RLS

```sql
-- Enable RLS
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Policy 1: Authenticated users can view non-hidden messages
CREATE POLICY "Users view chat messages"
  ON chat_messages FOR SELECT
  TO authenticated
  USING (
    hidden_at IS NULL
  );

-- Policy 2: Moderators can view all messages (including hidden)
CREATE POLICY "Moderators view all chat messages"
  ON chat_messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  );

-- Policy 3: Users can insert messages (profanity + rate limit via trigger)
CREATE POLICY "Users insert chat messages"
  ON chat_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND hidden_at IS NULL
  );

-- Policy 4: Users cannot update or delete messages (immutable)
-- No UPDATE or DELETE policies for regular users

-- Policy 5: Moderators can hide messages
CREATE POLICY "Moderators hide chat messages"
  ON chat_messages FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  );
```

---

### `chat_reactions` Table RLS

```sql
-- Enable RLS
ALTER TABLE chat_reactions ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view reactions on visible messages
CREATE POLICY "Users view chat reactions"
  ON chat_reactions FOR SELECT
  TO authenticated
  USING (
    message_id IN (
      SELECT id FROM chat_messages WHERE hidden_at IS NULL
    )
  );

-- Policy 2: Users can add reactions
CREATE POLICY "Users add chat reactions"
  ON chat_reactions FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
  );

-- Policy 3: Users can remove their own reactions
CREATE POLICY "Users remove own chat reactions"
  ON chat_reactions FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
```

---

### `chat_reports` Table RLS

```sql
-- Enable RLS
ALTER TABLE chat_reports ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view own reports
CREATE POLICY "Users view own chat reports"
  ON chat_reports FOR SELECT
  TO authenticated
  USING (auth.uid() = reporter_user_id);

-- Policy 2: Moderators can view all reports
CREATE POLICY "Moderators view all chat reports"
  ON chat_reports FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  );

-- Policy 3: Users can submit reports (one per message)
CREATE POLICY "Users submit chat reports"
  ON chat_reports FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = reporter_user_id
    AND status = 'pending'
  );

-- Policy 4: Moderators can update report status
CREATE POLICY "Moderators review chat reports"
  ON chat_reports FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  );
```

---

### `chat_media` Table RLS

```sql
-- Enable RLS
ALTER TABLE chat_media ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view media metadata for visible messages
CREATE POLICY "Users view chat media metadata"
  ON chat_media FOR SELECT
  TO authenticated
  USING (
    message_id IN (
      SELECT id FROM chat_messages WHERE hidden_at IS NULL
    )
  );

-- Policy 2: Users can insert media (uploader only)
CREATE POLICY "Users insert chat media"
  ON chat_media FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = uploader_user_id
  );

-- Policy 3: Any user can mark media as viewed (UPDATE for is_viewed)
CREATE POLICY "Users mark media viewed"
  ON chat_media FOR UPDATE
  TO authenticated
  USING (
    is_viewed = FALSE
    AND auth.uid() != uploader_user_id -- Can't view own media
  )
  WITH CHECK (
    is_viewed = TRUE
    AND viewed_by_user_id = auth.uid()
  );
```

---

## Database Functions & Triggers

### 1. Rate Limiting Function (10 messages/minute)

```sql
CREATE OR REPLACE FUNCTION check_chat_rate_limit()
RETURNS TRIGGER AS $$
DECLARE
  recent_count INT;
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

CREATE TRIGGER check_chat_rate_limit_trigger
  BEFORE INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION check_chat_rate_limit();
```

---

### 2. Profanity Check Trigger

```sql
CREATE OR REPLACE FUNCTION validate_chat_profanity()
RETURNS TRIGGER AS $$
BEGIN
  IF contains_profanity(NEW.content) THEN
    RAISE EXCEPTION 'Message contains inappropriate language'
      USING ERRCODE = 'P0002';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_chat_profanity_trigger
  BEFORE INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION validate_chat_profanity();
```

---

### 3. Reaction Count Trigger

```sql
CREATE OR REPLACE FUNCTION update_chat_reaction_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE chat_messages
    SET reaction_count = reaction_count + 1
    WHERE id = NEW.message_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE chat_messages
    SET reaction_count = GREATEST(0, reaction_count - 1)
    WHERE id = OLD.message_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_chat_reaction_count
  AFTER INSERT OR DELETE ON chat_reactions
  FOR EACH ROW
  EXECUTE FUNCTION update_chat_reaction_count();
```

---

### 4. Reply Count Trigger

```sql
CREATE OR REPLACE FUNCTION update_chat_reply_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.reply_to_id IS NOT NULL THEN
    UPDATE chat_messages
    SET reply_count = reply_count + 1
    WHERE id = NEW.reply_to_id;
  ELSIF TG_OP = 'DELETE' AND OLD.reply_to_id IS NOT NULL THEN
    UPDATE chat_messages
    SET reply_count = GREATEST(0, reply_count - 1)
    WHERE id = OLD.reply_to_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_chat_reply_count
  AFTER INSERT OR DELETE ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_chat_reply_count();
```

---

### 5. Report Count & Auto-Hide Trigger

```sql
CREATE OR REPLACE FUNCTION update_chat_report_count()
RETURNS TRIGGER AS $$
DECLARE
  total_reports INT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT COUNT(DISTINCT reporter_user_id) INTO total_reports
    FROM chat_reports
    WHERE message_id = NEW.message_id;

    UPDATE chat_messages
    SET report_count = total_reports
    WHERE id = NEW.message_id;

    -- Auto-hide at 3+ reports
    IF total_reports >= 3 THEN
      UPDATE chat_messages
      SET
        hidden_at = NOW(),
        hidden_reason = 'auto_hide_reports'
      WHERE id = NEW.message_id AND hidden_at IS NULL;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_chat_report_count
  AFTER INSERT ON chat_reports
  FOR EACH ROW
  EXECUTE FUNCTION update_chat_report_count();
```

---

### 6. Mention Notification Trigger

```sql
CREATE OR REPLACE FUNCTION notify_chat_mentions()
RETURNS TRIGGER AS $$
DECLARE
  mention JSONB;
  mentioned_user_id UUID;
BEGIN
  -- Parse mentions array and create notifications
  FOR mention IN SELECT * FROM jsonb_array_elements(NEW.mentions) LOOP
    mentioned_user_id := (mention->>'user_id')::UUID;

    -- Insert notification (uses existing notification system)
    INSERT INTO notifications (
      user_id,
      type,
      title,
      body,
      data,
      created_at
    ) VALUES (
      mentioned_user_id,
      'chat_mention',
      'Ti hanno menzionato in chat',
      substring(NEW.content from 1 for 100),
      jsonb_build_object(
        'message_id', NEW.id,
        'sender_id', NEW.user_id
      ),
      NOW()
    );
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notify_mentions_trigger
  AFTER INSERT ON chat_messages
  FOR EACH ROW
  WHEN (jsonb_array_length(NEW.mentions) > 0)
  EXECUTE FUNCTION notify_chat_mentions();
```

---

## pg_cron: 24-Hour Auto-Delete Job

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule hourly deletion job
SELECT cron.schedule(
  'chat-auto-delete-24h',
  '0 * * * *',  -- Every hour at minute 0
  $$
    -- Delete messages older than 24 hours
    -- CASCADE deletes reactions, reports, media
    DELETE FROM chat_messages
    WHERE created_at < NOW() - INTERVAL '24 hours';

    -- Cleanup orphaned storage files
    -- (Handled by Supabase Edge Function or separate job)
  $$
);

-- Also schedule media expiration check (every 15 minutes)
SELECT cron.schedule(
  'chat-media-expire',
  '*/15 * * * *',
  $$
    -- Mark expired media as viewed (prevents re-viewing)
    UPDATE chat_media
    SET is_viewed = TRUE
    WHERE expires_at < NOW()
      AND is_viewed = FALSE;
  $$
);
```

---

## Storage Bucket Configuration

```sql
-- Create ephemeral-media bucket (via Supabase Dashboard or SQL)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'ephemeral-media',
  'ephemeral-media',
  FALSE, -- Private bucket, signed URLs required
  10485760, -- 10MB max
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'video/mp4']
);

-- Storage RLS: Users can upload to their own folder
CREATE POLICY "Users upload own media"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'ephemeral-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Storage RLS: Users can read media if message is visible
CREATE POLICY "Users read visible media"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'ephemeral-media'
    AND EXISTS (
      SELECT 1 FROM chat_media cm
      JOIN chat_messages m ON cm.message_id = m.id
      WHERE cm.storage_path = name
        AND m.hidden_at IS NULL
    )
  );
```

---

## Domain Entities (Flutter)

### 1. `ChatMessage` Entity

```dart
/// Domain entity representing a message in the global chat
class ChatMessage {
  final String id;
  final String userId;
  final String? replyToId;
  final String content;
  final List<MentionInfo> mentions;
  final int reactionCount;
  final int replyCount;
  final int reportCount;
  final DateTime? hiddenAt;
  final String? hiddenReason;
  final DateTime createdAt;

  // Joined data
  final UserProfile author;
  final ChatMessage? replyTo; // The quoted message (if reply)
  final Map<String, int> reactionCounts; // emoji -> count
  final Set<String> currentUserReactions; // emoji set
  final ChatMediaInfo? media; // View-once media (if any)

  // Computed
  bool get isHidden => hiddenAt != null;
  bool get isReply => replyToId != null;
  bool get hasMedia => media != null;
  bool get hasMentions => mentions.isNotEmpty;

  const ChatMessage({
    required this.id,
    required this.userId,
    this.replyToId,
    required this.content,
    required this.mentions,
    required this.reactionCount,
    required this.replyCount,
    required this.reportCount,
    this.hiddenAt,
    this.hiddenReason,
    required this.createdAt,
    required this.author,
    this.replyTo,
    required this.reactionCounts,
    required this.currentUserReactions,
    this.media,
  });

  /// Display text with highlighted mentions
  String get displayContent {
    if (isHidden) return '[Messaggio nascosto]';
    return content;
  }

  /// Relative timestamp (e.g., "2 min fa", "1 ora fa")
  String get relativeTimestamp {
    final difference = DateTime.now().difference(createdAt);

    if (difference.inSeconds < 60) return 'Adesso';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min fa';
    if (difference.inHours < 24) return '${difference.inHours} ore fa';
    return 'Ieri'; // Messages older than 24h are deleted
  }

  ChatMessage copyWith({
    String? id,
    String? userId,
    String? replyToId,
    String? content,
    List<MentionInfo>? mentions,
    int? reactionCount,
    int? replyCount,
    int? reportCount,
    DateTime? hiddenAt,
    String? hiddenReason,
    DateTime? createdAt,
    UserProfile? author,
    ChatMessage? replyTo,
    Map<String, int>? reactionCounts,
    Set<String>? currentUserReactions,
    ChatMediaInfo? media,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      replyToId: replyToId ?? this.replyToId,
      content: content ?? this.content,
      mentions: mentions ?? this.mentions,
      reactionCount: reactionCount ?? this.reactionCount,
      replyCount: replyCount ?? this.replyCount,
      reportCount: reportCount ?? this.reportCount,
      hiddenAt: hiddenAt ?? this.hiddenAt,
      hiddenReason: hiddenReason ?? this.hiddenReason,
      createdAt: createdAt ?? this.createdAt,
      author: author ?? this.author,
      replyTo: replyTo ?? this.replyTo,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      currentUserReactions: currentUserReactions ?? this.currentUserReactions,
      media: media ?? this.media,
    );
  }
}
```

---

### 2. `MentionInfo` Entity

```dart
/// Info about a @mention in a message
class MentionInfo {
  final String userId;
  final String username; // Display name at time of mention
  final int startIndex; // Position in content string
  final int endIndex;

  const MentionInfo({
    required this.userId,
    required this.username,
    required this.startIndex,
    required this.endIndex,
  });

  factory MentionInfo.fromJson(Map<String, dynamic> json) {
    return MentionInfo(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      startIndex: json['start_index'] as int,
      endIndex: json['end_index'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'username': username,
    'start_index': startIndex,
    'end_index': endIndex,
  };
}
```

---

### 3. `ChatReaction` Entity

```dart
/// Domain entity representing an emoji reaction
class ChatReaction {
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  const ChatReaction({
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });
}

/// Allowed emoji reactions
class ChatEmoji {
  static const heart = '❤️';
  static const thumbsUp = '👍';
  static const laughing = '😂';
  static const surprised = '😮';
  static const sad = '😢';
  static const fire = '🔥';

  static const all = [heart, thumbsUp, laughing, surprised, sad, fire];

  static bool isValid(String emoji) => all.contains(emoji);
}
```

---

### 4. `ChatReport` Entity

```dart
/// Domain entity for message reports
class ChatReport {
  final String id;
  final String messageId;
  final String reporterUserId;
  final ChatReportReason reason;
  final ChatReportStatus status;
  final String? reviewedByModeratorId;
  final DateTime? reviewedAt;
  final String? moderatorNotes;
  final DateTime createdAt;

  const ChatReport({
    required this.id,
    required this.messageId,
    required this.reporterUserId,
    required this.reason,
    required this.status,
    this.reviewedByModeratorId,
    this.reviewedAt,
    this.moderatorNotes,
    required this.createdAt,
  });
}

enum ChatReportReason {
  spam('spam', 'Spam'),
  inappropriate('inappropriate', 'Contenuto inappropriato'),
  bullying('bullying', 'Bullismo'),
  offTopic('off_topic', 'Off-topic');

  final String value;
  final String label;

  const ChatReportReason(this.value, this.label);

  static ChatReportReason fromValue(String value) {
    return values.firstWhere((r) => r.value == value);
  }
}

enum ChatReportStatus {
  pending('pending', 'In attesa'),
  reviewed('reviewed', 'Revisionato'),
  dismissed('dismissed', 'Respinto');

  final String value;
  final String label;

  const ChatReportStatus(this.value, this.label);

  static ChatReportStatus fromValue(String value) {
    return values.firstWhere((s) => s.value == value);
  }
}
```

---

### 5. `ChatMediaInfo` Entity (P3)

```dart
/// Metadata for view-once media
class ChatMediaInfo {
  final String id;
  final String messageId;
  final String uploaderUserId;
  final String storagePath;
  final ChatMediaType mediaType;
  final int fileSizeBytes;
  final bool isViewed;
  final DateTime? viewedAt;
  final String? viewedByUserId;
  final bool screenshotDetected;
  final DateTime expiresAt;
  final DateTime createdAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get canView => !isViewed && !isExpired;

  const ChatMediaInfo({
    required this.id,
    required this.messageId,
    required this.uploaderUserId,
    required this.storagePath,
    required this.mediaType,
    required this.fileSizeBytes,
    required this.isViewed,
    this.viewedAt,
    this.viewedByUserId,
    required this.screenshotDetected,
    required this.expiresAt,
    required this.createdAt,
  });
}

enum ChatMediaType {
  image('image'),
  video('video');

  final String value;

  const ChatMediaType(this.value);

  static ChatMediaType fromValue(String value) {
    return values.firstWhere((t) => t.value == value);
  }
}
```

---

## Entity Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                        chat_messages                             │
│                                                                  │
│ id (PK)                                                         │
│ user_id (FK → profiles)                                         │
│ reply_to_id (FK → chat_messages, self-ref, 1-level max) ◄──────┤
│ content                                                         │
│ mentions (JSONB)                                                │
│ reaction_count, reply_count, report_count                       │
│ hidden_at, hidden_reason                                        │
│ created_at                                                      │
└──┬─────────────────────────┬────────────────────────────┬───────┘
   │                         │                            │
   ▼                         ▼                            ▼
┌──────────────────┐  ┌──────────────────┐  ┌─────────────────────┐
│  chat_reactions  │  │   chat_reports   │  │     chat_media      │
│                  │  │                  │  │                     │
│ message_id (FK)  │  │ id (PK)          │  │ id (PK)             │
│ user_id (FK)     │  │ message_id (FK)  │  │ message_id (FK,UQ)  │
│ emoji            │  │ reporter_user_id │  │ uploader_user_id    │
│ created_at       │  │ reason           │  │ storage_path        │
│                  │  │ status           │  │ media_type          │
│ PK: (msg,user,   │  │ created_at       │  │ is_viewed           │
│      emoji)      │  └──────────────────┘  │ expires_at          │
└──────────────────┘                        └─────────────────────┘

┌─────────────┐
│  profiles   │
│             │
│ user_id (PK)│◄─── Referenced by all user_id FKs
│ full_name   │
│ avatar_url  │
│ class       │
└─────────────┘

┌─────────────┐
│ user_roles  │
│             │
│ user_id (FK)│◄─── Used for moderator checks in RLS
│ role        │
└─────────────┘
```

---

## Data Access Patterns

### 1. Load Chat Feed (Paginated, Real-Time)

```dart
// Riverpod StreamProvider for real-time chat
final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  final currentUserId = ref.read(currentUserIdProvider);

  return supabase
    .from('chat_messages')
    .stream(primaryKey: ['id'])
    .order('created_at', ascending: false)
    .limit(50)
    .map((data) => data.map((json) => _parseMessage(json, currentUserId)).toList());
});
```

### 2. Send Message (Optimistic)

```sql
INSERT INTO chat_messages (user_id, content, mentions, reply_to_id)
VALUES ($user_id, $content, $mentions::jsonb, $reply_to_id)
RETURNING *;
```

### 3. Add Reaction

```sql
INSERT INTO chat_reactions (message_id, user_id, emoji)
VALUES ($message_id, $user_id, $emoji)
ON CONFLICT (message_id, user_id, emoji) DO NOTHING
RETURNING *;
```

### 4. Remove Reaction

```sql
DELETE FROM chat_reactions
WHERE message_id = $message_id
  AND user_id = $user_id
  AND emoji = $emoji
RETURNING *;
```

### 5. @Mention Autocomplete

```sql
SELECT user_id, full_name, avatar_url, class
FROM profiles
WHERE LOWER(full_name) LIKE '%' || LOWER($search) || '%'
ORDER BY
  CASE WHEN LOWER(full_name) LIKE LOWER($search) || '%' THEN 0 ELSE 1 END,
  full_name
LIMIT 5;
```

### 6. Report Message

```sql
INSERT INTO chat_reports (message_id, reporter_user_id, reason)
VALUES ($message_id, $reporter_user_id, $reason)
ON CONFLICT (message_id, reporter_user_id) DO NOTHING
RETURNING *;
```

---

## Performance Considerations

### Index Usage

| Query Pattern | Index Used | Scan Type |
|--------------|-----------|-----------|
| Load chat feed | `idx_chat_messages_feed` | Index Scan (O(log n)) |
| User's messages | `idx_chat_messages_user` | Index Scan (O(log n)) |
| Message replies | `idx_chat_messages_replies` | Index Scan (O(log n)) |
| Rate limit check | `idx_chat_messages_user` | Index Scan (O(log n)) |
| Autocomplete | `idx_profiles_fullname_trgm` | GIN Index Scan |
| Moderation queue | `idx_chat_messages_moderation_queue` | Index Scan |

### Denormalized Fields

- `reaction_count`, `reply_count`, `report_count` on `chat_messages`
- **Rationale**: Avoids COUNT(*) queries, improves read performance
- **Trade-off**: Trigger execution on writes, eventual consistency

---

## Migration File Reference

Complete SQL migration will be in:
```
supabase/migrations/011_global_chat_system.sql
```

---

**Status**: Phase 1 Data Model Complete
**Next**: API Contracts (Supabase client calls)
