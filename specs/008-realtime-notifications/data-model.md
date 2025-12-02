# Data Model: Real-Time In-App Notifications System

**Feature**: 008-realtime-notifications
**Date**: 2025-11-23
**Database**: PostgreSQL 15+ (Supabase)

## Entity Definitions

### Entity 1: Notification

**Purpose**: Represents a single notification sent to a user about an action related to their content.

**Table Name**: `notifications`

**Fields**:

| Field Name | Type | Constraints | Description |
|------------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Unique notification identifier |
| `recipient_id` | UUID | NOT NULL, FOREIGN KEY → profiles(id) | User receiving the notification |
| `sender_id` | UUID | NULLABLE, FOREIGN KEY → profiles(id) | User who triggered the notification (NULL for system notifications like moderation) |
| `type` | TEXT | NOT NULL, CHECK (type IN ('event_moderation', 'new_comment', 'comment_reply', 'event_like', 'event_participation', 'coorganizer_update')) | Notification channel type |
| `title` | TEXT | NOT NULL, LENGTH 1-200 | Bold notification title (e.g., "Marco ha commentato sul tuo evento") |
| `description` | TEXT | NOT NULL, LENGTH 1-500 | Notification body text (comment preview, rejection reason, etc.) |
| `target_type` | TEXT | NOT NULL, CHECK (target_type IN ('event', 'comment')) | Type of entity this notification links to |
| `target_id` | UUID | NOT NULL | ID of the target entity (event_id or comment_id) |
| `metadata` | JSONB | NOT NULL, DEFAULT '{}'::jsonb | Extensible metadata field (comment_id, reply_to_id, etc.) |
| `is_read` | BOOLEAN | NOT NULL, DEFAULT FALSE | Read status (false = unread, true = read) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | When notification was created |

**Indexes**:
```sql
CREATE INDEX idx_notifications_recipient_created ON notifications(recipient_id, created_at DESC);
CREATE INDEX idx_notifications_recipient_unread ON notifications(recipient_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_created_at ON notifications(created_at); -- For 90-day deletion
```

**RLS Policies**:
```sql
-- Users can only see their own notifications
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
USING (auth.uid() = recipient_id);

-- Users can update (mark as read) their own notifications
CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
USING (auth.uid() = recipient_id);

-- Users can delete their own notifications
CREATE POLICY "Users can delete own notifications"
ON notifications FOR DELETE
USING (auth.uid() = recipient_id);

-- Only database triggers can insert notifications (not direct user INSERT)
CREATE POLICY "System can insert notifications"
ON notifications FOR INSERT
WITH CHECK (FALSE); -- Explicit block, only SECURITY DEFINER functions allowed
```

**Validation Rules**:
- `title` must be 1-200 characters (prevent empty or excessively long titles)
- `description` must be 1-500 characters (balance detail with brevity)
- `type` must be one of 6 valid notification channels
- `target_type` must be 'event' or 'comment'
- `sender_id` must exist in profiles table OR be NULL (system notifications)
- `recipient_id` must exist in profiles table
- `target_id` must exist in corresponding table (events or comments)

**State Transitions**:
```
[Created] → is_read = FALSE (default state)
    ↓
[User taps notification]
    ↓
[Marked as Read] → is_read = TRUE (via UPDATE)
    ↓
[90 days pass]
    ↓
[Auto-Deleted] → Row removed from table (via pg_cron)
```

**Relationships**:
- **Many-to-One with profiles (recipient)**: Each notification belongs to one recipient user
- **Many-to-One with profiles (sender)**: Each notification may be triggered by one sender user (nullable for system)
- **Many-to-One with events**: Notification may reference one event (if target_type = 'event')
- **Many-to-One with comments**: Notification may reference one comment (if target_type = 'comment')

---

### Entity 2: NotificationPreferences

**Purpose**: Stores user's opt-in/opt-out preferences for each notification channel. Stored as extended columns on existing `profiles` table.

**Table Name**: `profiles` (extended)

**New Fields Added**:

| Field Name | Type | Constraints | Description |
|------------|------|-------------|-------------|
| `eventi_moderati_enabled` | BOOLEAN | NOT NULL, DEFAULT TRUE | Event moderation notifications (approved/rejected) |
| `nuovi_commenti_enabled` | BOOLEAN | NOT NULL, DEFAULT TRUE | New comment notifications on user's events |
| `risposte_commenti_enabled` | BOOLEAN | NOT NULL, DEFAULT TRUE | Reply notifications on user's comments |
| `like_eventi_enabled` | BOOLEAN | NOT NULL, DEFAULT TRUE | Like notifications on user's events |
| `nuove_partecipazioni_enabled` | BOOLEAN | NOT NULL, DEFAULT TRUE | Participation notifications on user's events |
| `coorganizer_updates_enabled` | BOOLEAN | NOT NULL, DEFAULT TRUE | Co-organizer update notifications |

