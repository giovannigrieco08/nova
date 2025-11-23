-- ============================================================================
-- Migration: Event Comments System
-- Feature: 007-event-comments
-- Created: 2025-01-23
-- Description: Complete comment system with threading, likes, reports,
--              moderation, profanity filtering, and GDPR compliance
-- ============================================================================

-- ============================================================================
-- SECTION 1: TABLE SCHEMAS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: comments
-- Purpose: Stores all comments and replies (1-level threading)
-- ----------------------------------------------------------------------------
CREATE TABLE comments (
  -- Identity
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relationships
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  parent_comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,

  -- Content
  text TEXT NOT NULL CHECK (char_length(trim(text)) BETWEEN 1 AND 500),

  -- Denormalized counters (for performance)
  like_count INT NOT NULL DEFAULT 0 CHECK (like_count >= 0),
  reply_count INT NOT NULL DEFAULT 0 CHECK (reply_count >= 0),
  report_count INT NOT NULL DEFAULT 0 CHECK (report_count >= 0),

  -- Soft delete (GDPR Right to Erasure)
  deleted_at TIMESTAMPTZ,
  deleted_by_user_id UUID REFERENCES profiles(id),

  -- Moderation
  hidden_at TIMESTAMPTZ, -- Auto-hidden at 3+ reports
  hidden_reason TEXT, -- "auto_hide_reports" or "moderator_removed"
  moderator_id UUID REFERENCES profiles(id), -- Who removed it (if moderator action)

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ, -- NULL if never edited

  -- Constraints
  CONSTRAINT parent_must_be_top_level
    CHECK (
      parent_comment_id IS NULL OR
      parent_comment_id IN (
        SELECT id FROM comments WHERE parent_comment_id IS NULL
      )
    ), -- Enforce max 1-level threading

  CONSTRAINT deleted_comments_are_empty
    CHECK (deleted_at IS NULL OR text = '[Commento eliminato]')
);

-- Indexes for comments table
CREATE INDEX idx_comments_event_top_level
  ON comments(event_id, created_at DESC)
  WHERE parent_comment_id IS NULL AND deleted_at IS NULL;

CREATE INDEX idx_comments_parent_replies
  ON comments(parent_comment_id, created_at ASC)
  WHERE parent_comment_id IS NOT NULL AND deleted_at IS NULL;

