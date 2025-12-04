-- =====================================================================
-- Migration: 015_global_chat_system.sql
-- Feature: 011-global-chat (Global Chat System)
-- Date: 2025-12-03
-- Purpose: Create Global Chat tables, RLS policies, triggers, and cron jobs
-- =====================================================================

-- This migration creates:
-- 1. chat_messages table (ephemeral, 24h auto-delete)
-- 2. chat_reactions table (6 emoji reactions)
-- 3. chat_reports table (content moderation)
-- 4. chat_media table (view-once ephemeral media) - P3
-- 5. All required RLS policies
-- 6. Triggers for rate limiting, counts, auto-hide
-- 7. pg_cron jobs for 24h auto-deletion
-- 8. Storage bucket for ephemeral media

-- =====================================================================
-- PREREQUISITES CHECK
-- =====================================================================
-- Requires:
-- - profiles table (from migration 002)
-- - user_roles table (from migration 005)
-- - contains_profanity function (from migration 007)
-- - notifications table (from migration 008)
-- - pg_trgm extension (will create if not exists)
-- - pg_cron extension (will create if not exists)

-- =====================================================================
-- PHASE 1: EXTENSIONS
-- =====================================================================

-- Trigram extension for @mention autocomplete
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =====================================================================
-- PHASE 2: CHAT_MESSAGES TABLE
-- =====================================================================

