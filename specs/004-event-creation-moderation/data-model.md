# Data Model: Event Creation and Moderation System

**Feature**: 004-event-creation-moderation
**Phase**: 1 (Data Model & Schema Design)
**Date**: 2025-01-09

---

## Entity-Relationship Overview

```
┌─────────────┐       ┌─────────────┐       ┌──────────────┐
│    User     │──────<│    Event    │>──────│ Notification │
│  (existing) │ 1:N   │             │ 1:N   │              │
└─────────────┘       └─────────────┘       └──────────────┘
       │                     │
       │                     │
       │                     │ M:N (via co_organizers array)
       └─────────────────────┘
```

**Relationships:**
1. User (1) → Events (N): One user creates many events (`creator_id` foreign key)
2. Event (1) → Notifications (N): One event triggers many notifications (approval, rejection, etc.)
3. User (M) ← → Event (N): Many-to-many via `co_organizers` UUID array (up to 3 co-organizers per event)

---

## Database Schema

### 1. Events Table

**Table Name**: `events`

```sql
CREATE TABLE events (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Content Fields (from FR-001)
  title TEXT NOT NULL CHECK (char_length(title) >= 5 AND char_length(title) <= 100),
  description TEXT NOT NULL CHECK (char_length(description) >= 20 AND char_length(description) <= 500),
  event_date TIMESTAMP WITH TIME ZONE NOT NULL CHECK (event_date > now()),
  location TEXT, -- Optional field (clarified in spec)
  image_url TEXT, -- Optional, Supabase Storage public URL

  -- Ownership & Collaboration
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  co_organizers UUID[] DEFAULT '{}', -- Array of user IDs (max 3, enforced in app)

  -- Moderation Fields
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  rejection_reason TEXT, -- Populated only when status='rejected' (min 10 chars, enforced in app)
  moderated_by UUID REFERENCES auth.users(id), -- Moderator who approved/rejected
  moderated_at TIMESTAMP WITH TIME ZONE, -- When moderation decision was made

  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Indexes for Performance
CREATE INDEX idx_events_status ON events(status); -- Fast pending queue lookup
CREATE INDEX idx_events_creator_id ON events(creator_id); -- Fast "My Events" lookup
CREATE INDEX idx_events_event_date ON events(event_date) WHERE status = 'approved'; -- Fast feed sorting
CREATE INDEX idx_events_created_at ON events(created_at) WHERE status = 'pending'; -- FIFO moderation queue
CREATE INDEX idx_events_co_organizers ON events USING GIN (co_organizers); -- Fast co-organizer lookup

-- Trigger for updated_at
CREATE TRIGGER set_events_updated_at
  BEFORE UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_updated_at();
```

**Validation Rules (enforced at DB + app layer):**
- Title: 5-100 characters (CHECK constraint)
- Description: 20-500 characters (CHECK constraint)
- Event Date: Must be in future (CHECK constraint)
- Status: Enum ('pending', 'approved', 'rejected')
- Rejection Reason: Required when status='rejected', min 10 characters (app-enforced per FR-016)
- Co-organizers: Max 3 (app-enforced per FR-027)

**State Transitions:**
```
pending ──[moderator approves]──> approved
pending ──[moderator rejects]───> rejected
rejected ─[creator edits]────────> pending (resubmission)
approved ─[co-organizer edits]──> pending (re-moderation per FR-033)
```

---

### 2. Notifications Table

**Table Name**: `notifications`

```sql
CREATE TABLE notifications (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Recipient
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Notification Content
  channel TEXT NOT NULL CHECK (channel IN (
    'event_approved',
    'event_rejected',
    'new_pending_event',
    'added_as_coorganizer',
    'event_modified'
  )),
  title TEXT NOT NULL,
  body TEXT NOT NULL,

  -- Event Reference
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,

  -- Metadata
  sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  read BOOLEAN NOT NULL DEFAULT false,
  delivered BOOLEAN NOT NULL DEFAULT false -- FCM delivery confirmation
);

-- Indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(user_id, read) WHERE read = false;
CREATE INDEX idx_notifications_sent_at ON notifications(sent_at DESC);
```

