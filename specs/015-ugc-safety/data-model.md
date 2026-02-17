# Data Model: UGC Safety System

**Feature**: 015-ugc-safety
**Date**: 2025-02-12
**Database**: PostgreSQL 15+ (Supabase)

## Entity Relationship Diagram

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│    profiles     │       │    reports      │       │  user_blocks    │
│ (existing)      │◄──────│                 │       │                 │
│                 │       │ reporter_id ────┼───────►│ blocker_id ────┼──►profiles
│ + tos_version   │       │ content_type    │       │ blocked_id ────┼──►profiles
│ + tos_accepted  │       │ content_id      │       │                 │
└────────┬────────┘       │ category        │       └─────────────────┘
         │                │ status          │
         │                └─────────────────┘
         │
         │                ┌─────────────────┐       ┌─────────────────┐
         │                │  banned_words   │       │ user_sanctions  │
         │                │                 │       │                 │
         │                │ word            │       │ user_id ────────┼──►profiles
         └───────────────►│ pattern_type    │       │ type            │
                          │ severity        │       │ reason          │
                          │ created_by ─────┼──►    │ issued_by ──────┼──►profiles
                          └─────────────────┘       │ expires_at      │
                                                    └─────────────────┘
```

---

## Tables

### 1. reports (NEW)

Unified report table for all content types.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() | Unique identifier |
| `reporter_id` | UUID | FK profiles.user_id, NOT NULL | User who reported |
| `content_type` | VARCHAR(50) | NOT NULL | 'event', 'comment', 'chat_message', 'profile' |
| `content_id` | UUID | NOT NULL | ID of reported content |
| `category` | VARCHAR(50) | NOT NULL | Report category |
| `note` | TEXT | NULL, MAX 500 chars | Optional description |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'pending' | 'pending', 'reviewed', 'dismissed', 'action_taken' |
| `reviewed_by` | UUID | FK profiles.user_id, NULL | Moderator who reviewed |
| `reviewed_at` | TIMESTAMPTZ | NULL | When reviewed |
| `action_taken` | VARCHAR(50) | NULL | 'content_removed', 'user_warned', 'user_suspended', 'user_banned' |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When reported |

**Categories** (ENUM):
- `spam`
- `offensive_content`
- `bullying`
- `inappropriate`
- `other`

**Constraints**:
```sql
UNIQUE(reporter_id, content_type, content_id)  -- One report per user per content
CHECK(status IN ('pending', 'reviewed', 'dismissed', 'action_taken'))
CHECK(content_type IN ('event', 'comment', 'chat_message', 'profile'))
CHECK(char_length(note) <= 500)
```

**Indexes**:
```sql
CREATE INDEX idx_reports_status_created ON reports(status, created_at)
  WHERE status = 'pending';  -- Partial for moderation queue
CREATE INDEX idx_reports_content ON reports(content_type, content_id);
CREATE INDEX idx_reports_reporter ON reports(reporter_id);
```

---

### 2. user_blocks (NEW)

User-to-user blocking relationships.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() | Unique identifier |
| `blocker_id` | UUID | FK profiles.user_id, NOT NULL | User who blocked |
| `blocked_id` | UUID | FK profiles.user_id, NOT NULL | User who was blocked |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When blocked |
| `moderator_notified` | BOOLEAN | NOT NULL, DEFAULT FALSE | Whether moderators were notified |
| `notified_at` | TIMESTAMPTZ | NULL | When notification sent |

**Constraints**:
```sql
UNIQUE(blocker_id, blocked_id)  -- Prevent duplicate blocks
CHECK(blocker_id != blocked_id)  -- Can't block yourself
```

**Indexes**:
```sql
CREATE INDEX idx_user_blocks_blocker ON user_blocks(blocker_id);
CREATE INDEX idx_user_blocks_blocked ON user_blocks(blocked_id);
```

---

### 3. banned_words (NEW)

Configurable content filter word list.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() | Unique identifier |
| `word` | TEXT | NOT NULL, UNIQUE | Word or pattern to block |
| `pattern_type` | VARCHAR(20) | NOT NULL, DEFAULT 'contains' | 'exact', 'contains', 'regex' |
| `severity` | VARCHAR(20) | NOT NULL, DEFAULT 'block' | 'warning', 'block' |
| `language` | VARCHAR(10) | NOT NULL, DEFAULT 'it' | Language code (ISO 639-1) |
| `created_by` | UUID | FK profiles.user_id, NOT NULL | Moderator who added |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When added |
| `deleted_at` | TIMESTAMPTZ | NULL | Soft delete |

**Indexes**:
```sql
CREATE INDEX idx_banned_words_active ON banned_words(word)
  WHERE deleted_at IS NULL;