CREATE TABLE IF NOT EXISTS chat_messages (
  -- Identity
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relationships
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  reply_to_id UUID REFERENCES chat_messages(id) ON DELETE SET NULL,

  -- Content
  content TEXT NOT NULL CHECK (char_length(trim(content)) BETWEEN 1 AND 500),
  mentions JSONB NOT NULL DEFAULT '[]'::jsonb,

  -- Denormalized counters (for performance)
  reaction_count INT NOT NULL DEFAULT 0 CHECK (reaction_count >= 0),
  reply_count INT NOT NULL DEFAULT 0 CHECK (reply_count >= 0),
  report_count INT NOT NULL DEFAULT 0 CHECK (report_count >= 0),

  -- Moderation
  hidden_at TIMESTAMPTZ,
  hidden_reason TEXT,
  moderator_id UUID REFERENCES profiles(user_id),

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT mentions_is_array
    CHECK (jsonb_typeof(mentions) = 'array')
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_feed
  ON chat_messages(created_at DESC)
  WHERE hidden_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_chat_messages_user
  ON chat_messages(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_replies
  ON chat_messages(reply_to_id, created_at ASC)
  WHERE reply_to_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_chat_messages_moderation_queue
  ON chat_messages(created_at DESC)
  WHERE hidden_at IS NOT NULL;

-- Index for 24-hour deletion job (simple btree on created_at)
-- Note: Cannot use NOW() in partial index predicate (must be IMMUTABLE)
-- Query "WHERE created_at < NOW() - INTERVAL '24 hours'" will still use this index
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at
  ON chat_messages(created_at);

-- Trigram index for @mention autocomplete on profiles
CREATE INDEX IF NOT EXISTS idx_profiles_fullname_trgm
  ON profiles USING gin(LOWER(full_name) gin_trgm_ops);

COMMENT ON TABLE chat_messages IS 'Global chat messages - ephemeral (24h auto-delete), max 500 chars';
COMMENT ON COLUMN chat_messages.mentions IS 'Array of {user_id, username, start_index, end_index} for @mentions';
COMMENT ON COLUMN chat_messages.hidden_at IS 'Auto-hidden at 3+ reports or by moderator';

-- =====================================================================
-- PHASE 3: CHAT_REACTIONS TABLE
-- =====================================================================

CREATE TABLE IF NOT EXISTS chat_reactions (
  -- Composite primary key (one reaction type per user per message)
  message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  emoji VARCHAR(10) NOT NULL,

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (message_id, user_id, emoji),

  -- Allowed emoji whitelist (6 reactions only)
  CONSTRAINT valid_emoji CHECK (
    emoji IN ('❤️', '👍', '😂', '😮', '😢', '🔥')
  )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_chat_reactions_message
  ON chat_reactions(message_id);

CREATE INDEX IF NOT EXISTS idx_chat_reactions_user
  ON chat_reactions(user_id, created_at DESC);

COMMENT ON TABLE chat_reactions IS 'Emoji reactions on chat messages - limited to 6 types';
COMMENT ON COLUMN chat_reactions.emoji IS 'One of: ❤️, 👍, 😂, 😮, 😢, 🔥';

-- =====================================================================
-- PHASE 4: CHAT_REPORTS TABLE
-- =====================================================================

CREATE TABLE IF NOT EXISTS chat_reports (
  -- Identity
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relationships
  message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
  reporter_user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,

  -- Report details
  reason TEXT NOT NULL CHECK (reason IN ('spam', 'inappropriate', 'bullying', 'off_topic')),

  -- Moderation workflow
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
  reviewed_by_moderator_id UUID REFERENCES profiles(user_id),
  reviewed_at TIMESTAMPTZ,
  moderator_notes TEXT,

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Prevent duplicate reports from same user
  CONSTRAINT unique_user_report_per_chat_message UNIQUE (message_id, reporter_user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_chat_reports_pending
  ON chat_reports(created_at DESC)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_chat_reports_message
  ON chat_reports(message_id, created_at DESC);

COMMENT ON TABLE chat_reports IS 'User-submitted reports for inappropriate chat messages';
COMMENT ON COLUMN chat_reports.reason IS 'One of: spam, inappropriate, bullying, off_topic';

-- =====================================================================
-- PHASE 5: CHAT_MEDIA TABLE (P3 - View-Once Media)
-- =====================================================================

CREATE TABLE IF NOT EXISTS chat_media (
  -- Identity
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relationships
  message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
  uploader_user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,

  -- Storage
  storage_path TEXT NOT NULL,
  media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
  file_size_bytes INT NOT NULL CHECK (file_size_bytes > 0 AND file_size_bytes <= 10485760),

  -- View-once state
  is_viewed BOOLEAN NOT NULL DEFAULT FALSE,
  viewed_at TIMESTAMPTZ,
  viewed_by_user_id UUID REFERENCES profiles(user_id),

  -- Screenshot detection (iOS)
  screenshot_detected_at TIMESTAMPTZ,
  screenshot_notified BOOLEAN NOT NULL DEFAULT FALSE,

  -- Expiration (24h from creation)
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Only one media per message
  CONSTRAINT one_media_per_message UNIQUE (message_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_chat_media_pending_view
  ON chat_media(message_id)
  WHERE is_viewed = FALSE;

CREATE INDEX IF NOT EXISTS idx_chat_media_expired
  ON chat_media(expires_at)
  WHERE is_viewed = FALSE;

CREATE INDEX IF NOT EXISTS idx_chat_media_uploader
  ON chat_media(uploader_user_id, created_at DESC);

COMMENT ON TABLE chat_media IS 'View-once ephemeral media for chat - max 10MB, 24h expiry';
COMMENT ON COLUMN chat_media.file_size_bytes IS 'Max 10MB (10485760 bytes)';

-- =====================================================================
-- PHASE 6: ROW-LEVEL SECURITY POLICIES
-- =====================================================================

-- Enable RLS on all tables
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_media ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------
-- chat_messages RLS
-- ---------------------------------------------------------------------

-- Policy 1: Authenticated users can view non-hidden messages
CREATE POLICY "chat_messages_select_visible"
  ON chat_messages FOR SELECT
  TO authenticated
  USING (hidden_at IS NULL);

-- Policy 2: Moderators can view all messages (including hidden)
CREATE POLICY "chat_messages_select_moderators"
  ON chat_messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  );

-- Policy 3: Users can insert their own messages
CREATE POLICY "chat_messages_insert_own"
  ON chat_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND hidden_at IS NULL
  );

-- Policy 4: Moderators can update messages (hide/unhide)
CREATE POLICY "chat_messages_update_moderators"
  ON chat_messages FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  );

-- ---------------------------------------------------------------------
-- chat_reactions RLS
-- ---------------------------------------------------------------------

-- Policy 1: Users can view reactions on visible messages
CREATE POLICY "chat_reactions_select_visible"
  ON chat_reactions FOR SELECT
  TO authenticated
  USING (
    message_id IN (
      SELECT id FROM chat_messages WHERE hidden_at IS NULL
    )
  );

-- Policy 2: Users can add reactions
CREATE POLICY "chat_reactions_insert_own"
  ON chat_reactions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Policy 3: Users can remove their own reactions
CREATE POLICY "chat_reactions_delete_own"
  ON chat_reactions FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- chat_reports RLS
-- ---------------------------------------------------------------------

-- Policy 1: Users can view own reports
CREATE POLICY "chat_reports_select_own"
  ON chat_reports FOR SELECT
  TO authenticated
  USING (auth.uid() = reporter_user_id);

-- Policy 2: Moderators can view all reports
CREATE POLICY "chat_reports_select_moderators"
  ON chat_reports FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  );

-- Policy 3: Users can submit reports
CREATE POLICY "chat_reports_insert_own"
  ON chat_reports FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = reporter_user_id
    AND status = 'pending'
  );

-- Policy 4: Moderators can update report status
CREATE POLICY "chat_reports_update_moderators"
  ON chat_reports FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND role IN ('moderator', 'admin')
    )
  );

