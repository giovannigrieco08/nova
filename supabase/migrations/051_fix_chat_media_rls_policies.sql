-- =====================================================================
-- Migration: 051_fix_chat_media_rls_policies
-- Purpose: Fix chat_media RLS policies that were broken by migration 043
-- Date: 2025-02-07
-- =====================================================================
--
-- Problem: Migration 043_fix_rls_auth_initplan_performance.sql recreated
-- the chat_media policies using OLD column names (is_viewed) that no longer
-- exist. The actual columns are max_views and view_count (from migration
-- 20241204_chat_media_view_count.sql).
--
-- This caused non-uploaders to be unable to view media sent by others,
-- because the RLS policy was either failing or not matching correctly.
--
-- Fix: Recreate the chat_media policies using the correct column names.
-- =====================================================================

-- =====================================================================
-- FIX CHAT_MEDIA SELECT POLICY
-- =====================================================================

-- Drop the broken policy
DROP POLICY IF EXISTS "chat_media_select_visible" ON chat_media;
DROP POLICY IF EXISTS "Users can view media" ON chat_media;

-- Create corrected SELECT policy
-- Users can view media if:
-- 1. They are the uploader (can always see their own media), OR
-- 2. The associated message is not hidden AND media has views remaining AND not expired
CREATE POLICY "chat_media_select"
  ON chat_media FOR SELECT
  TO authenticated
  USING (
    -- Uploader can always view their own media
    uploader_user_id = (SELECT auth.uid())
    OR
    (
      -- Associated message must not be hidden
      message_id IN (
        SELECT id FROM chat_messages WHERE hidden_at IS NULL
      )
      AND
      -- Media must have views remaining and not be expired
      view_count < max_views
      AND expires_at > NOW()
    )
  );

-- =====================================================================
-- FIX CHAT_MEDIA UPDATE POLICY
-- =====================================================================

-- Drop the broken policy (uses non-existent is_viewed column)
DROP POLICY IF EXISTS "chat_media_update_viewed" ON chat_media;

-- Create corrected UPDATE policy
-- The increment_media_view_count function handles view counting atomically,
-- but we need an UPDATE policy for the RPC to work
-- Only non-uploaders can trigger view increment, and only when views remain
CREATE POLICY "chat_media_update"
  ON chat_media FOR UPDATE
  TO authenticated
  USING (
    -- Only non-uploaders can update (increment view count)
    uploader_user_id != (SELECT auth.uid())
    AND
    -- Only if views remain
    view_count < max_views
    AND
    -- Only if not expired
    expires_at > NOW()
  )
  WITH CHECK (
    -- The update must be incrementing view_count by 1
    -- and setting viewed_by_user_id to current user
    view_count <= max_views
    AND viewed_by_user_id = (SELECT auth.uid())
  );

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  -- Verify policies exist with correct names
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'chat_media'
      AND schemaname = 'public'
      AND policyname = 'chat_media_select'
  ) THEN
    RAISE EXCEPTION 'Migration failed: chat_media_select policy not created';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'chat_media'
      AND schemaname = 'public'
      AND policyname = 'chat_media_update'
  ) THEN
    RAISE EXCEPTION 'Migration failed: chat_media_update policy not created';
  END IF;

  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'Migration 051_fix_chat_media_rls_policies completed';
  RAISE NOTICE '  - Fixed chat_media SELECT policy to use view_count/max_views';
  RAISE NOTICE '  - Fixed chat_media UPDATE policy to use correct columns';
  RAISE NOTICE '  - Non-uploaders can now view media sent by others';
  RAISE NOTICE '=====================================================';
END $$;
