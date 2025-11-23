# Data Model: Event Comments System

**Feature**: Event Comments System
**Branch**: `007-event-comments`
**Created**: 2025-01-22
**Phase**: Phase 1 (Data Model & Schema Design)

## Overview

This document defines the complete data model for the event comments system, including PostgreSQL schema, Row-Level Security (RLS) policies, indexes, triggers, and domain entities for Flutter.

---

## Database Schema (PostgreSQL)

### 1. `comments` Table

Stores all comments and replies (1-level threading via `parent_comment_id`).

```sql
CREATE TABLE comments (
  -- Identity
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relationships
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  parent_comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,

  -- Content
  text TEXT NOT NULL CHECK (char_length(trim(text)) BETWEEN 1 AND 500),

  -- Denormalized counters (for performance)
  like_count INT NOT NULL DEFAULT 0 CHECK (like_count >= 0),
  reply_count INT NOT NULL DEFAULT 0 CHECK (reply_count >= 0),
  report_count INT NOT NULL DEFAULT 0 CHECK (report_count >= 0),

  -- Soft delete (GDPR Right to Erasure)
  deleted_at TIMESTAMPTZ,
  deleted_by_user_id UUID REFERENCES profiles(id),

  -- Moderation
  hidden_at TIMESTAMPTZ, -- Auto-hidden at 3+ reports
  hidden_reason TEXT, -- "auto_hide_reports" or "moderator_removed"
  moderator_id UUID REFERENCES profiles(id), -- Who removed it (if moderator action)

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ, -- NULL if never edited

  -- Constraints
  CONSTRAINT parent_must_be_top_level
    CHECK (
      parent_comment_id IS NULL OR
      parent_comment_id IN (
        SELECT id FROM comments WHERE parent_comment_id IS NULL
      )
    ), -- Enforce max 1-level threading

  CONSTRAINT deleted_comments_are_empty
    CHECK (deleted_at IS NULL OR text = '[Commento eliminato]')
);

-- Indexes for performance
CREATE INDEX idx_comments_event_top_level
  ON comments(event_id, created_at DESC)
  WHERE parent_comment_id IS NULL AND deleted_at IS NULL;

CREATE INDEX idx_comments_parent_replies
  ON comments(parent_comment_id, created_at ASC)
  WHERE parent_comment_id IS NOT NULL AND deleted_at IS NULL;

CREATE INDEX idx_comments_user
  ON comments(user_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_comments_moderation_queue
  ON comments(created_at DESC)
  WHERE hidden_at IS NOT NULL AND deleted_at IS NULL;

-- Full-text search index (future enhancement)
CREATE INDEX idx_comments_text_search
  ON comments USING gin(to_tsvector('italian', text))
  WHERE deleted_at IS NULL;

-- Soft delete cleanup index (for CRON job)
CREATE INDEX idx_comments_pending_hard_delete
  ON comments(deleted_at)
  WHERE deleted_at IS NOT NULL;
```

---

### 2. `comment_likes` Table

Stores like relationships (many-to-many between users and comments).

```sql
CREATE TABLE comment_likes (
  -- Composite primary key (prevents duplicate likes)
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Soft delete (for GDPR, preserves like_count accuracy)
  deleted_at TIMESTAMPTZ,

  PRIMARY KEY (comment_id, user_id)
);

-- Indexes
CREATE INDEX idx_comment_likes_user
  ON comment_likes(user_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_comment_likes_rate_limit
  ON comment_likes(user_id, created_at DESC)
  WHERE deleted_at IS NULL AND created_at > NOW() - INTERVAL '1 hour';

-- Soft delete cleanup index
CREATE INDEX idx_comment_likes_pending_hard_delete
  ON comment_likes(deleted_at)
  WHERE deleted_at IS NOT NULL;
```

---

### 3. `comment_reports` Table

Stores user-submitted reports for inappropriate comments.

