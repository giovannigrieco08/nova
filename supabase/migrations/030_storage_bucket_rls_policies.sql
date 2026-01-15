-- Migration: 030_storage_bucket_rls_policies
-- Description: Add RLS policies for storage buckets (avatars, event-images, ephemeral-media)
--
-- This migration adds Row Level Security policies to storage buckets to ensure:
-- 1. Users can only upload to their own folders
-- 2. Users can only read their own content or public content
-- 3. Ephemeral media has proper access controls based on chat_media table

-- ============================================================================
-- AVATARS BUCKET POLICIES
-- ============================================================================

-- Users can upload avatars to their own folder
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Users can update their own avatar
CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars'
  AND auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Users can delete their own avatar
CREATE POLICY "Users can delete own avatar"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'avatars'
  AND auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Anyone can view avatars (public profile pictures)
CREATE POLICY "Avatars are publicly viewable"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'avatars');


-- ============================================================================
-- EVENT-IMAGES BUCKET POLICIES
-- ============================================================================

-- Users can upload event images to their own folder
CREATE POLICY "Users can upload event images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'event-images'
  AND auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Users can update their own event images
CREATE POLICY "Users can update own event images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'event-images'
  AND auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Users can delete their own event images
CREATE POLICY "Users can delete own event images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'event-images'
  AND auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Anyone can view event images (events are public once approved)
CREATE POLICY "Event images are publicly viewable"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'event-images');


-- ============================================================================
-- EPHEMERAL-MEDIA BUCKET POLICIES (Chat Media)
-- ============================================================================

-- Users can upload ephemeral media to their own folder
-- File size limit of 10MB is enforced at application level
CREATE POLICY "Users can upload ephemeral media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'ephemeral-media'
  AND auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Users can delete their own ephemeral media
CREATE POLICY "Users can delete own ephemeral media"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'ephemeral-media'
  AND auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Users can view ephemeral media only if:
-- 1. They are the uploader, OR
-- 2. The media is linked to a visible chat_media record (not expired, not view-once already viewed)
CREATE POLICY "Users can view ephemeral media if authorized"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'ephemeral-media'
  AND (
    -- Uploader can always view their own media
    auth.uid()::text = (string_to_array(name, '/'))[1]
    OR
    -- Others can view if chat_media record permits
    EXISTS (
      SELECT 1 FROM chat_media
      WHERE chat_media.storage_path = storage.objects.name
        AND (
          -- Non-view-once media that hasn't expired
          (chat_media.is_view_once = false AND chat_media.expires_at > NOW())
          OR
          -- View-once media that hasn't been viewed yet
          (chat_media.is_view_once = true AND chat_media.is_viewed = false AND chat_media.expires_at > NOW())
        )
    )
  )
);


-- ============================================================================
-- CLEANUP: Auto-delete expired ephemeral media
-- ============================================================================
-- Note: This function should be called by a cron job or Edge Function
-- to clean up expired media files from storage

CREATE OR REPLACE FUNCTION cleanup_expired_ephemeral_media()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_count INTEGER := 0;
BEGIN
  -- Delete storage objects for expired chat_media
  -- Note: This requires the storage.objects table to be accessible
  -- In practice, this should be done via Supabase Storage API from an Edge Function

  -- For now, just delete the chat_media records (storage cleanup done separately)
  WITH expired AS (
    DELETE FROM chat_media
    WHERE expires_at < NOW()
    RETURNING storage_path
  )
  SELECT COUNT(*) INTO deleted_count FROM expired;

  RETURN deleted_count;
END;
$$;

-- Grant execute to authenticated users (for manual cleanup if needed)
GRANT EXECUTE ON FUNCTION cleanup_expired_ephemeral_media() TO authenticated;

COMMENT ON FUNCTION cleanup_expired_ephemeral_media() IS
  'Cleans up expired ephemeral media records. Storage files should be deleted via Edge Function.';
