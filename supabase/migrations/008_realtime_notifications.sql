-- =====================================================================
-- Migration: 008_realtime_notifications.sql
-- Feature: Real-Time In-App Notifications System
-- Date: 2025-11-23
-- Description: Implements real-time notification system with 6 channels,
--              user preferences, Supabase Realtime support, and GDPR
--              90-day auto-deletion for privacy compliance
-- =====================================================================

-- =====================================================================
-- PART 1: EXTEND PROFILES TABLE WITH NOTIFICATION PREFERENCES
-- =====================================================================
-- Add 6 notification preference columns (opt-out model: all default TRUE)

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS eventi_moderati_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS nuovi_commenti_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS risposte_commenti_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS like_eventi_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS nuove_partecipazioni_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS coorganizer_updates_enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- Add comments for documentation
COMMENT ON COLUMN profiles.eventi_moderati_enabled IS 'Event moderation notifications (approved/rejected) - default enabled';
COMMENT ON COLUMN profiles.nuovi_commenti_enabled IS 'New comment notifications on user events - default enabled';
COMMENT ON COLUMN profiles.risposte_commenti_enabled IS 'Reply notifications on user comments - default enabled';
COMMENT ON COLUMN profiles.like_eventi_enabled IS 'Like notifications on user events - default enabled';
COMMENT ON COLUMN profiles.nuove_partecipazioni_enabled IS 'Participation notifications on user events - default enabled';
COMMENT ON COLUMN profiles.coorganizer_updates_enabled IS 'Co-organizer update notifications - default enabled';

-- =====================================================================
-- PART 2: CREATE NOTIFICATIONS TABLE
-- =====================================================================
-- Core table for storing all notification records

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipient_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  sender_id UUID REFERENCES profiles(user_id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN (
    'event_moderation',
    'new_comment',
    'comment_reply',
    'event_like',
    'event_participation',
    'coorganizer_update'
  )),
  title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 200),
  description TEXT NOT NULL CHECK (LENGTH(description) BETWEEN 1 AND 500),
  target_type TEXT NOT NULL CHECK (target_type IN ('event', 'comment')),
  target_id UUID NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add table comment
COMMENT ON TABLE notifications IS 'Stores all in-app notifications with real-time delivery via Supabase Realtime. Auto-deleted after 90 days (GDPR compliance).';

-- =====================================================================
-- PART 3: CREATE INDEXES FOR PERFORMANCE
-- =====================================================================

-- Composite index for fetching user notifications sorted by recency
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_created
  ON notifications(recipient_id, created_at DESC);

-- Partial index for unread badge count queries (only indexes unread notifications)
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread
  ON notifications(recipient_id, is_read)
  WHERE is_read = FALSE;

-- Index for 90-day auto-deletion cron job
CREATE INDEX IF NOT EXISTS idx_notifications_created_at
  ON notifications(created_at);

COMMENT ON INDEX idx_notifications_recipient_created IS 'Optimized for notification center queries (user-specific, sorted by recency)';
COMMENT ON INDEX idx_notifications_recipient_unread IS 'Partial index for badge count queries (unread notifications only)';
COMMENT ON INDEX idx_notifications_created_at IS 'For 90-day auto-deletion cron job';

-- =====================================================================
-- PART 4: ENABLE ROW-LEVEL SECURITY
-- =====================================================================

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- PART 5: CREATE RLS POLICIES FOR NOTIFICATIONS TABLE
-- =====================================================================

-- =====================
-- SELECT Policy
-- =====================

-- Users can only view their own notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications"
  ON notifications
  FOR SELECT
  USING (auth.uid() = recipient_id);

-- =====================
-- UPDATE Policy
-- =====================

-- Users can update (mark as read) their own notifications
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications"
  ON notifications
  FOR UPDATE
  USING (auth.uid() = recipient_id);

-- =====================
-- DELETE Policy
-- =====================

-- Users can delete their own notifications
DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
CREATE POLICY "Users can delete own notifications"
  ON notifications
  FOR DELETE
  USING (auth.uid() = recipient_id);

-- =====================
-- INSERT Policy
-- =====================

-- Explicit block: users cannot directly insert notifications
-- Only SECURITY DEFINER functions (create_notification) can insert
DROP POLICY IF EXISTS "System can insert notifications" ON notifications;
CREATE POLICY "System can insert notifications"
  ON notifications
  FOR INSERT
  WITH CHECK (FALSE);

