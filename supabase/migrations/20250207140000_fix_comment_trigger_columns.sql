-- =====================================================================
-- Migration: 20250207140000_fix_comment_trigger_columns.sql
-- Purpose: Fix comment notification triggers to use correct column names
-- Date: 2025-02-07
-- =====================================================================
--
-- Problem: The original comment triggers used user_id and text columns,
-- but the comments table actually uses author_id and content.
--
-- Fix: Update the trigger functions to use the correct column names.
-- =====================================================================

-- =====================================================================
-- FIX TRIGGER FUNCTION: Comment Notification
-- =====================================================================

CREATE OR REPLACE FUNCTION trigger_comment_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event RECORD;
  v_commenter_name TEXT;
BEGIN
  -- Only for top-level comments (not replies)
  IF NEW.parent_comment_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Get event details
  SELECT id, creator_id, title INTO v_event
  FROM events
  WHERE id = NEW.event_id;

  -- Don't notify if commenter is the event creator
  IF v_event.creator_id = NEW.author_id THEN
    RETURN NEW;
  END IF;

  -- Get commenter name
  SELECT full_name INTO v_commenter_name
  FROM profiles
  WHERE user_id = NEW.author_id;

  -- Create notification
  PERFORM create_notification(
    p_recipient_id := v_event.creator_id,
    p_sender_id := NEW.author_id,
    p_type := 'new_comment',
    p_title := 'Nuovo commento',
    p_description := COALESCE(v_commenter_name, 'Qualcuno') || ' ha commentato il tuo evento',
    p_target_type := 'event',
    p_target_id := NEW.event_id,
    p_metadata := jsonb_build_object(
      'event_title', v_event.title,
      'comment_id', NEW.id,
      'comment_text', LEFT(NEW.content, 100)
    )
  );

  RETURN NEW;
END;
$$;

-- =====================================================================
-- FIX TRIGGER FUNCTION: Comment Reply Notification
-- =====================================================================

CREATE OR REPLACE FUNCTION trigger_comment_reply_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_parent_comment RECORD;
  v_replier_name TEXT;
  v_event_title TEXT;
BEGIN
  -- Only for replies (has parent_comment_id)
  IF NEW.parent_comment_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get parent comment details
  SELECT id, author_id, event_id INTO v_parent_comment
  FROM comments
  WHERE id = NEW.parent_comment_id;

  -- Don't notify if replier is the original commenter
  IF v_parent_comment.author_id = NEW.author_id THEN
    RETURN NEW;
  END IF;

  -- Get replier name
  SELECT full_name INTO v_replier_name
  FROM profiles
  WHERE user_id = NEW.author_id;

  -- Get event title
  SELECT title INTO v_event_title
  FROM events
  WHERE id = NEW.event_id;

  -- Create notification
  PERFORM create_notification(
    p_recipient_id := v_parent_comment.author_id,
    p_sender_id := NEW.author_id,
    p_type := 'comment_reply',
    p_title := 'Nuova risposta',
    p_description := COALESCE(v_replier_name, 'Qualcuno') || ' ha risposto al tuo commento',
    p_target_type := 'comment',
    p_target_id := NEW.id,
    p_metadata := jsonb_build_object(
      'event_id', NEW.event_id,
      'event_title', v_event_title,
      'parent_comment_id', NEW.parent_comment_id,
      'reply_text', LEFT(NEW.content, 100)
    )
  );

  RETURN NEW;
END;
$$;

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE 'Comment trigger functions fixed to use author_id and content columns';
END $$;
