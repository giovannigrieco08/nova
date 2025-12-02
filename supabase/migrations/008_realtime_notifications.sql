-- =====================================================================
-- Migration: 006_realtime_notifications.sql
-- Feature: 008-realtime-notifications (Real-Time In-App Notifications)
-- Date: 2025-11-29
-- Purpose: Create notifications system with Supabase Realtime support
-- =====================================================================
--
-- This migration:
-- 1. Extends profiles table with 6 notification preference columns
-- 2. Creates notifications table with RLS policies
-- 3. Creates centralized create_notification() function (SECURITY DEFINER)
-- 4. Creates 6 trigger functions for automatic notification generation
-- 5. Schedules 90-day auto-deletion job (GDPR compliance)
--
-- Constitutional Compliance:
-- - PRIVACY_FOUNDATION: RLS enforces user-only access, 90-day auto-delete
-- - PERFORMANCE_FIRST: Indexes optimized for <1s Realtime delivery
-- - STUDENTS_FIRST: Opt-out model (all enabled by default)
-- =====================================================================

-- =====================================================================
-- PART 1: EXTEND PROFILES TABLE WITH NOTIFICATION PREFERENCES
-- =====================================================================

-- Add 6 notification preference columns (opt-out model: all enabled by default)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS eventi_moderati_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS nuovi_commenti_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS risposte_commenti_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS like_eventi_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS nuove_partecipazioni_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS coorganizer_updates_enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- Add column comments
COMMENT ON COLUMN profiles.eventi_moderati_enabled IS 'Receive notifications when events are approved/rejected';
COMMENT ON COLUMN profiles.nuovi_commenti_enabled IS 'Receive notifications when someone comments on your events';
COMMENT ON COLUMN profiles.risposte_commenti_enabled IS 'Receive notifications when someone replies to your comments';
COMMENT ON COLUMN profiles.like_eventi_enabled IS 'Receive notifications when someone likes your events';
COMMENT ON COLUMN profiles.nuove_partecipazioni_enabled IS 'Receive notifications when someone joins your events';
COMMENT ON COLUMN profiles.coorganizer_updates_enabled IS 'Receive notifications when events you co-organize are edited';

-- =====================================================================
-- PART 2: CREATE NOTIFICATIONS TABLE
-- =====================================================================

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Recipient (who receives this notification)
  recipient_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,

  -- Sender (who triggered this notification, NULL for system notifications)
  sender_id UUID REFERENCES profiles(user_id) ON DELETE SET NULL,

  -- Notification type (one of 6 channels)
  type TEXT NOT NULL CHECK (type IN (
    'event_moderation',    -- Event approved/rejected
    'new_comment',         -- New comment on your event
    'comment_reply',       -- Reply to your comment
    'event_like',          -- Someone liked your event
    'event_participation', -- Someone joined your event
    'coorganizer_update'   -- Event you co-organize was edited
  )),

  -- Content
  title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 200),
  description TEXT NOT NULL CHECK (LENGTH(description) BETWEEN 1 AND 500),

  -- Navigation target
  target_type TEXT NOT NULL CHECK (target_type IN ('event', 'comment')),
  target_id UUID NOT NULL,

  -- Additional metadata (JSON)
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

  -- Read status
  is_read BOOLEAN NOT NULL DEFAULT FALSE,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table comment
COMMENT ON TABLE notifications IS 'In-app notifications for Nova platform (GDPR: auto-deleted after 90 days)';

-- =====================================================================
-- PART 3: PERFORMANCE INDEXES
-- =====================================================================

-- Primary query index: user's notifications ordered by time (for notification list)
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_created
  ON notifications(recipient_id, created_at DESC);

-- Partial index for unread count badge (highly optimized)
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread
  ON notifications(recipient_id)
  WHERE is_read = FALSE;

-- Index for 90-day deletion job
CREATE INDEX IF NOT EXISTS idx_notifications_created_at
  ON notifications(created_at);

-- =====================================================================
-- PART 4: ENABLE ROW-LEVEL SECURITY
-- =====================================================================

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- PART 5: RLS POLICIES
-- =====================================================================