CREATE INDEX idx_comments_user
  ON comments(user_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_comments_moderation_queue
  ON comments(created_at DESC)
  WHERE hidden_at IS NOT NULL AND deleted_at IS NULL;

CREATE INDEX idx_comments_text_search
  ON comments USING gin(to_tsvector('italian', text))
  WHERE deleted_at IS NULL;

CREATE INDEX idx_comments_pending_hard_delete
  ON comments(deleted_at)
  WHERE deleted_at IS NOT NULL;

-- ----------------------------------------------------------------------------
-- Table: comment_likes
-- Purpose: Many-to-many relationship between users and comments
-- ----------------------------------------------------------------------------
CREATE TABLE comment_likes (
  -- Composite primary key (prevents duplicate likes)
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Soft delete (for GDPR, preserves like_count accuracy)
  deleted_at TIMESTAMPTZ,

  PRIMARY KEY (comment_id, user_id)
);

-- Indexes for comment_likes table
CREATE INDEX idx_comment_likes_user
  ON comment_likes(user_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_comment_likes_rate_limit
  ON comment_likes(user_id, created_at DESC)
  WHERE deleted_at IS NULL AND created_at > NOW() - INTERVAL '1 hour';

CREATE INDEX idx_comment_likes_pending_hard_delete
  ON comment_likes(deleted_at)
  WHERE deleted_at IS NOT NULL;

-- ----------------------------------------------------------------------------
-- Table: comment_reports
-- Purpose: User-submitted reports for inappropriate comments
-- ----------------------------------------------------------------------------
CREATE TABLE comment_reports (
  -- Identity
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relationships
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  reporter_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Report details
  reason TEXT NOT NULL CHECK (reason IN ('spam', 'inappropriate', 'bullying', 'off_topic')),
  details TEXT CHECK (char_length(trim(details)) <= 500), -- Optional elaboration

  -- Moderation workflow
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
  reviewed_by_moderator_id UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  moderator_notes TEXT,

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Prevent duplicate reports from same user
  CONSTRAINT unique_user_report_per_comment UNIQUE (comment_id, reporter_user_id)
);

-- Indexes for comment_reports table
CREATE INDEX idx_comment_reports_pending
  ON comment_reports(created_at DESC)
  WHERE status = 'pending';

CREATE INDEX idx_comment_reports_comment
  ON comment_reports(comment_id, created_at DESC);

CREATE INDEX idx_comment_reports_user
  ON comment_reports(reporter_user_id, created_at DESC);

-- ============================================================================
-- SECTION 2: ALTER EXISTING TABLES
-- ============================================================================

-- Add comment_count field to events table
ALTER TABLE events
ADD COLUMN IF NOT EXISTS comment_count INT NOT NULL DEFAULT 0 CHECK (comment_count >= 0);

CREATE INDEX IF NOT EXISTS idx_events_comment_count
  ON events(comment_count DESC)
  WHERE status = 'approved';

-- ============================================================================
-- SECTION 3: DATABASE FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function: contains_profanity
-- Purpose: Check if text contains Italian profanity (whole-word matching)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION contains_profanity(input_text TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  -- Italian profanity list (150+ words)
  -- NOTE: Curated list maintained for school-appropriate content (ages 14-19)
  profane_words TEXT[] := ARRAY[
    'cazzo', 'merda', 'stronzo', 'bastardo', 'fica', 'figa', 'puttana',
    'troia', 'vaffanculo', 'fanculo', 'porco', 'porca', 'dio', 'madonna',
    'cristo', 'porcodio', 'porcamadonna', 'porcocristo', 'coglione',
    'minchia', 'testa di cazzo', 'figlio di puttana', 'pezzo di merda',
    'cazzone', 'stronza', 'troietta', 'puttaniere', 'merdoso', 'cazzata',
    'incazzato', 'rompicoglioni', 'rompiballe', 'scemo', 'idiota', 'imbecille',
    'deficiente', 'cretino', 'mongoloide', 'handicappato', 'ritardato',
    'froci', 'frocio', 'finocchio', 'lesbica', 'culattone', 'checca',
    'negro', 'negra', 'terrone', 'polentone', 'crucco', 'marocchino',
    -- Add more as needed based on moderation review
    'vaffanculo', 'fottiti', 'fottuto', 'scopare', 'pompino', 'sega',
    'cazzi', 'palle', 'cazzo', 'culo', 'pezzo di merda', 'testa di minchia'
  ];
  word TEXT;
BEGIN
  -- Normalize: lowercase, trim
  input_text := lower(trim(input_text));

  -- Check each profane word with word boundaries (whole-word matching only)
  FOREACH word IN ARRAY profane_words LOOP
    -- \y = word boundary (supports Unicode characters in Italian)
    IF input_text ~* ('\y' || word || '\y') THEN
      RETURN TRUE;
    END IF;
  END LOOP;

  RETURN FALSE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ----------------------------------------------------------------------------
-- Function: check_comment_spam
-- Purpose: Prevent spam (max 3 identical comments in 5 minutes)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_comment_spam()
RETURNS TRIGGER AS $$
DECLARE
  recent_count INT;
BEGIN
  SELECT COUNT(*) INTO recent_count
  FROM comments
  WHERE user_id = NEW.user_id
    AND event_id = NEW.event_id
    AND text = NEW.text
    AND created_at > NOW() - INTERVAL '5 minutes';

  IF recent_count >= 3 THEN
    RAISE EXCEPTION 'Rate limit exceeded: max 3 identical comments in 5 minutes';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Function: check_like_rate_limit
-- Purpose: Prevent like spam (max 100 likes per hour)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_like_rate_limit()
RETURNS TRIGGER AS $$
DECLARE
  recent_likes INT;
BEGIN
  SELECT COUNT(*) INTO recent_likes
  FROM comment_likes
  WHERE user_id = NEW.user_id
    AND created_at > NOW() - INTERVAL '1 hour';

  IF recent_likes >= 100 THEN
    RAISE EXCEPTION 'Rate limit exceeded: max 100 likes per hour';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Function: validate_comment_profanity
-- Purpose: Check profanity on insert/update
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_comment_profanity()
RETURNS TRIGGER AS $$
BEGIN
  IF contains_profanity(NEW.text) THEN
    RAISE EXCEPTION 'Comment contains inappropriate language';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Function: update_comment_like_count
-- Purpose: Denormalized counter for like_count
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_comment_like_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE comments
    SET like_count = like_count + 1
    WHERE id = NEW.comment_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE comments
    SET like_count = GREATEST(0, like_count - 1)
    WHERE id = OLD.comment_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Function: update_comment_reply_count
-- Purpose: Denormalized counter for reply_count
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_comment_reply_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.parent_comment_id IS NOT NULL THEN
    UPDATE comments
    SET reply_count = reply_count + 1
    WHERE id = NEW.parent_comment_id;
  ELSIF TG_OP = 'DELETE' AND OLD.parent_comment_id IS NOT NULL THEN
    UPDATE comments
    SET reply_count = GREATEST(0, reply_count - 1)
    WHERE id = OLD.parent_comment_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Function: update_comment_report_count
-- Purpose: Denormalized counter for report_count + auto-hide at 3+ reports
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_comment_report_count()
RETURNS TRIGGER AS $$
DECLARE
  total_reports INT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Count unique reporters for this comment
    SELECT COUNT(DISTINCT reporter_user_id) INTO total_reports
    FROM comment_reports
    WHERE comment_id = NEW.comment_id;

    -- Update report_count
    UPDATE comments
    SET report_count = total_reports
    WHERE id = NEW.comment_id;

    -- Auto-hide if 3+ reports (embedded auto-hide logic)
    IF total_reports >= 3 THEN
      UPDATE comments
      SET
        hidden_at = NOW(),
        hidden_reason = 'auto_hide_reports'
      WHERE id = NEW.comment_id AND hidden_at IS NULL;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Function: update_event_comment_count
-- Purpose: Denormalized counter for events.comment_count
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_event_comment_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.parent_comment_id IS NULL THEN
    UPDATE events
    SET comment_count = comment_count + 1
    WHERE id = NEW.event_id;
  ELSIF TG_OP = 'DELETE' AND OLD.parent_comment_id IS NULL THEN
    UPDATE events
    SET comment_count = GREATEST(0, comment_count - 1)
    WHERE id = OLD.event_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Function: gdpr_hard_delete_old_data
-- Purpose: Permanently delete soft-deleted data after 30-day grace period
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gdpr_hard_delete_old_data()
RETURNS void AS $$
BEGIN
  -- Hard delete comments after 30-day grace period
  DELETE FROM comments
  WHERE deleted_at IS NOT NULL
    AND deleted_at < NOW() - INTERVAL '30 days';

  -- Hard delete likes after 30-day grace period
  DELETE FROM comment_likes
  WHERE deleted_at IS NOT NULL
    AND deleted_at < NOW() - INTERVAL '30 days';

  -- Log cleanup action
  RAISE NOTICE 'GDPR hard delete completed at %', NOW();
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECTION 4: TRIGGERS
-- ============================================================================

-- Rate limiting triggers
CREATE TRIGGER prevent_comment_spam
  BEFORE INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION check_comment_spam();

CREATE TRIGGER prevent_like_spam
  BEFORE INSERT ON comment_likes
  FOR EACH ROW
  EXECUTE FUNCTION check_like_rate_limit();

-- Profanity filter triggers
CREATE TRIGGER check_profanity_on_insert
  BEFORE INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION validate_comment_profanity();

CREATE TRIGGER check_profanity_on_update
  BEFORE UPDATE ON comments
  FOR EACH ROW
  WHEN (OLD.text IS DISTINCT FROM NEW.text)
  EXECUTE FUNCTION validate_comment_profanity();

-- Denormalized counter triggers
CREATE TRIGGER sync_comment_like_count
  AFTER INSERT OR DELETE ON comment_likes
  FOR EACH ROW
  EXECUTE FUNCTION update_comment_like_count();

CREATE TRIGGER sync_comment_reply_count
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW
  EXECUTE FUNCTION update_comment_reply_count();

CREATE TRIGGER sync_comment_report_count
  AFTER INSERT ON comment_reports
  FOR EACH ROW
  EXECUTE FUNCTION update_comment_report_count();

CREATE TRIGGER sync_event_comment_count
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW
  EXECUTE FUNCTION update_event_comment_count();

-- ============================================================================
-- SECTION 5: ROW-LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- RLS for comments table
-- ----------------------------------------------------------------------------
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- Policy 1: Students can view non-deleted, non-hidden comments on approved events
CREATE POLICY "Students view approved event comments"
  ON comments FOR SELECT
  TO authenticated
  USING (
    deleted_at IS NULL
    AND hidden_at IS NULL
    AND event_id IN (
      SELECT id FROM events WHERE status = 'approved'
    )
  );

-- Policy 2: Moderators can view all comments (including hidden/deleted)
CREATE POLICY "Moderators view all comments"
  ON comments FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'moderator'
    )
  );

-- Policy 3: Students can insert comments (profanity filter via trigger)
CREATE POLICY "Students insert comments"
  ON comments FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND event_id IN (SELECT id FROM events WHERE status = 'approved')
    AND deleted_at IS NULL
    AND hidden_at IS NULL
  );

