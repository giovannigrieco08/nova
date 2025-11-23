-- Migration: Moderation Admin Panel System
-- Feature: 005-moderation-admin-panel
-- Created: 2025-11-14
-- Description: Complete moderation system with role-based access control, event approval workflow,
--              audit logging, statistics tracking, and push notification integration.

BEGIN;

-- =============================================================================
-- TABLES (T001-T009)
-- =============================================================================

-- T001: User Roles Table
-- Three-tier role system: student (default), moderator, admin
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

COMMENT ON TABLE user_roles IS 'Stores user role assignments for access control';
COMMENT ON COLUMN user_roles.user_id IS 'Foreign key to auth.users table';
COMMENT ON COLUMN user_roles.role IS 'One of: student (default), moderator, admin';
COMMENT ON COLUMN user_roles.assigned_by IS 'Admin who assigned this role (NULL for default student role)';

ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- T002: Modify Events Table
-- Add moderation-specific columns to existing events table
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS moderated_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS moderated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS submission_count INTEGER DEFAULT 1 NOT NULL CHECK (submission_count > 0);

COMMENT ON COLUMN events.status IS 'Event approval status: pending (in queue), approved (visible to all), rejected (visible to creator only)';
COMMENT ON COLUMN events.moderated_by IS 'User ID of moderator who approved/rejected this event';
COMMENT ON COLUMN events.moderated_at IS 'Timestamp when event was moderated';
COMMENT ON COLUMN events.rejection_reason IS 'Reason provided by moderator when rejecting (NULL if approved)';
COMMENT ON COLUMN events.submission_count IS 'Number of times this event was submitted (increments on re-submission after rejection)';

-- Constraint: Ensure moderation metadata is consistent with status
ALTER TABLE events
  DROP CONSTRAINT IF EXISTS moderated_data_consistency,
  ADD CONSTRAINT moderated_data_consistency
  CHECK (
    (status = 'pending' AND moderated_by IS NULL AND moderated_at IS NULL AND rejection_reason IS NULL)
    OR
    (status = 'approved' AND moderated_by IS NOT NULL AND moderated_at IS NOT NULL AND rejection_reason IS NULL)
    OR
    (status = 'rejected' AND moderated_by IS NOT NULL AND moderated_at IS NOT NULL AND rejection_reason IS NOT NULL)
  );

COMMENT ON CONSTRAINT moderated_data_consistency ON events IS 'Ensures moderation metadata is consistent with status';

-- T003: Moderation Log Table
-- Immutable audit trail of all moderation actions
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

COMMENT ON TABLE moderation_log IS 'Immutable audit trail of moderation actions (used for statistics and accountability)';
COMMENT ON COLUMN moderation_log.event_id IS 'Event that was moderated';
COMMENT ON COLUMN moderation_log.moderator_id IS 'User who performed the moderation (SET NULL on user deletion to preserve audit history)';
COMMENT ON COLUMN moderation_log.action IS 'approved or rejected';
COMMENT ON COLUMN moderation_log.rejection_reason IS 'Reason provided if action was rejected (NULL if approved)';
COMMENT ON CONSTRAINT rejection_reason_required_if_rejected ON moderation_log IS 'Ensures rejection reason is provided when action is rejected';

ALTER TABLE moderation_log ENABLE ROW LEVEL SECURITY;

-- T004: Admin Log Table
-- Immutable audit trail of administrative actions (role promotions/removals)
CREATE TABLE IF NOT EXISTS admin_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES auth.users(id) ON DELETE SET NULL NOT NULL,
  target_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('promoted', 'removed')),
  old_role TEXT CHECK (old_role IN ('student', 'moderator', 'admin')),
  new_role TEXT NOT NULL CHECK (new_role IN ('student', 'moderator', 'admin')),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON TABLE admin_log IS 'Immutable audit trail of administrative role changes';
COMMENT ON COLUMN admin_log.admin_id IS 'Admin who performed the action (SET NULL on deletion to preserve history)';
COMMENT ON COLUMN admin_log.target_user_id IS 'User whose role was changed (CASCADE delete when user deleted)';
COMMENT ON COLUMN admin_log.action IS 'promoted (student → moderator) or removed (moderator → student)';
COMMENT ON COLUMN admin_log.old_role IS 'Role before change (NULL for initial role assignment)';
COMMENT ON COLUMN admin_log.new_role IS 'Role after change';

ALTER TABLE admin_log ENABLE ROW LEVEL SECURITY;

