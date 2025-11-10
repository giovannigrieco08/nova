# Data Model: Events Feed

**Feature**: 003-events-feed
**Date**: 2025-01-02
**Purpose**: Define all entities, relationships, fields, constraints, and validation rules for the Events Feed feature.

---

## Entity Relationship Diagram (ERD)

```text
┌─────────────────────┐
│      Users          │
│  (Supabase Auth)    │
└─────────────────────┘
          │
          │ created_by (1:N)
          ▼
┌─────────────────────┐         ┌────────────────────┐
│      Events         │◄────────│   Likes            │
│  (Approved Only)    │  (N:M)  │ (event_id,user_id) │
└─────────────────────┘         └────────────────────┘
          │
          │ event_id (1:N)
          ├──────────────────────┐
          │                      │
          ▼                      ▼
┌─────────────────────┐  ┌────────────────────┐
│    Comments         │  │  Participations    │
│  (500 char limit)   │  │ (event_id,user_id) │
└─────────────────────┘  └────────────────────┘
          │
          │ event_id (1:N)
          ▼
┌─────────────────────┐
│     Reports         │
│ (Moderation Queue)  │
└─────────────────────┘

┌─────────────────────┐
│  OfflineActions     │
│  (Hive only)        │
│ (Pending Sync Queue)│
└─────────────────────┘
```

---

## Entity 1: Event

**Description**: Represents a school event with metadata (title, description, date, time, location, images, creator, status, timestamps).

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Unique event identifier |
| `title` | VARCHAR(200) | NOT NULL | Event title (e.g., "School Dance 2025") |
| `description` | TEXT | NOT NULL | Full event description with details |
| `event_date` | DATE | NOT NULL | Date when event occurs (e.g., 2025-01-15) |
| `event_time` | TIME | NOT NULL | Time when event starts (e.g., 15:00:00) |
| `location` | VARCHAR(200) | NOT NULL | Event location (e.g., "School Gym") |
| `cover_images` | TEXT[] | DEFAULT '{}' | Array of Supabase Storage URLs (WebP, max 200KB each) |
| `creator_id` | UUID | NOT NULL, FOREIGN KEY → users(id) ON DELETE CASCADE | User who created the event |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'pending', CHECK IN ('pending', 'approved', 'rejected') | Moderation status |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Event creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Last update timestamp |

### Indexes

```sql
CREATE INDEX idx_events_date_status ON events(event_date, status);
CREATE INDEX idx_events_created_at ON events(created_at DESC);
CREATE INDEX idx_events_creator_id ON events(creator_id);
```

### Validation Rules

- **Title length**: 1-200 characters (enforced by VARCHAR(200))
- **Description**: Not empty (enforced by NOT NULL)
- **Event date**: Must be >= CURRENT_DATE for display in main feed (enforced by query, not constraint)
- **Status**: Must be 'pending', 'approved', or 'rejected' (CHECK constraint)
- **Images**: Maximum 5 images per event (enforced client-side)
- **Image format**: WebP only, max 200KB each (enforced by Supabase Edge Function)

### Relationships

- **Creator**: Many-to-One with Users (creator_id → users.id)
- **Likes**: One-to-Many with Likes (id ← likes.event_id)
- **Participations**: One-to-Many with Participations (id ← participations.event_id)
- **Comments**: One-to-Many with Comments (id ← comments.event_id)
- **Reports**: One-to-Many with Reports (id ← reports.event_id)

### State Transitions

```text
pending → approved (moderator approves)
pending → rejected (moderator rejects)
approved → (no transition - event published)
rejected → (no transition - event hidden)
```

### Row-Level Security (RLS) Policies

```sql
-- Users can view upcoming approved events only
CREATE POLICY "Users can view upcoming approved events"
  ON events FOR SELECT
  USING (
    status = 'approved'
    AND event_date >= CURRENT_DATE
  );

-- Users can edit/delete their own events
CREATE POLICY "Users can update their own events"
  ON events FOR UPDATE
  USING (creator_id = auth.uid());

CREATE POLICY "Users can delete their own events"
  ON events FOR DELETE
  USING (creator_id = auth.uid());
```

---

## Entity 2: User (Profile)