```sql
CREATE TABLE comment_reports (
  -- Identity
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relationships
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  reporter_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Report details
  reason TEXT NOT NULL CHECK (reason IN ('spam', 'inappropriate', 'bullying', 'off_topic')),
  details TEXT CHECK (char_length(trim(details)) <= 500), -- Optional elaboration

  -- Moderation workflow
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
  reviewed_by_moderator_id UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  moderator_notes TEXT,

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Prevent duplicate reports from same user
  CONSTRAINT unique_user_report_per_comment UNIQUE (comment_id, reporter_user_id)
);

-- Indexes
CREATE INDEX idx_comment_reports_pending
  ON comment_reports(created_at DESC)
  WHERE status = 'pending';

CREATE INDEX idx_comment_reports_comment
  ON comment_reports(comment_id, created_at DESC);

CREATE INDEX idx_comment_reports_user
  ON comment_reports(reporter_user_id, created_at DESC);
```

---

## Row-Level Security (RLS) Policies

### `comments` Table RLS

```sql
-- Enable RLS
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- Policy 1: Students can view non-deleted, non-hidden comments on approved events
CREATE POLICY "Students view approved event comments"
  ON comments FOR SELECT
  TO authenticated
  USING (
    deleted_at IS NULL
    AND hidden_at IS NULL
    AND event_id IN (
      SELECT id FROM events WHERE status = 'approved'
    )
  );

-- Policy 2: Moderators can view all comments (including hidden/deleted)
CREATE POLICY "Moderators view all comments"
  ON comments FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'moderator'
    )
  );

-- Policy 3: Students can insert comments (profanity filter via trigger)
CREATE POLICY "Students insert comments"
  ON comments FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND event_id IN (SELECT id FROM events WHERE status = 'approved')
    AND deleted_at IS NULL
    AND hidden_at IS NULL
  );

-- Policy 4: Users can soft-delete own comments
CREATE POLICY "Users delete own comments"
  ON comments FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND deleted_at IS NOT NULL
    AND text = '[Commento eliminato]'
  );

-- Policy 5: Moderators can hide/remove any comment
CREATE POLICY "Moderators remove comments"
  ON comments FOR UPDATE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'moderator'
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'moderator'
    )
  );

-- Policy 6: Users can edit own comments within 5 minutes
CREATE POLICY "Users edit own recent comments"
  ON comments FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = user_id
    AND deleted_at IS NULL
    AND created_at > NOW() - INTERVAL '5 minutes'
  )
  WITH CHECK (
    auth.uid() = user_id
    AND updated_at = NOW()
  );
```

---

### `comment_likes` Table RLS

```sql
-- Enable RLS
ALTER TABLE comment_likes ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view likes on visible comments
CREATE POLICY "Users view comment likes"
  ON comment_likes FOR SELECT
  TO authenticated
  USING (
    deleted_at IS NULL
    AND comment_id IN (
      SELECT id FROM comments WHERE deleted_at IS NULL AND hidden_at IS NULL
    )
  );

-- Policy 2: Users can like comments (rate limit via trigger)
CREATE POLICY "Users like comments"
  ON comment_likes FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND deleted_at IS NULL
  );

-- Policy 3: Users can unlike own likes
CREATE POLICY "Users unlike comments"
  ON comment_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
```

---

### `comment_reports` Table RLS

```sql
-- Enable RLS
ALTER TABLE comment_reports ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view own reports
CREATE POLICY "Users view own reports"
  ON comment_reports FOR SELECT
  TO authenticated
  USING (auth.uid() = reporter_user_id);

-- Policy 2: Moderators can view all reports
CREATE POLICY "Moderators view all reports"
  ON comment_reports FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'moderator'
    )
  );

-- Policy 3: Users can submit reports (one per comment)
CREATE POLICY "Users submit reports"
  ON comment_reports FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = reporter_user_id
    AND status = 'pending'
  );

-- Policy 4: Moderators can update report status
CREATE POLICY "Moderators review reports"
  ON comment_reports FOR UPDATE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'moderator'
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'moderator'
    )
  );
```

---

## Database Functions & Triggers

### 1. Profanity Filter Function