**Notification Channels (from FR-037, FR-036):**
- `event_approved`: Student receives when their event is approved
- `event_rejected`: Student receives when their event is rejected
- `new_pending_event`: Moderator receives (batched daily per FR-040)
- `added_as_coorganizer`: User receives when added as co-organizer (FR-029)
- `event_modified`: Co-organizers + creator receive when event is edited (FR-034)

---

## Row-Level Security (RLS) Policies

### Events Table Policies

**Enable RLS:**
```sql
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
```

**Policy 1: Public Read for Approved Events**
```sql
CREATE POLICY "Public can read approved events"
  ON events
  FOR SELECT
  USING (status = 'approved');
```

**Policy 2: Moderators Can Read All Events**
```sql
CREATE POLICY "Moderators can read all events"
  ON events
  FOR SELECT
  USING (
    -- User is moderator (from custom claim in JWT)
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'moderator'
  );
```

**Policy 3: Creators Can Read Their Own Events (Any Status)**
```sql
CREATE POLICY "Creators can read their own events"
  ON events
  FOR SELECT
  USING (creator_id = auth.uid());
```

**Policy 4: Co-Organizers Can Read Their Events**
```sql
CREATE POLICY "Co-organizers can read their events"
  ON events
  FOR SELECT
  USING (auth.uid() = ANY(co_organizers));
```

**Policy 5: Authenticated Users Can Create Events**
```sql
CREATE POLICY "Authenticated users can create events"
  ON events
  FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated'
    AND creator_id = auth.uid()
    AND status = 'pending' -- New events must start as pending
  );
```

**Policy 6: Creators and Co-Organizers Can Update Events (Except Status)**
```sql
CREATE POLICY "Creators and co-organizers can update events"
  ON events
  FOR UPDATE
  USING (
    creator_id = auth.uid()
    OR auth.uid() = ANY(co_organizers)
  )
  WITH CHECK (
    -- Prevent status changes by non-moderators
    (OLD.status IS NOT DISTINCT FROM NEW.status)
    OR ((auth.jwt() -> 'user_metadata' ->> 'role') = 'moderator')
  );
```

**Policy 7: Only Moderators Can Approve/Reject Events**
```sql
CREATE POLICY "Only moderators can change event status"
  ON events
  FOR UPDATE
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'moderator')
  WITH CHECK (
    -- Moderator can change status
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'moderator'
    -- And must populate moderated_by and moderated_at when changing status
    AND (OLD.status = NEW.status OR (moderated_by IS NOT NULL AND moderated_at IS NOT NULL))
  );
```

**Policy 8: Creators Can Delete Their Own Pending/Rejected Events**
```sql
CREATE POLICY "Creators can delete own pending/rejected events"
  ON events
  FOR DELETE
  USING (
    creator_id = auth.uid()
    AND status IN ('pending', 'rejected')
  );
```

---

### Notifications Table Policies

**Enable RLS:**
```sql
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
```

**Policy 1: Users Can Only Read Their Own Notifications**
```sql
CREATE POLICY "Users can read own notifications"
  ON notifications
  FOR SELECT
  USING (user_id = auth.uid());
```

**Policy 2: System Can Insert Notifications (Backend Function)**
```sql
CREATE POLICY "System can insert notifications"
  ON notifications
  FOR INSERT
  WITH CHECK (true); -- System-level insert via service role key
```

**Policy 3: Users Can Mark Their Notifications as Read**
```sql
CREATE POLICY "Users can update own notifications"
  ON notifications
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

---

## Database Functions

### Function 1: Notify Event Approval

```sql
CREATE OR REPLACE FUNCTION notify_event_approval()
RETURNS TRIGGER AS $$
BEGIN
  -- Only trigger when status changes to 'approved'
  IF NEW.status = 'approved' AND OLD.status = 'pending' THEN
    -- Insert notification for creator
    INSERT INTO notifications (user_id, channel, title, body, event_id)
    VALUES (
      NEW.creator_id,
      'event_approved',
      'Evento Approvato!',
      '✅ Evento "' || NEW.title || '" approvato! È ora visibile a tutti',
      NEW.id
    );

    -- TODO: Trigger FCM push via Edge Function (not in this function)
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_event_approval
  AFTER UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION notify_event_approval();
