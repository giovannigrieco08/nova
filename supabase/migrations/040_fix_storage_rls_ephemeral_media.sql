-- Migration: 040_fix_storage_rls_ephemeral_media
-- Description: Fix RLS policy for ephemeral-media bucket
--
-- Problem: The existing policy uses columns that don't exist (is_view_once, is_viewed)
-- The chat_media table actually uses max_views and view_count columns.
-- This caused non-uploaders to be unable to view media sent by others.
--
-- Fix: Update the policy to use the correct column names

-- ============================================================================
-- DROP EXISTING BROKEN POLICY
-- ============================================================================

DROP POLICY IF EXISTS "Users can view ephemeral media if authorized"
ON storage.objects;

-- ============================================================================
-- CREATE FIXED POLICY
-- ============================================================================

-- Users can view ephemeral media if:
-- 1. They are the uploader (first segment of path = user_id), OR
-- 2. The media is linked to a valid chat_media record that hasn't exceeded max views
CREATE POLICY "Users can view ephemeral media if authorized"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'ephemeral-media'
  AND (
    -- Uploader can always view their own media
    auth.uid()::text = (string_to_array(name, '/'))[1]
    OR
    -- Others can view if chat_media record permits (views remaining and not expired)
    EXISTS (
      SELECT 1 FROM chat_media
      WHERE chat_media.storage_path = storage.objects.name
        AND chat_media.view_count < chat_media.max_views
        AND chat_media.expires_at > NOW()
    )
  )
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
  -- Verify policy exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'objects'
      AND schemaname = 'storage'
      AND policyname = 'Users can view ephemeral media if authorized'
  ) THEN
    RAISE EXCEPTION 'Migration failed: Storage RLS policy not created';
  END IF;

  RAISE NOTICE 'Migration 040_fix_storage_rls_ephemeral_media completed successfully';
  RAISE NOTICE '   - Fixed ephemeral-media SELECT policy to use correct columns';
END $$;