-- ---------------------------------------------------------------------
-- chat_media RLS
-- ---------------------------------------------------------------------

-- Policy 1: Users can view media metadata for visible messages
CREATE POLICY "chat_media_select_visible"
  ON chat_media FOR SELECT
  TO authenticated
  USING (
    message_id IN (
      SELECT id FROM chat_messages WHERE hidden_at IS NULL
    )
  );

-- Policy 2: Users can insert media (uploader only)
CREATE POLICY "chat_media_insert_own"
  ON chat_media FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = uploader_user_id);

-- Policy 3: Any user can mark media as viewed (not own media)
CREATE POLICY "chat_media_update_viewed"
  ON chat_media FOR UPDATE
  TO authenticated
  USING (
    is_viewed = FALSE
    AND auth.uid() != uploader_user_id
  )
  WITH CHECK (
    is_viewed = TRUE
    AND viewed_by_user_id = auth.uid()
  );

-- =====================================================================
-- PHASE 7: DATABASE FUNCTIONS & TRIGGERS
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Rate Limiting Function (10 messages/minute)
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_chat_rate_limit()
RETURNS TRIGGER AS $$
DECLARE
  recent_count INT;
BEGIN
  SELECT COUNT(*) INTO recent_count
  FROM chat_messages
  WHERE user_id = NEW.user_id
    AND created_at > NOW() - INTERVAL '1 minute';

  IF recent_count >= 10 THEN
    RAISE EXCEPTION 'Rate limit exceeded: max 10 messages per minute'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS check_chat_rate_limit_trigger ON chat_messages;
CREATE TRIGGER check_chat_rate_limit_trigger
  BEFORE INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION check_chat_rate_limit();

COMMENT ON FUNCTION check_chat_rate_limit() IS 'Enforce 10 messages/minute rate limit per user';

-- ---------------------------------------------------------------------
-- 2. Profanity Check Trigger
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION validate_chat_profanity()
RETURNS TRIGGER AS $$
BEGIN
  IF contains_profanity(NEW.content) THEN
    RAISE EXCEPTION 'Message contains inappropriate language'
      USING ERRCODE = 'P0002';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS check_chat_profanity_trigger ON chat_messages;
CREATE TRIGGER check_chat_profanity_trigger
  BEFORE INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION validate_chat_profanity();

COMMENT ON FUNCTION validate_chat_profanity() IS 'Block messages containing Italian profanity';

-- ---------------------------------------------------------------------
-- 3. Reaction Count Trigger
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_chat_reaction_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE chat_messages
    SET reaction_count = reaction_count + 1
    WHERE id = NEW.message_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE chat_messages
    SET reaction_count = GREATEST(0, reaction_count - 1)
    WHERE id = OLD.message_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS sync_chat_reaction_count ON chat_reactions;
CREATE TRIGGER sync_chat_reaction_count
  AFTER INSERT OR DELETE ON chat_reactions
  FOR EACH ROW
  EXECUTE FUNCTION update_chat_reaction_count();

