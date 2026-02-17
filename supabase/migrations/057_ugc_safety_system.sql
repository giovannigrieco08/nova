-- =====================================================================
-- Migration: 057_ugc_safety_system.sql
-- Purpose: UGC Safety System for Apple Guideline 1.2 compliance
-- Date: 2025-02-12
-- Feature: 015-ugc-safety
-- =====================================================================
--
-- This migration creates:
-- 1. reports table - Unified content reporting system
-- 2. user_blocks table - User blocking relationships
-- 3. banned_words table - Configurable content filter
-- 4. user_sanctions table - User penalties tracking
-- 5. Profile columns for ToS acceptance
-- 6. Helper functions for blocking and content checking
-- 7. Triggers for moderator notifications
-- 8. RLS policies for all tables
-- =====================================================================

-- =====================================================================
-- SECTION 1: Profile Table Updates (ToS Acceptance)
-- =====================================================================

-- Add ToS acceptance columns to profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS tos_accepted_version VARCHAR(20),
ADD COLUMN IF NOT EXISTS tos_accepted_at TIMESTAMPTZ;

COMMENT ON COLUMN profiles.tos_accepted_version IS 'Version of Terms of Service accepted by user (e.g., "1.0.0")';
COMMENT ON COLUMN profiles.tos_accepted_at IS 'Timestamp when user accepted the Terms of Service';

-- =====================================================================
-- SECTION 2: Reports Table
-- =====================================================================

-- Create report categories type
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'report_category') THEN
    CREATE TYPE report_category AS ENUM (
      'spam',
      'offensive_content',
      'bullying',
      'inappropriate',
      'other'
    );
  END IF;
END$$;

-- Create report status type
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'report_status') THEN
    CREATE TYPE report_status AS ENUM (
      'pending',
      'reviewed',
      'dismissed',
      'action_taken'
    );
  END IF;
END$$;

-- Create content type enum
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'reportable_content_type') THEN
    CREATE TYPE reportable_content_type AS ENUM (
      'event',
      'comment',
      'chat_message',
      'profile'
    );
  END IF;
END$$;

-- Create reports table
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content_type reportable_content_type NOT NULL,
  content_id UUID NOT NULL,
  category report_category NOT NULL,
  note TEXT CHECK (char_length(note) <= 500),
  status report_status NOT NULL DEFAULT 'pending',
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMPTZ,
  action_taken VARCHAR(50),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Prevent duplicate reports from same user on same content
  UNIQUE(reporter_id, content_type, content_id)
);

-- Ensure all columns exist (for idempotent migration)
ALTER TABLE reports ADD COLUMN IF NOT EXISTS reporter_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS content_type reportable_content_type;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS content_id UUID;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS category report_category;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS note TEXT;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS status report_status NOT NULL DEFAULT 'pending';
ALTER TABLE reports ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES auth.users(id);
ALTER TABLE reports ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS action_taken VARCHAR(50);
ALTER TABLE reports ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- Create indexes for reports
CREATE INDEX IF NOT EXISTS idx_reports_status_created
ON reports(status, created_at)
WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_reports_content
ON reports(content_type, content_id);

CREATE INDEX IF NOT EXISTS idx_reports_reporter
ON reports(reporter_id);

-- Note: urgency check (created_at < NOW() - INTERVAL '20 hours') must be done at query time
-- because NOW() is not IMMUTABLE
CREATE INDEX IF NOT EXISTS idx_reports_pending_urgent
ON reports(status, created_at)
WHERE status = 'pending';

-- Enable RLS on reports
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- RLS Policies for reports
CREATE POLICY "Users can create reports"
ON reports FOR INSERT
TO authenticated
WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "Users can view own reports"
ON reports FOR SELECT
TO authenticated
USING (reporter_id = auth.uid());

CREATE POLICY "Moderators can view all reports"
ON reports FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  )
);

CREATE POLICY "Moderators can update reports"
ON reports FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  )
);

COMMENT ON TABLE reports IS 'Unified content reporting system for UGC compliance';

