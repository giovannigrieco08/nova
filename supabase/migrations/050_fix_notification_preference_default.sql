-- Migration: 050_fix_notification_preference_default
-- Purpose: Fix bug in create_notification where missing preferences caused notifications to be skipped
-- Date: 2026-02-06
-- Issue: Notifications not showing because COALESCE defaulted to FALSE instead of TRUE
--
-- Bug in migration 049:
--   IF NOT COALESCE(v_preference_enabled, FALSE) THEN  -- Wrong!
-- Should be:
--   IF NOT COALESCE(v_preference_enabled, TRUE) THEN   -- Correct (default to enabled)

-- ============================================================================
-- FIX: UPDATE create_notification() TO DEFAULT TO TRUE
-- ============================================================================

CREATE OR REPLACE FUNCTION create_notification(
  p_recipient_id UUID,
  p_sender_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_description TEXT,
  p_target_type TEXT,
  p_target_id UUID,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notification_id UUID;
  v_preference_enabled BOOLEAN;
BEGIN
  -- Check if recipient has this notification type enabled
  SELECT
    CASE p_type
      WHEN 'event_moderation' THEN COALESCE(eventi_moderati_enabled, TRUE)
      WHEN 'new_comment' THEN COALESCE(nuovi_commenti_enabled, TRUE)
      WHEN 'comment_reply' THEN COALESCE(risposte_commenti_enabled, TRUE)
      WHEN 'event_like' THEN COALESCE(like_eventi_enabled, TRUE)
      WHEN 'event_participation' THEN COALESCE(nuove_partecipazioni_enabled, TRUE)
      WHEN 'coorganizer_update' THEN COALESCE(coorganizer_updates_enabled, TRUE)
      WHEN 'chat_mention' THEN COALESCE(chat_mentions_enabled, TRUE)
      WHEN 'event_invitation' THEN COALESCE(event_invitations_enabled, TRUE)
      WHEN 'moderator_alert' THEN COALESCE(moderator_alerts_enabled, TRUE)
      ELSE TRUE -- Unknown types default to enabled
    END INTO v_preference_enabled
  FROM profiles
  WHERE user_id = p_recipient_id;

  -- If preference is explicitly disabled, skip notification
  -- Default to TRUE if profile not found (opt-out model)
  IF NOT COALESCE(v_preference_enabled, TRUE) THEN
    RETURN NULL;
  END IF;

  -- Prevent self-notifications (don't notify yourself of your own actions)
  IF p_sender_id = p_recipient_id THEN
    RETURN NULL;
  END IF;

  -- Insert notification (bypasses RLS due to SECURITY DEFINER)
  INSERT INTO notifications (
    recipient_id,
    sender_id,
    type,
    title,
    description,
    target_type,
    target_id,
    metadata
  ) VALUES (
    p_recipient_id,
    p_sender_id,
    p_type,
    p_title,
    p_description,
    p_target_type,
    p_target_id,
    p_metadata
  )
  RETURNING id INTO v_notification_id;

  RETURN v_notification_id;
END;
$$;

COMMENT ON FUNCTION create_notification IS 'Creates notification if recipient preferences allow it. Returns NULL if skipped. Defaults to enabled (opt-out model).';

-- ============================================================================
-- ALSO ADD moderator_alert TYPE IF MISSING
-- ============================================================================

DO $$ BEGIN
  -- Drop and recreate constraint to include moderator_alert
  ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

  ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
    CHECK (type IN (
      'event_moderation',
      'new_comment',
      'comment_reply',
      'event_like',
      'event_participation',
      'coorganizer_update',
      'chat_mention',
      'event_invitation',
      'moderator_alert'
    ));

  RAISE NOTICE 'Updated notifications type constraint';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Could not update type constraint: %', SQLERRM;
END $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE 'Migration 050 complete: Fixed notification preference default';
  RAISE NOTICE '- COALESCE now defaults to TRUE (opt-out model)';
  RAISE NOTICE '- Added COALESCE inside CASE for each preference column';
  RAISE NOTICE '- Added moderator_alert to allowed notification types';
END $$;