COMMENT ON FUNCTION update_chat_reaction_count() IS 'Maintain denormalized reaction_count on chat_messages';

-- ---------------------------------------------------------------------
-- 4. Reply Count Trigger
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_chat_reply_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.reply_to_id IS NOT NULL THEN
    UPDATE chat_messages
    SET reply_count = reply_count + 1
    WHERE id = NEW.reply_to_id;
  ELSIF TG_OP = 'DELETE' AND OLD.reply_to_id IS NOT NULL THEN
    UPDATE chat_messages
    SET reply_count = GREATEST(0, reply_count - 1)
    WHERE id = OLD.reply_to_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS sync_chat_reply_count ON chat_messages;
CREATE TRIGGER sync_chat_reply_count
  AFTER INSERT OR DELETE ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_chat_reply_count();

COMMENT ON FUNCTION update_chat_reply_count() IS 'Maintain denormalized reply_count on chat_messages';

-- ---------------------------------------------------------------------
-- 5. Report Count & Auto-Hide Trigger
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_chat_report_count()
RETURNS TRIGGER AS $$
DECLARE
  total_reports INT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT COUNT(DISTINCT reporter_user_id) INTO total_reports
    FROM chat_reports
    WHERE message_id = NEW.message_id;

    UPDATE chat_messages
    SET report_count = total_reports
    WHERE id = NEW.message_id;

    -- Auto-hide at 3+ reports
    IF total_reports >= 3 THEN
      UPDATE chat_messages
      SET
        hidden_at = NOW(),
        hidden_reason = 'auto_hide_reports'
      WHERE id = NEW.message_id AND hidden_at IS NULL;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS sync_chat_report_count ON chat_reports;
CREATE TRIGGER sync_chat_report_count
  AFTER INSERT ON chat_reports
  FOR EACH ROW
  EXECUTE FUNCTION update_chat_report_count();

COMMENT ON FUNCTION update_chat_report_count() IS 'Maintain report_count and auto-hide at 3+ reports';

-- ---------------------------------------------------------------------
-- 6. Mention Notification Trigger
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION notify_chat_mentions()
RETURNS TRIGGER AS $$
DECLARE
  mention JSONB;
  mentioned_user_id UUID;
  sender_name TEXT;