```sql
CREATE OR REPLACE FUNCTION contains_profanity(input_text TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  -- Italian profanity list (150+ words)
  profane_words TEXT[] := ARRAY[
    'cazzo', 'merda', 'stronzo', 'bastardo', 'fica', 'figa', 'puttana',
    'troia', 'vaffanculo', 'fanculo', 'porco', 'dio', 'madonna', 'cristo',
    -- ... (full list maintained separately for security)
  ];
  word TEXT;
BEGIN
  -- Normalize: lowercase, trim
  input_text := lower(trim(input_text));

  -- Check each profane word with word boundaries
  FOREACH word IN ARRAY profane_words LOOP
    IF input_text ~* ('\y' || word || '\y') THEN
      RETURN TRUE;
    END IF;
  END LOOP;

  RETURN FALSE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

---

### 2. Rate Limiting Functions

```sql
-- Check comment spam (3 identical in 5 min)
CREATE OR REPLACE FUNCTION check_comment_spam()
RETURNS TRIGGER AS $$
DECLARE
  recent_count INT;
BEGIN
  SELECT COUNT(*) INTO recent_count
  FROM comments
  WHERE user_id = NEW.user_id
    AND event_id = NEW.event_id
    AND text = NEW.text
    AND created_at > NOW() - INTERVAL '5 minutes';

  IF recent_count >= 3 THEN
    RAISE EXCEPTION 'Rate limit exceeded: max 3 identical comments in 5 minutes';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_comment_spam
  BEFORE INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION check_comment_spam();

-- Check like rate limit (100 likes/hour)
CREATE OR REPLACE FUNCTION check_like_rate_limit()
RETURNS TRIGGER AS $$
DECLARE
  recent_likes INT;
BEGIN
  SELECT COUNT(*) INTO recent_likes
  FROM comment_likes
  WHERE user_id = NEW.user_id
    AND created_at > NOW() - INTERVAL '1 hour';

  IF recent_likes >= 100 THEN
    RAISE EXCEPTION 'Rate limit exceeded: max 100 likes per hour';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_like_spam
  BEFORE INSERT ON comment_likes
  FOR EACH ROW
  EXECUTE FUNCTION check_like_rate_limit();
```

---

### 3. Profanity Check Trigger

```sql
CREATE OR REPLACE FUNCTION validate_comment_profanity()
RETURNS TRIGGER AS $$
BEGIN
  IF contains_profanity(NEW.text) THEN
    RAISE EXCEPTION 'Comment contains inappropriate language';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_profanity_on_insert
  BEFORE INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION validate_comment_profanity();

CREATE TRIGGER check_profanity_on_update
  BEFORE UPDATE ON comments
  FOR EACH ROW
  WHEN (OLD.text IS DISTINCT FROM NEW.text)
  EXECUTE FUNCTION validate_comment_profanity();
```

---

### 4. Denormalized Counter Triggers

```sql
-- Update like_count on comment when like added/removed
CREATE OR REPLACE FUNCTION update_comment_like_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE comments
    SET like_count = like_count + 1
    WHERE id = NEW.comment_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE comments
    SET like_count = GREATEST(0, like_count - 1)
    WHERE id = OLD.comment_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_comment_like_count
  AFTER INSERT OR DELETE ON comment_likes
  FOR EACH ROW
  EXECUTE FUNCTION update_comment_like_count();

-- Update reply_count on parent comment when reply added/removed
CREATE OR REPLACE FUNCTION update_comment_reply_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.parent_comment_id IS NOT NULL THEN
    UPDATE comments
    SET reply_count = reply_count + 1
    WHERE id = NEW.parent_comment_id;
  ELSIF TG_OP = 'DELETE' AND OLD.parent_comment_id IS NOT NULL THEN
    UPDATE comments
    SET reply_count = GREATEST(0, reply_count - 1)
    WHERE id = OLD.parent_comment_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_comment_reply_count
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW
  EXECUTE FUNCTION update_comment_reply_count();

-- Update report_count and auto-hide at 3+ reports
CREATE OR REPLACE FUNCTION update_comment_report_count()
RETURNS TRIGGER AS $$
DECLARE
  total_reports INT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Count unique reporters for this comment
    SELECT COUNT(DISTINCT reporter_user_id) INTO total_reports
    FROM comment_reports
    WHERE comment_id = NEW.comment_id;

    -- Update report_count
    UPDATE comments
    SET report_count = total_reports
    WHERE id = NEW.comment_id;

    -- Auto-hide if 3+ reports
    IF total_reports >= 3 THEN
      UPDATE comments
      SET
        hidden_at = NOW(),
        hidden_reason = 'auto_hide_reports'
      WHERE id = NEW.comment_id AND hidden_at IS NULL;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_comment_report_count
  AFTER INSERT ON comment_reports
  FOR EACH ROW
  EXECUTE FUNCTION update_comment_report_count();