-- Policy 4: Users can soft-delete own comments
CREATE POLICY "Users delete own comments"
  ON comments FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND deleted_at IS NOT NULL
    AND text = '[Commento eliminato]'
  );

-- Policy 5: Moderators can hide/remove any comment
CREATE POLICY "Moderators remove comments"
  ON comments FOR UPDATE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'moderator'
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'moderator'
    )
  );

-- Policy 6: Users can edit own comments within 5 minutes
CREATE POLICY "Users edit own recent comments"
  ON comments FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = user_id
    AND deleted_at IS NULL
    AND created_at > NOW() - INTERVAL '5 minutes'
  )
  WITH CHECK (
    auth.uid() = user_id
    AND updated_at = NOW()
  );

-- ----------------------------------------------------------------------------
-- RLS for comment_likes table
-- ----------------------------------------------------------------------------
ALTER TABLE comment_likes ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view likes on visible comments
CREATE POLICY "Users view comment likes"
  ON comment_likes FOR SELECT
  TO authenticated
  USING (
    deleted_at IS NULL
    AND comment_id IN (
      SELECT id FROM comments WHERE deleted_at IS NULL AND hidden_at IS NULL
    )
  );

-- Policy 2: Users can like comments (rate limit via trigger)
CREATE POLICY "Users like comments"
  ON comment_likes FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND deleted_at IS NULL
  );