**Validation Rules**:
- All preference fields must be boolean (TRUE or FALSE)
- All default to TRUE (opt-out model per constitutional requirement)
- No NULL values allowed (explicit TRUE/FALSE only)

**Relationships**:
- **One-to-One with profiles**: Each user has exactly one set of notification preferences (embedded in profile row)

**RLS Policies** (existing profiles RLS already covers):
```sql
-- Users can view their own profile (includes preferences)
-- Users can update their own profile (includes preferences)
-- Already implemented in existing profiles table
```

---

### Entity 3: NotificationChannel (Enum)

**Purpose**: Enumeration of the 6 notification types. Implemented as PostgreSQL CHECK constraint on `type` field.

**Enum Values**:

| Enum Value | Display Name (Italian) | Triggered By | Target Recipient |
|------------|----------------------|--------------|------------------|
| `event_moderation` | Eventi moderati | Moderator approves/rejects event | Event creator |
| `new_comment` | Nuovi commenti | User comments on event | Event creator |
| `comment_reply` | Risposte commenti | User replies to comment | Original commenter |
| `event_like` | Like agli eventi | User likes event | Event creator |
| `event_participation` | Nuove partecipazioni | User joins event as participant | Event creator |
| `coorganizer_update` | Co-organizer updates | Primary organizer edits event details | All co-organizers (except editor) |

**Implementation**:
```sql
-- CHECK constraint on type field (defined in notifications table)
ALTER TABLE notifications
ADD CONSTRAINT valid_notification_type
CHECK (type IN (
  'event_moderation',
  'new_comment',
  'comment_reply',
  'event_like',
  'event_participation',
  'coorganizer_update'
));
```

---

## Entity Relationships Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          profiles                                │
│ ─────────────────────────────────────────────────────────────── │
│ id (UUID, PK)                                                    │
│ name (TEXT)                                                      │
│ email (TEXT)                                                     │
│ ...existing fields...                                            │
│                                                                   │
│ -- NEW notification preference columns --                        │
│ eventi_moderati_enabled (BOOLEAN, DEFAULT TRUE)                 │
│ nuovi_commenti_enabled (BOOLEAN, DEFAULT TRUE)                  │
│ risposte_commenti_enabled (BOOLEAN, DEFAULT TRUE)               │
│ like_eventi_enabled (BOOLEAN, DEFAULT TRUE)                     │
│ nuove_partecipazioni_enabled (BOOLEAN, DEFAULT TRUE)            │
│ coorganizer_updates_enabled (BOOLEAN, DEFAULT TRUE)             │
└─────────────────────────────────────────────────────────────────┘
         ▲                                    ▲
         │ (recipient)                        │ (sender, nullable)
         │                                    │
┌────────┴────────────────────────────────────┴───────────────────┐
│                      notifications                               │
│ ──────────────────────────────────────────────────────────────  │
│ id (UUID, PK)                                                    │
│ recipient_id (UUID, FK → profiles.id, NOT NULL)                 │
│ sender_id (UUID, FK → profiles.id, NULLABLE)                    │
│ type (TEXT, CHECK constraint, NOT NULL)                         │
│ title (TEXT, 1-200 chars, NOT NULL)                             │
│ description (TEXT, 1-500 chars, NOT NULL)                       │
│ target_type (TEXT, CHECK: 'event' | 'comment', NOT NULL)        │
│ target_id (UUID, NOT NULL)                                      │
│ metadata (JSONB, DEFAULT '{}', NOT NULL)                        │
│ is_read (BOOLEAN, DEFAULT FALSE, NOT NULL)                      │
│ created_at (TIMESTAMPTZ, DEFAULT NOW(), NOT NULL)               │
└──────────────────────────────────────────────────────────────────┘
         │
         │ (target_type = 'event')
         ├──────────────┐
         │              │ (target_type = 'comment')
         ▼              ▼
┌─────────────┐  ┌──────────────┐
│   events    │  │   comments   │
│ ─────────── │  │ ──────────── │
│ id (UUID)   │  │ id (UUID)    │
│ title       │  │ content      │
│ ...         │  │ event_id     │
└─────────────┘  │ ...          │
                 └──────────────┘