-- T005: Role History Table
-- Tracks complete history of role changes for each user (supports statistics restoration)
CREATE TABLE IF NOT EXISTS role_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  old_role TEXT CHECK (old_role IN ('student', 'moderator', 'admin')),
  new_role TEXT NOT NULL CHECK (new_role IN ('student', 'moderator', 'admin')),
  changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  changed_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

COMMENT ON TABLE role_history IS 'Complete history of role changes (enables statistics restoration when user re-promoted)';
COMMENT ON COLUMN role_history.user_id IS 'User whose role changed';
COMMENT ON COLUMN role_history.old_role IS 'Previous role (NULL for initial assignment)';
COMMENT ON COLUMN role_history.new_role IS 'New role';
COMMENT ON COLUMN role_history.changed_by IS 'Admin who made the change (NULL for system-initiated changes)';

ALTER TABLE role_history ENABLE ROW LEVEL SECURITY;

-- T006: Moderator Statistics Table
-- Stores aggregated statistics for each moderator (calculated from moderation_log)
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

ALTER TABLE moderator_stats ENABLE ROW LEVEL SECURITY;

-- T007: Moderator Statistics Archive Table
-- Stores archived statistics when moderator role is removed (supports restoration on re-promotion)
CREATE TABLE IF NOT EXISTS moderator_stats_archive (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  archived_stats JSONB NOT NULL,
  archived_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  archived_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

COMMENT ON TABLE moderator_stats_archive IS 'Archived moderator statistics when role removed (supports restoration on re-promotion per Assumption #9)';
COMMENT ON COLUMN moderator_stats_archive.user_id IS 'User whose statistics were archived';
COMMENT ON COLUMN moderator_stats_archive.archived_stats IS 'Full moderator_stats record as JSON';
COMMENT ON COLUMN moderator_stats_archive.archived_at IS 'When the statistics were archived';
COMMENT ON COLUMN moderator_stats_archive.archived_by IS 'Admin who removed the moderator role';

ALTER TABLE moderator_stats_archive ENABLE ROW LEVEL SECURITY;

-- T008: Notifications Table
-- Stores notification records for push notification delivery via Edge Function webhook
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

COMMENT ON TABLE notifications IS 'Notification queue for push notification delivery via Supabase Edge Function webhook';
COMMENT ON COLUMN notifications.recipient_id IS 'User who should receive the notification';
COMMENT ON COLUMN notifications.title IS 'Notification title (e.g., "Event Approved!")';
COMMENT ON COLUMN notifications.body IS 'Notification body text';
COMMENT ON COLUMN notifications.data IS 'Deep link payload (e.g., {"type": "event_moderation", "event_id": "..."})';
COMMENT ON COLUMN notifications.sent IS 'Whether notification was successfully sent via FCM';
COMMENT ON COLUMN notifications.sent_at IS 'When notification was sent (NULL if pending)';

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- T009: System Statistics View
-- Read-only view aggregating system-wide statistics for Admin Panel
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

-- =============================================================================
-- INDEXES (T021-T022)
-- =============================================================================

-- User roles indexes: Speed up role checks in RLS policies
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id_role ON user_roles(user_id, role);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role) WHERE role IN ('moderator', 'admin');

COMMENT ON INDEX idx_user_roles_user_id_role IS 'Optimize has_role() function lookups in RLS policies (CRITICAL for performance)';
COMMENT ON INDEX idx_user_roles_role IS 'Optimize moderator/admin count queries (partial index)';

