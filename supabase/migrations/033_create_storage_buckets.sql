-- Migration: 033_create_storage_buckets
-- Description: Create storage buckets for avatars, event-images, and ephemeral-media
-- Note: This should have been created BEFORE 030_storage_bucket_rls_policies.sql
--       Adding now to fix missing bucket creation

-- ============================================================================
-- CREATE STORAGE BUCKETS
-- ============================================================================

-- Avatars bucket (public - profile pictures are viewable by all)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,  -- Public bucket: anyone can view avatars via public URL
  2097152,  -- 2MB max file size
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Event images bucket (public - event images are viewable once approved)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'event-images',
  'event-images',
  true,  -- Public bucket: event images are viewable by all
  5242880,  -- 5MB max file size
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Ephemeral media bucket (private - access controlled via RLS)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'ephemeral-media',
  'ephemeral-media',
  false,  -- Private bucket: access controlled by RLS policies
  10485760,  -- 10MB max file size
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/quicktime', 'audio/mpeg', 'audio/mp4', 'audio/aac']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Log created buckets for verification
DO $$
BEGIN
  RAISE NOTICE 'Storage buckets created/updated: avatars, event-images, ephemeral-media';
END $$;