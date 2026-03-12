-- Migration: 064_notify_moderators_on_report
-- Purpose: Notify moderators when a new report is submitted
-- Date: 2026-03-12

-- ============================================================================
-- TRIGGER FUNCTION: Notify moderators on new report
-- ============================================================================

CREATE OR REPLACE FUNCTION notify_moderators_on_report()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  reporter_name TEXT;
  reported_user_id UUID;
  reported_user_name TEXT;
  content_description TEXT;
  category_display TEXT;
BEGIN
  -- Get reporter name
  SELECT COALESCE(full_name, username, 'Utente') INTO reporter_name
  FROM profiles WHERE user_id = NEW.reporter_id;

  reporter_name := COALESCE(reporter_name, 'Utente');

  -- Get category display name
  category_display := CASE NEW.category
    WHEN 'spam' THEN 'Spam'
    WHEN 'harassment' THEN 'Molestie'
    WHEN 'hate_speech' THEN 'Incitamento all''odio'
    WHEN 'violence' THEN 'Violenza'
    WHEN 'sexual_content' THEN 'Contenuto sessuale'
    WHEN 'misinformation' THEN 'Disinformazione'
    WHEN 'other' THEN 'Altro'
    ELSE NEW.category::TEXT
  END;

  -- Get content info based on type
  CASE NEW.content_type
    WHEN 'profile' THEN
      SELECT user_id, COALESCE(full_name, username, 'Utente')
      INTO reported_user_id, reported_user_name
      FROM profiles WHERE user_id = NEW.content_id;
      content_description := 'Profilo di ' || COALESCE(reported_user_name, 'utente');

    WHEN 'event' THEN
      SELECT e.organizer_id, COALESCE(p.full_name, p.username, 'Utente')
      INTO reported_user_id, reported_user_name
      FROM events e
      LEFT JOIN profiles p ON p.user_id = e.organizer_id
      WHERE e.id = NEW.content_id;
      content_description := 'Evento';

    WHEN 'comment' THEN
      SELECT c.user_id, COALESCE(p.full_name, p.username, 'Utente')
      INTO reported_user_id, reported_user_name
      FROM comments c
      LEFT JOIN profiles p ON p.user_id = c.user_id
      WHERE c.id = NEW.content_id;
      content_description := 'Commento di ' || COALESCE(reported_user_name, 'utente');

    WHEN 'chat_message' THEN
      SELECT cm.sender_id, COALESCE(p.full_name, p.username, 'Utente')
      INTO reported_user_id, reported_user_name
      FROM chat_messages cm
      LEFT JOIN profiles p ON p.user_id = cm.sender_id
      WHERE cm.id = NEW.content_id;
      content_description := 'Messaggio di ' || COALESCE(reported_user_name, 'utente');

    ELSE
      content_description := NEW.content_type::TEXT;
  END CASE;

  -- Insert notification for all moderators and admins
  INSERT INTO notifications (
    recipient_id,
    sender_id,
    type,
    title,
    description,
    target_type,
    target_id
  )
  SELECT
    ur.user_id,
    NULL, -- No sender for system notifications
    'user_report',
    'Nuova segnalazione: ' || category_display,
    reporter_name || ' ha segnalato: ' || content_description,
    'report',
    NEW.id
  FROM user_roles ur
  WHERE ur.role IN ('moderator', 'admin')
    AND ur.user_id != NEW.reporter_id; -- Don't notify if reporter is also a mod

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't fail the report operation
  RAISE WARNING 'notify_moderators_on_report failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- ============================================================================
-- CREATE TRIGGER
-- ============================================================================

DROP TRIGGER IF EXISTS trg_notify_moderators_on_report ON reports;
CREATE TRIGGER trg_notify_moderators_on_report
AFTER INSERT ON reports
FOR EACH ROW
EXECUTE FUNCTION notify_moderators_on_report();

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'Migration 064_notify_moderators_on_report completed';
  RAISE NOTICE '  - Created function notify_moderators_on_report()';
  RAISE NOTICE '  - Created trigger trg_notify_moderators_on_report';
  RAISE NOTICE '  - Moderators will be notified on new reports';
  RAISE NOTICE '=====================================================';
END $$;