```

---

### 5. Event Comment Count Trigger

```sql
-- Update comment_count on events table
CREATE OR REPLACE FUNCTION update_event_comment_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.parent_comment_id IS NULL THEN
    UPDATE events
    SET comment_count = comment_count + 1
    WHERE id = NEW.event_id;
  ELSIF TG_OP = 'DELETE' AND OLD.parent_comment_id IS NULL THEN
    UPDATE events
    SET comment_count = GREATEST(0, comment_count - 1)
    WHERE id = OLD.event_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_event_comment_count
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW
  EXECUTE FUNCTION update_event_comment_count();
```

---

## GDPR Compliance: Hard Delete CRON Job

```sql
-- Function to permanently delete soft-deleted data after 30 days
CREATE OR REPLACE FUNCTION gdpr_hard_delete_old_data()
RETURNS void AS $$
BEGIN
  -- Hard delete comments after 30-day grace period
  DELETE FROM comments
  WHERE deleted_at IS NOT NULL
    AND deleted_at < NOW() - INTERVAL '30 days';

  -- Hard delete likes after 30-day grace period
  DELETE FROM comment_likes
  WHERE deleted_at IS NOT NULL
    AND deleted_at < NOW() - INTERVAL '30 days';

  -- Log cleanup action
  RAISE NOTICE 'GDPR hard delete completed at %', NOW();
END;
$$ LANGUAGE plpgsql;

-- Schedule via pg_cron extension (daily at 2 AM UTC)
-- SELECT cron.schedule('gdpr-hard-delete', '0 2 * * *', 'SELECT gdpr_hard_delete_old_data()');
```

---

## Domain Entities (Flutter)

### 1. `Comment` Entity

```dart
/// Domain entity representing a comment on an event
class Comment {
  final String id;
  final String eventId;
  final String userId;
  final String? parentCommentId; // NULL for top-level comments
  final String text;
  final int likeCount;
  final int replyCount;
  final int reportCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final DateTime? hiddenAt;
  final String? hiddenReason;

  // Computed properties (not stored in DB)
  final bool isDeleted;
  final bool isHidden;
  final bool isReply;
  final bool isEdited;

  // Related entities (joined from other tables)
  final UserProfile author;
  final bool isLikedByCurrentUser; // From comment_likes join
  final List<Comment>? replies; // Loaded lazily for threading

  Comment({
    required this.id,
    required this.eventId,
    required this.userId,
    this.parentCommentId,
    required this.text,
    required this.likeCount,
    required this.replyCount,
    required this.reportCount,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.hiddenAt,
    this.hiddenReason,
    required this.author,
    required this.isLikedByCurrentUser,
    this.replies,
  })  : isDeleted = deletedAt != null,
        isHidden = hiddenAt != null,
        isReply = parentCommentId != null,
        isEdited = updatedAt != null;

  /// Check if comment can be edited (within 5-min window)
  bool get canEdit {
    if (isDeleted || isHidden) return false;
    final fiveMinutesAgo = DateTime.now().subtract(Duration(minutes: 5));
    return createdAt.isAfter(fiveMinutesAgo);
  }

  /// Check if comment can be deleted by current user
  bool canDeleteByUser(String currentUserId) {
    return userId == currentUserId && !isDeleted;
  }

  /// Display text (shows placeholder for deleted comments)
  String get displayText {
    if (isDeleted) return '[Commento eliminato]';
    return text;
  }

  /// Relative timestamp (e.g., "2h fa", "1 giorno fa")
  String get relativeTimestamp {
    final difference = DateTime.now().difference(createdAt);

    if (difference.inMinutes < 1) return 'Adesso';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m fa';
    if (difference.inHours < 24) return '${difference.inHours}h fa';
    if (difference.inDays < 7) return '${difference.inDays}g fa';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}s fa';

