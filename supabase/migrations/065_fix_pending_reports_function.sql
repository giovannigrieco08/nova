-- Migration: 065_fix_pending_reports_function
-- Purpose: Fix get_pending_reports to handle missing profiles and improve reliability
-- Date: 2026-03-13

-- ============================================================================
-- FIX: get_pending_reports function
-- ============================================================================

CREATE OR REPLACE FUNCTION get_pending_reports(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  p_category TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSONB;
BEGIN
  -- Verify moderator role
  IF NOT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  ) THEN
    RAISE EXCEPTION 'Permesso negato';
  END IF;

  WITH pending AS (
    SELECT
      r.id,
      r.content_type::TEXT AS content_type,
      r.content_id,
      r.category::TEXT AS category,
      r.note,
      r.status::TEXT AS status,
      r.created_at,
      r.reporter_id,
      EXTRACT(EPOCH FROM (NOW() - r.created_at)) / 3600 AS hours_pending,
      EXTRACT(EPOCH FROM (NOW() - r.created_at)) / 3600 > 20 AS is_urgent,
      COALESCE(reporter.full_name, reporter.username, 'Utente') AS reporter_name,
      reporter.username AS reporter_username
    FROM reports r
    LEFT JOIN profiles reporter ON r.reporter_id = reporter.user_id
    WHERE r.status = 'pending'
    AND (p_category IS NULL OR r.category::TEXT = p_category)
    ORDER BY r.created_at ASC
    LIMIT p_limit OFFSET p_offset
  )
  SELECT jsonb_build_object(
    'reports', COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', pending.id,
        'content_type', pending.content_type,
        'content_id', pending.content_id,
        'category', pending.category,
        'note', pending.note,
        'status', pending.status,
        'created_at', pending.created_at,
        'reporter_id', pending.reporter_id,
        'hours_pending', pending.hours_pending,
        'is_urgent', pending.is_urgent,
        'reporter_name', pending.reporter_name,
        'reporter_username', pending.reporter_username
      )
    ), '[]'::jsonb),
    'total_count', (SELECT COUNT(*) FROM reports WHERE status = 'pending'),
    'urgent_count', (SELECT COUNT(*) FROM reports WHERE status = 'pending' AND created_at < NOW() - INTERVAL '20 hours')
  ) INTO result
  FROM pending;

  RETURN result;
END;
$$;

-- ============================================================================
-- FIX: review_report function to handle all actions
-- ============================================================================

CREATE OR REPLACE FUNCTION review_report(
  p_report_id UUID,
  p_action TEXT,
  p_sanction_reason TEXT DEFAULT NULL,
  p_suspension_days INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  report_record RECORD;
  reported_user_id UUID;
  sanction_id UUID;
  moderator_id UUID;
BEGIN
  moderator_id := auth.uid();

  -- Verify moderator role
  IF NOT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = moderator_id
    AND role IN ('moderator', 'admin')
  ) THEN
    RAISE EXCEPTION 'Permesso negato';
  END IF;

  -- Get report details
  SELECT * INTO report_record FROM reports WHERE id = p_report_id;

  IF report_record IS NULL THEN
    RAISE EXCEPTION 'Report non trovato';
  END IF;

  IF report_record.status != 'pending' THEN
    RAISE EXCEPTION 'Report già processato';
  END IF;

  -- Get reported user ID based on content type
  CASE report_record.content_type::TEXT
    WHEN 'profile' THEN
      reported_user_id := report_record.content_id;
    WHEN 'event' THEN
      SELECT creator_id INTO reported_user_id FROM events WHERE id = report_record.content_id;
    WHEN 'comment' THEN
      SELECT user_id INTO reported_user_id FROM comments WHERE id = report_record.content_id;
    WHEN 'chat_message' THEN
      SELECT sender_id INTO reported_user_id FROM chat_messages WHERE id = report_record.content_id;
    ELSE
      reported_user_id := NULL;
  END CASE;

  -- Process action
  CASE p_action
    WHEN 'dismissed' THEN
      -- Just mark as reviewed
      UPDATE reports
      SET status = 'reviewed',
          reviewed_by = moderator_id,
          reviewed_at = NOW(),
          action_taken = 'dismissed'
      WHERE id = p_report_id;

    WHEN 'content_removed' THEN
      -- Remove the content
      IF report_record.content_type::TEXT = 'comment' THEN
        UPDATE comments SET is_deleted = TRUE WHERE id = report_record.content_id;
      ELSIF report_record.content_type::TEXT = 'chat_message' THEN
        UPDATE chat_messages SET is_deleted = TRUE WHERE id = report_record.content_id;
      ELSIF report_record.content_type::TEXT = 'event' THEN
        UPDATE events SET is_cancelled = TRUE WHERE id = report_record.content_id;
      END IF;

      UPDATE reports
      SET status = 'reviewed',
          reviewed_by = moderator_id,
          reviewed_at = NOW(),
          action_taken = 'content_removed'
      WHERE id = p_report_id;

    WHEN 'user_warned' THEN
      -- Create warning sanction
      IF reported_user_id IS NOT NULL THEN
        INSERT INTO user_sanctions (user_id, type, reason, issued_by)
        VALUES (reported_user_id, 'warning', COALESCE(p_sanction_reason, 'Comportamento inappropriato'), moderator_id)
        RETURNING id INTO sanction_id;
      END IF;

      UPDATE reports
      SET status = 'reviewed',
          reviewed_by = moderator_id,
          reviewed_at = NOW(),
          action_taken = 'user_warned'
      WHERE id = p_report_id;

    WHEN 'user_suspended' THEN
      -- Create suspension sanction
      IF reported_user_id IS NOT NULL THEN
        INSERT INTO user_sanctions (user_id, type, reason, issued_by, expires_at)
        VALUES (
          reported_user_id,
          'suspension',
          COALESCE(p_sanction_reason, 'Violazione delle regole'),
          moderator_id,
          NOW() + (COALESCE(p_suspension_days, 7) || ' days')::INTERVAL
        )
        RETURNING id INTO sanction_id;
      END IF;

      UPDATE reports
      SET status = 'reviewed',
          reviewed_by = moderator_id,
          reviewed_at = NOW(),
          action_taken = 'user_suspended'
      WHERE id = p_report_id;

    WHEN 'user_banned' THEN
      -- Create ban sanction (permanent)
      IF reported_user_id IS NOT NULL THEN
        INSERT INTO user_sanctions (user_id, type, reason, issued_by)
        VALUES (
          reported_user_id,
          'ban',
          COALESCE(p_sanction_reason, 'Violazione grave delle regole'),
          moderator_id
        )
        RETURNING id INTO sanction_id;
      END IF;

      UPDATE reports
      SET status = 'reviewed',
          reviewed_by = moderator_id,
          reviewed_at = NOW(),
          action_taken = 'user_banned'
      WHERE id = p_report_id;

    ELSE
      RAISE EXCEPTION 'Azione non valida: %', p_action;
  END CASE;

  RETURN jsonb_build_object(
    'success', TRUE,
    'action_taken', p_action,
    'sanction_id', sanction_id,
    'reported_user_id', reported_user_id
  );