-- =====================================================================
-- SECTION 3: User Blocks Table
-- =====================================================================

CREATE TABLE IF NOT EXISTS user_blocks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  moderator_notified BOOLEAN NOT NULL DEFAULT FALSE,
  notified_at TIMESTAMPTZ,

  -- Prevent duplicate blocks
  UNIQUE(blocker_id, blocked_id),
  -- Can't block yourself
  CHECK(blocker_id != blocked_id)
);

-- Create indexes for user_blocks
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON user_blocks(blocked_id);

-- Enable RLS on user_blocks
ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_blocks
CREATE POLICY "Users can block others"
ON user_blocks FOR INSERT
TO authenticated
WITH CHECK (blocker_id = auth.uid());

CREATE POLICY "Users can view own blocks"
ON user_blocks FOR SELECT
TO authenticated
USING (blocker_id = auth.uid());

CREATE POLICY "Users can unblock"
ON user_blocks FOR DELETE
TO authenticated
USING (blocker_id = auth.uid());

CREATE POLICY "Moderators can view all blocks"
ON user_blocks FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  )
);

COMMENT ON TABLE user_blocks IS 'User blocking relationships for content filtering';

-- =====================================================================
-- SECTION 4: Banned Words Table
-- =====================================================================

-- Create pattern type enum
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'banned_word_pattern_type') THEN
    CREATE TYPE banned_word_pattern_type AS ENUM (
      'exact',
      'contains',
      'regex'
    );
  END IF;
END$$;

-- Create severity enum
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'banned_word_severity') THEN
    CREATE TYPE banned_word_severity AS ENUM (
      'warning',
      'block'
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS banned_words (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  word TEXT NOT NULL,
  pattern_type banned_word_pattern_type NOT NULL DEFAULT 'contains',
  severity banned_word_severity NOT NULL DEFAULT 'block',
  language VARCHAR(10) NOT NULL DEFAULT 'it',
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Create indexes for banned_words
-- Partial unique index for active words per language (replaces invalid inline UNIQUE WHERE)
CREATE UNIQUE INDEX IF NOT EXISTS idx_banned_words_unique_active
ON banned_words(word, language)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_banned_words_active
ON banned_words(word)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_banned_words_language
ON banned_words(language)
WHERE deleted_at IS NULL;

-- Enable RLS on banned_words
ALTER TABLE banned_words ENABLE ROW LEVEL SECURITY;

-- RLS Policies for banned_words
CREATE POLICY "Moderators can manage banned words"
ON banned_words FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  )
);

CREATE POLICY "Users can read banned words for validation"
ON banned_words FOR SELECT
TO authenticated
USING (deleted_at IS NULL);

COMMENT ON TABLE banned_words IS 'Configurable content filter word list';

-- =====================================================================
-- SECTION 5: User Sanctions Table
-- =====================================================================

-- Create sanction type enum
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sanction_type') THEN
    CREATE TYPE sanction_type AS ENUM (
      'warning',
      'suspension',
      'ban'
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS user_sanctions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type sanction_type NOT NULL,
  reason TEXT NOT NULL,
  related_report_id UUID REFERENCES reports(id),
  related_content_type reportable_content_type,
  related_content_id UUID,
  issued_by UUID NOT NULL REFERENCES auth.users(id),
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  lifted_at TIMESTAMPTZ,
  lifted_by UUID REFERENCES auth.users(id),

  -- Only suspensions can have expiry
  CHECK(expires_at IS NULL OR type = 'suspension')
);

-- Create indexes for user_sanctions
CREATE INDEX IF NOT EXISTS idx_user_sanctions_user ON user_sanctions(user_id);
-- Note: expires_at comparison with NOW() must be done at query time (not in index predicate)
-- because NOW() is not IMMUTABLE
CREATE INDEX IF NOT EXISTS idx_user_sanctions_active
ON user_sanctions(user_id, type, expires_at)
WHERE lifted_at IS NULL;