```

### Function 2: Notify Event Rejection

```sql
CREATE OR REPLACE FUNCTION notify_event_rejection()
RETURNS TRIGGER AS $$
BEGIN
  -- Only trigger when status changes to 'rejected'
  IF NEW.status = 'rejected' AND OLD.status = 'pending' THEN
    -- Insert notification for creator
    INSERT INTO notifications (user_id, channel, title, body, event_id)
    VALUES (
      NEW.creator_id,
      'event_rejected',
      'Evento Non Approvato',
      '❌ Evento "' || NEW.title || '" non approvato',
      NEW.id
    );

    -- TODO: Trigger FCM push via Edge Function
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_event_rejection
  AFTER UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION notify_event_rejection();
```

### Function 3: Notify Co-Organizer Addition

```sql
CREATE OR REPLACE FUNCTION notify_co_organizer_addition()
RETURNS TRIGGER AS $$
DECLARE
  added_user_id UUID;
BEGIN
  -- Find newly added co-organizers (compare OLD and NEW arrays)
  FOR added_user_id IN
    SELECT unnest(NEW.co_organizers)
    EXCEPT
    SELECT unnest(OLD.co_organizers)
  LOOP
    INSERT INTO notifications (user_id, channel, title, body, event_id)
    VALUES (
      added_user_id,
      'added_as_coorganizer',
      'Aggiunto come Co-Organizzatore',
      (SELECT full_name FROM auth.users WHERE id = NEW.creator_id) ||
        ' ti ha aggiunto come co-organizer dell''evento "' || NEW.title || '"',
      NEW.id
    );
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_co_organizer_addition
  AFTER UPDATE ON events
  FOR EACH ROW
  WHEN (OLD.co_organizers IS DISTINCT FROM NEW.co_organizers)
  EXECUTE FUNCTION notify_co_organizer_addition();
```

---

## Flutter Entity Models (Freezed)

### Event Entity

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'event.freezed.dart';
part 'event.g.dart';

@freezed
class Event with _$Event {
  const factory Event({
    required String id,
    required String title,
    required String description,
    required DateTime eventDate,
    String? location,
    String? imageUrl,
    required String creatorId,
    @Default([]) List<String> coOrganizers,
    required EventStatus status,
    String? rejectionReason,
    String? moderatedBy,
    DateTime? moderatedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Event;

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
}

enum EventStatus {
  @JsonValue('pending') pending,
  @JsonValue('approved') approved,
  @JsonValue('rejected') rejected,
}
```

### Notification Entity

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification.freezed.dart';
part 'notification.g.dart';

@freezed
class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    required String userId,
    required NotificationChannel channel,
    required String title,
    required String body,
    String? eventId,
    required DateTime sentAt,
    @Default(false) bool read,
    @Default(false) bool delivered,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}

enum NotificationChannel {
  @JsonValue('event_approved') eventApproved,
  @JsonValue('event_rejected') eventRejected,
  @JsonValue('new_pending_event') newPendingEvent,
  @JsonValue('added_as_coorganizer') addedAsCoorganizer,
  @JsonValue('event_modified') eventModified,
}
```

---

## Migration File

**File**: `supabase/migrations/005_create_events_tables.sql`

See full migration in `contracts/` directory.

---

## Summary

**Tables Created**: 2 (events, notifications)
**RLS Policies**: 11 total (8 for events, 3 for notifications)
**Database Functions**: 3 (approval, rejection, co-organizer notifications)
**Indexes**: 8 (optimized for pending queue, feed sorting, user lookups)
**Foreign Keys**: 3 (creator_id, moderated_by, user_id in notifications)

**Data Model Status**: ✅ Complete. Proceed to Contracts generation.
