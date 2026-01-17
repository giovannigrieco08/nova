-- Migration: 036_soft_delete_messages.sql
-- Feature: 013-chat-message-actions
-- Description: Add soft delete support for chat messages
--
-- Changes:
-- - Add deleted_at and deleted_by_user fields for soft delete
-- - Add partial index for efficient filtering
-- - Update RLS policy to use UPDATE for soft delete instead of DELETE

-- ============================================================================
-- T001: Add soft delete fields
-- ============================================================================

ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ NULL;
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_by_user BOOLEAN DEFAULT FALSE;

-- Add comment for documentation
COMMENT ON COLUMN chat_messages.deleted_at IS 'Timestamp when message was soft-deleted (NULL = not deleted)';
COMMENT ON COLUMN chat_messages.deleted_by_user IS 'TRUE if deleted by user, FALSE if deleted by system/moderator';

-- ============================================================================
-- T002: Add partial index for efficient filtering of non-deleted messages
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_chat_messages_deleted_at
  ON chat_messages(deleted_at)
  WHERE deleted_at IS NULL;

-- ============================================================================
-- T003: Update RLS policies for soft delete
-- ============================================================================

-- Drop old hard-delete policy (if exists)
DROP POLICY IF EXISTS "chat_messages_delete_own" ON chat_messages;

-- Create new soft delete policy
-- Users can UPDATE their own messages to set deleted_at
-- This replaces the DELETE operation with a soft delete (UPDATE)
CREATE POLICY "chat_messages_soft_delete_own" ON chat_messages
  FOR UPDATE
  USING (
    auth.uid() = user_id
  )
  WITH CHECK (
    auth.uid() = user_id
  );

-- Note: The existing "chat_messages_update_own" policy may already allow updates.
-- We create this explicit policy to document the soft delete intent.
-- If "chat_messages_update_own" already exists, this is complementary.
