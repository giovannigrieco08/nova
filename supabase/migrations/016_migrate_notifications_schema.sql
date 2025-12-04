-- =====================================================================
-- Migration: 016_migrate_notifications_schema.sql
-- Purpose: Migrate existing notifications table to new schema
-- Date: 2025-12-03
-- =====================================================================
--
-- This migration safely transforms the existing notifications table
-- from the old schema (user_id, channel, body) to the new schema
-- (recipient_id, sender_id, type, title, description, etc.)
-- =====================================================================

-- =====================================================================
-- STEP 1: ADD MISSING COLUMNS TO EXISTING TABLE
-- =====================================================================

-- Add recipient_id if user_id exists (rename it)
DO $$
BEGIN
  -- Check if user_id exists and recipient_id doesn't
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'notifications' AND column_name = 'user_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'notifications' AND column_name = 'recipient_id'
  ) THEN
    ALTER TABLE notifications RENAME COLUMN user_id TO recipient_id;
    RAISE NOTICE 'Renamed user_id to recipient_id';
  END IF;
END $$;

-- Add sender_id column if not exists
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS sender_id UUID REFERENCES profiles(user_id) ON DELETE SET NULL;

-- Rename channel to type if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'notifications' AND column_name = 'channel'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'notifications' AND column_name = 'type'
  ) THEN
    ALTER TABLE notifications RENAME COLUMN channel TO type;
    RAISE NOTICE 'Renamed channel to type';
  END IF;
END $$;

-- Add type column if neither channel nor type exist
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS type TEXT;

-- Rename body to description if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'notifications' AND column_name = 'body'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'notifications' AND column_name = 'description'
  ) THEN
    ALTER TABLE notifications RENAME COLUMN body TO description;
    RAISE NOTICE 'Renamed body to description';
  END IF;
END $$;

-- Add title column if not exists
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS title TEXT;

-- Add description column if not exists (in case body didn't exist)
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS description TEXT;

-- Add target_type column if not exists
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS target_type TEXT;

-- Add target_id column if not exists
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS target_id UUID;

-- Add metadata column if not exists
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Rename read to is_read if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'notifications' AND column_name = 'read'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'notifications' AND column_name = 'is_read'
  ) THEN
    ALTER TABLE notifications RENAME COLUMN read TO is_read;
    RAISE NOTICE 'Renamed read to is_read';
  END IF;
END $$;

-- Add is_read column if not exists
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE;

-- Rename sent_at to created_at if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'notifications' AND column_name = 'sent_at'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'notifications' AND column_name = 'created_at'
  ) THEN
    ALTER TABLE notifications RENAME COLUMN sent_at TO created_at;
    RAISE NOTICE 'Renamed sent_at to created_at';
  END IF;
END $$;

-- Add created_at column if not exists
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- =====================================================================
-- STEP 2: UPDATE EXISTING DATA TO NEW FORMAT
-- =====================================================================

-- Set default values for new required columns where NULL
UPDATE notifications SET title = 'Notifica' WHERE title IS NULL;
UPDATE notifications SET description = '' WHERE description IS NULL;
UPDATE notifications SET target_type = 'event' WHERE target_type IS NULL;
UPDATE notifications SET target_id = gen_random_uuid() WHERE target_id IS NULL;
UPDATE notifications SET type = 'event_moderation' WHERE type IS NULL OR type = '';

-- Map old channel values to new type values
UPDATE notifications SET type = 'event_moderation' WHERE type IN ('moderation', 'event_approved', 'event_rejected');
UPDATE notifications SET type = 'new_comment' WHERE type IN ('comment', 'new_comment');
UPDATE notifications SET type = 'comment_reply' WHERE type IN ('reply', 'comment_reply');
UPDATE notifications SET type = 'event_like' WHERE type IN ('like', 'event_like');
UPDATE notifications SET type = 'event_participation' WHERE type IN ('participation', 'event_participation', 'join');
UPDATE notifications SET type = 'coorganizer_update' WHERE type IN ('coorganizer', 'coorganizer_update');
UPDATE notifications SET type = 'chat_mention' WHERE type IN ('mention', 'chat_mention', 'chat');