-- Enable RLS on user_sanctions
ALTER TABLE user_sanctions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_sanctions
CREATE POLICY "Moderators can manage sanctions"
ON user_sanctions FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  )
);

CREATE POLICY "Users can view own sanctions"
ON user_sanctions FOR SELECT
TO authenticated
USING (user_id = auth.uid());

COMMENT ON TABLE user_sanctions IS 'User penalty tracking for moderation actions';

-- =====================================================================
-- SECTION 6: Helper Functions
-- =====================================================================

-- Function: Check if user is blocked by another user
CREATE OR REPLACE FUNCTION is_blocked_by(target_user_id UUID, viewer_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_blocks
    WHERE blocker_id = target_user_id
    AND blocked_id = viewer_user_id
  );
$$;

COMMENT ON FUNCTION is_blocked_by IS 'Check if viewer is blocked by target user';

-- Function: Check if current user has blocked a user
CREATE OR REPLACE FUNCTION is_user_blocked(p_target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_blocks
    WHERE blocker_id = auth.uid()
    AND blocked_id = p_target_user_id
  );
$$;

COMMENT ON FUNCTION is_user_blocked IS 'Check if current user has blocked the target user';

-- Function: Check if current user is blocked by another user
CREATE OR REPLACE FUNCTION is_blocked_by_user(p_target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_blocks
    WHERE blocker_id = p_target_user_id
    AND blocked_id = auth.uid()
  );
$$;

COMMENT ON FUNCTION is_blocked_by_user IS 'Check if current user is blocked by target user';

-- Function: Check if user has active ban
CREATE OR REPLACE FUNCTION is_user_banned(check_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_sanctions
    WHERE user_id = check_user_id
    AND type = 'ban'
    AND lifted_at IS NULL
    AND (expires_at IS NULL OR expires_at > NOW())
  );
$$;

COMMENT ON FUNCTION is_user_banned IS 'Check if user has an active ban';

