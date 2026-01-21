-- Migration: 039_add_media_caption_column.sql
-- Description: Add media_caption column to chat_messages table for image/video captions
--
-- This column stores the caption text for media messages.
-- The caption is displayed below the media in the chat and in the media viewer.

-- ============================================================================
-- Add media_caption column
-- ============================================================================

ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS media_caption TEXT NULL;

-- Add comment for documentation
COMMENT ON COLUMN chat_messages.media_caption IS 'Optional caption text for media messages (images/videos)';

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE 'Column media_caption added to chat_messages table';
END $$;