-- =====================================================================
-- STEP 3: ADD CONSTRAINTS (drop existing if needed)
-- =====================================================================

-- Drop old constraints if they exist
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_target_type_check;
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_title_check;
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_description_check;

-- Add new constraints
DO $$
BEGIN
  -- Type constraint
  ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
    CHECK (type IN (
      'event_moderation',
      'new_comment',
      'comment_reply',
      'event_like',
      'event_participation',
      'coorganizer_update',
      'chat_mention'
    ));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Type constraint already exists or failed: %', SQLERRM;
END $$;

DO $$
BEGIN
  -- Target type constraint
  ALTER TABLE notifications ADD CONSTRAINT notifications_target_type_check
    CHECK (target_type IN ('event', 'comment', 'chat_message'));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Target type constraint already exists or failed: %', SQLERRM;
END $$;

-- =====================================================================
-- STEP 4: CREATE INDEXES
-- =====================================================================

-- Primary query index
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_created
  ON notifications(recipient_id, created_at DESC);

-- Partial index for unread count
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread
  ON notifications(recipient_id)
  WHERE is_read = FALSE;

-- Index for cleanup job
CREATE INDEX IF NOT EXISTS idx_notifications_created_at
  ON notifications(created_at);

-- =====================================================================
-- STEP 5: ENABLE RLS AND CREATE POLICIES
-- =====================================================================

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
DROP POLICY IF EXISTS "System only insert notifications" ON notifications;

-- Create new policies
CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = recipient_id);

CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = recipient_id)
  WITH CHECK (auth.uid() = recipient_id);

CREATE POLICY "Users can delete own notifications"
  ON notifications FOR DELETE
  USING (auth.uid() = recipient_id);

CREATE POLICY "System only insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (FALSE);

-- =====================================================================
-- STEP 6: CREATE NOTIFICATION FUNCTION
-- =====================================================================

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
  -- Check user preferences
  SELECT
    CASE p_type
      WHEN 'event_moderation' THEN COALESCE(eventi_moderati_enabled, TRUE)
      WHEN 'new_comment' THEN COALESCE(nuovi_commenti_enabled, TRUE)
      WHEN 'comment_reply' THEN COALESCE(risposte_commenti_enabled, TRUE)
      WHEN 'event_like' THEN COALESCE(like_eventi_enabled, TRUE)
      WHEN 'event_participation' THEN COALESCE(nuove_partecipazioni_enabled, TRUE)
      WHEN 'coorganizer_update' THEN COALESCE(coorganizer_updates_enabled, TRUE)
      WHEN 'chat_mention' THEN COALESCE(chat_mentions_enabled, TRUE)
      ELSE TRUE
    END INTO v_preference_enabled
  FROM profiles
  WHERE user_id = p_recipient_id;

  IF NOT COALESCE(v_preference_enabled, TRUE) THEN
    RETURN NULL;
  END IF;

  IF p_sender_id = p_recipient_id THEN
    RETURN NULL;
  END IF;

  INSERT INTO notifications (
    recipient_id, sender_id, type, title, description,
    target_type, target_id, metadata
  ) VALUES (
    p_recipient_id, p_sender_id, p_type, p_title, p_description,
    p_target_type, p_target_id, p_metadata
  )
  RETURNING id INTO v_notification_id;

  RETURN v_notification_id;
END;
$$;

-- =====================================================================
-- STEP 7: ADD NOTIFICATION PREFERENCES TO PROFILES (if not exist)
-- =====================================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS eventi_moderati_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS nuovi_commenti_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS risposte_commenti_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS like_eventi_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS nuove_partecipazioni_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS coorganizer_updates_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS chat_mentions_enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- =====================================================================
-- STEP 8: ENABLE REALTIME
-- =====================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'notifications already in realtime publication';
END $$;

-- =====================================================================
-- VERIFICATION
-- =====================================================================

SELECT
  'Migration complete: notifications table has ' ||
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'notifications') ||
  ' columns' AS status;