-- Function: Check content against banned words
CREATE OR REPLACE FUNCTION check_content(p_text TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSONB := '{"allowed": true, "blocked": false, "matched_words": [], "severity": null}';
  banned_record RECORD;
  lower_text TEXT := LOWER(p_text);
  matched_words TEXT[] := ARRAY[]::TEXT[];
  max_severity TEXT := NULL;
  is_match BOOLEAN;
BEGIN
  FOR banned_record IN
    SELECT word, pattern_type, severity
    FROM banned_words
    WHERE deleted_at IS NULL
  LOOP
    is_match := FALSE;

    IF banned_record.pattern_type = 'exact' THEN
      -- Exact whole word match
      is_match := lower_text ~ ('\y' || LOWER(banned_record.word) || '\y');
    ELSIF banned_record.pattern_type = 'contains' THEN
      -- Substring match
      is_match := lower_text LIKE '%' || LOWER(banned_record.word) || '%';
    ELSIF banned_record.pattern_type = 'regex' THEN
      -- Regex match
      BEGIN
        is_match := lower_text ~ banned_record.word;
      EXCEPTION WHEN OTHERS THEN
        is_match := FALSE;  -- Invalid regex, skip
      END;
    END IF;

    IF is_match THEN
      matched_words := array_append(matched_words, banned_record.word);
      IF max_severity IS NULL OR banned_record.severity::TEXT = 'block' THEN
        max_severity := banned_record.severity::TEXT;
      END IF;
    END IF;
  END LOOP;

  IF array_length(matched_words, 1) > 0 THEN
    result := jsonb_build_object(
      'allowed', max_severity = 'warning',
      'blocked', max_severity = 'block',
      'matched_words', to_jsonb(matched_words),
      'severity', max_severity
    );
  END IF;

  RETURN result;
END;
$$;

COMMENT ON FUNCTION check_content IS 'Check text against banned words list, returns {allowed, blocked, matched_words, severity}';

-- Function: Check if user has accepted current ToS
CREATE OR REPLACE FUNCTION has_accepted_current_tos(check_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_tos_version TEXT := '1.0.0';  -- Update when ToS changes
  user_tos_version TEXT;
BEGIN
  SELECT tos_accepted_version INTO user_tos_version
  FROM profiles
  WHERE user_id = check_user_id;

  RETURN user_tos_version = current_tos_version;
END;
$$;

COMMENT ON FUNCTION has_accepted_current_tos IS 'Check if user has accepted the current Terms of Service version';

-- Function: Accept ToS
CREATE OR REPLACE FUNCTION accept_tos(p_version TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE profiles
  SET
    tos_accepted_version = p_version,
    tos_accepted_at = NOW()
  WHERE user_id = auth.uid();

  RETURN jsonb_build_object(
    'success', TRUE,
    'accepted_version', p_version,
    'accepted_at', NOW()
  );
END;
$$;

COMMENT ON FUNCTION accept_tos IS 'Accept Terms of Service for current user';

-- Function: Get ToS status
CREATE OR REPLACE FUNCTION get_tos_status()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_tos_version TEXT := '1.0.0';  -- Update when ToS changes
  user_record RECORD;
BEGIN
  SELECT tos_accepted_version, tos_accepted_at
  INTO user_record
  FROM profiles
  WHERE user_id = auth.uid();

  RETURN jsonb_build_object(
    'has_accepted', user_record.tos_accepted_version IS NOT NULL,
    'accepted_version', user_record.tos_accepted_version,
    'current_version', current_tos_version,
    'needs_reaccept', COALESCE(user_record.tos_accepted_version, '0.0.0') < current_tos_version,
    'accepted_at', user_record.tos_accepted_at
  );
END;
$$;

COMMENT ON FUNCTION get_tos_status IS 'Get current ToS acceptance status for user';

-- Function: Check if user has reported content
CREATE OR REPLACE FUNCTION has_user_reported(p_content_type TEXT, p_content_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM reports
    WHERE reporter_id = auth.uid()
    AND content_type = p_content_type::reportable_content_type
    AND content_id = p_content_id
  );
$$;

COMMENT ON FUNCTION has_user_reported IS 'Check if current user has already reported this content';

-- =====================================================================
-- SECTION 7: Moderation Functions
-- =====================================================================

-- Function: Get pending reports for moderation
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
      r.content_type,
      r.content_id,
      r.category,
      r.note,
      r.status,
      r.created_at,
      EXTRACT(EPOCH FROM (NOW() - r.created_at)) / 3600 AS hours_pending,
      EXTRACT(EPOCH FROM (NOW() - r.created_at)) / 3600 > 20 AS is_urgent,
      jsonb_build_object(
        'user_id', reporter.user_id,
        'full_name', reporter.full_name,
        'username', reporter.username
      ) AS reporter
    FROM reports r
    JOIN profiles reporter ON r.reporter_id = reporter.user_id
    WHERE r.status = 'pending'
    AND (p_category IS NULL OR r.category::TEXT = p_category)
    ORDER BY r.created_at ASC
    LIMIT p_limit OFFSET p_offset
  )
  SELECT jsonb_build_object(
    'reports', COALESCE(jsonb_agg(row_to_json(pending)), '[]'::jsonb),
    'total_count', (SELECT COUNT(*) FROM reports WHERE status = 'pending'),
    'urgent_count', (SELECT COUNT(*) FROM reports WHERE status = 'pending' AND created_at < NOW() - INTERVAL '20 hours')
  ) INTO result
  FROM pending;

  RETURN result;
END;
$$;

COMMENT ON FUNCTION get_pending_reports IS 'Get pending reports for moderation dashboard';

-- Function: Remove content (soft delete)
CREATE OR REPLACE FUNCTION remove_content(p_content_type TEXT, p_content_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_content_type = 'comment' THEN
    UPDATE comments
    SET deleted_at = NOW(),
        text = '[Commento eliminato]'
    WHERE id = p_content_id;
    RETURN FOUND;
  ELSIF p_content_type = 'chat_message' THEN
    UPDATE chat_messages
    SET hidden_at = NOW(),
        hidden_reason = 'Removed by moderation'
    WHERE id = p_content_id;
    RETURN FOUND;
  ELSIF p_content_type = 'event' THEN
    UPDATE events
    SET status = 'rejected',
        rejection_reason = 'Removed by moderation'
    WHERE id = p_content_id;
    RETURN FOUND;
  END IF;

  RETURN FALSE;
END;
$$;

COMMENT ON FUNCTION remove_content IS 'Soft delete content by type and ID';

-- Function: Review report and take action
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
  sanction_id UUID;
  content_owner_id UUID;
BEGIN
  -- Verify moderator role
  IF NOT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  ) THEN
    RAISE EXCEPTION 'Permesso negato';
  END IF;

  -- Get report
  SELECT * INTO report_record
  FROM reports
  WHERE id = p_report_id
  FOR UPDATE NOWAIT;

  IF report_record IS NULL THEN
    RAISE EXCEPTION 'Segnalazione non trovata';
  END IF;

  IF report_record.status != 'pending' THEN
    RAISE EXCEPTION 'Segnalazione già gestita';
  END IF;

  -- Get content owner
  IF report_record.content_type = 'comment' THEN
    SELECT user_id INTO content_owner_id FROM comments WHERE id = report_record.content_id;
  ELSIF report_record.content_type = 'chat_message' THEN
    SELECT user_id INTO content_owner_id FROM chat_messages WHERE id = report_record.content_id;
  ELSIF report_record.content_type = 'event' THEN
    SELECT creator_id INTO content_owner_id FROM events WHERE id = report_record.content_id;
  ELSIF report_record.content_type = 'profile' THEN
    content_owner_id := report_record.content_id;
  END IF;

  -- Execute action
  IF p_action = 'content_removed' THEN
    PERFORM remove_content(report_record.content_type::TEXT, report_record.content_id);
  ELSIF p_action IN ('user_warned', 'user_suspended', 'user_banned') THEN
    INSERT INTO user_sanctions (user_id, type, reason, related_report_id, issued_by, expires_at)
    VALUES (
      content_owner_id,
      CASE p_action
        WHEN 'user_warned' THEN 'warning'::sanction_type
        WHEN 'user_suspended' THEN 'suspension'::sanction_type
        WHEN 'user_banned' THEN 'ban'::sanction_type
      END,
      p_sanction_reason,
      p_report_id,
      auth.uid(),
      CASE WHEN p_action = 'user_suspended' THEN NOW() + (p_suspension_days || ' days')::INTERVAL ELSE NULL END
    )
    RETURNING id INTO sanction_id;

    -- Remove content as well
    PERFORM remove_content(report_record.content_type::TEXT, report_record.content_id);
  END IF;

  -- Update report
  UPDATE reports
  SET
    status = CASE WHEN p_action = 'dismissed' THEN 'dismissed'::report_status ELSE 'action_taken'::report_status END,
    action_taken = p_action,
    reviewed_by = auth.uid(),
    reviewed_at = NOW()
  WHERE id = p_report_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'action_taken', p_action,
    'sanction_id', sanction_id,
    'notification_sent', TRUE
  );
END;
$$;

COMMENT ON FUNCTION review_report IS 'Review a report and take moderation action';

-- Function: Get moderation stats
CREATE OR REPLACE FUNCTION get_moderation_stats()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify moderator role
  IF NOT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  ) THEN
    RAISE EXCEPTION 'Permesso negato';
  END IF;

  RETURN jsonb_build_object(
    'pending_reports', (SELECT COUNT(*) FROM reports WHERE status = 'pending'),
    'urgent_reports', (SELECT COUNT(*) FROM reports WHERE status = 'pending' AND created_at < NOW() - INTERVAL '20 hours'),
    'reports_today', (SELECT COUNT(*) FROM reports WHERE created_at >= CURRENT_DATE),
    'reports_this_week', (SELECT COUNT(*) FROM reports WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'),
    'actions_by_type', (
      SELECT jsonb_object_agg(COALESCE(action_taken, 'pending'), cnt)
      FROM (
        SELECT action_taken, COUNT(*) as cnt
        FROM reports
        WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY action_taken
      ) sub
    )
  );
END;
$$;

COMMENT ON FUNCTION get_moderation_stats IS 'Get moderation statistics for dashboard';

-- Function: Lift a sanction
CREATE OR REPLACE FUNCTION lift_sanction(p_sanction_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify moderator role
  IF NOT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role IN ('moderator', 'admin')
  ) THEN
    RAISE EXCEPTION 'Permesso negato';
  END IF;

  UPDATE user_sanctions
  SET
    lifted_at = NOW(),
    lifted_by = auth.uid()
  WHERE id = p_sanction_id
  AND lifted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sanzione non trovata o già revocata';
  END IF;

  RETURN jsonb_build_object(
    'success', TRUE,
    'lifted_at', NOW()
  );
END;
$$;

COMMENT ON FUNCTION lift_sanction IS 'Lift/revoke a user sanction';

-- =====================================================================
-- SECTION 8: Triggers
-- =====================================================================

-- Trigger: Notify moderators on new block
CREATE OR REPLACE FUNCTION notify_moderators_on_block()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  blocker_name TEXT;
  blocked_name TEXT;
BEGIN
  -- Get user names
  SELECT full_name INTO blocker_name FROM profiles WHERE user_id = NEW.blocker_id;
  SELECT full_name INTO blocked_name FROM profiles WHERE user_id = NEW.blocked_id;

  -- Insert notification for all moderators
  INSERT INTO notifications (recipient_id, sender_id, type, title, description, target_type, target_id)
  SELECT
    ur.user_id,
    NEW.blocker_id,
    'user_block',
    'Nuovo blocco utente',
    blocker_name || ' ha bloccato ' || blocked_name,
    'user_block',
    NEW.id
  FROM user_roles ur
  WHERE ur.role IN ('moderator', 'admin');

  -- Mark as notified
  UPDATE user_blocks
  SET moderator_notified = TRUE, notified_at = NOW()
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$;

-- Create trigger if not exists
DROP TRIGGER IF EXISTS trg_notify_moderators_on_block ON user_blocks;
CREATE TRIGGER trg_notify_moderators_on_block
AFTER INSERT ON user_blocks
FOR EACH ROW
EXECUTE FUNCTION notify_moderators_on_block();

-- =====================================================================
-- SECTION 9: Grants
-- =====================================================================

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION is_blocked_by(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_user_blocked(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_blocked_by_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_user_banned(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_content(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION has_accepted_current_tos(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION accept_tos(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_tos_status() TO authenticated;
GRANT EXECUTE ON FUNCTION has_user_reported(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_reports(INT, INT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION review_report(UUID, TEXT, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_moderation_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION lift_sanction(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_content(TEXT, UUID) TO authenticated;

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
DECLARE
  table_count INT;
  function_count INT;
BEGIN
  -- Verify tables
  SELECT COUNT(*) INTO table_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
  AND table_name IN ('reports', 'user_blocks', 'banned_words', 'user_sanctions');

  -- Verify functions
  SELECT COUNT(*) INTO function_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
  AND p.proname IN (
    'is_blocked_by', 'is_user_blocked', 'is_blocked_by_user', 'is_user_banned',
    'check_content', 'has_accepted_current_tos', 'accept_tos', 'get_tos_status',
    'has_user_reported', 'get_pending_reports', 'review_report', 'get_moderation_stats',
    'lift_sanction', 'remove_content', 'notify_moderators_on_block'
  );

  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'Migration 057_ugc_safety_system completed';
  RAISE NOTICE '  - Tables created: %', table_count;
  RAISE NOTICE '  - Functions created: %', function_count;
  RAISE NOTICE '  - Profile columns added: tos_accepted_version, tos_accepted_at';
  RAISE NOTICE '=====================================================';
END $$;
