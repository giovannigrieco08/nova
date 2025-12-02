-- =====================================================================
-- Migration: 009_moderator_comment_notifications.sql
-- Purpose: Add notification trigger for moderators when comments are auto-hidden
-- Task: T067 - Add notification to moderators when comment auto-hidden
--
-- Constitutional Compliance:
-- - CONTENT_MODERATION: Moderators notified of auto-hidden content
-- - PRIVACY_FOUNDATION: Only moderator alerts, no extra data collection
-- =====================================================================

-- =====================================================================
-- PART 1: ADD MODERATOR ALERT PREFERENCE TO PROFILES
-- =====================================================================

-- Add notification preference for moderator alerts (only for moderators/admins)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS moderator_alerts_enabled BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN profiles.moderator_alerts_enabled IS 'Whether to receive moderator alerts (auto-hidden comments, reports). Only applicable to moderators/admins.';

-- =====================================================================
-- PART 2: UPDATE NOTIFICATION CREATION FUNCTION
-- =====================================================================

-- Update create_notification to handle moderator_alert type
CREATE OR REPLACE FUNCTION create_notification(
  p_recipient_id UUID,
  p_sender_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_description TEXT,
  p_target_type TEXT,
  p_target_id UUID,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notification_id UUID;
  v_preference_enabled BOOLEAN;
BEGIN
  -- Check if recipient has this notification type enabled
  SELECT
    CASE p_type
      WHEN 'event_moderation' THEN eventi_moderati_enabled
      WHEN 'new_comment' THEN nuovi_commenti_enabled
      WHEN 'comment_reply' THEN risposte_commenti_enabled
      WHEN 'event_like' THEN like_eventi_enabled
      WHEN 'event_participation' THEN nuove_partecipazioni_enabled
      WHEN 'coorganizer_update' THEN coorganizer_updates_enabled
      WHEN 'moderator_alert' THEN moderator_alerts_enabled
      ELSE TRUE -- Unknown types default to enabled
    END INTO v_preference_enabled
  FROM profiles
  WHERE user_id = p_recipient_id;

  -- If preference is disabled or user doesn't exist, skip notification
  IF NOT COALESCE(v_preference_enabled, FALSE) THEN
    RETURN NULL;
  END IF;

  -- Create notification
  INSERT INTO notifications (
    recipient_id,
    sender_id,
    type,
    title,
    description,
    target_type,
    target_id,
    metadata
  ) VALUES (
    p_recipient_id,
    p_sender_id,
    p_type,
    p_title,
    p_description,
    p_target_type,
    p_target_id,
    p_metadata
  )
  RETURNING id INTO v_notification_id;

  RETURN v_notification_id;
END;
$$;

-- =====================================================================
-- PART 3: CREATE FUNCTION TO NOTIFY MODERATORS ON AUTO-HIDE
-- =====================================================================

CREATE OR REPLACE FUNCTION notify_moderators_on_auto_hide()
RETURNS TRIGGER AS $$
DECLARE
  v_moderator RECORD;
  v_event_title TEXT;
  v_comment_text TEXT;
BEGIN
  -- Only trigger when comment is newly auto-hidden
  IF NEW.hidden_at IS NOT NULL
     AND NEW.hidden_reason = 'auto_hide_reports'
     AND (OLD.hidden_at IS NULL OR OLD.hidden_reason IS NULL) THEN

    -- Get event title for notification context
    SELECT e.title INTO v_event_title
    FROM events e
    WHERE e.id = NEW.event_id;

    -- Get truncated comment text (max 50 chars)
    v_comment_text := LEFT(NEW.text, 50);
    IF LENGTH(NEW.text) > 50 THEN
      v_comment_text := v_comment_text || '...';
    END IF;

    -- Notify all moderators and admins
    FOR v_moderator IN
      SELECT ur.user_id
      FROM user_roles ur
      WHERE ur.role IN ('moderator', 'admin')
    LOOP
      PERFORM create_notification(
        v_moderator.user_id,                                    -- recipient_id
        NULL,                                                    -- sender_id (system notification)
        'moderator_alert',                                       -- type
        'Commento auto-nascosto',                               -- title
        'Commento nascosto da 3+ segnalazioni: "' || v_comment_text || '"', -- description
        'comment',                                              -- target_type
        NEW.id,                                                 -- target_id
        jsonb_build_object(
          'event_id', NEW.event_id,
          'event_title', v_event_title,
          'report_count', NEW.report_count,
          'hidden_reason', NEW.hidden_reason
        )
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- PART 4: CREATE TRIGGER FOR AUTO-HIDE NOTIFICATIONS
-- =====================================================================

-- Drop existing trigger if exists (for idempotency)
DROP TRIGGER IF EXISTS notify_moderators_on_comment_auto_hide ON comments;

-- Create trigger that fires after comment is updated with auto-hide
CREATE TRIGGER notify_moderators_on_comment_auto_hide
  AFTER UPDATE ON comments
  FOR EACH ROW
  WHEN (NEW.hidden_at IS NOT NULL AND NEW.hidden_reason = 'auto_hide_reports')
  EXECUTE FUNCTION notify_moderators_on_auto_hide();

-- =====================================================================
-- COMMENTS
-- =====================================================================

COMMENT ON FUNCTION notify_moderators_on_auto_hide() IS
  'T067: Notifies all moderators when a comment is auto-hidden due to 3+ reports';

COMMENT ON TRIGGER notify_moderators_on_comment_auto_hide ON comments IS
  'Fires when a comment is auto-hidden, creating notifications for moderators';