    // Fallback: absolute date
    return DateFormat('dd/MM/yyyy').format(createdAt);
  }

  Comment copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? parentCommentId,
    String? text,
    int? likeCount,
    int? replyCount,
    int? reportCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? hiddenAt,
    String? hiddenReason,
    UserProfile? author,
    bool? isLikedByCurrentUser,
    List<Comment>? replies,
  }) {
    return Comment(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      text: text ?? this.text,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      reportCount: reportCount ?? this.reportCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      hiddenAt: hiddenAt ?? this.hiddenAt,
      hiddenReason: hiddenReason ?? this.hiddenReason,
      author: author ?? this.author,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      replies: replies ?? this.replies,
    );
  }
}
```

---

### 2. `CommentLike` Entity

```dart
/// Domain entity representing a like on a comment
class CommentLike {
  final String commentId;
  final String userId;
  final DateTime createdAt;

  const CommentLike({
    required this.commentId,
    required this.userId,
    required this.createdAt,
  });
}
```

---

### 3. `CommentReport` Entity

```dart
/// Domain entity representing a report on an inappropriate comment
class CommentReport {
  final String id;
  final String commentId;
  final String reporterUserId;
  final CommentReportReason reason;
  final String? details; // Optional elaboration
  final CommentReportStatus status;
  final String? reviewedByModeratorId;
  final DateTime? reviewedAt;
  final String? moderatorNotes;
  final DateTime createdAt;

  const CommentReport({
    required this.id,
    required this.commentId,
    required this.reporterUserId,
    required this.reason,
    this.details,
    required this.status,
    this.reviewedByModeratorId,
    this.reviewedAt,
    this.moderatorNotes,
    required this.createdAt,
  });
}

/// Report reason enum
enum CommentReportReason {
  spam('spam', 'Spam o pubblicità'),
  inappropriate('inappropriate', 'Contenuto inappropriato'),
  bullying('bullying', 'Bullismo o molestie'),
  offTopic('off_topic', 'Fuori tema');

  final String value;
  final String label;

  const CommentReportReason(this.value, this.label);

  static CommentReportReason fromValue(String value) {
    return values.firstWhere((r) => r.value == value);
  }
}

/// Report status enum
enum CommentReportStatus {
  pending('pending', 'In attesa'),
  reviewed('reviewed', 'Revisionato'),
  dismissed('dismissed', 'Respinto');

  final String value;
  final String label;

  const CommentReportStatus(this.value, this.label);

  static CommentReportStatus fromValue(String value) {
    return values.firstWhere((s) => s.value == value);
  }
}
```

---

## Entity Relationships

```
┌─────────────┐
│   events    │
│             │
│ id (PK)     │◄─────────┐
│ comment_count│          │
└─────────────┘          │
                         │
                    ┌────┴─────────────────┐
                    │      comments        │
                    │                      │
                    │ id (PK)              │
                    │ event_id (FK)        │
                    │ user_id (FK)         │
                    │ parent_comment_id ◄──┼── Self-referencing (1-level max)
                    │ text                 │
                    │ like_count           │
                    │ reply_count          │
                    │ report_count         │
                    │ deleted_at           │
                    │ hidden_at            │
                    └──┬────────────────┬──┘
                       │                │
              ┌────────┘                └─────────┐
              │                                   │
     ┌────────▼──────────┐            ┌──────────▼────────┐
     │  comment_likes    │            │  comment_reports  │
     │                   │            │                   │
     │ comment_id (PK,FK)│            │ id (PK)           │
     │ user_id (PK,FK)   │            │ comment_id (FK)   │
     │ created_at        │            │ reporter_user_id  │
     │ deleted_at        │            │ reason            │
     └───────────────────┘            │ status            │
                                      │ created_at        │
                                      └───────────────────┘

┌─────────────┐
│  profiles   │
│             │
│ id (PK)     │◄───── Referenced by user_id, moderator_id, etc.
│ name        │
│ avatar_url  │
│ role        │
└─────────────┘
```

---

## Data Access Patterns

### 1. Load Comments for Event (Top-Level + Replies)

```sql
-- Efficient two-query approach (avoids N+1 problem)

-- Query 1: Load top-level comments with pagination
SELECT
  c.*,
  p.id AS author_id,
  p.name AS author_name,
  p.avatar_url AS author_avatar,
  p.class AS author_class,
  EXISTS(
    SELECT 1 FROM comment_likes cl
    WHERE cl.comment_id = c.id
      AND cl.user_id = $current_user_id
      AND cl.deleted_at IS NULL
  ) AS is_liked_by_current_user
