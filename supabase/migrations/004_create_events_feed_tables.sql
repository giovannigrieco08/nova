-- =====================================================================
-- Migration: 004_create_events_feed_tables.sql
-- Feature: 003-events-feed (Events Feed - Instagram-style infinite scroll)
-- Date: 2025-01-02 (Patched: 2025-11-02)
-- Purpose: Create all tables, indexes, and RLS policies for Events Feed
-- =====================================================================

-- This migration creates:
-- - 5 tables: events, likes, participations, comments, reports
-- - 14 indexes for query performance
-- - 21 RLS policies for security (with proper TO clauses and auth.uid() wrapping)
-- - Triggers for auto-updating updated_at timestamps
-- - Realtime publication configuration (guarded)
--
-- IMPORTANT: Uses existing 'profiles' table (from migration 002) instead of creating new 'users' table

-- =====================================================================
-- PHASE 1: CREATE TABLES
-- =====================================================================

-- Table 1: Events (approved events with moderation status)
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(200) NOT NULL,
  description TEXT NOT NULL,
  event_date DATE NOT NULL,
  event_time TIME NOT NULL,
  location VARCHAR(200) NOT NULL,
  cover_images TEXT[] NOT NULL DEFAULT '{}',
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table 2: Likes (junction table for event likes)
-- References auth.users directly (profiles.user_id is same as auth.users.id)
CREATE TABLE IF NOT EXISTS likes (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, event_id)
);

-- Table 3: Participations (junction table for event RSVPs)
CREATE TABLE IF NOT EXISTS participations (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, event_id)
);

-- Table 4: Comments (event comments with 500 char limit)
-- Renamed 'text' column to 'content' to avoid confusion with TEXT type
CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content VARCHAR(500) NOT NULL CHECK (length(trim(content)) > 0 AND length(content) <= 500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table 5: Reports (event reports for moderation)
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason VARCHAR(50) NOT NULL CHECK (reason IN ('inappropriate', 'spam', 'harassment', 'other')),
  explanation TEXT NOT NULL CHECK (length(trim(explanation)) > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed BOOLEAN NOT NULL DEFAULT FALSE
);

-- =====================================================================
-- PHASE 2: CREATE INDEXES (for query performance)
-- =====================================================================

-- Events indexes
CREATE INDEX IF NOT EXISTS idx_events_date_status ON events(event_date, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_creator_id ON events(creator_id);
CREATE INDEX IF NOT EXISTS idx_events_created_at ON events(created_at DESC);

-- Likes indexes
CREATE INDEX IF NOT EXISTS idx_likes_event_id ON likes(event_id);
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON likes(user_id);

-- Participations indexes
CREATE INDEX IF NOT EXISTS idx_participations_event_id ON participations(event_id);
CREATE INDEX IF NOT EXISTS idx_participations_user_id ON participations(user_id);

-- Comments indexes
CREATE INDEX IF NOT EXISTS idx_comments_event_id ON comments(event_id, created_at);
CREATE INDEX IF NOT EXISTS idx_comments_author_id ON comments(author_id);

-- Reports indexes
CREATE INDEX IF NOT EXISTS idx_reports_event_id ON reports(event_id);
CREATE INDEX IF NOT EXISTS idx_reports_reviewed ON reports(reviewed, created_at);

-- =====================================================================
-- PHASE 3: CREATE TRIGGERS (for auto-updating updated_at)
-- =====================================================================

-- Reuse existing update_updated_at_column() function from migration 002
-- Create trigger for events table to auto-update updated_at
CREATE TRIGGER update_events_updated_at
BEFORE UPDATE ON events
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- =====================================================================
-- PHASE 4: ENABLE ROW LEVEL SECURITY (RLS)
-- =====================================================================

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE participations ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- PHASE 5: CREATE RLS POLICIES
-- =====================================================================
-- NOTE: Using DROP POLICY IF EXISTS + CREATE POLICY pattern instead of
-- CREATE POLICY IF NOT EXISTS (which PostgreSQL doesn't support)
-- All policies explicitly specify TO authenticated and wrap auth.uid() with SELECT

-- =====================================================================
-- EVENTS TABLE POLICIES
-- =====================================================================

-- Policy 1: Users can view upcoming approved events only (FR-002, FR-072, FR-003a)
DROP POLICY IF EXISTS "users_view_approved_upcoming_events" ON events;
CREATE POLICY "users_view_approved_upcoming_events"
  ON events
  FOR SELECT
  TO authenticated
  USING (
    status = 'approved'
    AND event_date >= CURRENT_DATE
  );

-- Policy 2: Users can create new events (default status='pending')
DROP POLICY IF EXISTS "users_create_events" ON events;
CREATE POLICY "users_create_events"
  ON events
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = creator_id
    AND status = 'pending'
  );

-- Policy 3: Users can update their own events (FR-073)
DROP POLICY IF EXISTS "users_update_own_events" ON events;
CREATE POLICY "users_update_own_events"
  ON events
  FOR UPDATE
  TO authenticated
  USING (creator_id = (SELECT auth.uid()))
  WITH CHECK (creator_id = (SELECT auth.uid()));

-- Policy 4: Users can delete their own events (FR-073)
DROP POLICY IF EXISTS "users_delete_own_events" ON events;
CREATE POLICY "users_delete_own_events"
  ON events
  FOR DELETE
  TO authenticated
  USING (creator_id = (SELECT auth.uid()));

-- =====================================================================
-- LIKES TABLE POLICIES
-- =====================================================================

-- Policy 5: Users can view all likes (needed for like count display)
DROP POLICY IF EXISTS "users_view_all_likes" ON likes;
CREATE POLICY "users_view_all_likes"
  ON likes
  FOR SELECT
  TO authenticated
  USING (true);

-- Policy 6: Users can like any approved event (FR-015)
DROP POLICY IF EXISTS "users_like_approved_events" ON likes;
CREATE POLICY "users_like_approved_events"
  ON likes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_id
        AND events.status = 'approved'
    )
    AND user_id = (SELECT auth.uid())
  );