COMMENT ON POLICY "System can insert notifications" ON notifications IS 'Prevents direct user INSERT. Only create_notification() SECURITY DEFINER function can insert notifications.';

-- =====================================================================
-- PART 6: CENTRALIZED NOTIFICATION CREATION FUNCTION
-- =====================================================================
-- Core function called by all triggers to create notifications
-- Handles preference checks and self-notification prevention

CREATE OR REPLACE FUNCTION create_notification(
  p_recipient_id UUID,
  p_sender_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_description TEXT,
  p_target_type TEXT,
  p_target_id UUID,
  p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if recipient has this notification type enabled
  IF NOT (
    SELECT CASE p_type
      WHEN 'event_moderation' THEN eventi_moderati_enabled
      WHEN 'new_comment' THEN nuovi_commenti_enabled
      WHEN 'comment_reply' THEN risposte_commenti_enabled
      WHEN 'event_like' THEN like_eventi_enabled
      WHEN 'event_participation' THEN nuove_partecipazioni_enabled
      WHEN 'coorganizer_update' THEN coorganizer_updates_enabled
      ELSE FALSE
    END
    FROM profiles
    WHERE user_id = p_recipient_id
  ) THEN
    RETURN; -- Recipient has disabled this notification type
  END IF;

  -- Prevent self-notifications (sender = recipient)
  IF p_sender_id = p_recipient_id THEN
    RETURN;
  END IF;

  -- Insert notification
  INSERT INTO notifications (
    recipient_id, sender_id, type, title, description,
    target_type, target_id, metadata, created_at
  ) VALUES (
    p_recipient_id, p_sender_id, p_type, p_title, p_description,
    p_target_type, p_target_id, p_metadata, NOW()
  );
END;
$$;

COMMENT ON FUNCTION create_notification IS 'Centralized notification creation with preference checks and self-notification prevention. Only callable by SECURITY DEFINER triggers.';

-- =====================================================================
-- PART 7: TRIGGER FUNCTIONS FOR NOTIFICATION GENERATION
-- =====================================================================

-- =====================
-- Event Moderation Notifications
-- =====================

CREATE OR REPLACE FUNCTION trigger_event_moderation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_title TEXT;
  v_notification_title TEXT;
  v_notification_description TEXT;
BEGIN
  -- Only trigger on status change to 'approved' or 'rejected'
  IF (OLD.status IS DISTINCT FROM NEW.status) AND (NEW.status IN ('approved', 'rejected')) THEN
    -- Get event title
    SELECT title INTO v_event_title
    FROM events
    WHERE id = NEW.id;

    -- Build notification content based on status
    IF NEW.status = 'approved' THEN
      v_notification_title := 'Evento Approvato! 🎉';
      v_notification_description := 'Il tuo evento "' || v_event_title || '" è ora visibile a tutti';
    ELSE -- rejected
      v_notification_title := 'Evento Rifiutato';
      v_notification_description := COALESCE(NEW.rejection_reason, 'Il tuo evento non rispetta le linee guida della community');
    END IF;

    -- Create notification
    PERFORM create_notification(
      p_recipient_id := NEW.creator_id,
      p_sender_id := NULL, -- System notification
      p_type := 'event_moderation',
      p_title := v_notification_title,
      p_description := v_notification_description,
      p_target_type := 'event',
      p_target_id := NEW.id,
      p_metadata := jsonb_build_object('status', NEW.status)
    );
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_event_moderation_notification IS 'Trigger: Notifies event creator when moderator approves or rejects event';

-- =====================
-- New Comment Notifications
-- =====================

CREATE OR REPLACE FUNCTION trigger_comment_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_creator_id UUID;
  v_commenter_name TEXT;
  v_comment_preview TEXT;
BEGIN
  -- Get event creator ID
  SELECT creator_id INTO v_event_creator_id
  FROM events
  WHERE id = NEW.event_id;

  -- Get commenter name
  SELECT full_name INTO v_commenter_name
  FROM profiles
  WHERE user_id = NEW.user_id;

  -- Get comment preview (first 100 characters)
  v_comment_preview := LEFT(NEW.content, 100);

  -- Create notification
  PERFORM create_notification(
    p_recipient_id := v_event_creator_id,
    p_sender_id := NEW.user_id,
    p_type := 'new_comment',
    p_title := v_commenter_name || ' ha commentato sul tuo evento',
    p_description := v_comment_preview,
    p_target_type := 'event',
    p_target_id := NEW.event_id,
    p_metadata := jsonb_build_object('comment_id', NEW.id)
  );

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_comment_notification IS 'Trigger: Notifies event creator when someone comments on their event';

-- =====================
-- Comment Reply Notifications
-- =====================

CREATE OR REPLACE FUNCTION trigger_comment_reply_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_parent_comment_user_id UUID;
  v_replier_name TEXT;
  v_event_id UUID;
BEGIN
  -- Only trigger if this is a reply (has parent_comment_id)
  IF NEW.parent_comment_id IS NOT NULL THEN
    -- Get original commenter's user_id
    SELECT user_id INTO v_parent_comment_user_id
    FROM comments
    WHERE id = NEW.parent_comment_id;

    -- Get event_id for notification target
    SELECT event_id INTO v_event_id
    FROM comments
    WHERE id = NEW.parent_comment_id;

    -- Get replier name
    SELECT full_name INTO v_replier_name
    FROM profiles
    WHERE user_id = NEW.user_id;

    -- Create notification
    PERFORM create_notification(
      p_recipient_id := v_parent_comment_user_id,
      p_sender_id := NEW.user_id,
      p_type := 'comment_reply',
      p_title := v_replier_name || ' ha risposto al tuo commento',
      p_description := LEFT(NEW.content, 100),
      p_target_type := 'comment',
      p_target_id := NEW.id,
      p_metadata := jsonb_build_object(
        'parent_comment_id', NEW.parent_comment_id,
        'event_id', v_event_id
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_comment_reply_notification IS 'Trigger: Notifies original commenter when someone replies to their comment';

-- =====================
-- Event Like Notifications
-- =====================

CREATE OR REPLACE FUNCTION trigger_event_like_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_creator_id UUID;
  v_liker_name TEXT;
BEGIN
  -- Get event creator ID
  SELECT creator_id INTO v_event_creator_id
  FROM events
  WHERE id = NEW.event_id;

  -- Get liker name
  SELECT full_name INTO v_liker_name
  FROM profiles
  WHERE user_id = NEW.user_id;

  -- Create notification
  PERFORM create_notification(
    p_recipient_id := v_event_creator_id,
    p_sender_id := NEW.user_id,
    p_type := 'event_like',
    p_title := v_liker_name || ' ha messo like al tuo evento',
    p_description := '',
    p_target_type := 'event',
    p_target_id := NEW.event_id,
    p_metadata := '{}'::jsonb
  );

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_event_like_notification IS 'Trigger: Notifies event creator when someone likes their event';

-- =====================
-- Event Participation Notifications
-- =====================

CREATE OR REPLACE FUNCTION trigger_event_participation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_creator_id UUID;
  v_participant_name TEXT;
BEGIN
  -- Get event creator ID
  SELECT creator_id INTO v_event_creator_id
  FROM events
  WHERE id = NEW.event_id;

  -- Get participant name
  SELECT full_name INTO v_participant_name
  FROM profiles
  WHERE user_id = NEW.user_id;

  -- Create notification
  PERFORM create_notification(
    p_recipient_id := v_event_creator_id,
    p_sender_id := NEW.user_id,
    p_type := 'event_participation',
    p_title := v_participant_name || ' parteciperà al tuo evento',
    p_description := '',
    p_target_type := 'event',
    p_target_id := NEW.event_id,
    p_metadata := '{}'::jsonb
  );

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_event_participation_notification IS 'Trigger: Notifies event creator when someone joins their event as participant';

-- =====================
-- Co-Organizer Update Notifications
-- =====================

CREATE OR REPLACE FUNCTION trigger_coorganizer_update_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_co_organizer_id UUID;
  v_editor_name TEXT;
  v_event_title TEXT;
BEGIN
  -- Only trigger on UPDATE (not INSERT) and if co_organizer_ids field exists and is not empty
  IF (TG_OP = 'UPDATE') AND (NEW.co_organizer_ids IS NOT NULL) AND (array_length(NEW.co_organizer_ids, 1) > 0) THEN
    -- Get editor name (the user who made the update, assumed to be current session user)
    SELECT full_name INTO v_editor_name
    FROM profiles
    WHERE user_id = auth.uid();

    -- Get event title
    v_event_title := NEW.title;

    -- Loop through co-organizers and notify each (except the editor)
    FOREACH v_co_organizer_id IN ARRAY NEW.co_organizer_ids LOOP
      PERFORM create_notification(
        p_recipient_id := v_co_organizer_id,
        p_sender_id := auth.uid(),
        p_type := 'coorganizer_update',
        p_title := COALESCE(v_editor_name, 'Organizzatore') || ' ha modificato ' || v_event_title,
        p_description := 'Controlla i dettagli aggiornati dell''evento',
        p_target_type := 'event',
        p_target_id := NEW.id,
        p_metadata := jsonb_build_object('updated_at', NOW())
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_coorganizer_update_notification IS 'Trigger: Notifies co-organizers when primary organizer edits event details';

-- =====================================================================
-- PART 8: ATTACH TRIGGERS TO TABLES
-- =====================================================================

-- Event moderation trigger (on events table)
DROP TRIGGER IF EXISTS on_event_moderation_notify_creator ON events;
CREATE TRIGGER on_event_moderation_notify_creator
  AFTER UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION trigger_event_moderation_notification();

-- New comment trigger (on comments table)
DROP TRIGGER IF EXISTS on_comment_create_notify_event_creator ON comments;
CREATE TRIGGER on_comment_create_notify_event_creator
  AFTER INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION trigger_comment_notification();

-- Comment reply trigger (on comments table, same table handles replies via parent_comment_id)
DROP TRIGGER IF EXISTS on_comment_reply_notify_parent_commenter ON comments;
CREATE TRIGGER on_comment_reply_notify_parent_commenter
  AFTER INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION trigger_comment_reply_notification();

-- Event like trigger (on likes table)
DROP TRIGGER IF EXISTS on_event_like_notify_creator ON likes;
CREATE TRIGGER on_event_like_notify_creator
  AFTER INSERT ON likes
  FOR EACH ROW
  EXECUTE FUNCTION trigger_event_like_notification();

-- Event participation trigger (on participations table)
DROP TRIGGER IF EXISTS on_participation_notify_event_creator ON participations;
CREATE TRIGGER on_participation_notify_event_creator
  AFTER INSERT ON participations
  FOR EACH ROW
  EXECUTE FUNCTION trigger_event_participation_notification();

-- Co-organizer update trigger (on events table)
DROP TRIGGER IF EXISTS on_event_update_notify_coorganizers ON events;
CREATE TRIGGER on_event_update_notify_coorganizers
  AFTER UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION trigger_coorganizer_update_notification();

-- =====================================================================
-- PART 9: 90-DAY AUTO-DELETION (GDPR COMPLIANCE)
-- =====================================================================
-- Enable pg_cron extension and schedule daily cleanup job

-- Enable extension (requires superuser or rds_superuser role)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule daily cleanup at 2 AM UTC (low-traffic time)
SELECT cron.schedule(
  'delete-old-notifications',                           -- Job name
  '0 2 * * *',                                          -- Cron expression: 2 AM daily
  $$DELETE FROM notifications WHERE created_at < NOW() - INTERVAL '90 days'$$
);

COMMENT ON EXTENSION pg_cron IS 'Scheduled jobs for 90-day notification auto-deletion (GDPR compliance)';

-- =====================================================================
-- MIGRATION VERIFICATION QUERIES
-- =====================================================================
-- Run these queries to verify migration success:
--
-- 1. Check profiles table extended:
--    SELECT eventi_moderati_enabled, nuovi_commenti_enabled FROM profiles LIMIT 1;
--
-- 2. Check notifications table created:
--    SELECT table_name FROM information_schema.tables WHERE table_name = 'notifications';
--
-- 3. Check indexes created:
--    SELECT indexname FROM pg_indexes WHERE tablename = 'notifications';
--
-- 4. Check RLS enabled:
--    SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'notifications';
--
-- 5. Check cron job scheduled:
--    SELECT * FROM cron.job WHERE jobname = 'delete-old-notifications';
--
-- 6. Test notification creation (requires existing event and users):
--    -- Create test comment
--    INSERT INTO comments (event_id, user_id, content) VALUES ('<event_id>', '<user_id>', 'Test comment');
--    -- Check notification created
--    SELECT * FROM notifications WHERE type = 'new_comment' ORDER BY created_at DESC LIMIT 1;
--
-- =====================================================================
-- MIGRATION COMPLETE
-- =====================================================================
