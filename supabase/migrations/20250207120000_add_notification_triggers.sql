-- =====================================================================
-- Migration: 051_add_notification_triggers.sql
-- Purpose: Add automatic notification triggers for likes, participations, comments
-- Date: 2025-02-07
-- =====================================================================
--
-- This migration creates trigger functions and triggers to automatically
-- create notifications when:
-- - Someone likes an event (notify event creator)
-- - Someone participates in an event (notify event creator)
-- - Someone comments on an event (notify event creator)
-- - Someone replies to a comment (notify comment author)
-- =====================================================================

-- =====================================================================
-- TRIGGER FUNCTION: Event Like Notification
-- =====================================================================

CREATE OR REPLACE FUNCTION trigger_event_like_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event RECORD;
  v_liker_name TEXT;
BEGIN
  -- Get event details
  SELECT id, creator_id, title INTO v_event
  FROM events
  WHERE id = NEW.event_id;

  -- Don't notify if liker is the event creator
  IF v_event.creator_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  -- Get liker name
  SELECT full_name INTO v_liker_name
  FROM profiles
  WHERE user_id = NEW.user_id;

  -- Create notification
  PERFORM create_notification(
    p_recipient_id := v_event.creator_id,
    p_sender_id := NEW.user_id,
    p_type := 'event_like',
    p_title := 'Nuovo like',
    p_description := COALESCE(v_liker_name, 'Qualcuno') || ' ha messo like al tuo evento',
    p_target_type := 'event',
    p_target_id := NEW.event_id,
    p_metadata := jsonb_build_object('event_title', v_event.title)
  );

  RETURN NEW;
END;
$$;

-- =====================================================================
-- TRIGGER FUNCTION: Event Participation Notification
-- =====================================================================

CREATE OR REPLACE FUNCTION trigger_event_participation_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event RECORD;
  v_participant_name TEXT;
BEGIN
  -- Get event details
  SELECT id, creator_id, title INTO v_event
  FROM events
  WHERE id = NEW.event_id;

  -- Don't notify if participant is the event creator
  IF v_event.creator_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  -- Get participant name
  SELECT full_name INTO v_participant_name
  FROM profiles
  WHERE user_id = NEW.user_id;

  -- Create notification
  PERFORM create_notification(
    p_recipient_id := v_event.creator_id,
    p_sender_id := NEW.user_id,
    p_type := 'event_participation',
    p_title := 'Nuova partecipazione',
    p_description := COALESCE(v_participant_name, 'Qualcuno') || ' parteciperà al tuo evento',
    p_target_type := 'event',
    p_target_id := NEW.event_id,
    p_metadata := jsonb_build_object('event_title', v_event.title)
  );

  RETURN NEW;
END;
$$;

-- =====================================================================
-- TRIGGER FUNCTION: Comment Notification (new comment on event)
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
  IF v_event.creator_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  -- Get commenter name
  SELECT full_name INTO v_commenter_name
  FROM profiles
  WHERE user_id = NEW.user_id;

  -- Create notification
  PERFORM create_notification(
    p_recipient_id := v_event.creator_id,
    p_sender_id := NEW.user_id,
    p_type := 'new_comment',
    p_title := 'Nuovo commento',
    p_description := COALESCE(v_commenter_name, 'Qualcuno') || ' ha commentato il tuo evento',
    p_target_type := 'event',
    p_target_id := NEW.event_id,
    p_metadata := jsonb_build_object(
      'event_title', v_event.title,
      'comment_id', NEW.id,
      'comment_text', LEFT(NEW.text, 100)
    )
  );

  RETURN NEW;
END;
$$;

-- =====================================================================
-- TRIGGER FUNCTION: Comment Reply Notification
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
  SELECT id, user_id, event_id INTO v_parent_comment
  FROM comments
  WHERE id = NEW.parent_comment_id;

  -- Don't notify if replier is the original commenter
  IF v_parent_comment.user_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  -- Get replier name
  SELECT full_name INTO v_replier_name
  FROM profiles
  WHERE user_id = NEW.user_id;

  -- Get event title
  SELECT title INTO v_event_title
  FROM events
  WHERE id = NEW.event_id;

  -- Create notification
  PERFORM create_notification(
    p_recipient_id := v_parent_comment.user_id,
    p_sender_id := NEW.user_id,
    p_type := 'comment_reply',
    p_title := 'Nuova risposta',
    p_description := COALESCE(v_replier_name, 'Qualcuno') || ' ha risposto al tuo commento',
    p_target_type := 'comment',
    p_target_id := NEW.id,
    p_metadata := jsonb_build_object(
      'event_id', NEW.event_id,
      'event_title', v_event_title,
      'parent_comment_id', NEW.parent_comment_id,
      'reply_text', LEFT(NEW.text, 100)
    )
  );

  RETURN NEW;
END;
$$;

-- =====================================================================
-- CREATE TRIGGERS
-- =====================================================================

-- Drop existing triggers if they exist (for idempotency)
DROP TRIGGER IF EXISTS on_event_like_notify_creator ON likes;
DROP TRIGGER IF EXISTS on_event_participation_notify_creator ON participations;
DROP TRIGGER IF EXISTS on_comment_notify_event_creator ON comments;
DROP TRIGGER IF EXISTS on_comment_reply_notify_author ON comments;

-- Trigger: Notify event creator on new like
CREATE TRIGGER on_event_like_notify_creator
  AFTER INSERT ON likes
  FOR EACH ROW
  EXECUTE FUNCTION trigger_event_like_notification();

-- Trigger: Notify event creator on new participation
CREATE TRIGGER on_event_participation_notify_creator
  AFTER INSERT ON participations
  FOR EACH ROW
  EXECUTE FUNCTION trigger_event_participation_notification();

-- Trigger: Notify event creator on new top-level comment
CREATE TRIGGER on_comment_notify_event_creator
  AFTER INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION trigger_comment_notification();

-- Trigger: Notify comment author on reply
CREATE TRIGGER on_comment_reply_notify_author
  AFTER INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION trigger_comment_reply_notification();

-- =====================================================================
-- VERIFICATION
-- =====================================================================

-- Check that all functions were created
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'trigger_event_like_notification') THEN
    RAISE EXCEPTION 'trigger_event_like_notification function not created';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'trigger_event_participation_notification') THEN
    RAISE EXCEPTION 'trigger_event_participation_notification function not created';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'trigger_comment_notification') THEN
    RAISE EXCEPTION 'trigger_comment_notification function not created';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'trigger_comment_reply_notification') THEN
    RAISE EXCEPTION 'trigger_comment_reply_notification function not created';
  END IF;
  RAISE NOTICE 'All notification trigger functions created successfully';
END $$;

-- Check that all triggers were created
SELECT 'Notification triggers created:' AS status;
SELECT tgname, tgrelid::regclass AS table_name
FROM pg_trigger
WHERE tgname IN (
  'on_event_like_notify_creator',
  'on_event_participation_notify_creator',
  'on_comment_notify_event_creator',
  'on_comment_reply_notify_author'
);