-- Policy 7: Users can unlike their own likes only (FR-017)
DROP POLICY IF EXISTS "users_unlike_own_likes" ON likes;
CREATE POLICY "users_unlike_own_likes"
  ON likes
  FOR DELETE
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- =====================================================================
-- PARTICIPATIONS TABLE POLICIES
-- =====================================================================

-- Policy 8: Users can view all participations (needed for participant count/list)
DROP POLICY IF EXISTS "users_view_all_participations" ON participations;
CREATE POLICY "users_view_all_participations"
  ON participations
  FOR SELECT
  TO authenticated
  USING (true);

-- Policy 9: Users can participate in any approved event (FR-022)
DROP POLICY IF EXISTS "users_participate_approved_events" ON participations;
CREATE POLICY "users_participate_approved_events"
  ON participations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_id
        AND events.status = 'approved'
    )
    AND user_id = (SELECT auth.uid())
  );

-- Policy 10: Users can unparticipate from their own RSVPs (FR-023)
DROP POLICY IF EXISTS "users_unparticipate_own" ON participations;
CREATE POLICY "users_unparticipate_own"
  ON participations
  FOR DELETE
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- =====================================================================
-- COMMENTS TABLE POLICIES
-- =====================================================================

-- Policy 11: Users can view comments on approved events (FR-027)
DROP POLICY IF EXISTS "users_view_comments_approved_events" ON comments;
CREATE POLICY "users_view_comments_approved_events"
  ON comments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = comments.event_id
        AND events.status = 'approved'
    )
  );

-- Policy 12: Users can post comments on approved events (FR-029)
DROP POLICY IF EXISTS "users_post_comments_approved_events" ON comments;
CREATE POLICY "users_post_comments_approved_events"
  ON comments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_id
        AND events.status = 'approved'
    )
    AND author_id = (SELECT auth.uid())
    AND length(trim(content)) > 0
    AND length(content) <= 500
  );