END;
$$;

-- ============================================================================
-- FIX: notify_moderators_on_report to use creator_id for events
-- ============================================================================

CREATE OR REPLACE FUNCTION notify_moderators_on_report()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  reporter_name TEXT;
  reported_user_name TEXT;
  content_description TEXT;
  category_display TEXT;
BEGIN
  -- Get reporter name
  SELECT COALESCE(full_name, username, 'Utente') INTO reporter_name
  FROM profiles WHERE user_id = NEW.reporter_id;
  reporter_name := COALESCE(reporter_name, 'Utente');

  -- Get category display name
  category_display := CASE NEW.category::TEXT
    WHEN 'spam' THEN 'Spam'
    WHEN 'harassment' THEN 'Molestie'
    WHEN 'hate_speech' THEN 'Incitamento all''odio'
    WHEN 'violence' THEN 'Violenza'
    WHEN 'sexual_content' THEN 'Contenuto sessuale'
    WHEN 'misinformation' THEN 'Disinformazione'
    WHEN 'other' THEN 'Altro'
    ELSE NEW.category::TEXT
  END;

  -- Get content description
  CASE NEW.content_type::TEXT
    WHEN 'profile' THEN
      SELECT COALESCE(full_name, username, 'Utente') INTO reported_user_name
      FROM profiles WHERE user_id = NEW.content_id;
      content_description := 'Profilo di ' || COALESCE(reported_user_name, 'utente');

    WHEN 'event' THEN
      SELECT COALESCE(p.full_name, p.username, 'Utente') INTO reported_user_name
      FROM events e
      LEFT JOIN profiles p ON p.user_id = e.creator_id
      WHERE e.id = NEW.content_id;
      content_description := 'Evento di ' || COALESCE(reported_user_name, 'utente');

    WHEN 'comment' THEN
      SELECT COALESCE(p.full_name, p.username, 'Utente') INTO reported_user_name
      FROM comments c
      LEFT JOIN profiles p ON p.user_id = c.user_id
      WHERE c.id = NEW.content_id;
      content_description := 'Commento di ' || COALESCE(reported_user_name, 'utente');

    WHEN 'chat_message' THEN
      SELECT COALESCE(p.full_name, p.username, 'Utente') INTO reported_user_name
      FROM chat_messages cm
      LEFT JOIN profiles p ON p.user_id = cm.sender_id
      WHERE cm.id = NEW.content_id;
      content_description := 'Messaggio di ' || COALESCE(reported_user_name, 'utente');

    ELSE
      content_description := NEW.content_type::TEXT;
  END CASE;

  -- Insert notification for all moderators and admins
  INSERT INTO notifications (recipient_id, sender_id, type, title, description, target_type, target_id)
  SELECT
    ur.user_id,
    NULL,
    'user_report',
    'Nuova segnalazione: ' || category_display,
    reporter_name || ' ha segnalato: ' || content_description,
    'report',
    NEW.id
  FROM user_roles ur
  WHERE ur.role IN ('moderator', 'admin')
    AND ur.user_id != NEW.reporter_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'notify_moderators_on_report failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Recreate trigger
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
  RAISE NOTICE 'Migration 065_fix_pending_reports_function completed';
  RAISE NOTICE '  - Fixed get_pending_reports with LEFT JOIN';
  RAISE NOTICE '  - Fixed review_report to use creator_id for events';
  RAISE NOTICE '  - Fixed notify_moderators_on_report';
  RAISE NOTICE '=====================================================';
END $$;
