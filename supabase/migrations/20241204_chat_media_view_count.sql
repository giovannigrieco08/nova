-- =====================================================================
-- MIGRATION: Add max_views and view_count to chat_media
-- Date: 2024-12-04
-- Purpose: Support 1x or 2x view ephemeral photos
-- =====================================================================

-- =====================================================================
-- 1. ADD NEW COLUMNS
-- =====================================================================

-- Add max_views column (default 1 for backwards compatibility)
ALTER TABLE chat_media
ADD COLUMN IF NOT EXISTS max_views INTEGER NOT NULL DEFAULT 1
CHECK (max_views >= 1 AND max_views <= 2);

-- Add view_count column (starts at 0)
ALTER TABLE chat_media
ADD COLUMN IF NOT EXISTS view_count INTEGER NOT NULL DEFAULT 0
CHECK (view_count >= 0);

-- Add constraint to ensure view_count doesn't exceed max_views
ALTER TABLE chat_media
ADD CONSTRAINT chat_media_view_count_max
CHECK (view_count <= max_views);

COMMENT ON COLUMN chat_media.max_views IS 'Maximum number of times the media can be viewed (1 or 2)';
COMMENT ON COLUMN chat_media.view_count IS 'Current number of times the media has been viewed';

-- =====================================================================
-- 2. CREATE FUNCTION TO INCREMENT VIEW COUNT
-- =====================================================================

CREATE OR REPLACE FUNCTION increment_media_view_count(
  p_media_id UUID,
  p_viewer_user_id UUID
)
RETURNS TABLE (
  id UUID,
  message_id UUID,
  uploader_user_id UUID,
  storage_path TEXT,
  media_type TEXT,
  file_size_bytes INTEGER,
  max_views INTEGER,
  view_count INTEGER,
  viewed_at TIMESTAMPTZ,
  viewed_by_user_id UUID,
  screenshot_detected_at TIMESTAMPTZ,
  screenshot_notified BOOLEAN,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_media RECORD;
BEGIN
  -- Get current media state with lock
  SELECT * INTO v_media
  FROM chat_media m
  WHERE m.id = p_media_id
  FOR UPDATE;

  -- Check if media exists
  IF v_media IS NULL THEN
    RETURN;
  END IF;

  -- Check if max views already reached
  IF v_media.view_count >= v_media.max_views THEN
    RETURN;
  END IF;

  -- Check if viewer is the uploader (can't view own media)
  IF v_media.uploader_user_id = p_viewer_user_id THEN
    -- Return current state without incrementing (uploader can always see)
    RETURN QUERY
    SELECT
      v_media.id,
      v_media.message_id,
      v_media.uploader_user_id,
      v_media.storage_path,
      v_media.media_type,
      v_media.file_size_bytes,
      v_media.max_views,
      v_media.view_count,
      v_media.viewed_at,
      v_media.viewed_by_user_id,
      v_media.screenshot_detected_at,
      v_media.screenshot_notified,
      v_media.expires_at,
      v_media.created_at;
    RETURN;
  END IF;

  -- Check if media has expired
  IF v_media.expires_at < NOW() THEN
    RETURN;
  END IF;

  -- Increment view count and update viewer info
  UPDATE chat_media
  SET
    view_count = view_count + 1,
    viewed_at = COALESCE(viewed_at, NOW()),
    viewed_by_user_id = COALESCE(viewed_by_user_id, p_viewer_user_id)
  WHERE chat_media.id = p_media_id
  RETURNING
    chat_media.id,
    chat_media.message_id,
    chat_media.uploader_user_id,
    chat_media.storage_path,
    chat_media.media_type,
    chat_media.file_size_bytes,
    chat_media.max_views,
    chat_media.view_count,
    chat_media.viewed_at,
    chat_media.viewed_by_user_id,
    chat_media.screenshot_detected_at,
    chat_media.screenshot_notified,
    chat_media.expires_at,
    chat_media.created_at
  INTO
    id, message_id, uploader_user_id, storage_path, media_type,
    file_size_bytes, max_views, view_count, viewed_at, viewed_by_user_id,
    screenshot_detected_at, screenshot_notified, expires_at, created_at;

  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION increment_media_view_count IS 'Atomically increment media view count if not exceeded. Returns updated media or NULL if cannot view.';

-- =====================================================================
-- 3. UPDATE RLS POLICIES (if needed)
-- =====================================================================

-- Users can read media for messages they can see
DROP POLICY IF EXISTS "Users can view media" ON chat_media;
CREATE POLICY "Users can view media" ON chat_media
  FOR SELECT
  USING (
    -- Can view if:
    -- 1. User is the uploader
    uploader_user_id = auth.uid()
    OR
    -- 2. Views remaining and not expired
    (view_count < max_views AND expires_at > NOW())
  );

-- Only uploaders can insert media
DROP POLICY IF EXISTS "Users can insert own media" ON chat_media;
CREATE POLICY "Users can insert own media" ON chat_media
  FOR INSERT
  WITH CHECK (uploader_user_id = auth.uid());

-- =====================================================================
-- 4. CREATE INDEX FOR PERFORMANCE
-- =====================================================================

CREATE INDEX IF NOT EXISTS idx_chat_media_view_status
ON chat_media (id, view_count, max_views, expires_at)
WHERE view_count < max_views;

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  -- Verify columns exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'chat_media' AND column_name = 'max_views'
  ) THEN
    RAISE EXCEPTION 'Migration failed: max_views column not created';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'chat_media' AND column_name = 'view_count'
  ) THEN
    RAISE EXCEPTION 'Migration failed: view_count column not created';
  END IF;

  -- Verify function exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'increment_media_view_count'
  ) THEN
    RAISE EXCEPTION 'Migration failed: increment_media_view_count function not created';
  END IF;

  RAISE NOTICE '✅ Migration completed successfully!';
  RAISE NOTICE '   - Added max_views column (default: 1)';
  RAISE NOTICE '   - Added view_count column (default: 0)';
  RAISE NOTICE '   - Created increment_media_view_count function';
  RAISE NOTICE '   - Updated RLS policies';
END $$;