-- Policy 13: Users can delete their own comments only
DROP POLICY IF EXISTS "users_delete_own_comments" ON comments;
CREATE POLICY "users_delete_own_comments"
  ON comments
  FOR DELETE
  TO authenticated
  USING (author_id = (SELECT auth.uid()));

-- =====================================================================
-- REPORTS TABLE POLICIES
-- =====================================================================

-- Policy 14: Users can view their own reports only
DROP POLICY IF EXISTS "users_view_own_reports" ON reports;
CREATE POLICY "users_view_own_reports"
  ON reports
  FOR SELECT
  TO authenticated
  USING (reporter_id = (SELECT auth.uid()));

-- Policy 15: Users can submit reports on any event (FR-049)
DROP POLICY IF EXISTS "users_submit_reports" ON reports;
CREATE POLICY "users_submit_reports"
  ON reports
  FOR INSERT
  TO authenticated
  WITH CHECK (
    reporter_id = (SELECT auth.uid())
    AND reason IN ('inappropriate', 'spam', 'harassment', 'other')
    AND length(trim(explanation)) > 0
  );

-- =====================================================================
-- PHASE 6: MODERATOR POLICIES (Future Feature - COMMENTED OUT)
-- =====================================================================
-- NOTE: The is_moderator() function and moderator policies are commented out
-- because the 'user_roles' table doesn't exist yet. Uncomment when implementing
-- moderation feature.

/*
-- Create moderator role check function
CREATE OR REPLACE FUNCTION is_moderator()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = (SELECT auth.uid())
      AND role = 'moderator'
  );
END;
$$;

-- Revoke public access to moderator function
REVOKE EXECUTE ON FUNCTION is_moderator() FROM PUBLIC, anon, authenticated;

-- Policy 16: Moderators can view all events (including pending/rejected)
DROP POLICY IF EXISTS "moderators_view_all_events" ON events;
CREATE POLICY "moderators_view_all_events"
  ON events
  FOR SELECT
  TO authenticated
  USING (is_moderator());

-- Policy 17: Moderators can update event status (approve/reject)
DROP POLICY IF EXISTS "moderators_update_event_status" ON events;
CREATE POLICY "moderators_update_event_status"
  ON events
  FOR UPDATE
  TO authenticated
  USING (is_moderator())
  WITH CHECK (is_moderator());

-- Policy 18: Moderators can view all reports
DROP POLICY IF EXISTS "moderators_view_all_reports" ON reports;
CREATE POLICY "moderators_view_all_reports"
  ON reports
  FOR SELECT
  TO authenticated
  USING (is_moderator());

-- Policy 19: Moderators can update report reviewed status
DROP POLICY IF EXISTS "moderators_update_reports" ON reports;
CREATE POLICY "moderators_update_reports"
  ON reports
  FOR UPDATE
  TO authenticated
  USING (is_moderator())
  WITH CHECK (is_moderator());
*/

-- =====================================================================
-- PHASE 7: ENABLE REALTIME ON EVENTS AND COMMENTS TABLES
-- =====================================================================

-- Enable Realtime publication on events and comments tables
-- Guarded with publication existence check to prevent errors
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    -- Check if events table is already in publication
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
      AND tablename = 'events'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.events';
    END IF;

    -- Check if comments table is already in publication
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
      AND tablename = 'comments'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.comments';
    END IF;
  END IF;
END;
$$;

-- =====================================================================
-- VALIDATION QUERIES (Uncomment to verify setup after migration)
-- =====================================================================

-- Verify all tables exist:
-- SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('events', 'likes', 'participations', 'comments', 'reports') ORDER BY tablename;

-- Verify all indexes exist:
-- SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND indexname LIKE 'idx_%' ORDER BY indexname;

-- Verify all RLS policies exist (should be 15 active policies):
-- SELECT tablename, policyname FROM pg_policies WHERE tablename IN ('events', 'likes', 'participations', 'comments', 'reports') ORDER BY tablename, policyname;

-- Verify Realtime is enabled:
-- SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename IN ('events', 'comments');

-- =====================================================================
-- END OF MIGRATION
-- =====================================================================