**Description**: Represents a student profile (from Supabase Auth) with minimal metadata for display purposes.

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, FOREIGN KEY → auth.users(id) ON DELETE CASCADE | Matches Supabase Auth user ID |
| `email` | VARCHAR(255) | NOT NULL, UNIQUE | School email (@galileimoro.edu.it) |
| `name` | VARCHAR(100) | NOT NULL | Student full name |
| `class` | VARCHAR(20) | NOT NULL | Class identifier (e.g., "5A Scientifico") |
| `avatar_url` | TEXT | NULL | Profile picture URL (Supabase Storage) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Account creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Last profile update timestamp |

### Indexes

```sql
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_class ON users(class);
```

### Validation Rules

- **Email**: Must match @galileimoro.edu.it domain (enforced by auth flow)
- **Name**: 1-100 characters (enforced by VARCHAR(100))
- **Class**: Not empty (enforced by NOT NULL)
- **Avatar**: Optional, WebP format preferred

### Relationships

- **Created Events**: One-to-Many with Events (id ← events.creator_id)
- **Likes**: One-to-Many with Likes (id ← likes.user_id)
- **Participations**: One-to-Many with Participations (id ← participations.user_id)
- **Comments**: One-to-Many with Comments (id ← comments.author_id)
- **Reports**: One-to-Many with Reports (id ← reports.reporter_id)

### Row-Level Security (RLS) Policies

```sql
-- Users can view all profiles (needed for event cards showing creator name)
CREATE POLICY "Users can view all profiles"
  ON users FOR SELECT
  USING (true);

-- Users can update their own profile only
CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE
  USING (id = auth.uid());
```

---

## Entity 3: Like

**Description**: Represents a user liking an event (many-to-many relationship with composite primary key).

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `user_id` | UUID | NOT NULL, FOREIGN KEY → users(id) ON DELETE CASCADE | User who liked the event |
| `event_id` | UUID | NOT NULL, FOREIGN KEY → events(id) ON DELETE CASCADE | Event that was liked |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Like timestamp |

### Primary Key

```sql
PRIMARY KEY (user_id, event_id)
```

### Indexes

```sql
CREATE INDEX idx_likes_event_id ON likes(event_id);
CREATE INDEX idx_likes_user_id ON likes(user_id);
```

### Validation Rules

- **Uniqueness**: A user can like an event only once (enforced by composite primary key)
- **Cascade delete**: If event is deleted, all likes are deleted (ON DELETE CASCADE)

### Relationships

- **User**: Many-to-One with Users (user_id → users.id)
- **Event**: Many-to-One with Events (event_id → events.id)

### Row-Level Security (RLS) Policies

```sql
-- Users can view all likes (needed for like count display)
CREATE POLICY "Users can view all likes"
  ON likes FOR SELECT
  USING (true);

-- Users can like any approved event
CREATE POLICY "Users can like events"
  ON likes FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_id
        AND events.status = 'approved'
    )
  );

-- Users can unlike their own likes only
CREATE POLICY "Users can unlike their own likes"
  ON likes FOR DELETE
  USING (user_id = auth.uid());
```

---

## Entity 4: Participation

**Description**: Represents a user RSVPing to an event (many-to-many relationship with composite primary key).

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `user_id` | UUID | NOT NULL, FOREIGN KEY → users(id) ON DELETE CASCADE | User who is participating |
| `event_id` | UUID | NOT NULL, FOREIGN KEY → events(id) ON DELETE CASCADE | Event being attended |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | RSVP timestamp |

### Primary Key

```sql
PRIMARY KEY (user_id, event_id)
```

### Indexes

```sql
CREATE INDEX idx_participations_event_id ON participations(event_id);
CREATE INDEX idx_participations_user_id ON participations(user_id);
```

### Validation Rules

- **Uniqueness**: A user can participate in an event only once (enforced by composite primary key)
- **Cascade delete**: If event is deleted, all participations are deleted (ON DELETE CASCADE)
- **Capacity limit**: If event has capacity field set, enforce limit (checked in application logic, not database constraint)

### Relationships

- **User**: Many-to-One with Users (user_id → users.id)
- **Event**: Many-to-One with Events (event_id → events.id)

### Row-Level Security (RLS) Policies

```sql
-- Users can view all participations (needed for participant count/list display)
CREATE POLICY "Users can view all participations"
  ON participations FOR SELECT
  USING (true);

-- Users can participate in any approved event
CREATE POLICY "Users can participate in events"
  ON participations FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_id
        AND events.status = 'approved'
    )
  );

-- Users can unparticipate from their own RSVPs only
CREATE POLICY "Users can unparticipate"
  ON participations FOR DELETE
  USING (user_id = auth.uid());
```

