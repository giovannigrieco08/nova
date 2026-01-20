-- Migration: 037_add_profile_banner.sql
-- Feature: 014-profile-banner
-- Description: Add banner_url column to profiles table for customizable profile banners
--
-- Changes:
-- - Add banner_url TEXT column (nullable) to profiles table
-- - No RLS changes needed (existing profile policies apply)

-- ============================================================================
-- Add banner_url column
-- ============================================================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS banner_url TEXT NULL;

-- Add comment for documentation
COMMENT ON COLUMN profiles.banner_url IS 'Supabase Storage public URL for profile banner image (3:1 aspect ratio, 1200x400px)';

-- ============================================================================
-- Create banners storage bucket (if not exists)
-- ============================================================================

-- Note: Bucket creation is idempotent with ON CONFLICT
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'banners',
  'banners',
  true,
  1048576,  -- 1MB limit
  ARRAY['image/jpeg', 'image/png', 'image/heic', 'image/heif']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Storage RLS policies for banners bucket
-- ============================================================================

-- Policy: Users can upload to their own folder
CREATE POLICY "banners_insert_own" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'banners' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Policy: Users can update their own files
CREATE POLICY "banners_update_own" ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'banners' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Policy: Users can delete their own files
CREATE POLICY "banners_delete_own" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'banners' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Policy: Anyone can read (public bucket)
CREATE POLICY "banners_select_public" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'banners');

-- ============================================================================
-- RLS: No changes needed to profiles table
-- ============================================================================
-- Existing RLS policies already handle profile updates:
-- - Users can UPDATE their own profile
-- - Users can read visible profiles
-- The banner_url follows the same access pattern as avatar_url