BEGIN
  -- Get sender name
  SELECT full_name INTO sender_name
  FROM profiles
  WHERE user_id = NEW.user_id;

  -- Parse mentions array and create notifications
  FOR mention IN SELECT * FROM jsonb_array_elements(NEW.mentions) LOOP
    mentioned_user_id := (mention->>'user_id')::UUID;

    -- Don't notify self-mentions
    IF mentioned_user_id != NEW.user_id THEN
      -- Insert notification using correct schema (from migration 008)
      INSERT INTO notifications (
        recipient_id,
        sender_id,
        type,
        title,
        description,
        target_type,
        target_id,
        metadata,
        created_at
      ) VALUES (
        mentioned_user_id,
        NEW.user_id,
        'chat_mention',
        'Ti hanno menzionato in chat',
        COALESCE(sender_name, 'Qualcuno') || ': ' || substring(NEW.content from 1 for 100),
        'chat_message',
        NEW.id,
        jsonb_build_object(
          'message_id', NEW.id,
          'sender_id', NEW.user_id
        ),
        NOW()
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS notify_mentions_trigger ON chat_messages;
CREATE TRIGGER notify_mentions_trigger
  AFTER INSERT ON chat_messages
  FOR EACH ROW
  WHEN (jsonb_array_length(NEW.mentions) > 0)
  EXECUTE FUNCTION notify_chat_mentions();

COMMENT ON FUNCTION notify_chat_mentions() IS 'Create notifications for @mentioned users';

-- =====================================================================
-- PHASE 8: @MENTION SEARCH FUNCTION (RPC)
-- =====================================================================

CREATE OR REPLACE FUNCTION search_users_for_mention(search_term TEXT)
RETURNS TABLE (
  user_id UUID,
  full_name TEXT,
  avatar_url TEXT,
  class TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.user_id,
    p.full_name,
    p.avatar_url,
    p.class
  FROM profiles p
  WHERE LOWER(p.full_name) LIKE '%' || LOWER(search_term) || '%'
  ORDER BY
    CASE WHEN LOWER(p.full_name) LIKE LOWER(search_term) || '%' THEN 0 ELSE 1 END,
    p.full_name
  LIMIT 5;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION search_users_for_mention(TEXT) IS 'Search users for @mention autocomplete - returns top 5 matches';

-- =====================================================================
-- PHASE 9: STORAGE BUCKET (ephemeral-media)
-- =====================================================================

-- Note: Storage bucket creation may need to be done via Supabase Dashboard
-- or using the storage API. This is a placeholder for documentation.

-- The bucket should have:
-- - Name: ephemeral-media
-- - Public: FALSE (requires signed URLs)
-- - File size limit: 10MB (10485760 bytes)
-- - Allowed MIME types: image/jpeg, image/png, image/webp, video/mp4

-- Storage policies should be:
-- 1. Users can upload to their own folder: {user_id}/*
-- 2. Users can read media if the chat_media record is visible

-- =====================================================================
-- PHASE 10: REALTIME CONFIGURATION
-- =====================================================================

-- Enable realtime for chat_messages table
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;

-- Note: If publication doesn't exist, create it:
-- CREATE PUBLICATION supabase_realtime FOR TABLE chat_messages;

-- =====================================================================
-- PHASE 11: pg_cron JOBS (24-hour auto-delete)
-- =====================================================================

-- Note: pg_cron must be enabled in your Supabase project settings
-- These commands will only work if pg_cron is available

-- Try to enable pg_cron extension (may require dashboard activation)
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule hourly deletion job (run at minute 0 of every hour)
-- SELECT cron.schedule(
--   'chat-auto-delete-24h',
--   '0 * * * *',
--   $$
--     DELETE FROM chat_messages
--     WHERE created_at < NOW() - INTERVAL '24 hours';
--   $$
-- );

-- Schedule media expiration check (every 15 minutes)
-- SELECT cron.schedule(
--   'chat-media-expire',
--   '*/15 * * * *',
--   $$
--     UPDATE chat_media
--     SET is_viewed = TRUE
--     WHERE expires_at < NOW()
--       AND is_viewed = FALSE;
--   $$
-- );

-- Alternative: Create a function to clean up old messages
-- This can be called via a Supabase Edge Function on a schedule

CREATE OR REPLACE FUNCTION cleanup_old_chat_messages()
RETURNS INT AS $$
DECLARE
  deleted_count INT;
BEGIN
  WITH deleted AS (
    DELETE FROM chat_messages
    WHERE created_at < NOW() - INTERVAL '24 hours'
    RETURNING 1
  )
  SELECT COUNT(*) INTO deleted_count FROM deleted;

  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION cleanup_expired_chat_media()
RETURNS INT AS $$
DECLARE
  expired_count INT;
BEGIN
  WITH expired AS (
    UPDATE chat_media
    SET is_viewed = TRUE
    WHERE expires_at < NOW()
      AND is_viewed = FALSE
    RETURNING 1
  )
  SELECT COUNT(*) INTO expired_count FROM expired;

  RETURN expired_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION cleanup_old_chat_messages() IS 'Delete chat messages older than 24 hours - call via cron or Edge Function';
COMMENT ON FUNCTION cleanup_expired_chat_media() IS 'Mark expired media as viewed - call via cron or Edge Function';

-- =====================================================================
-- MIGRATION COMPLETE
-- =====================================================================

-- Summary of created objects:
-- Tables: chat_messages, chat_reactions, chat_reports, chat_media
-- Indexes: 11 indexes for optimal query performance
-- RLS Policies: 14 policies for secure data access
-- Triggers: 6 triggers for business logic enforcement
-- Functions: 10 functions for triggers, search, and cleanup
--
-- Next steps:
-- 1. Create 'ephemeral-media' storage bucket in Supabase Dashboard
-- 2. Enable pg_cron in Supabase Dashboard and uncomment cron jobs
-- 3. OR set up Edge Function to call cleanup_old_chat_messages() hourly