---

## Entity 5: Comment

**Description**: Represents a user comment on an event (with 500 character limit, chronological ordering).

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Unique comment identifier |
| `event_id` | UUID | NOT NULL, FOREIGN KEY → events(id) ON DELETE CASCADE | Event being commented on |
| `author_id` | UUID | NOT NULL, FOREIGN KEY → users(id) ON DELETE CASCADE | User who wrote the comment |
| `text` | VARCHAR(500) | NOT NULL, CHECK (length(trim(text)) > 0) | Comment text (max 500 chars) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Comment timestamp |

### Indexes

```sql
CREATE INDEX idx_comments_event_id ON comments(event_id);
CREATE INDEX idx_comments_created_at ON comments(created_at ASC);  -- Chronological order
```

### Validation Rules

- **Character limit**: Maximum 500 characters (enforced by VARCHAR(500))
- **Not empty**: Trimmed text must have at least 1 character (CHECK constraint)
- **Cascade delete**: If event is deleted, all comments are deleted (ON DELETE CASCADE)

### Relationships

- **Author**: Many-to-One with Users (author_id → users.id)
- **Event**: Many-to-One with Events (event_id → events.id)

### Row-Level Security (RLS) Policies

```sql
-- Users can view comments on approved events only
CREATE POLICY "Users can view comments on approved events"
  ON comments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = comments.event_id
        AND events.status = 'approved'
    )
  );

-- Users can post comments on approved events
CREATE POLICY "Users can post comments"
  ON comments FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_id
        AND events.status = 'approved'
    )
  );

-- Users can delete their own comments only
CREATE POLICY "Users can delete their own comments"
  ON comments FOR DELETE
  USING (author_id = auth.uid());
```

---

## Entity 6: Report

**Description**: Represents a user-submitted report for inappropriate content (links to moderation queue).

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Unique report identifier |
| `event_id` | UUID | NOT NULL, FOREIGN KEY → events(id) ON DELETE CASCADE | Event being reported |
| `reporter_id` | UUID | NOT NULL, FOREIGN KEY → users(id) ON DELETE CASCADE | User who submitted the report |
| `reason` | VARCHAR(50) | NOT NULL, CHECK IN ('inappropriate', 'spam', 'harassment', 'other') | Report reason category |
| `explanation` | TEXT | NOT NULL | Detailed explanation from reporter |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Report submission timestamp |
| `reviewed` | BOOLEAN | NOT NULL, DEFAULT false | Whether moderator has reviewed this report |

### Indexes

```sql
CREATE INDEX idx_reports_event_id ON reports(event_id);
CREATE INDEX idx_reports_reviewed ON reports(reviewed);
CREATE INDEX idx_reports_created_at ON reports(created_at DESC);
```

### Validation Rules

- **Reason**: Must be one of: 'inappropriate', 'spam', 'harassment', 'other' (CHECK constraint)
- **Explanation**: Not empty (enforced by NOT NULL)
- **One report per user per event**: Enforced client-side (no database constraint to allow multiple reports if needed)

### Relationships

- **Event**: Many-to-One with Events (event_id → events.id)
- **Reporter**: Many-to-One with Users (reporter_id → users.id)

### Row-Level Security (RLS) Policies

```sql
-- Users can view their own reports only
CREATE POLICY "Users can view their own reports"
  ON reports FOR SELECT
  USING (reporter_id = auth.uid());

-- Users can submit reports on any event
CREATE POLICY "Users can submit reports"
  ON reports FOR INSERT
  WITH CHECK (true);

-- Moderators can view all reports (handled by separate admin RLS)
-- Moderators can update reviewed status (handled by separate admin RLS)
```

---

## Entity 7: OfflineAction (Hive only, not in Supabase)

**Description**: Queued action (like, comment, participate) stored locally in Hive when offline, synced when back online.

### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | String (UUID) | PRIMARY KEY | Unique action identifier |
| `type` | String (enum) | NOT NULL, one of: 'like', 'unlike', 'comment', 'participate', 'unparticipate' | Action type |
| `payload` | Map<String, dynamic> | NOT NULL | JSON payload with action data (event_id, user_id, text, etc.) |
| `queuedAt` | DateTime | NOT NULL | Timestamp when action was queued |
| `retryCount` | int | NOT NULL, DEFAULT 0 | Number of retry attempts (max 3) |
| `lastRetryAt` | DateTime | NULL | Timestamp of last retry attempt |

### Hive Type Adapter

```dart
import 'package:hive/hive.dart';

part 'offline_action.g.dart';

@HiveType(typeId: 1)
class OfflineAction {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type;  // 'like', 'unlike', 'comment', 'participate', 'unparticipate'

  @HiveField(2)
  final Map<String, dynamic> payload;

  @HiveField(3)
  final DateTime queuedAt;

  @HiveField(4)
  final int retryCount;

  @HiveField(5)
  final DateTime? lastRetryAt;

  OfflineAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.queuedAt,
    this.retryCount = 0,
    this.lastRetryAt,
  });
}
```

### Validation Rules

- **Type**: Must be one of: 'like', 'unlike', 'comment', 'participate', 'unparticipate' (enforced in Dart code)
- **Retry limit**: Maximum 3 retry attempts (enforced in sync logic)
- **Expiration**: Actions older than 7 days are discarded (cleanup task)

### Sync Logic

1. **Queue action** when offline or optimistic UI is used
2. **Retry with exponential backoff** (1s, 2s, 4s) when back online
3. **Remove from queue** on success
4. **Show notification** if all 3 retries fail

---

## Database Triggers

### Auto-update `updated_at` Timestamp

```sql
-- Function to auto-update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to events table
CREATE TRIGGER update_events_updated_at
BEFORE UPDATE ON events
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Apply to users table
CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
```

---

## Aggregate Queries (Counts)

### Event Like Count

```sql
-- Efficient count query (uses index on likes.event_id)
SELECT COUNT(*) AS like_count
FROM likes
WHERE event_id = $1;
```

### Event Participant Count

```sql
-- Efficient count query (uses index on participations.event_id)
SELECT COUNT(*) AS participant_count
FROM participations
WHERE event_id = $1;
```

### Event Comment Count

```sql
-- Efficient count query (uses index on comments.event_id)
SELECT COUNT(*) AS comment_count
FROM comments
WHERE event_id = $1;
```

---

## Cache Strategy (Hive)

### Events Cache

```dart
// Hive box: 'events_cache'
// Type: Map<String, EventModel>
// Max size: 100 events (LRU eviction)
// TTL: None (persists until explicit clear or app uninstall)

class EventsLocalDataSource {
  final Box<EventModel> eventsBox;

  Future<void> cacheEvents(List<EventModel> events) async {
    // Store events by ID
    for (final event in events) {
      await eventsBox.put(event.id, event);
    }

    // Enforce 100-event limit (LRU eviction)
    if (eventsBox.length > 100) {
      final keys = eventsBox.keys.toList();
      final keysToDelete = keys.take(eventsBox.length - 100);
      await eventsBox.deleteAll(keysToDelete);
    }
  }

  List<EventModel> getCachedEvents({int page = 1, int limit = 20}) {
    final allEvents = eventsBox.values.toList();

    // Sort by created_at DESC (newest first)
    allEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Paginate
    final offset = (page - 1) * limit;
    return allEvents.skip(offset).take(limit).toList();
  }
}
```

---

## Summary

| Entity | Primary Key | Relationships | Storage |
|--------|-------------|---------------|---------|
| **Event** | id (UUID) | Creator (User), Likes, Participations, Comments, Reports | Supabase PostgreSQL |
| **User** | id (UUID) | Created Events, Likes, Participations, Comments, Reports | Supabase PostgreSQL |
| **Like** | (user_id, event_id) | User, Event | Supabase PostgreSQL |
| **Participation** | (user_id, event_id) | User, Event | Supabase PostgreSQL |
| **Comment** | id (UUID) | Author (User), Event | Supabase PostgreSQL |
| **Report** | id (UUID) | Reporter (User), Event | Supabase PostgreSQL |
| **OfflineAction** | id (String UUID) | None (local queue) | Hive (offline only) |

**Total Tables (Supabase)**: 6
**Total Hive Boxes**: 2 (events_cache, offline_actions_queue)

---

**Data Model Status**: ✅ Complete - All entities defined with fields, relationships, indexes, and RLS policies
