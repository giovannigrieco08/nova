-- =====================================================================
-- Migration: Push Notifications System
-- Feature: 009-push-notifications
-- Date: 2025-11-30
-- =====================================================================
-- Purpose: Add FCM token storage for push notification delivery
--
-- Creates:
-- 1. fcm_tokens table - stores FCM registration tokens per device
-- 2. push_enabled column on profiles - global push toggle
-- 3. RLS policies for fcm_tokens
-- 4. Indexes for efficient queries
-- =====================================================================

-- =====================================================================
-- T001: Create fcm_tokens Table
-- =====================================================================

CREATE TABLE IF NOT EXISTS fcm_tokens (
  -- Primary key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Foreign key to profiles
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,

  -- FCM token (unique per device)
  token TEXT UNIQUE NOT NULL,

  -- Platform identifier
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),

  -- Device name (for user-facing UI, e.g., "iPhone di Mario")
  device_name TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table comment
COMMENT ON TABLE fcm_tokens IS 'Firebase Cloud Messaging tokens for push notification delivery';
COMMENT ON COLUMN fcm_tokens.token IS 'FCM registration token (device-specific, rotates periodically)';
COMMENT ON COLUMN fcm_tokens.platform IS 'Device platform: android or ios';
COMMENT ON COLUMN fcm_tokens.device_name IS 'Human-readable device name for user reference';
COMMENT ON COLUMN fcm_tokens.last_used_at IS 'Last time a push was successfully sent to this token';

-- =====================================================================
-- T002: Row-Level Security for fcm_tokens
-- =====================================================================

ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (idempotent migration)
DROP POLICY IF EXISTS "Users can view own fcm_tokens" ON fcm_tokens;
DROP POLICY IF EXISTS "Users can insert own fcm_tokens" ON fcm_tokens;
DROP POLICY IF EXISTS "Users can update own fcm_tokens" ON fcm_tokens;
DROP POLICY IF EXISTS "Users can delete own fcm_tokens" ON fcm_tokens;

-- Users can view their own tokens
CREATE POLICY "Users can view own fcm_tokens"
  ON fcm_tokens FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own tokens
CREATE POLICY "Users can insert own fcm_tokens"
  ON fcm_tokens FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own tokens
CREATE POLICY "Users can update own fcm_tokens"
  ON fcm_tokens FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own tokens
CREATE POLICY "Users can delete own fcm_tokens"
  ON fcm_tokens FOR DELETE
  USING (auth.uid() = user_id);

-- =====================================================================
-- T003: Add push_enabled Column to Profiles
-- =====================================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS push_enabled BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN profiles.push_enabled IS 'Master toggle for push notifications (overrides all channel preferences)';

-- =====================================================================
-- T004: Create Indexes for fcm_tokens
-- =====================================================================

-- Index for querying user's tokens (used by Edge Function)
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id
  ON fcm_tokens(user_id);

-- Index for token cleanup job (stale tokens)
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_last_used
  ON fcm_tokens(last_used_at);

-- =====================================================================
-- Helper Function: Upsert FCM Token
-- =====================================================================
--
-- Handles token registration and updates in a single operation.
-- If token already exists, updates last_used_at and device_name.
-- If token is new, inserts new record.
--
-- Usage: SELECT upsert_fcm_token('user-uuid', 'fcm-token', 'android', 'Pixel 7');
-- =====================================================================

CREATE OR REPLACE FUNCTION upsert_fcm_token(
  p_user_id UUID,
  p_token TEXT,
  p_platform TEXT,
  p_device_name TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_token_id UUID;
BEGIN
  -- Validate platform
  IF p_platform NOT IN ('android', 'ios') THEN
    RAISE EXCEPTION 'Invalid platform: %. Must be android or ios', p_platform;
  END IF;

  -- Upsert: insert or update on conflict
  INSERT INTO fcm_tokens (user_id, token, platform, device_name, last_used_at)
  VALUES (p_user_id, p_token, p_platform, p_device_name, NOW())
  ON CONFLICT (token) DO UPDATE SET
    user_id = p_user_id,
    platform = p_platform,
    device_name = COALESCE(p_device_name, fcm_tokens.device_name),
    last_used_at = NOW()
  RETURNING id INTO v_token_id;

  RETURN v_token_id;
END;
$$;

COMMENT ON FUNCTION upsert_fcm_token IS 'Register or update FCM token for a user device';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION upsert_fcm_token TO authenticated;

-- =====================================================================
-- Helper Function: Delete User FCM Token
-- =====================================================================
--
-- Deletes a specific token (used on logout from a device)
--
-- Usage: SELECT delete_fcm_token('fcm-token-string');
-- =====================================================================

CREATE OR REPLACE FUNCTION delete_fcm_token(p_token TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted BOOLEAN;
BEGIN
  DELETE FROM fcm_tokens
  WHERE token = p_token
    AND user_id = auth.uid()
  RETURNING TRUE INTO v_deleted;

  RETURN COALESCE(v_deleted, FALSE);
END;
$$;

COMMENT ON FUNCTION delete_fcm_token IS 'Delete FCM token on logout';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_fcm_token TO authenticated;

-- =====================================================================
-- Helper Function: Cleanup Stale Tokens
-- =====================================================================
--
-- Removes tokens not used in the last 30 days.
-- Should be called periodically (e.g., weekly cron job).
--
-- Usage: SELECT cleanup_stale_fcm_tokens();
-- =====================================================================

CREATE OR REPLACE FUNCTION cleanup_stale_fcm_tokens()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  DELETE FROM fcm_tokens
  WHERE last_used_at < NOW() - INTERVAL '30 days'
  RETURNING COUNT(*) INTO v_deleted_count;

  -- Log cleanup
  IF v_deleted_count > 0 THEN
    RAISE NOTICE 'Cleaned up % stale FCM tokens', v_deleted_count;
  END IF;

  RETURN COALESCE(v_deleted_count, 0);
END;
$$;

COMMENT ON FUNCTION cleanup_stale_fcm_tokens IS 'Remove FCM tokens not used in 30+ days';

-- =====================================================================
-- Migration Complete
-- =====================================================================
--
-- Next steps after migration:
-- 1. Deploy Edge Function: npx supabase functions deploy send-push-notification
-- 2. Set FCM_SERVER_KEY secret: npx supabase secrets set FCM_SERVER_KEY=<key>
-- 3. Configure webhook in Supabase Dashboard:
--    - Table: notifications
--    - Event: INSERT
--    - URL: https://<project-ref>.supabase.co/functions/v1/send-push-notification
--    - Headers: Authorization: Bearer <service_role_key>
-- =====================================================================
