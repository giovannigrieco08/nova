-- =====================================================================
-- Migration: 20250207130000_fix_create_notification_function.sql
-- Purpose: Fix create_notification function that referenced non-existent columns
-- Date: 2025-02-07
-- =====================================================================
--
-- Problem: The create_notification function was updated to reference columns
-- that don't exist in the profiles table:
--   - event_invitations_enabled
--   - moderator_alerts_enabled
--
-- This caused ALL notification triggers to fail silently.
--
-- Fix: Remove references to non-existent columns and use ELSE TRUE for
-- unknown notification types.
-- =====================================================================

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
  -- Check user preferences (only check columns that exist in profiles table)
  SELECT
    CASE p_type
      WHEN 'event_moderation' THEN COALESCE(eventi_moderati_enabled, TRUE)
      WHEN 'new_comment' THEN COALESCE(nuovi_commenti_enabled, TRUE)
      WHEN 'comment_reply' THEN COALESCE(risposte_commenti_enabled, TRUE)
      WHEN 'event_like' THEN COALESCE(like_eventi_enabled, TRUE)
      WHEN 'event_participation' THEN COALESCE(nuove_partecipazioni_enabled, TRUE)
      WHEN 'coorganizer_update' THEN COALESCE(coorganizer_updates_enabled, TRUE)
      WHEN 'chat_mention' THEN COALESCE(chat_mentions_enabled, TRUE)
      ELSE TRUE -- Unknown types default to enabled
    END INTO v_preference_enabled
  FROM profiles
  WHERE user_id = p_recipient_id;

  -- If preference disabled, skip notification
  IF NOT COALESCE(v_preference_enabled, TRUE) THEN
    RETURN NULL;
  END IF;

  -- Don't notify yourself
  IF p_sender_id = p_recipient_id THEN
    RETURN NULL;
  END IF;

  -- Insert notification
  INSERT INTO notifications (
    recipient_id, sender_id, type, title, description,
    target_type, target_id, metadata
  ) VALUES (
    p_recipient_id, p_sender_id, p_type, p_title, p_description,
    p_target_type, p_target_id, p_metadata
  )
  RETURNING id INTO v_notification_id;

  RETURN v_notification_id;
END;
$$;

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE 'create_notification function fixed successfully';
  RAISE NOTICE 'Notification triggers should now work correctly';
END $$;