FROM comments c
JOIN profiles p ON c.user_id = p.id
WHERE c.event_id = $event_id
  AND c.parent_comment_id IS NULL
  AND c.deleted_at IS NULL
  AND c.hidden_at IS NULL
ORDER BY c.created_at DESC
LIMIT 20 OFFSET $cursor;

-- Query 2: Load all replies for fetched top-level comments (batch query)
SELECT
  c.*,
  p.id AS author_id,
  p.name AS author_name,
  p.avatar_url AS author_avatar,
  EXISTS(
    SELECT 1 FROM comment_likes cl
    WHERE cl.comment_id = c.id
      AND cl.user_id = $current_user_id
      AND cl.deleted_at IS NULL
  ) AS is_liked_by_current_user
FROM comments c
JOIN profiles p ON c.user_id = p.id
WHERE c.parent_comment_id = ANY($parent_comment_ids)
  AND c.deleted_at IS NULL
  AND c.hidden_at IS NULL
ORDER BY c.created_at ASC;
```

---

### 2. Post New Comment (Optimistic Insert)

```sql
-- Insert with profanity check and rate limit (via triggers)
INSERT INTO comments (event_id, user_id, parent_comment_id, text)
VALUES ($event_id, $user_id, $parent_comment_id, $text)
RETURNING *;
```

---

### 3. Like Comment (Optimistic)

```sql
-- Insert like (triggers update like_count on comments table)
INSERT INTO comment_likes (comment_id, user_id)
VALUES ($comment_id, $user_id)
ON CONFLICT (comment_id, user_id) DO NOTHING
RETURNING *;
```

---

### 4. Unlike Comment (Optimistic)

```sql
-- Delete like (triggers decrement like_count)
DELETE FROM comment_likes
WHERE comment_id = $comment_id
  AND user_id = $user_id
RETURNING *;
```

---

### 5. Report Comment

```sql
-- Insert report (triggers update report_count, potential auto-hide)
INSERT INTO comment_reports (comment_id, reporter_user_id, reason, details)
VALUES ($comment_id, $reporter_user_id, $reason, $details)
ON CONFLICT (comment_id, reporter_user_id) DO NOTHING
RETURNING *;
```

---

### 6. Soft Delete Own Comment

```sql
-- Soft delete (preserves thread structure)
UPDATE comments
SET
  text = '[Commento eliminato]',
  deleted_at = NOW(),
  deleted_by_user_id = $user_id
WHERE id = $comment_id
  AND user_id = $user_id
  AND deleted_at IS NULL
RETURNING *;
```

---

### 7. Moderator Remove Comment

```sql
-- Hard hide (moderator action, preserves for audit)
UPDATE comments
SET
  hidden_at = NOW(),
  hidden_reason = 'moderator_removed',
  moderator_id = $moderator_id
WHERE id = $comment_id
RETURNING *;
```

---

## Performance Considerations

### Index Usage

| Query Pattern | Index Used | Scan Type |
|--------------|-----------|-----------|
| Load top-level comments for event | `idx_comments_event_top_level` | Index Scan (O(log n)) |
| Load replies for parent comment | `idx_comments_parent_replies` | Index Scan (O(log n)) |
| Check if user liked comment | `comment_likes` PRIMARY KEY | Index Scan (O(1)) |
| Load user's comment history | `idx_comments_user` | Index Scan (O(log n)) |
| Moderation queue (hidden comments) | `idx_comments_moderation_queue` | Index Scan (O(log n)) |
| Rate limit check (likes/hour) | `idx_comment_likes_rate_limit` | Index Scan (O(log n)) |

### Denormalized Fields

- `like_count`, `reply_count`, `report_count` on `comments` table
- `comment_count` on `events` table (updated via trigger)
- **Rationale**: Avoids COUNT(*) queries on large tables, improves read performance
- **Trade-off**: Slight write overhead (trigger execution), eventual consistency during high concurrency

---

## Migration File Reference

Complete SQL migration will be in:
```
supabase/migrations/007_event_comments_system.sql
```

---

**Status**: ✅ Phase 1 Data Model Complete
**Next**: API Contracts (Supabase client calls)
