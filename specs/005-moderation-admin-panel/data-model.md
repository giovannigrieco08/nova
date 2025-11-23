# Data Model: Admin Panel & Moderation Queue

**Feature**: 005-moderation-admin-panel
**Version**: 1.0
**Created**: 2025-11-13
**Database**: PostgreSQL 15+ (Supabase Cloud)
**Region**: EU Frankfurt (GDPR compliance)

---

## Table of Contents

1. [Entity Definitions](#entity-definitions)
2. [Row-Level Security (RLS) Policies](#row-level-security-rls-policies)
3. [Database Functions](#database-functions)
4. [Triggers](#triggers)
5. [Indexes](#indexes)
6. [State Transitions](#state-transitions)
7. [Data Retention](#data-retention)

---

## Entity Definitions

### 1. User Roles Table

Stores role assignments for the three-tier role system (student, moderator, admin).

```sql
-- User roles table
CREATE TABLE user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('student', 'moderator', 'admin')),
  assigned_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  assigned_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(user_id, role)
);

-- Comments for documentation
COMMENT ON TABLE user_roles IS 'Stores user role assignments for access control';
COMMENT ON COLUMN user_roles.user_id IS 'Foreign key to auth.users table';
COMMENT ON COLUMN user_roles.role IS 'One of: student (default), moderator, admin';
COMMENT ON COLUMN user_roles.assigned_by IS 'Admin who assigned this role (NULL for default student role)';

-- Enable RLS
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
```

**Rationale**: Separate table for roles (vs. single column in profiles) allows multiple future roles per user and maintains audit trail of role assignments.

---

### 2. Events Table (Modifications)

Adds moderation-specific columns to existing events table.

```sql
-- Moderation columns added to existing events table
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS moderated_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS moderated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS submission_count INTEGER DEFAULT 1 NOT NULL CHECK (submission_count > 0);

-- Comments
COMMENT ON COLUMN events.status IS 'Event approval status: pending (in queue), approved (visible to all), rejected (visible to creator only)';
COMMENT ON COLUMN events.moderated_by IS 'User ID of moderator who approved/rejected this event';
COMMENT ON COLUMN events.moderated_at IS 'Timestamp when event was moderated';
COMMENT ON COLUMN events.rejection_reason IS 'Reason provided by moderator when rejecting (NULL if approved)';
COMMENT ON COLUMN events.submission_count IS 'Number of times this event was submitted (increments on re-submission after rejection)';

-- Constraints
ALTER TABLE events
  ADD CONSTRAINT moderated_data_consistency
  CHECK (
    (status = 'pending' AND moderated_by IS NULL AND moderated_at IS NULL AND rejection_reason IS NULL)
    OR
    (status = 'approved' AND moderated_by IS NOT NULL AND moderated_at IS NOT NULL AND rejection_reason IS NULL)
    OR
    (status = 'rejected' AND moderated_by IS NOT NULL AND moderated_at IS NOT NULL AND rejection_reason IS NOT NULL)
  );

COMMENT ON CONSTRAINT moderated_data_consistency ON events IS 'Ensures moderation metadata is consistent with status';
```

**Rationale**: Constraints enforce data integrity at database level. `submission_count` tracks re-submissions for analytics (no limit enforced per Assumption #10).

---

### 3. Moderation Log Table

Immutable audit trail of all moderation actions.

```sql
-- Moderation log table
CREATE TABLE moderation_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
  moderator_id UUID REFERENCES auth.users(id) ON DELETE SET NULL NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('approved', 'rejected')),
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Comments
COMMENT ON TABLE moderation_log IS 'Immutable audit trail of moderation actions (used for statistics and accountability)';
COMMENT ON COLUMN moderation_log.event_id IS 'Event that was moderated';
COMMENT ON COLUMN moderation_log.moderator_id IS 'User who performed the moderation (SET NULL on user deletion to preserve audit history)';
COMMENT ON COLUMN moderation_log.action IS 'approved or rejected';
COMMENT ON COLUMN moderation_log.rejection_reason IS 'Reason provided if action was rejected (NULL if approved)';

-- Enable RLS
ALTER TABLE moderation_log ENABLE ROW LEVEL SECURITY;

-- Constraints
ALTER TABLE moderation_log
  ADD CONSTRAINT rejection_reason_required_if_rejected
  CHECK (
    (action = 'approved' AND rejection_reason IS NULL)
    OR
    (action = 'rejected' AND rejection_reason IS NOT NULL)
  );

COMMENT ON CONSTRAINT rejection_reason_required_if_rejected ON moderation_log IS 'Ensures rejection reason is provided when action is rejected';
```

**Rationale**: Immutable log table (no UPDATE/DELETE policies) preserves complete audit trail. `ON DELETE SET NULL` for moderator_id preserves history when moderators leave.

---

### 4. Admin Log Table

Immutable audit trail of administrative actions (role promotions/removals).

```sql
-- Admin log table
CREATE TABLE admin_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES auth.users(id) ON DELETE SET NULL NOT NULL,
  target_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('promoted', 'removed')),
  old_role TEXT CHECK (old_role IN ('student', 'moderator', 'admin')),
  new_role TEXT NOT NULL CHECK (new_role IN ('student', 'moderator', 'admin')),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Comments
COMMENT ON TABLE admin_log IS 'Immutable audit trail of administrative role changes';
COMMENT ON COLUMN admin_log.admin_id IS 'Admin who performed the action (SET NULL on deletion to preserve history)';
COMMENT ON COLUMN admin_log.target_user_id IS 'User whose role was changed (CASCADE delete when user deleted)';
COMMENT ON COLUMN admin_log.action IS 'promoted (student → moderator) or removed (moderator → student)';
COMMENT ON COLUMN admin_log.old_role IS 'Role before change (NULL for initial role assignment)';
COMMENT ON COLUMN admin_log.new_role IS 'Role after change';

-- Enable RLS
ALTER TABLE admin_log ENABLE ROW LEVEL SECURITY;
```

**Rationale**: Tracks accountability for role changes. `old_role` NULL for initial assignments (e.g., first admin created manually).

---

### 5. Role History Table

Tracks complete history of role changes for each user (supports statistics restoration).

```sql
-- Role history table
CREATE TABLE role_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  old_role TEXT CHECK (old_role IN ('student', 'moderator', 'admin')),
  new_role TEXT NOT NULL CHECK (new_role IN ('student', 'moderator', 'admin')),
  changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  changed_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Comments
COMMENT ON TABLE role_history IS 'Complete history of role changes (enables statistics restoration when user re-promoted)';
COMMENT ON COLUMN role_history.user_id IS 'User whose role changed';
COMMENT ON COLUMN role_history.old_role IS 'Previous role (NULL for initial assignment)';
COMMENT ON COLUMN role_history.new_role IS 'New role';
COMMENT ON COLUMN role_history.changed_by IS 'Admin who made the change (NULL for system-initiated changes)';

-- Enable RLS
ALTER TABLE role_history ENABLE ROW LEVEL SECURITY;
```

**Rationale**: Separate from admin_log to track all role transitions, including system-initiated changes. Supports Assumption #9 (restore statistics when user re-promoted).

---

### 6. Moderator Statistics Table

Stores aggregated statistics for each moderator (calculated from moderation_log).

```sql
-- Moderator statistics table
CREATE TABLE moderator_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  total_reviews INTEGER DEFAULT 0 NOT NULL CHECK (total_reviews >= 0),
  reviews_today INTEGER DEFAULT 0 NOT NULL CHECK (reviews_today >= 0),
  reviews_this_week INTEGER DEFAULT 0 NOT NULL CHECK (reviews_this_week >= 0),
  approval_count INTEGER DEFAULT 0 NOT NULL CHECK (approval_count >= 0),
  rejection_count INTEGER DEFAULT 0 NOT NULL CHECK (rejection_count >= 0),
  approval_rate_percent NUMERIC(5,2) DEFAULT 0 NOT NULL CHECK (approval_rate_percent BETWEEN 0 AND 100),
  last_review_at TIMESTAMPTZ,
  stats_updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Comments
COMMENT ON TABLE moderator_stats IS 'Aggregated moderation statistics per moderator (derived from moderation_log)';
COMMENT ON COLUMN moderator_stats.user_id IS 'Moderator user ID (unique, one stats record per moderator)';
COMMENT ON COLUMN moderator_stats.total_reviews IS 'Total number of moderation actions (approved + rejected) all-time';
COMMENT ON COLUMN moderator_stats.reviews_today IS 'Number of reviews performed today (resets daily at midnight UTC)';
COMMENT ON COLUMN moderator_stats.reviews_this_week IS 'Number of reviews this week (Monday 00:00 UTC - Sunday 23:59 UTC)';
COMMENT ON COLUMN moderator_stats.approval_count IS 'Total approved events';
COMMENT ON COLUMN moderator_stats.rejection_count IS 'Total rejected events';
COMMENT ON COLUMN moderator_stats.approval_rate_percent IS 'Calculated as (approval_count / total_reviews) × 100';
COMMENT ON COLUMN moderator_stats.last_review_at IS 'Timestamp of most recent moderation action';
COMMENT ON COLUMN moderator_stats.stats_updated_at IS 'When these statistics were last recalculated';

-- Enable RLS
ALTER TABLE moderator_stats ENABLE ROW LEVEL SECURITY;
```

**Rationale**: Denormalized statistics table for performance (avoids aggregating moderation_log on every query). Updated via triggers on moderation_log inserts.

---

### 7. Moderator Statistics Archive Table

Stores archived statistics when moderator role is removed (supports restoration on re-promotion).

```sql
-- Moderator statistics archive table
CREATE TABLE moderator_stats_archive (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  archived_stats JSONB NOT NULL,
  archived_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  archived_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Comments
COMMENT ON TABLE moderator_stats_archive IS 'Archived moderator statistics when role removed (supports restoration on re-promotion per Assumption #9)';
COMMENT ON COLUMN moderator_stats_archive.user_id IS 'User whose statistics were archived';
COMMENT ON COLUMN moderator_stats_archive.archived_stats IS 'Full moderator_stats record as JSON';
COMMENT ON COLUMN moderator_stats_archive.archived_at IS 'When the statistics were archived';
COMMENT ON COLUMN moderator_stats_archive.archived_by IS 'Admin who removed the moderator role';

-- Enable RLS
ALTER TABLE moderator_stats_archive ENABLE ROW LEVEL SECURITY;

-- Index for restoration queries
CREATE INDEX idx_moderator_stats_archive_user_id ON moderator_stats_archive(user_id, archived_at DESC);
```

**Rationale**: JSONB column stores complete snapshot of moderator_stats. Most recent archive retrieved when user re-promoted (index on user_id + archived_at DESC).

---

### 8. Notifications Table

Stores notification records for push notification delivery via Edge Function webhook.

```sql
-- Notifications table
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB,
  sent BOOLEAN DEFAULT FALSE NOT NULL,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Comments
COMMENT ON TABLE notifications IS 'Notification queue for push notification delivery via Supabase Edge Function webhook';
COMMENT ON COLUMN notifications.recipient_id IS 'User who should receive the notification';
COMMENT ON COLUMN notifications.title IS 'Notification title (e.g., "Event Approved!")';
COMMENT ON COLUMN notifications.body IS 'Notification body text';
COMMENT ON COLUMN notifications.data IS 'Deep link payload (e.g., {"type": "event_moderation", "event_id": "..."})';
COMMENT ON COLUMN notifications.sent IS 'Whether notification was successfully sent via FCM';
COMMENT ON COLUMN notifications.sent_at IS 'When notification was sent (NULL if pending)';

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Index for unsent notifications (processed by Edge Function)
CREATE INDEX idx_notifications_unsent ON notifications(created_at) WHERE sent = FALSE;
```

**Rationale**: Webhook triggers on INSERT to this table. `sent` flag updated by Edge Function after successful FCM delivery. Supports notification history for future in-app notification center.

---

### 9. System Statistics View

Read-only view aggregating system-wide statistics for Admin Panel.

```sql
-- System statistics view
CREATE OR REPLACE VIEW system_statistics AS
SELECT
  -- Event counts
  COUNT(*) FILTER (WHERE status = 'pending') AS pending_events,
  COUNT(*) FILTER (WHERE status = 'approved') AS approved_events,
  COUNT(*) FILTER (WHERE status = 'rejected') AS rejected_events,
  COUNT(*) AS total_events,

  -- Event percentages
  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'pending') / NULLIF(COUNT(*), 0), 2) AS pending_percent,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'approved') / NULLIF(COUNT(*), 0), 2) AS approved_percent,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'rejected') / NULLIF(COUNT(*), 0), 2) AS rejected_percent,

  -- Events pending over 24 hours
  COUNT(*) FILTER (WHERE status = 'pending' AND created_at < NOW() - INTERVAL '24 hours') AS events_pending_over_24h,

  -- Moderator counts
  (SELECT COUNT(DISTINCT user_id) FROM user_roles WHERE role IN ('moderator', 'admin')) AS total_moderators,
  (SELECT COUNT(DISTINCT user_id) FROM user_roles
   WHERE role IN ('moderator', 'admin')
   AND user_id IN (SELECT DISTINCT moderator_id FROM moderation_log WHERE created_at > NOW() - INTERVAL '7 days')) AS active_moderators_7d,

  -- Average review time (rolling 7-day window)
  (SELECT EXTRACT(EPOCH FROM AVG(moderated_at - events.created_at)) / 60
   FROM events
   WHERE moderated_at > NOW() - INTERVAL '7 days' AND moderated_at IS NOT NULL) AS avg_review_time_minutes,

  -- Current backlog size
  COUNT(*) FILTER (WHERE status = 'pending') AS current_backlog

FROM events;

COMMENT ON VIEW system_statistics IS 'Aggregated system-wide statistics for Admin Panel (calculated from events and moderation_log tables)';
```

**Rationale**: Materialized as view (not table) ensures always-current data. Single query provides all admin dashboard metrics. Average review time uses rolling 7-day window per FR-046.

---

## Row-Level Security (RLS) Policies

### User Roles Table

```sql
-- RLS Policy: Admins can manage roles
CREATE POLICY "Admins can manage roles"
ON user_roles FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

-- RLS Policy: Users can view their own roles
CREATE POLICY "Users can view own roles"
ON user_roles FOR SELECT
TO authenticated
USING (user_id = auth.uid());

COMMENT ON POLICY "Admins can manage roles" ON user_roles IS 'Only admins can INSERT/UPDATE/DELETE role assignments';
COMMENT ON POLICY "Users can view own roles" ON user_roles IS 'All users can read their own role (needed for role-based UI)';
```

---

### Events Table

```sql
-- RLS Policy: Students see only approved events (or their own)
CREATE POLICY "Students see approved events"
ON events FOR SELECT
TO authenticated
USING (
  status = 'approved'
  OR created_by = auth.uid()  -- Can see own events regardless of status
);

-- RLS Policy: Moderators and admins see all events
CREATE POLICY "Moderators see all events"
ON events FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
  )
);

-- RLS Policy: Students can create events (forced to pending status)
CREATE POLICY "Students can create events"
ON events FOR INSERT
TO authenticated
WITH CHECK (
  created_by = auth.uid()
  AND status = 'pending'  -- Force new events to pending
);

-- RLS Policy: Event creators can update their own rejected events (re-submission)
CREATE POLICY "Creators can update rejected events"
ON events FOR UPDATE
TO authenticated
USING (
  created_by = auth.uid()
  AND status = 'rejected'
)
WITH CHECK (
  created_by = auth.uid()
  AND status = 'pending'  -- After edit, must reset to pending
  AND rejection_reason IS NULL  -- Clear previous rejection reason
);

-- RLS Policy: Moderators can approve/reject events (but not their own)
CREATE POLICY "Moderators can moderate events"
ON events FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
  )
  AND created_by != auth.uid()  -- Prevent self-moderation
  AND status = 'pending'  -- Can only moderate pending events
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
  )
  AND created_by != auth.uid()
  AND status IN ('approved', 'rejected')  -- Can only change to approved or rejected
);

COMMENT ON POLICY "Students see approved events" ON events IS 'Students see approved events + their own pending/rejected events (FR-003, FR-015, FR-017)';
COMMENT ON POLICY "Moderators see all events" ON events IS 'Moderators and admins see all events regardless of status (FR-004)';
COMMENT ON POLICY "Students can create events" ON events IS 'All authenticated users can create events (forced to pending status per FR-010)';
COMMENT ON POLICY "Creators can update rejected events" ON events IS 'Event creators can edit and re-submit rejected events (FR-065, FR-066)';
COMMENT ON POLICY "Moderators can moderate events" ON events IS 'Moderators can approve/reject pending events (except own events per FR-062)';
```

**Critical Security Note**: `USING` clause validates row before UPDATE, `WITH CHECK` validates row after UPDATE. Both required for data integrity.

---

### Moderation Log Table

```sql
-- RLS Policy: Moderators and admins can view all moderation logs
CREATE POLICY "Moderators can view logs"
ON moderation_log FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
  )
);

-- RLS Policy: Only database triggers can insert (no direct INSERT allowed)
-- Note: No INSERT policy means INSERT is blocked for all users
-- Inserts happen via database trigger on events UPDATE

COMMENT ON POLICY "Moderators can view logs" ON moderation_log IS 'Moderators and admins can read audit logs for transparency (FR-049)';
```

**Rationale**: No INSERT/UPDATE/DELETE policies = immutable to all users (FR-061). Inserts only via trigger (prevents manual tampering).

---

### Admin Log Table

```sql
-- RLS Policy: Admins can view all admin logs
CREATE POLICY "Admins can view admin logs"
ON admin_log FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

-- No INSERT/UPDATE/DELETE policies (immutable, populated via triggers)

COMMENT ON POLICY "Admins can view admin logs" ON admin_log IS 'Admins can read audit trail of role changes (FR-050)';
```

---

### Role History Table

```sql
-- RLS Policy: Admins can view all role history
CREATE POLICY "Admins can view role history"
ON role_history FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

-- No INSERT/UPDATE/DELETE policies (immutable, populated via triggers)
```

---

### Moderator Statistics Table

```sql
-- RLS Policy: Moderators can view their own statistics
CREATE POLICY "Moderators can view own stats"
ON moderator_stats FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
  )
);

-- RLS Policy: Admins can view all moderator statistics
CREATE POLICY "Admins can view all stats"
ON moderator_stats FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

-- No direct INSERT/UPDATE/DELETE policies (managed via triggers and functions)

COMMENT ON POLICY "Moderators can view own stats" ON moderator_stats IS 'Moderators see their own statistics (FR-029)';
COMMENT ON POLICY "Admins can view all stats" ON moderator_stats IS 'Admins see all moderator statistics for monitoring (FR-041)';
```

---

### Moderator Statistics Archive Table

```sql
-- RLS Policy: Admins can view all archived statistics
CREATE POLICY "Admins can view archived stats"
ON moderator_stats_archive FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

-- No INSERT/UPDATE/DELETE policies (populated via triggers)
```

---

### Notifications Table

```sql
-- RLS Policy: Users can view their own notifications
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
TO authenticated
USING (recipient_id = auth.uid());

-- No INSERT/UPDATE/DELETE policies for users (created via triggers, updated by Edge Function)
```

---

## Database Functions

### 1. Helper Function: Check User Role

```sql
-- Helper function to check if current user has a specific role
CREATE OR REPLACE FUNCTION has_role(required_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = required_role
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION has_role IS 'Check if current authenticated user has the specified role (used in RLS policies)';
```

**Rationale**: `SECURITY DEFINER` allows function to read user_roles table even if caller doesn't have direct access. `STABLE` hints optimizer that result won't change within transaction.

---

### 2. Function: Moderate Event (with Concurrent Modification Protection)

```sql
-- Function to moderate event with row locking
CREATE OR REPLACE FUNCTION moderate_event(
  p_event_id UUID,
  p_action TEXT,
  p_rejection_reason TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_event_record RECORD;
  v_moderator_id UUID;
BEGIN
  -- Get current user ID
  v_moderator_id := auth.uid();

  -- Validate action
  IF p_action NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid action. Must be "approved" or "rejected".';
  END IF;

  -- Validate rejection reason provided if action is rejected
  IF p_action = 'rejected' AND (p_rejection_reason IS NULL OR p_rejection_reason = '') THEN
    RAISE EXCEPTION 'Rejection reason required when rejecting event';
  END IF;

  -- Lock row for update (fail immediately if locked by another moderator)
  BEGIN
    SELECT * INTO STRICT v_event_record
    FROM events
    WHERE id = p_event_id
    FOR UPDATE NOWAIT;
  EXCEPTION
    WHEN lock_not_available THEN
      RAISE EXCEPTION 'Another moderator is currently reviewing this event';
    WHEN no_data_found THEN
      RAISE EXCEPTION 'Event not found';
  END;

  -- Check if event is pending (not already moderated)
  IF v_event_record.status != 'pending' THEN
    RAISE EXCEPTION 'Event already moderated with status: %', v_event_record.status;
  END IF;

  -- Check if moderator is not the creator (prevent self-moderation)
  IF v_event_record.created_by = v_moderator_id THEN
    RAISE EXCEPTION 'Cannot moderate your own event';
  END IF;

  -- Update event with moderation info
  UPDATE events
  SET
    status = p_action,
    moderated_by = v_moderator_id,
    moderated_at = NOW(),
    rejection_reason = CASE WHEN p_action = 'rejected' THEN p_rejection_reason ELSE NULL END,
    updated_at = NOW()
  WHERE id = p_event_id;

  -- Insert into moderation log (audit trail)
  INSERT INTO moderation_log (event_id, moderator_id, action, rejection_reason)
  VALUES (p_event_id, v_moderator_id, p_action, p_rejection_reason);

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION moderate_event IS 'Approve or reject event with concurrent modification protection (FOR UPDATE NOWAIT) and self-moderation prevention (FR-062, FR-063)';
```

**Rationale**: `FOR UPDATE NOWAIT` provides immediate error if row locked (better UX than waiting). Validates all business rules: pending status, no self-moderation, rejection reason required.

---

### 3. Function: Calculate Moderator Statistics

```sql
-- Function to recalculate moderator statistics
CREATE OR REPLACE FUNCTION calculate_moderator_stats(p_user_id UUID)
RETURNS VOID AS $$
DECLARE
  v_total_reviews INTEGER;
  v_approval_count INTEGER;
  v_rejection_count INTEGER;
  v_approval_rate NUMERIC(5,2);
  v_reviews_today INTEGER;
  v_reviews_this_week INTEGER;
  v_last_review_at TIMESTAMPTZ;
BEGIN
  -- Calculate aggregate statistics from moderation_log
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE action = 'approved'),
    COUNT(*) FILTER (WHERE action = 'rejected'),
    MAX(created_at)
  INTO
    v_total_reviews,
    v_approval_count,
    v_rejection_count,
    v_last_review_at
  FROM moderation_log
  WHERE moderator_id = p_user_id;

  -- Calculate approval rate
  IF v_total_reviews > 0 THEN
    v_approval_rate := ROUND((v_approval_count::NUMERIC / v_total_reviews) * 100, 2);
  ELSE
    v_approval_rate := 0;
  END IF;

  -- Calculate reviews today (UTC timezone)
  SELECT COUNT(*)
  INTO v_reviews_today
  FROM moderation_log
  WHERE moderator_id = p_user_id
    AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC');

  -- Calculate reviews this week (Monday 00:00 UTC to Sunday 23:59 UTC)
  SELECT COUNT(*)
  INTO v_reviews_this_week
  FROM moderation_log
  WHERE moderator_id = p_user_id
    AND created_at >= DATE_TRUNC('week', NOW() AT TIME ZONE 'UTC');

  -- Upsert into moderator_stats
  INSERT INTO moderator_stats (
    user_id,
    total_reviews,
    approval_count,
    rejection_count,
    approval_rate_percent,
    reviews_today,
    reviews_this_week,
    last_review_at,
    stats_updated_at
  ) VALUES (
    p_user_id,
    v_total_reviews,
    v_approval_count,
    v_rejection_count,
    v_approval_rate,
    v_reviews_today,
    v_reviews_this_week,
    v_last_review_at,
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    total_reviews = EXCLUDED.total_reviews,
    approval_count = EXCLUDED.approval_count,
    rejection_count = EXCLUDED.rejection_count,
    approval_rate_percent = EXCLUDED.approval_rate_percent,
    reviews_today = EXCLUDED.reviews_today,
    reviews_this_week = EXCLUDED.reviews_this_week,
    last_review_at = EXCLUDED.last_review_at,
    stats_updated_at = NOW(),
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION calculate_moderator_stats IS 'Recalculate moderator statistics from moderation_log (called by trigger after each moderation action per FR-030)';
```

**Rationale**: Aggregates statistics from source of truth (moderation_log). UPSERT pattern handles both initial stats creation and updates. Week starts Monday 00:00 UTC per Assumption #7.

---

### 4. Function: Promote User to Moderator

```sql
-- Function to promote user to moderator
CREATE OR REPLACE FUNCTION promote_to_moderator(
  p_target_user_id UUID,
  p_admin_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_current_role TEXT;
BEGIN
  -- Check if target user exists
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_target_user_id) THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- Get current role
  SELECT role INTO v_current_role
  FROM user_roles
  WHERE user_id = p_target_user_id
  ORDER BY assigned_at DESC
  LIMIT 1;

  -- If already moderator or admin, raise error
  IF v_current_role IN ('moderator', 'admin') THEN
    RAISE EXCEPTION 'User is already a moderator or admin';
  END IF;

  -- Insert new role
  INSERT INTO user_roles (user_id, role, assigned_by)
  VALUES (p_target_user_id, 'moderator', p_admin_id);

  -- Log in admin_log
  INSERT INTO admin_log (admin_id, target_user_id, action, old_role, new_role)
  VALUES (p_admin_id, p_target_user_id, 'promoted', COALESCE(v_current_role, 'student'), 'moderator');

  -- Log in role_history
  INSERT INTO role_history (user_id, old_role, new_role, changed_by)
  VALUES (p_target_user_id, v_current_role, 'moderator', p_admin_id);

  -- Check if user was previously a moderator (restore archived stats)
  DECLARE
    v_archived_stats JSONB;
  BEGIN
    SELECT archived_stats INTO v_archived_stats
    FROM moderator_stats_archive
    WHERE user_id = p_target_user_id
    ORDER BY archived_at DESC
    LIMIT 1;

    IF v_archived_stats IS NOT NULL THEN
      -- Restore archived statistics
      INSERT INTO moderator_stats (
        user_id,
        total_reviews,
        approval_count,
        rejection_count,
        approval_rate_percent,
        last_review_at,
        reviews_today,
        reviews_this_week,
        stats_updated_at
      ) VALUES (
        p_target_user_id,
        (v_archived_stats->>'total_reviews')::INTEGER,
        (v_archived_stats->>'approval_count')::INTEGER,
        (v_archived_stats->>'rejection_count')::INTEGER,
        (v_archived_stats->>'approval_rate_percent')::NUMERIC,
        (v_archived_stats->>'last_review_at')::TIMESTAMPTZ,
        0,  -- Reset daily/weekly counters
        0,
        NOW()
      )
      ON CONFLICT (user_id) DO UPDATE SET
        total_reviews = EXCLUDED.total_reviews,
        approval_count = EXCLUDED.approval_count,
        rejection_count = EXCLUDED.rejection_count,
        approval_rate_percent = EXCLUDED.approval_rate_percent,
        last_review_at = EXCLUDED.last_review_at,
        reviews_today = 0,
        reviews_this_week = 0,
        stats_updated_at = NOW();
    ELSE
      -- Initialize new moderator stats
      INSERT INTO moderator_stats (user_id)
      VALUES (p_target_user_id)
      ON CONFLICT (user_id) DO NOTHING;
    END IF;
  END;

  -- Create notification
  INSERT INTO notifications (recipient_id, title, body, data)
  VALUES (
    p_target_user_id,
    '🛡️ Sei stato nominato moderatore Nova!',
    'Ora puoi approvare e rifiutare eventi nella scheda Moderazione.',
    jsonb_build_object('type', 'role_change', 'new_role', 'moderator')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION promote_to_moderator IS 'Promote user to moderator role, restore archived stats if previously moderator, send notification (FR-038, Assumption #9)';
```

**Rationale**: Single atomic operation handles role assignment, audit logging, statistics restoration, and notification. Supports Assumption #9 (restore stats on re-promotion).

---

### 5. Function: Remove Moderator Role

```sql
-- Function to remove moderator role
CREATE OR REPLACE FUNCTION remove_moderator_role(
  p_target_user_id UUID,
  p_admin_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_current_role TEXT;
  v_stats_record moderator_stats%ROWTYPE;
BEGIN
  -- Get current role
  SELECT role INTO v_current_role
  FROM user_roles
  WHERE user_id = p_target_user_id
  ORDER BY assigned_at DESC
  LIMIT 1;

  -- If not moderator, raise error
  IF v_current_role NOT IN ('moderator', 'admin') THEN
    RAISE EXCEPTION 'User is not a moderator or admin';
  END IF;

  -- Prevent removing last admin
  IF v_current_role = 'admin' THEN
    IF (SELECT COUNT(*) FROM user_roles WHERE role = 'admin') <= 1 THEN
      RAISE EXCEPTION 'Cannot remove the last admin';
    END IF;
  END IF;

  -- Archive moderator statistics
  SELECT * INTO v_stats_record
  FROM moderator_stats
  WHERE user_id = p_target_user_id;

  IF FOUND THEN
    INSERT INTO moderator_stats_archive (user_id, archived_stats, archived_by)
    VALUES (
      p_target_user_id,
      jsonb_build_object(
        'total_reviews', v_stats_record.total_reviews,
        'approval_count', v_stats_record.approval_count,
        'rejection_count', v_stats_record.rejection_count,
        'approval_rate_percent', v_stats_record.approval_rate_percent,
        'last_review_at', v_stats_record.last_review_at
      ),
      p_admin_id
    );

    -- Delete current stats
    DELETE FROM moderator_stats WHERE user_id = p_target_user_id;
  END IF;

  -- Remove moderator role
  DELETE FROM user_roles WHERE user_id = p_target_user_id AND role IN ('moderator', 'admin');

  -- Add back student role (default)
  INSERT INTO user_roles (user_id, role, assigned_by)
  VALUES (p_target_user_id, 'student', p_admin_id);

  -- Log in admin_log
  INSERT INTO admin_log (admin_id, target_user_id, action, old_role, new_role)
  VALUES (p_admin_id, p_target_user_id, 'removed', v_current_role, 'student');

  -- Log in role_history
  INSERT INTO role_history (user_id, old_role, new_role, changed_by)
  VALUES (p_target_user_id, v_current_role, 'student', p_admin_id);

  -- Create notification
  INSERT INTO notifications (recipient_id, title, body, data)
  VALUES (
    p_target_user_id,
    'Il tuo ruolo moderatore è stato rimosso',
    'Non hai più accesso alla dashboard di moderazione.',
    jsonb_build_object('type', 'role_change', 'new_role', 'student')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION remove_moderator_role IS 'Remove moderator role, archive statistics, send notification (FR-040, Assumption #9)';
```

**Rationale**: Archives stats before deletion (supports restoration). Prevents removing last admin (system must have at least one admin). Atomic operation.

---

### 6. Function: Get System Statistics

```sql
-- Function to get current system statistics
CREATE OR REPLACE FUNCTION get_system_statistics()
RETURNS TABLE (
  pending_events BIGINT,
  approved_events BIGINT,
  rejected_events BIGINT,
  total_events BIGINT,
  pending_percent NUMERIC,
  approved_percent NUMERIC,
  rejected_percent NUMERIC,
  events_pending_over_24h BIGINT,
  total_moderators BIGINT,
  active_moderators_7d BIGINT,
  avg_review_time_minutes NUMERIC,
  current_backlog BIGINT
) AS $$
BEGIN
  RETURN QUERY SELECT * FROM system_statistics;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON FUNCTION get_system_statistics IS 'Retrieve system-wide statistics for Admin Panel (FR-044, FR-045, FR-046)';
```

**Rationale**: Wrapper function for view provides consistent API. `STABLE` hints optimizer that result won't change within transaction.

---

## Triggers

### 1. Trigger: Update Moderator Statistics After Moderation

```sql
-- Trigger function to update moderator statistics
CREATE OR REPLACE FUNCTION trigger_update_moderator_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Recalculate statistics for the moderator who just performed an action
  PERFORM calculate_moderator_stats(NEW.moderator_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger on moderation_log INSERT
CREATE TRIGGER update_moderator_stats_after_moderation
AFTER INSERT ON moderation_log
FOR EACH ROW
EXECUTE FUNCTION trigger_update_moderator_stats();

COMMENT ON TRIGGER update_moderator_stats_after_moderation ON moderation_log IS 'Update moderator statistics immediately after moderation action (FR-030)';
```

---

### 2. Trigger: Create Notification on Event Moderation

```sql
-- Trigger function to create notification on event status change
CREATE OR REPLACE FUNCTION trigger_notify_event_moderation()
RETURNS TRIGGER AS $$
BEGIN
  -- Only notify when event moves from pending to approved/rejected
  IF OLD.status = 'pending' AND NEW.status IN ('approved', 'rejected') THEN
    INSERT INTO notifications (recipient_id, title, body, data)
    VALUES (
      NEW.created_by,
      CASE
        WHEN NEW.status = 'approved' THEN '✅ Il tuo evento è stato approvato!'
        WHEN NEW.status = 'rejected' THEN '❌ Il tuo evento è stato rifiutato'
      END,
      CASE
        WHEN NEW.status = 'approved' THEN 'Il tuo evento "' || NEW.title || '" è stato approvato e ora è visibile a tutti.'
        WHEN NEW.status = 'rejected' THEN 'Il tuo evento "' || NEW.title || '" è stato rifiutato. Motivo: ' || COALESCE(NEW.rejection_reason, 'Non specificato')
      END,
      jsonb_build_object(
        'type', 'event_moderation',
        'event_id', NEW.id,
        'status', NEW.status
      )
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger on events UPDATE
CREATE TRIGGER notify_event_moderation
AFTER UPDATE ON events
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION trigger_notify_event_moderation();

COMMENT ON TRIGGER notify_event_moderation ON events IS 'Create notification when event is approved or rejected (FR-054, FR-055)';
```

**Rationale**: `WHEN` clause filters trigger to only fire when status actually changes (performance optimization). Notification inserted into table, webhook triggers Edge Function.

---

### 3. Trigger: Update Timestamps Automatically

```sql
-- Generic trigger function to update updated_at
CREATE OR REPLACE FUNCTION trigger_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to tables with updated_at column
CREATE TRIGGER update_timestamp_user_roles
BEFORE UPDATE ON user_roles
FOR EACH ROW
EXECUTE FUNCTION trigger_update_timestamp();

CREATE TRIGGER update_timestamp_moderator_stats
BEFORE UPDATE ON moderator_stats
FOR EACH ROW
EXECUTE FUNCTION trigger_update_timestamp();

COMMENT ON FUNCTION trigger_update_timestamp IS 'Automatically update updated_at timestamp on row modification';
```

---

### 4. Trigger: Populate Moderation Log on Event Update

```sql
-- Trigger to insert into moderation_log when event is moderated
CREATE OR REPLACE FUNCTION trigger_log_moderation()
RETURNS TRIGGER AS $$
BEGIN
  -- Only log when status changes from pending to approved/rejected
  IF OLD.status = 'pending' AND NEW.status IN ('approved', 'rejected') THEN
    INSERT INTO moderation_log (event_id, moderator_id, action, rejection_reason)
    VALUES (NEW.id, NEW.moderated_by, NEW.status, NEW.rejection_reason);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_moderation_action
AFTER UPDATE ON events
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION trigger_log_moderation();

COMMENT ON TRIGGER log_moderation_action ON events IS 'Create immutable audit log entry when event is moderated (FR-059)';
```

**Rationale**: Separate trigger from notification trigger for single responsibility. Both fire on same UPDATE but handle different concerns.

---

## Indexes

### Performance-Critical Indexes for RLS Policies

```sql
-- User roles table: Speed up role checks in RLS policies
CREATE INDEX idx_user_roles_user_id_role ON user_roles(user_id, role);
CREATE INDEX idx_user_roles_role ON user_roles(role) WHERE role IN ('moderator', 'admin');

COMMENT ON INDEX idx_user_roles_user_id_role IS 'Optimize has_role() function lookups in RLS policies (CRITICAL for performance)';
COMMENT ON INDEX idx_user_roles_role IS 'Optimize moderator/admin count queries (partial index)';

-- Events table: Speed up status filtering and moderation queue queries
CREATE INDEX idx_events_status_created_at ON events(status, created_at DESC);
CREATE INDEX idx_events_created_by ON events(created_by);
CREATE INDEX idx_events_status_pending ON events(created_at DESC) WHERE status = 'pending';
CREATE INDEX idx_events_moderated_at ON events(moderated_at DESC) WHERE moderated_at IS NOT NULL;

COMMENT ON INDEX idx_events_status_created_at IS 'Optimize moderation queue queries (oldest pending first per FR-019)';
COMMENT ON INDEX idx_events_created_by IS 'Optimize RLS policy self-moderation check (FR-062)';
COMMENT ON INDEX idx_events_status_pending IS 'Partial index for pending events queue (smaller, faster)';
COMMENT ON INDEX idx_events_moderated_at IS 'Optimize average review time calculation (rolling 7-day window)';

-- Moderation log: Speed up statistics aggregation
CREATE INDEX idx_moderation_log_moderator_created ON moderation_log(moderator_id, created_at DESC);
CREATE INDEX idx_moderation_log_moderator_action ON moderation_log(moderator_id, action);
CREATE INDEX idx_moderation_log_created_at ON moderation_log(created_at DESC);

COMMENT ON INDEX idx_moderation_log_moderator_created IS 'Optimize calculate_moderator_stats() function';
COMMENT ON INDEX idx_moderation_log_moderator_action IS 'Optimize approval rate calculation';
COMMENT ON INDEX idx_moderation_log_created_at IS 'Optimize activity log queries (FR-049)';

-- Moderator statistics: Speed up admin panel queries
CREATE INDEX idx_moderator_stats_last_review ON moderator_stats(last_review_at DESC NULLS LAST);

COMMENT ON INDEX idx_moderator_stats_last_review IS 'Optimize inactive moderator detection (>7 days per FR-042)';

-- Notifications: Speed up unsent notification processing
CREATE INDEX idx_notifications_recipient ON notifications(recipient_id, created_at DESC);
CREATE INDEX idx_notifications_unsent ON notifications(created_at) WHERE sent = FALSE;

COMMENT ON INDEX idx_notifications_recipient IS 'Optimize user notification history queries';
COMMENT ON INDEX idx_notifications_unsent IS 'Partial index for Edge Function webhook processing';

-- Admin log: Speed up activity log queries
CREATE INDEX idx_admin_log_created_at ON admin_log(created_at DESC);
CREATE INDEX idx_admin_log_target_user ON admin_log(target_user_id, created_at DESC);

COMMENT ON INDEX idx_admin_log_created_at IS 'Optimize admin activity log display (FR-049)';
COMMENT ON INDEX idx_admin_log_target_user IS 'Optimize user role history lookup';

-- Role history: Speed up statistics restoration
CREATE INDEX idx_role_history_user_changed ON role_history(user_id, changed_at DESC);

COMMENT ON INDEX idx_role_history_user_changed IS 'Optimize role history lookup for statistics restoration';
```

**Performance Impact**: Based on research findings, RLS policies can be 100x slower without proper indexes. These indexes are non-negotiable for production.

---

## State Transitions

### Event Status State Machine

```
┌──────────┐
│ pending  │ ◄─────────────────┐
└────┬─────┘                   │
     │                         │
     │  moderate_event()       │  re-submit
     │  (moderator action)     │  (creator edits)
     │                         │
     ├─────────────┬───────────┴──────┐
     │             │                  │
     v             v                  │
┌──────────┐  ┌───────────┐          │
│ approved │  │ rejected  │──────────┘
└──────────┘  └───────────┘

IMMUTABLE     RE-SUBMITTABLE
```

**Valid Transitions**:

1. **pending → approved** (via `moderate_event('approved')`)
   - Moderator approves event
   - Sets moderated_by, moderated_at
   - Creates moderation_log entry
   - Sends approval notification to creator
   - Event becomes visible in public feed

2. **pending → rejected** (via `moderate_event('rejected', 'reason')`)
   - Moderator rejects event with reason
   - Sets moderated_by, moderated_at, rejection_reason
   - Creates moderation_log entry
   - Sends rejection notification to creator
   - Event visible only to creator

3. **rejected → pending** (via creator UPDATE)
   - Creator edits description (only field editable per FR-067)
   - Resets status to pending
   - Clears rejection_reason
   - Increments submission_count
   - Creates new moderation queue entry

**Invalid Transitions** (blocked by constraints):

- ❌ approved → pending (approved events are immutable)
- ❌ approved → rejected (cannot change approved events)
- ❌ rejected → approved (must go through pending first)

**Enforcement**: `moderated_data_consistency` CHECK constraint + RLS policies enforce valid transitions at database level.

---

## Data Retention

### Retention Policies

| Entity | Retention Period | Rationale |
|--------|------------------|-----------|
| **Events** | Permanent (soft delete on user request) | GDPR Right to Erasure applies. Events deleted when creator deletes account. |
| **Moderation Log** | Permanent (immutable) | Audit trail required for accountability (FR-061). Moderator deletion sets moderator_id to NULL (preserves history). |
| **Admin Log** | Permanent (immutable) | Audit trail for role changes. Admin deletion sets admin_id to NULL. |
| **Role History** | Permanent | Required for statistics restoration (Assumption #9). |
| **Moderator Stats** | Deleted on role removal, archived in moderator_stats_archive | Statistics restored if user re-promoted (Assumption #9). |
| **Moderator Stats Archive** | Permanent | Preserves historical statistics for re-promoted moderators. |
| **Notifications** | 90 days (auto-delete) | Notification history for future in-app notification center. Older than 90 days purged via scheduled job. |
| **User Roles** | Permanent | Required for access control. CASCADE deleted when user deleted. |

### GDPR Compliance: Right to Erasure

When user exercises Right to Erasure (deletes account):

```sql
-- Cascade deletions triggered by auth.users deletion
DELETE FROM auth.users WHERE id = '<user_id>';

-- This triggers CASCADE deletes on:
-- - user_roles (role assignments)
-- - events (created events)
-- - notifications (sent notifications)
-- - moderator_stats (current statistics)
-- - moderator_stats_archive (archived statistics)
-- - role_history (role change history)

-- Admin/moderation logs preserve audit trail:
-- - moderation_log.moderator_id SET NULL (preserves action attribution)
-- - admin_log.admin_id SET NULL (preserves role change attribution)
-- - admin_log.target_user_id CASCADE (removes records about deleted user)
```

### Automated Cleanup Jobs (via pg_cron or Supabase Edge Functions)

```sql
-- Daily job: Reset reviews_today counter at midnight UTC
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
  'reset-daily-review-counters',
  '0 0 * * *',  -- Every day at midnight UTC
  $$
  UPDATE moderator_stats
  SET reviews_today = 0
  WHERE reviews_today > 0;
  $$
);

-- Weekly job: Reset reviews_this_week counter on Monday 00:00 UTC
SELECT cron.schedule(
  'reset-weekly-review-counters',
  '0 0 * * 1',  -- Every Monday at midnight UTC
  $$
  UPDATE moderator_stats
  SET reviews_this_week = 0
  WHERE reviews_this_week > 0;
  $$
);

-- Daily job: Purge old notifications (older than 90 days)
SELECT cron.schedule(
  'purge-old-notifications',
  '0 2 * * *',  -- Every day at 2 AM UTC
  $$
  DELETE FROM notifications
  WHERE created_at < NOW() - INTERVAL '90 days';
  $$
);
```

**Note**: If pg_cron not available in Supabase plan, implement these as Supabase Edge Functions with scheduled triggers.

---

## Database Schema Verification Script

```sql
-- Verification script to ensure all tables, indexes, and policies are created
DO $$
BEGIN
  -- Check tables exist
  ASSERT (SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN (
    'user_roles', 'moderation_log', 'admin_log', 'role_history',
    'moderator_stats', 'moderator_stats_archive', 'notifications'
  )) = 7, 'Missing required tables';

  -- Check RLS enabled on all tables
  ASSERT (SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public' AND rowsecurity = true) >= 7,
    'RLS not enabled on all tables';

  -- Check critical indexes exist
  ASSERT (SELECT COUNT(*) FROM pg_indexes WHERE indexname LIKE 'idx_%') >= 15,
    'Missing critical indexes';

  -- Check functions exist
  ASSERT (SELECT COUNT(*) FROM pg_proc WHERE proname IN (
    'has_role', 'moderate_event', 'calculate_moderator_stats',
    'promote_to_moderator', 'remove_moderator_role', 'get_system_statistics'
  )) = 6, 'Missing required functions';

  -- Check triggers exist
  ASSERT (SELECT COUNT(*) FROM pg_trigger WHERE tgname IN (
    'update_moderator_stats_after_moderation', 'notify_event_moderation',
    'log_moderation_action', 'update_timestamp_user_roles'
  )) >= 4, 'Missing required triggers';

  RAISE NOTICE 'Schema verification passed!';
END $$;
```

---

## Migration Script (Complete DDL)

**File**: `supabase/migrations/20251113_moderation_system.sql`

```sql
-- Migration: Moderation Admin Panel System
-- Feature: 005-moderation-admin-panel
-- Created: 2025-11-13

BEGIN;

-- =============================================================================
-- TABLES
-- =============================================================================

-- 1. User Roles Table
CREATE TABLE IF NOT EXISTS user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('student', 'moderator', 'admin')),
  assigned_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  assigned_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(user_id, role)
);

ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- 2. Modify Events Table
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS moderated_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS moderated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS submission_count INTEGER DEFAULT 1 NOT NULL CHECK (submission_count > 0);

ALTER TABLE events
  ADD CONSTRAINT moderated_data_consistency
  CHECK (
    (status = 'pending' AND moderated_by IS NULL AND moderated_at IS NULL AND rejection_reason IS NULL)
    OR
    (status = 'approved' AND moderated_by IS NOT NULL AND moderated_at IS NOT NULL AND rejection_reason IS NULL)
    OR
    (status = 'rejected' AND moderated_by IS NOT NULL AND moderated_at IS NOT NULL AND rejection_reason IS NOT NULL)
  );

-- 3. Moderation Log Table
CREATE TABLE IF NOT EXISTS moderation_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
  moderator_id UUID REFERENCES auth.users(id) ON DELETE SET NULL NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('approved', 'rejected')),
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT rejection_reason_required_if_rejected CHECK (
    (action = 'approved' AND rejection_reason IS NULL)
    OR
    (action = 'rejected' AND rejection_reason IS NOT NULL)
  )
);

ALTER TABLE moderation_log ENABLE ROW LEVEL SECURITY;

-- 4. Admin Log Table
CREATE TABLE IF NOT EXISTS admin_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES auth.users(id) ON DELETE SET NULL NOT NULL,
  target_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('promoted', 'removed')),
  old_role TEXT CHECK (old_role IN ('student', 'moderator', 'admin')),
  new_role TEXT NOT NULL CHECK (new_role IN ('student', 'moderator', 'admin')),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE admin_log ENABLE ROW LEVEL SECURITY;

-- 5. Role History Table
CREATE TABLE IF NOT EXISTS role_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  old_role TEXT CHECK (old_role IN ('student', 'moderator', 'admin')),
  new_role TEXT NOT NULL CHECK (new_role IN ('student', 'moderator', 'admin')),
  changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  changed_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE role_history ENABLE ROW LEVEL SECURITY;

-- 6. Moderator Statistics Table
CREATE TABLE IF NOT EXISTS moderator_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  total_reviews INTEGER DEFAULT 0 NOT NULL CHECK (total_reviews >= 0),
  reviews_today INTEGER DEFAULT 0 NOT NULL CHECK (reviews_today >= 0),
  reviews_this_week INTEGER DEFAULT 0 NOT NULL CHECK (reviews_this_week >= 0),
  approval_count INTEGER DEFAULT 0 NOT NULL CHECK (approval_count >= 0),
  rejection_count INTEGER DEFAULT 0 NOT NULL CHECK (rejection_count >= 0),
  approval_rate_percent NUMERIC(5,2) DEFAULT 0 NOT NULL CHECK (approval_rate_percent BETWEEN 0 AND 100),
  last_review_at TIMESTAMPTZ,
  stats_updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE moderator_stats ENABLE ROW LEVEL SECURITY;

-- 7. Moderator Statistics Archive Table
CREATE TABLE IF NOT EXISTS moderator_stats_archive (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  archived_stats JSONB NOT NULL,
  archived_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  archived_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE moderator_stats_archive ENABLE ROW LEVEL SECURITY;

-- 8. Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB,
  sent BOOLEAN DEFAULT FALSE NOT NULL,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_user_roles_user_id_role ON user_roles(user_id, role);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role) WHERE role IN ('moderator', 'admin');

CREATE INDEX IF NOT EXISTS idx_events_status_created_at ON events(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_created_by ON events(created_by);
CREATE INDEX IF NOT EXISTS idx_events_status_pending ON events(created_at DESC) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_events_moderated_at ON events(moderated_at DESC) WHERE moderated_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_moderation_log_moderator_created ON moderation_log(moderator_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_moderation_log_moderator_action ON moderation_log(moderator_id, action);
CREATE INDEX IF NOT EXISTS idx_moderation_log_created_at ON moderation_log(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_moderator_stats_last_review ON moderator_stats(last_review_at DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_moderator_stats_archive_user_id ON moderator_stats_archive(user_id, archived_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unsent ON notifications(created_at) WHERE sent = FALSE;

CREATE INDEX IF NOT EXISTS idx_admin_log_created_at ON admin_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_log_target_user ON admin_log(target_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_role_history_user_changed ON role_history(user_id, changed_at DESC);

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- (Function definitions from "Database Functions" section above)
-- Include all 6 functions here...

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- (Trigger definitions from "Triggers" section above)
-- Include all 4 trigger functions and trigger attachments...

-- =============================================================================
-- RLS POLICIES
-- =============================================================================

-- (RLS policy definitions from "Row-Level Security" section above)
-- Include all policies for all 8 tables...

-- =============================================================================
-- VIEWS
-- =============================================================================

CREATE OR REPLACE VIEW system_statistics AS
SELECT
  COUNT(*) FILTER (WHERE status = 'pending') AS pending_events,
  COUNT(*) FILTER (WHERE status = 'approved') AS approved_events,
  COUNT(*) FILTER (WHERE status = 'rejected') AS rejected_events,
  COUNT(*) AS total_events,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'pending') / NULLIF(COUNT(*), 0), 2) AS pending_percent,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'approved') / NULLIF(COUNT(*), 0), 2) AS approved_percent,
  ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'rejected') / NULLIF(COUNT(*), 0), 2) AS rejected_percent,
  COUNT(*) FILTER (WHERE status = 'pending' AND created_at < NOW() - INTERVAL '24 hours') AS events_pending_over_24h,
  (SELECT COUNT(DISTINCT user_id) FROM user_roles WHERE role IN ('moderator', 'admin')) AS total_moderators,
  (SELECT COUNT(DISTINCT user_id) FROM user_roles
   WHERE role IN ('moderator', 'admin')
   AND user_id IN (SELECT DISTINCT moderator_id FROM moderation_log WHERE created_at > NOW() - INTERVAL '7 days')) AS active_moderators_7d,
  (SELECT EXTRACT(EPOCH FROM AVG(moderated_at - events.created_at)) / 60
   FROM events
   WHERE moderated_at > NOW() - INTERVAL '7 days' AND moderated_at IS NOT NULL) AS avg_review_time_minutes,
  COUNT(*) FILTER (WHERE status = 'pending') AS current_backlog
FROM events;

COMMIT;
```

---

## Summary

This data model implements a complete moderation system with:

- **3-tier role system** (student, moderator, admin) with Row-Level Security
- **Event status workflow** (pending → approved/rejected) with concurrent modification protection
- **Immutable audit trails** (moderation_log, admin_log) for accountability
- **Real-time statistics** (moderator_stats) updated via triggers
- **Statistics archival and restoration** when moderators are promoted/demoted
- **Push notification integration** via notifications table + Supabase Edge Function webhook
- **GDPR compliance** with Right to Erasure (CASCADE deletes on user deletion)
- **Performance-optimized indexes** for RLS policies and real-time queries

All requirements from spec.md and research.md are addressed at the database level with defense-in-depth security (RLS + constraints + functions).