```

---

## Data Access Patterns

### Pattern 1: Fetch User's Notifications (Notification Center)

**Query**:
```sql
SELECT
  n.id,
  n.sender_id,
  n.type,
  n.title,
  n.description,
  n.target_type,
  n.target_id,
  n.metadata,
  n.is_read,
  n.created_at,
  p.name AS sender_name,
  p.avatar_url AS sender_avatar_url
FROM notifications n
LEFT JOIN profiles p ON n.sender_id = p.id
WHERE n.recipient_id = :current_user_id
ORDER BY n.created_at DESC
LIMIT 100;
```

**Index Used**: `idx_notifications_recipient_created` (optimized for this exact query)

**Expected Performance**: <50ms for typical user (50-100 notifications), <10ms if cached

---

### Pattern 2: Get Unread Count (Badge)

**Query**:
```sql
SELECT COUNT(*)
FROM notifications
WHERE recipient_id = :current_user_id
  AND is_read = FALSE;
```

**Index Used**: `idx_notifications_recipient_unread` (partial index on unread only)

**Expected Performance**: <10ms (index scan only, no table scan)

---

### Pattern 3: Mark Notification as Read

**Query**:
```sql
UPDATE notifications
SET is_read = TRUE
WHERE id = :notification_id
  AND recipient_id = :current_user_id; -- RLS ensures this, but explicit check
```

**Index Used**: Primary key index on `id`

**Expected Performance**: <5ms (single row update by PK)

---

### Pattern 4: Delete Notification

**Query**:
```sql
DELETE FROM notifications
WHERE id = :notification_id
  AND recipient_id = :current_user_id; -- RLS ensures this, but explicit check
```

**Index Used**: Primary key index on `id`

**Expected Performance**: <5ms (single row delete by PK)

---

### Pattern 5: Get User's Notification Preferences

**Query**:
```sql
SELECT
  eventi_moderati_enabled,
  nuovi_commenti_enabled,
  risposte_commenti_enabled,
  like_eventi_enabled,
  nuove_partecipazioni_enabled,
  coorganizer_updates_enabled
FROM profiles
WHERE id = :current_user_id;
```

**Index Used**: Primary key index on `profiles.id`

**Expected Performance**: <5ms (single row lookup by PK)

---

### Pattern 6: Update Notification Preferences

**Query**:
```sql
UPDATE profiles
SET
  eventi_moderati_enabled = :eventi_moderati_enabled,
  nuovi_commenti_enabled = :nuovi_commenti_enabled,
  risposte_commenti_enabled = :risposte_commenti_enabled,
  like_eventi_enabled = :like_eventi_enabled,
  nuove_partecipazioni_enabled = :nuove_partecipazioni_enabled,
  coorganizer_updates_enabled = :coorganizer_updates_enabled
WHERE id = :current_user_id;
```

**Index Used**: Primary key index on `profiles.id`

**Expected Performance**: <10ms (single row update by PK with 6 columns)

---

## Database Migration

**Migration File**: `supabase/migrations/008_realtime_notifications.sql`

**Migration Steps**:
1. Add notification preference columns to `profiles` table
2. Create `notifications` table with all columns
3. Create indexes for performance
4. Enable RLS on `notifications` table
5. Create RLS policies for SELECT, UPDATE, DELETE
6. Create `create_notification()` stored function
7. Create trigger functions for each notification type
8. Attach triggers to relevant tables (comments, likes, participations, events)
9. Enable pg_cron extension
10. Schedule 90-day auto-deletion job

**Rollback Strategy**:
- Drop all triggers first (prevent orphaned trigger calls)
- Drop stored functions
- Drop RLS policies
- Drop `notifications` table
- Remove preference columns from `profiles` (ALTER TABLE DROP COLUMN)

---

## Performance Considerations

**Table Growth Estimate**:
- 500-1000 active users
- 50-200 notifications per user per month
- With 90-day retention: ~1,500-6,000 notifications per user
- Total table size: 750k - 6M rows (worst case)
- Storage: ~50-400 MB (with indexes)

**Query Performance Targets**:
- Fetch notifications (100 rows): <50ms (p95), <20ms (p50)
- Unread count: <10ms (p95), <5ms (p50)
- Mark as read: <5ms (p95), <2ms (p50)
- Delete notification: <5ms (p95), <2ms (p50)
- Realtime subscription: <1s latency (CDC replication lag)

**Scaling Strategies** (if table exceeds 10M rows):
1. Partition `notifications` table by `created_at` (monthly partitions)
2. Archive notifications >90 days to separate `notifications_archive` table (read-only)
3. Add materialized view for unread counts (refresh every 5 minutes)
4. Implement notification batching (group similar notifications together)

Currently not needed for MVP scope (500-1000 users).
