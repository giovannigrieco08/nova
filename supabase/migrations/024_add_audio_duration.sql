-- Migration: Add duration_seconds column to chat_media table
-- Purpose: Store audio message duration for display before playback
-- Date: 2024-12-06

-- Add duration_seconds column (nullable, only used for audio)
ALTER TABLE chat_media
ADD COLUMN IF NOT EXISTS duration_seconds INTEGER DEFAULT NULL;

-- Add comment for documentation
COMMENT ON COLUMN chat_media.duration_seconds IS 'Duration in seconds for audio messages. NULL for images/videos.';