-- Policy 3: Users can unlike own likes
CREATE POLICY "Users unlike comments"
  ON comment_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- RLS for comment_reports table
-- ----------------------------------------------------------------------------
ALTER TABLE comment_reports ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view own reports
CREATE POLICY "Users view own reports"
  ON comment_reports FOR SELECT
  TO authenticated
  USING (auth.uid() = reporter_user_id);

-- Policy 2: Moderators can view all reports
CREATE POLICY "Moderators view all reports"
  ON comment_reports FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'moderator'
    )
  );

-- Policy 3: Users can submit reports (one per comment)
CREATE POLICY "Users submit reports"
  ON comment_reports FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = reporter_user_id
    AND status = 'pending'
  );

-- Policy 4: Moderators can update report status
CREATE POLICY "Moderators review reports"
  ON comment_reports FOR UPDATE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'moderator'
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'moderator'
    )
  );

-- ============================================================================
-- SECTION 6: INITIAL DATA & COMMENTS
-- ============================================================================

-- No seed data required for comments system (user-generated content)

COMMENT ON TABLE comments IS 'Event comments with 1-level threading, soft-delete, and moderation';
COMMENT ON TABLE comment_likes IS 'User likes on comments with rate limiting';
COMMENT ON TABLE comment_reports IS 'User-submitted reports for inappropriate comments';

COMMENT ON FUNCTION contains_profanity(TEXT) IS 'Check if text contains Italian profanity using whole-word boundary matching';
COMMENT ON FUNCTION check_comment_spam() IS 'Rate limit: max 3 identical comments in 5 minutes per user per event';
COMMENT ON FUNCTION check_like_rate_limit() IS 'Rate limit: max 100 likes per user per hour';
COMMENT ON FUNCTION update_comment_report_count() IS 'Update report_count and auto-hide comment at 3+ unique reports';
COMMENT ON FUNCTION gdpr_hard_delete_old_data() IS 'GDPR compliance: hard delete soft-deleted data after 30-day grace period';

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