-- Events indexes: Speed up status filtering and moderation queue queries
CREATE INDEX IF NOT EXISTS idx_events_status_created_at ON events(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_created_by ON events(created_by);
CREATE INDEX IF NOT EXISTS idx_events_status_pending ON events(created_at DESC) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_events_moderated_at ON events(moderated_at DESC) WHERE moderated_at IS NOT NULL;

COMMENT ON INDEX idx_events_status_created_at IS 'Optimize moderation queue queries (oldest pending first per FR-019)';
COMMENT ON INDEX idx_events_created_by IS 'Optimize RLS policy self-moderation check (FR-062)';
COMMENT ON INDEX idx_events_status_pending IS 'Partial index for pending events queue (smaller, faster)';
COMMENT ON INDEX idx_events_moderated_at IS 'Optimize average review time calculation (rolling 7-day window)';

-- Moderation log indexes: Speed up statistics aggregation
CREATE INDEX IF NOT EXISTS idx_moderation_log_moderator_created ON moderation_log(moderator_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_moderation_log_moderator_action ON moderation_log(moderator_id, action);
CREATE INDEX IF NOT EXISTS idx_moderation_log_created_at ON moderation_log(created_at DESC);

COMMENT ON INDEX idx_moderation_log_moderator_created IS 'Optimize calculate_moderator_stats() function';
COMMENT ON INDEX idx_moderation_log_moderator_action IS 'Optimize approval rate calculation';
COMMENT ON INDEX idx_moderation_log_created_at IS 'Optimize activity log queries (FR-049)';

-- Moderator statistics indexes
CREATE INDEX IF NOT EXISTS idx_moderator_stats_last_review ON moderator_stats(last_review_at DESC NULLS LAST);

COMMENT ON INDEX idx_moderator_stats_last_review IS 'Optimize inactive moderator detection (>7 days per FR-042)';

-- Moderator statistics archive indexes
CREATE INDEX IF NOT EXISTS idx_moderator_stats_archive_user_id ON moderator_stats_archive(user_id, archived_at DESC);

COMMENT ON INDEX idx_moderator_stats_archive_user_id IS 'Optimize statistics restoration queries';

-- Notifications indexes
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unsent ON notifications(created_at) WHERE sent = FALSE;

COMMENT ON INDEX idx_notifications_recipient IS 'Optimize user notification history queries';
COMMENT ON INDEX idx_notifications_unsent IS 'Partial index for Edge Function webhook processing';

-- Admin log indexes
CREATE INDEX IF NOT EXISTS idx_admin_log_created_at ON admin_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_log_target_user ON admin_log(target_user_id, created_at DESC);

COMMENT ON INDEX idx_admin_log_created_at IS 'Optimize admin activity log display (FR-049)';
COMMENT ON INDEX idx_admin_log_target_user IS 'Optimize user role history lookup';

-- Role history indexes
CREATE INDEX IF NOT EXISTS idx_role_history_user_changed ON role_history(user_id, changed_at DESC);

COMMENT ON INDEX idx_role_history_user_changed IS 'Optimize role history lookup for statistics restoration';

-- =============================================================================
-- FUNCTIONS (T010-T016)
-- =============================================================================

-- T010: Helper Function - Check User Role
-- Used in RLS policies to check if current user has a specific role
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

-- T011: Function - Moderate Event (with Concurrent Modification Protection)
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

-- T012: Function - Calculate Moderator Statistics
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

-- T013: Function - Promote User to Moderator
CREATE OR REPLACE FUNCTION promote_to_moderator(
  p_target_user_id UUID,
  p_admin_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_current_role TEXT;
  v_archived_stats JSONB;
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

-- T014: Function - Remove Moderator Role
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

-- T015: Function - Get System Statistics
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

-- =============================================================================
-- TRIGGERS (T017-T020)
-- =============================================================================

-- T017: Trigger Function - Update Moderator Statistics After Moderation
CREATE OR REPLACE FUNCTION trigger_update_moderator_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Recalculate statistics for the moderator who just performed an action
  PERFORM calculate_moderator_stats(NEW.moderator_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_moderator_stats_after_moderation ON moderation_log;
CREATE TRIGGER update_moderator_stats_after_moderation
AFTER INSERT ON moderation_log
FOR EACH ROW
EXECUTE FUNCTION trigger_update_moderator_stats();

COMMENT ON TRIGGER update_moderator_stats_after_moderation ON moderation_log IS 'Update moderator statistics immediately after moderation action (FR-030)';

-- T018: Trigger Function - Create Notification on Event Moderation
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

DROP TRIGGER IF EXISTS notify_event_moderation ON events;
CREATE TRIGGER notify_event_moderation
AFTER UPDATE ON events
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION trigger_notify_event_moderation();

COMMENT ON TRIGGER notify_event_moderation ON events IS 'Create notification when event is approved or rejected (FR-054, FR-055)';

-- T019: Trigger Function - Populate Moderation Log on Event Update
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

DROP TRIGGER IF EXISTS log_moderation_action ON events;
CREATE TRIGGER log_moderation_action
AFTER UPDATE ON events
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION trigger_log_moderation();

COMMENT ON TRIGGER log_moderation_action ON events IS 'Create immutable audit log entry when event is moderated (FR-059)';

-- T020: Trigger Function - Update Timestamps Automatically
CREATE OR REPLACE FUNCTION trigger_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to tables with updated_at column
DROP TRIGGER IF EXISTS update_timestamp_user_roles ON user_roles;
CREATE TRIGGER update_timestamp_user_roles
BEFORE UPDATE ON user_roles
FOR EACH ROW
EXECUTE FUNCTION trigger_update_timestamp();

DROP TRIGGER IF EXISTS update_timestamp_moderator_stats ON moderator_stats;
CREATE TRIGGER update_timestamp_moderator_stats
BEFORE UPDATE ON moderator_stats
FOR EACH ROW
EXECUTE FUNCTION trigger_update_timestamp();

COMMENT ON FUNCTION trigger_update_timestamp IS 'Automatically update updated_at timestamp on row modification';

-- =============================================================================
-- RLS POLICIES
-- =============================================================================

-- User Roles Table Policies
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

CREATE POLICY "Users can view own roles"
ON user_roles FOR SELECT
TO authenticated
USING (user_id = auth.uid());

COMMENT ON POLICY "Admins can manage roles" ON user_roles IS 'Only admins can INSERT/UPDATE/DELETE role assignments';
COMMENT ON POLICY "Users can view own roles" ON user_roles IS 'All users can read their own role (needed for role-based UI)';

-- Events Table Policies (RLS already enabled in previous migrations)
DROP POLICY IF EXISTS "Students see approved events" ON events;
CREATE POLICY "Students see approved events"
ON events FOR SELECT
TO authenticated
USING (
  status = 'approved'
  OR created_by = auth.uid()  -- Can see own events regardless of status
);

DROP POLICY IF EXISTS "Moderators see all events" ON events;
CREATE POLICY "Moderators see all events"
ON events FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
  )
);

DROP POLICY IF EXISTS "Students can create events" ON events;
CREATE POLICY "Students can create events"
ON events FOR INSERT
TO authenticated
WITH CHECK (
  created_by = auth.uid()
  AND status = 'pending'  -- Force new events to pending
);

DROP POLICY IF EXISTS "Creators can update rejected events" ON events;
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

DROP POLICY IF EXISTS "Moderators can moderate events" ON events;
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

-- Moderation Log Policies
CREATE POLICY "Moderators can view logs"
ON moderation_log FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
  )
);