-- Policy 1: Users can only view their own notifications
CREATE POLICY "Users can view own notifications"
  ON notifications
  FOR SELECT
  USING (auth.uid() = recipient_id);

-- Policy 2: Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications"
  ON notifications
  FOR UPDATE
  USING (auth.uid() = recipient_id)
  WITH CHECK (auth.uid() = recipient_id);

-- Policy 3: Users can delete their own notifications
CREATE POLICY "Users can delete own notifications"
  ON notifications
  FOR DELETE
  USING (auth.uid() = recipient_id);

-- Policy 4: Block direct INSERT (only SECURITY DEFINER functions can insert)
-- This prevents users from creating fake notifications
CREATE POLICY "System only insert notifications"
  ON notifications
  FOR INSERT
  WITH CHECK (FALSE);

-- =====================================================================
-- PART 6: CENTRALIZED NOTIFICATION CREATION FUNCTION
-- =====================================================================

-- This function is SECURITY DEFINER to bypass RLS for system-generated notifications
-- It checks user preferences before creating notifications
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
      ELSE TRUE -- Unknown types default to enabled
    END INTO v_preference_enabled
  FROM profiles
  WHERE user_id = p_recipient_id;

  -- If preference is disabled or user doesn't exist, skip notification
  IF NOT COALESCE(v_preference_enabled, FALSE) THEN
    RETURN NULL;
  END IF;

  -- Prevent self-notifications (don't notify yourself of your own actions)
  IF p_sender_id = p_recipient_id THEN
    RETURN NULL;
  END IF;

  -- Insert notification (bypasses RLS due to SECURITY DEFINER)
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

COMMENT ON FUNCTION create_notification IS 'Creates notification if recipient preferences allow it. Returns NULL if skipped.';

-- =====================================================================
-- PART 7: TRIGGER FUNCTIONS FOR AUTOMATIC NOTIFICATION GENERATION
-- =====================================================================

-- 7.1: Event Moderation Notification (approved/rejected)
CREATE OR REPLACE FUNCTION trigger_event_moderation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title TEXT;
  v_description TEXT;
  v_metadata JSONB;
BEGIN
  -- Only trigger on status change to approved or rejected
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  IF NEW.status NOT IN ('approved', 'rejected') THEN
    RETURN NEW;
  END IF;

  -- Build notification content
  IF NEW.status = 'approved' THEN
    v_title := 'Il tuo evento è stato approvato!';
    v_description := 'Il tuo evento "' || LEFT(NEW.title, 50) || '" è ora visibile a tutti gli studenti.';
    v_metadata := '{}'::jsonb;
  ELSE
    v_title := 'Il tuo evento è stato rifiutato';
    v_description := COALESCE(NEW.rejection_reason, 'Contatta un moderatore per maggiori informazioni.');
    v_metadata := jsonb_build_object('rejection_reason', NEW.rejection_reason);
  END IF;

  -- Create notification for event creator
  PERFORM create_notification(
    NEW.creator_id,
    NEW.moderated_by,
    'event_moderation',
    v_title,
    v_description,
    'event',
    NEW.id,
    v_metadata
  );

  RETURN NEW;
END;
$$;

-- 7.2: New Comment Notification
CREATE OR REPLACE FUNCTION trigger_comment_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_creator_id UUID;
  v_event_title TEXT;
  v_sender_name TEXT;
BEGIN
  -- Get event creator and title
  SELECT creator_id, title INTO v_event_creator_id, v_event_title
  FROM events
  WHERE id = NEW.event_id;

  -- Get commenter's name
  SELECT full_name INTO v_sender_name
  FROM profiles
  WHERE user_id = NEW.user_id;

  -- Create notification for event creator (only if not replying to someone)
  IF NEW.parent_comment_id IS NULL THEN
    PERFORM create_notification(
      v_event_creator_id,
      NEW.user_id,
      'new_comment',
      v_sender_name || ' ha commentato sul tuo evento',
      LEFT(NEW.content, 100),
      'event',
      NEW.event_id,
      jsonb_build_object('comment_id', NEW.id)
    );
  END IF;

  RETURN NEW;
END;
$$;

-- 7.3: Comment Reply Notification
CREATE OR REPLACE FUNCTION trigger_comment_reply_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_parent_author_id UUID;
  v_sender_name TEXT;
BEGIN
  -- Only for replies (parent_comment_id is not null)
  IF NEW.parent_comment_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get parent comment author
  SELECT user_id INTO v_parent_author_id
  FROM comments
  WHERE id = NEW.parent_comment_id;

  -- Get replier's name
  SELECT full_name INTO v_sender_name
  FROM profiles
  WHERE user_id = NEW.user_id;

  -- Create notification for parent comment author
  PERFORM create_notification(
    v_parent_author_id,
    NEW.user_id,
    'comment_reply',
    v_sender_name || ' ha risposto al tuo commento',
    LEFT(NEW.content, 100),
    'comment',
    NEW.parent_comment_id,
    jsonb_build_object('reply_id', NEW.id, 'event_id', NEW.event_id)
  );

  RETURN NEW;
END;
$$;

-- 7.4: Event Like Notification
CREATE OR REPLACE FUNCTION trigger_event_like_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_creator_id UUID;
  v_event_title TEXT;
  v_sender_name TEXT;
BEGIN
  -- Get event creator and title
  SELECT creator_id, title INTO v_event_creator_id, v_event_title
  FROM events
  WHERE id = NEW.event_id;

  -- Get liker's name
  SELECT full_name INTO v_sender_name
  FROM profiles
  WHERE user_id = NEW.user_id;

  -- Create notification
  PERFORM create_notification(
    v_event_creator_id,
    NEW.user_id,
    'event_like',
    v_sender_name || ' ha messo like al tuo evento',
    '"' || LEFT(v_event_title, 80) || '"',
    'event',
    NEW.event_id,
    '{}'::jsonb
  );

  RETURN NEW;
END;
$$;

-- 7.5: Event Participation Notification
CREATE OR REPLACE FUNCTION trigger_event_participation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_creator_id UUID;
  v_event_title TEXT;
  v_sender_name TEXT;
BEGIN
  -- Get event creator and title
  SELECT creator_id, title INTO v_event_creator_id, v_event_title
  FROM events
  WHERE id = NEW.event_id;

  -- Get participant's name
  SELECT full_name INTO v_sender_name
  FROM profiles
  WHERE user_id = NEW.user_id;

  -- Create notification
  PERFORM create_notification(
    v_event_creator_id,
    NEW.user_id,
    'event_participation',
    v_sender_name || ' parteciperà al tuo evento',
    '"' || LEFT(v_event_title, 80) || '"',
    'event',
    NEW.event_id,
    '{}'::jsonb
  );

  RETURN NEW;
END;
$$;

-- 7.6: Co-organizer Update Notification
CREATE OR REPLACE FUNCTION trigger_coorganizer_update_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_coorganizer_id UUID;
  v_updater_name TEXT;
BEGIN
  -- Only trigger on event updates (not status changes)
  IF OLD.title = NEW.title
     AND OLD.description = NEW.description
     AND OLD.event_date = NEW.event_date
     AND OLD.location = NEW.location THEN
    RETURN NEW;
  END IF;

  -- Get updater's name
  SELECT full_name INTO v_updater_name
  FROM profiles
  WHERE user_id = NEW.creator_id; -- Assuming creator made the update

  -- Notify each co-organizer
  FOREACH v_coorganizer_id IN ARRAY COALESCE(NEW.co_organizers, '{}')
  LOOP
    PERFORM create_notification(
      v_coorganizer_id,
      NEW.creator_id,
      'coorganizer_update',
      'L''evento che co-organizzi è stato modificato',
      '"' || LEFT(NEW.title, 80) || '" è stato aggiornato da ' || v_updater_name,
      'event',
      NEW.id,
      '{}'::jsonb
    );
  END LOOP;

  RETURN NEW;
END;
$$;

-- =====================================================================
-- PART 8: ATTACH TRIGGERS TO TABLES
-- =====================================================================

-- Drop existing triggers if they exist (for idempotent migration)
DROP TRIGGER IF EXISTS on_event_moderation_notify_creator ON events;
DROP TRIGGER IF EXISTS on_comment_create_notify_event_creator ON comments;
DROP TRIGGER IF EXISTS on_comment_reply_notify_parent_author ON comments;
DROP TRIGGER IF EXISTS on_event_like_notify_creator ON event_likes;
DROP TRIGGER IF EXISTS on_event_participation_notify_creator ON event_participants;
DROP TRIGGER IF EXISTS on_event_update_notify_coorganizers ON events;

-- Create triggers
CREATE TRIGGER on_event_moderation_notify_creator
  AFTER UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION trigger_event_moderation_notification();

-- Note: These triggers require the comments, event_likes, event_participants tables to exist
-- They will be created when those tables are available

DO $$
BEGIN
  -- Check if comments table exists before creating trigger
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'comments') THEN
    CREATE TRIGGER on_comment_create_notify_event_creator
      AFTER INSERT ON comments
      FOR EACH ROW
      EXECUTE FUNCTION trigger_comment_notification();

    CREATE TRIGGER on_comment_reply_notify_parent_author
      AFTER INSERT ON comments
      FOR EACH ROW
      EXECUTE FUNCTION trigger_comment_reply_notification();
  END IF;

  -- Check if event_likes table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'event_likes') THEN
    CREATE TRIGGER on_event_like_notify_creator
      AFTER INSERT ON event_likes
      FOR EACH ROW
      EXECUTE FUNCTION trigger_event_like_notification();
  END IF;

  -- Check if event_participants table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'event_participants') THEN
    CREATE TRIGGER on_event_participation_notify_creator
      AFTER INSERT ON event_participants
      FOR EACH ROW
      EXECUTE FUNCTION trigger_event_participation_notification();
  END IF;
