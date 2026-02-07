-- =====================================================================
-- Migration: 052_fix_chat_media_select_policy
-- Purpose: Fix chat_media SELECT policy to allow reading expired/viewed media
-- Date: 2025-02-07
-- =====================================================================
--
-- Problem: The current SELECT policy blocks reading chat_media if:
--   - view_count >= max_views (fully viewed)
--   - expires_at <= NOW() (expired)
--
-- This prevents the UI from showing "Scaduta" (expired) or "Aperta" (viewed)
-- states, because it can't read the media record at all.
--
-- Fix: Allow SELECT on chat_media for any associated message that is visible.
-- The UI handles displaying the correct state (viewable, viewed, expired).
-- Keep restrictions only on UPDATE (to prevent incrementing view count).
-- =====================================================================

-- =====================================================================
-- FIX CHAT_MEDIA SELECT POLICY
-- =====================================================================

-- Drop the overly restrictive policy
DROP POLICY IF EXISTS "chat_media_select" ON chat_media;

-- Create permissive SELECT policy
-- Users can view media metadata if:
-- 1. They are the uploader (can always see their own media), OR
-- 2. The associated message is visible (not hidden)
-- NOTE: UI handles showing expired/viewed states - RLS just controls access to metadata
CREATE POLICY "chat_media_select"
  ON chat_media FOR SELECT
  TO authenticated
  USING (
    -- Uploader can always view their own media
    uploader_user_id = (SELECT auth.uid())
    OR
    -- Others can view if the message is visible
    EXISTS (
      SELECT 1 FROM chat_messages
      WHERE chat_messages.id = chat_media.message_id
      AND chat_messages.hidden_at IS NULL
    )
  );

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  -- Verify policy exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'chat_media'
      AND schemaname = 'public'
      AND policyname = 'chat_media_select'
  ) THEN
    RAISE EXCEPTION 'Migration failed: chat_media_select policy not created';
  END IF;

  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'Migration 052_fix_chat_media_select_policy completed';
  RAISE NOTICE '  - SELECT policy now allows reading expired/viewed media';
  RAISE NOTICE '  - UI handles displaying correct state';
  RAISE NOTICE '  - UPDATE policy unchanged (still requires views remaining)';
  RAISE NOTICE '=====================================================';
END $$;
