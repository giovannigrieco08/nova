-- Migration: 022_add_audio_media_type
-- Feature: Voice Messages Support
-- Date: 2024-12-06
-- Purpose: Add 'audio' to chat_media media_type CHECK constraint

-- =====================================================================
-- FIX: chat_media_media_type_check constraint
-- Current constraint only allows ('image', 'video')
-- Need to add 'audio' for voice message support
-- =====================================================================

BEGIN;

-- Drop the existing CHECK constraint
ALTER TABLE chat_media
  DROP CONSTRAINT IF EXISTS chat_media_media_type_check;

-- Recreate the CHECK constraint with 'audio' included
ALTER TABLE chat_media
  ADD CONSTRAINT chat_media_media_type_check
  CHECK (media_type IN ('image', 'video', 'audio'));

-- Add comment for documentation
COMMENT ON COLUMN chat_media.media_type IS 'Media type: image, video, or audio (voice messages)';

-- Verification
DO $$
BEGIN
  RAISE NOTICE 'Migration 022 complete: Added audio to media_type constraint';
END $$;

COMMIT;