CREATE INDEX idx_banned_words_language ON banned_words(language)
  WHERE deleted_at IS NULL;
```

---

### 4. user_sanctions (NEW)

User penalty tracking for moderation actions.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() | Unique identifier |
| `user_id` | UUID | FK profiles.user_id, NOT NULL | Sanctioned user |
| `type` | VARCHAR(20) | NOT NULL | 'warning', 'suspension', 'ban' |
| `reason` | TEXT | NOT NULL | Explanation for sanction |
| `related_report_id` | UUID | FK reports.id, NULL | Triggering report if any |
| `related_content_type` | VARCHAR(50) | NULL | Content type that caused sanction |
| `related_content_id` | UUID | NULL | Content ID that caused sanction |
| `issued_by` | UUID | FK profiles.user_id, NOT NULL | Moderator who issued |
| `issued_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When issued |
| `expires_at` | TIMESTAMPTZ | NULL | For suspensions; NULL = permanent |
| `lifted_at` | TIMESTAMPTZ | NULL | When sanction was lifted |
| `lifted_by` | UUID | FK profiles.user_id, NULL | Who lifted the sanction |

**Constraints**:
```sql
CHECK(type IN ('warning', 'suspension', 'ban'))
CHECK(expires_at IS NULL OR type = 'suspension')  -- Only suspensions have expiry
```

**Indexes**:
```sql
CREATE INDEX idx_user_sanctions_user ON user_sanctions(user_id);
CREATE INDEX idx_user_sanctions_active ON user_sanctions(user_id, type)
  WHERE lifted_at IS NULL AND (expires_at IS NULL OR expires_at > NOW());
```

---

### 5. profiles (MODIFICATION)

Add ToS acceptance tracking columns.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `tos_accepted_version` | VARCHAR(20) | NULL | Version accepted (e.g., "1.0.0") |
| `tos_accepted_at` | TIMESTAMPTZ | NULL | When accepted |

**Migration**:
```sql
ALTER TABLE profiles
ADD COLUMN tos_accepted_version VARCHAR(20),
ADD COLUMN tos_accepted_at TIMESTAMPTZ;
```

---

## Functions

### 1. is_blocked_by(target_user_id, viewer_user_id)

Check if viewer is blocked by target.

```sql
CREATE OR REPLACE FUNCTION is_blocked_by(target_user_id UUID, viewer_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_blocks
    WHERE blocker_id = target_user_id
    AND blocked_id = viewer_user_id
  );
$$;
```

### 2. is_user_banned(check_user_id)

Check if user has active ban.

```sql
CREATE OR REPLACE FUNCTION is_user_banned(check_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_sanctions
    WHERE user_id = check_user_id
    AND type = 'ban'
    AND lifted_at IS NULL
    AND (expires_at IS NULL OR expires_at > NOW())
  );
$$;
```

### 3. check_banned_content(input_text)

Check text against banned words list.

```sql
CREATE OR REPLACE FUNCTION check_banned_content(input_text TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSONB := '{"blocked": false, "matched_words": []}';
  banned_record RECORD;
  lower_text TEXT := LOWER(input_text);
  matched_words TEXT[] := ARRAY[]::TEXT[];
BEGIN
  FOR banned_record IN
    SELECT word, pattern_type, severity FROM banned_words
    WHERE deleted_at IS NULL
  LOOP
    IF banned_record.pattern_type = 'exact' AND lower_text = LOWER(banned_record.word) THEN
      matched_words := array_append(matched_words, banned_record.word);
    ELSIF banned_record.pattern_type = 'contains' AND lower_text LIKE '%' || LOWER(banned_record.word) || '%' THEN
      matched_words := array_append(matched_words, banned_record.word);
    ELSIF banned_record.pattern_type = 'regex' AND lower_text ~ banned_record.word THEN
      matched_words := array_append(matched_words, banned_record.word);
    END IF;
  END LOOP;

  IF array_length(matched_words, 1) > 0 THEN
    result := jsonb_build_object(
      'blocked', TRUE,
      'matched_words', to_jsonb(matched_words)
    );
  END IF;

  RETURN result;
END;
$$;
```

### 4. has_accepted_current_tos(check_user_id)

Check if user has accepted the current ToS version.

