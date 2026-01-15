-- =====================================================================
-- Migration: 018_chat_message_deletion.sql
-- Feature: Chat Message Deletion
-- Date: 2025-12-06
-- Purpose: Allow users to delete their own messages within 30 minutes
-- =====================================================================

-- =====================================================================
-- PHASE 1: ADD DELETE RLS POLICY FOR CHAT MESSAGES
-- =====================================================================

-- Drop existing policy if exists (to make migration idempotent)
DROP POLICY IF EXISTS "chat_messages_delete_own" ON chat_messages;

-- Users can delete their own messages only within 30 minutes of sending
CREATE POLICY "chat_messages_delete_own"
  ON chat_messages FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id
    AND created_at > NOW() - INTERVAL '30 minutes'
    AND hidden_at IS NULL  -- Cannot delete hidden messages
  );

COMMENT ON POLICY "chat_messages_delete_own" ON chat_messages
  IS 'Users can delete own messages within 30 minutes of sending';

-- =====================================================================
-- PHASE 2: ENABLE PG_CRON FOR 24-HOUR AUTO-DELETE
-- =====================================================================

-- Note: pg_cron must be enabled in Supabase Dashboard first
-- Go to Database > Extensions > Enable pg_cron

-- Uncomment these lines after enabling pg_cron:

-- Schedule hourly cleanup job (run at minute 0 of every hour)
-- This deletes all messages older than 24 hours
-- SELECT cron.schedule(
--   'chat-auto-delete-24h',
--   '0 * * * *',
--   $$
--     SELECT cleanup_old_chat_messages();
--   $$
-- );

-- Schedule media expiration check (every 15 minutes)
-- SELECT cron.schedule(
--   'chat-media-expire',
--   '*/15 * * * *',
--   $$
--     SELECT cleanup_expired_chat_media();
--   $$
-- );

-- =====================================================================
-- PHASE 3: CREATE HELPER FUNCTION TO CLEAR ALL CHAT MESSAGES
-- =====================================================================

-- Function to clear all chat messages (for testing/admin purposes)
-- This should only be called by admins
CREATE OR REPLACE FUNCTION clear_all_chat_messages()
RETURNS INT AS $$
DECLARE
  deleted_count INT;
BEGIN
  -- Only allow admins to run this
  IF NOT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can clear all chat messages';
  END IF;

  -- Delete all media files from storage first
  -- Note: This is best done via Edge Function for storage cleanup

  -- Delete all messages (CASCADE will handle reactions, reports, media)
  WITH deleted AS (
    DELETE FROM chat_messages
    RETURNING 1
  )
  SELECT COUNT(*) INTO deleted_count FROM deleted;

  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION clear_all_chat_messages() IS 'Admin-only function to clear all chat messages (for testing)';

-- =====================================================================
-- PHASE 4: CREATE RPC FOR TRIGGERING 24H CLEANUP
-- =====================================================================

-- This RPC can be called by Edge Function on schedule
-- or manually for testing
CREATE OR REPLACE FUNCTION trigger_chat_cleanup()
RETURNS TABLE (
  messages_deleted INT,
  media_expired INT
) AS $$
BEGIN
  messages_deleted := cleanup_old_chat_messages();
  media_expired := cleanup_expired_chat_media();
  RETURN NEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION trigger_chat_cleanup() IS 'Trigger cleanup of old messages and expired media - call via cron or Edge Function';

-- =====================================================================
-- MIGRATION COMPLETE
-- =====================================================================

-- Summary of created objects:
-- RLS Policy: chat_messages_delete_own (users can delete own messages within 30min)
-- Functions: clear_all_chat_messages (admin only), trigger_chat_cleanup (cron target)
--
-- Next steps:
-- 1. Enable pg_cron in Supabase Dashboard if not already enabled
-- 2. Uncomment the cron.schedule calls above to enable automatic cleanup
-- 3. OR set up a Supabase Edge Function to call trigger_chat_cleanup() hourly