COMMENT ON POLICY "Moderators can view logs" ON moderation_log IS 'Moderators and admins can read audit logs for transparency (FR-049)';

-- Admin Log Policies
CREATE POLICY "Admins can view admin logs"
ON admin_log FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

COMMENT ON POLICY "Admins can view admin logs" ON admin_log IS 'Admins can read audit trail of role changes (FR-050)';

-- Role History Policies
CREATE POLICY "Admins can view role history"
ON role_history FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

-- Moderator Statistics Policies
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

CREATE POLICY "Admins can view all stats"
ON moderator_stats FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

COMMENT ON POLICY "Moderators can view own stats" ON moderator_stats IS 'Moderators see their own statistics (FR-029)';
COMMENT ON POLICY "Admins can view all stats" ON moderator_stats IS 'Admins see all moderator statistics for monitoring (FR-041)';

-- Moderator Statistics Archive Policies
CREATE POLICY "Admins can view archived stats"
ON moderator_stats_archive FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

-- Notifications Policies
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
TO authenticated
USING (recipient_id = auth.uid());

-- =============================================================================
-- VERIFICATION
-- =============================================================================

DO $$
BEGIN
  -- Verify all tables exist
  IF (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN (
    'user_roles', 'moderation_log', 'admin_log', 'role_history',
    'moderator_stats', 'moderator_stats_archive', 'notifications'
  )) != 7 THEN
    RAISE EXCEPTION 'Not all required tables were created';
  END IF;

  -- Verify all functions exist
  IF (SELECT COUNT(*) FROM pg_proc WHERE proname IN (
    'has_role', 'moderate_event', 'calculate_moderator_stats',
    'promote_to_moderator', 'remove_moderator_role', 'get_system_statistics'
  )) < 6 THEN
    RAISE EXCEPTION 'Not all required functions were created';
  END IF;

  RAISE NOTICE 'Migration completed successfully!';
  RAISE NOTICE 'Tables created: 7 (user_roles, moderation_log, admin_log, role_history, moderator_stats, moderator_stats_archive, notifications)';
  RAISE NOTICE 'Events table modified: Added status, moderated_by, moderated_at, rejection_reason, submission_count columns';
  RAISE NOTICE 'Views created: 1 (system_statistics)';
  RAISE NOTICE 'Functions created: 6 (has_role, moderate_event, calculate_moderator_stats, promote_to_moderator, remove_moderator_role, get_system_statistics)';
  RAISE NOTICE 'Triggers created: 4 (update_moderator_stats_after_moderation, notify_event_moderation, log_moderation_action, update_timestamp triggers)';
  RAISE NOTICE 'Indexes created: 15+ performance-critical indexes';
  RAISE NOTICE 'RLS Policies created: 13+ policies across all tables';
END $$;

COMMIT;