END $$;

-- Co-organizer trigger on events table (events table always exists)
CREATE TRIGGER on_event_update_notify_coorganizers
  AFTER UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION trigger_coorganizer_update_notification();

-- =====================================================================
-- PART 9: GDPR 90-DAY AUTO-DELETION (pg_cron)
-- =====================================================================

-- Enable pg_cron extension if available (Supabase has this enabled)
-- Note: This may require superuser privileges on some setups
DO $$
BEGIN
  -- Try to create extension, ignore if it fails (might already exist or not be available)
  CREATE EXTENSION IF NOT EXISTS pg_cron;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron extension not available. Manual deletion job required.';
END $$;

-- Schedule daily job at 2 AM UTC to delete notifications older than 90 days
-- This ensures GDPR compliance for data retention
DO $$
BEGIN
  -- Check if pg_cron is available before scheduling
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Remove existing job if it exists
    PERFORM cron.unschedule('delete-old-notifications');

    -- Schedule new job
    PERFORM cron.schedule(
      'delete-old-notifications',
      '0 2 * * *',  -- Every day at 2 AM UTC
      'DELETE FROM notifications WHERE created_at < NOW() - INTERVAL ''90 days'''
    );

    RAISE NOTICE 'pg_cron job scheduled: delete-old-notifications';
  ELSE
    RAISE NOTICE 'pg_cron not available. Set up manual deletion for GDPR compliance.';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Could not schedule cron job: %', SQLERRM;
END $$;

-- =====================================================================
-- PART 10: ENABLE REALTIME FOR NOTIFICATIONS TABLE
-- =====================================================================

-- Add table to Supabase Realtime publication
-- This enables Postgres CDC (Change Data Capture) for live updates
DO $$
BEGIN
  -- Check if supabase_realtime publication exists
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    -- Add notifications table to realtime publication
    ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
    RAISE NOTICE 'notifications table added to supabase_realtime publication';
  END IF;
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'notifications table already in supabase_realtime publication';
END $$;

-- =====================================================================
-- MIGRATION COMPLETE
-- =====================================================================

-- Verification query
SELECT
  'Migration 006 complete: notifications table created with ' ||
  (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'notifications') ||
  ' RLS policies, ' ||
  (SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'notifications') ||
  ' indexes' AS migration_status;