```sql
CREATE OR REPLACE FUNCTION has_accepted_current_tos(check_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_tos_version TEXT := '1.0.0';  -- Update when ToS changes
  user_tos_version TEXT;
BEGIN
  SELECT tos_accepted_version INTO user_tos_version
  FROM profiles
  WHERE user_id = check_user_id;

  RETURN user_tos_version = current_tos_version;
END;
$$;
```

---

## RLS Policies

### reports

```sql
-- Authenticated users can create reports
CREATE POLICY "Users can create reports"
ON reports FOR INSERT
TO authenticated
WITH CHECK (reporter_id = auth.uid());

-- Users can see their own reports
CREATE POLICY "Users can view own reports"
ON reports FOR SELECT
TO authenticated
USING (reporter_id = auth.uid());

-- Moderators can view all reports
CREATE POLICY "Moderators can view all reports"
ON reports FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  )
);

-- Moderators can update reports
CREATE POLICY "Moderators can update reports"
ON reports FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  )
);
```

### user_blocks

```sql
-- Users can create blocks
CREATE POLICY "Users can block others"
ON user_blocks FOR INSERT
TO authenticated
WITH CHECK (blocker_id = auth.uid());

-- Users can see their own blocks
CREATE POLICY "Users can view own blocks"
ON user_blocks FOR SELECT
TO authenticated
USING (blocker_id = auth.uid());

-- Users can delete their own blocks (unblock)
CREATE POLICY "Users can unblock"
ON user_blocks FOR DELETE
TO authenticated
USING (blocker_id = auth.uid());

-- Moderators can view all blocks
CREATE POLICY "Moderators can view all blocks"
ON user_blocks FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  )
);
```

### banned_words

```sql
-- Only moderators/admins can manage
CREATE POLICY "Moderators can manage banned words"
ON banned_words FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  )
);

-- Authenticated users can read for client-side validation
CREATE POLICY "Users can read banned words"
ON banned_words FOR SELECT
TO authenticated
USING (deleted_at IS NULL);
```

### user_sanctions

```sql
-- Only moderators can create/manage sanctions
CREATE POLICY "Moderators can manage sanctions"
ON user_sanctions FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  )
);

-- Users can see their own sanctions
CREATE POLICY "Users can view own sanctions"
ON user_sanctions FOR SELECT
TO authenticated
USING (user_id = auth.uid());
```

---

## Triggers

### 1. Notify moderators on new block

```sql
CREATE OR REPLACE FUNCTION notify_moderators_on_block()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Insert notification for all moderators
  INSERT INTO notifications (recipient_id, sender_id, type, title, description, target_type, target_id)
  SELECT
    ur.user_id,
    NEW.blocker_id,
    'user_block',
    'Nuovo blocco utente',
    (SELECT full_name FROM profiles WHERE user_id = NEW.blocker_id) ||
    ' ha bloccato ' ||
    (SELECT full_name FROM profiles WHERE user_id = NEW.blocked_id),
    'user_block',
    NEW.id
  FROM user_roles ur
  WHERE ur.role IN ('moderator', 'admin');

  -- Mark as notified
  UPDATE user_blocks
  SET moderator_notified = TRUE, notified_at = NOW()
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_moderators_on_block
AFTER INSERT ON user_blocks
FOR EACH ROW
EXECUTE FUNCTION notify_moderators_on_block();
```

### 2. Auto-update report count on content

```sql
CREATE OR REPLACE FUNCTION update_content_report_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.content_type = 'comment' THEN
    UPDATE comments
    SET report_count = (
      SELECT COUNT(*) FROM reports
      WHERE content_type = 'comment' AND content_id = NEW.content_id
    )
    WHERE id = NEW.content_id;
  ELSIF NEW.content_type = 'chat_message' THEN
    UPDATE chat_messages
    SET report_count = (
      SELECT COUNT(*) FROM reports
      WHERE content_type = 'chat_message' AND content_id = NEW.content_id
    )
    WHERE id = NEW.content_id;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_content_report_count
AFTER INSERT ON reports
FOR EACH ROW
EXECUTE FUNCTION update_content_report_count();
```

---

## Migration Order

1. Add columns to `profiles` (tos_accepted_version, tos_accepted_at)
2. Create `reports` table with indexes
3. Create `user_blocks` table with indexes
4. Create `banned_words` table with indexes
5. Create `user_sanctions` table with indexes
6. Create helper functions
7. Enable RLS and create policies
8. Create triggers
9. Add 'user_block' to notifications type enum
10. Seed initial banned_words from existing `contains_profanity()` list
