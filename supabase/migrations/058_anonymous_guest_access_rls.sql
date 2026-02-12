-- =====================================================================
-- Migration: 058_anonymous_guest_access_rls.sql
-- Purpose: Enable anonymous (guest) read access for Apple Guideline 5.1.1
-- Date: 2025-02-12
-- =====================================================================
--
-- Apple App Store Guideline 5.1.1 requires that users can access
-- non-account-based features without logging in.
--
-- This migration adds SELECT policies for the 'anon' role to allow
-- unauthenticated users to browse events (Instagram-style guest mode).
--
-- Guest users CAN:
-- - View approved upcoming events
-- - View public profile info (for event creator display)
-- - View like counts
-- - View participant counts
-- - View comments on events
--
-- Guest users CANNOT:
-- - Like events
-- - Participate in events
-- - Post comments
-- - Submit reports
-- - Access any write operations
--
-- =====================================================================

-- =====================================================================
-- EVENTS TABLE - Anonymous SELECT Policy
-- =====================================================================

DROP POLICY IF EXISTS "anon_view_approved_upcoming_events" ON events;
CREATE POLICY "anon_view_approved_upcoming_events"
  ON events
  FOR SELECT
  TO anon
  USING (
    status = 'approved'
    AND event_date >= CURRENT_DATE
  );

-- =====================================================================
-- PROFILES TABLE - Anonymous SELECT Policy (for event creator info)
-- =====================================================================

-- Check if profile_visible column exists and use it in policy
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'profile_visible'
  ) THEN
    -- Policy with profile_visible check
    DROP POLICY IF EXISTS "anon_view_public_profiles" ON profiles;
    EXECUTE 'CREATE POLICY "anon_view_public_profiles"
      ON profiles
      FOR SELECT
      TO anon
      USING (profile_visible = true)';
  ELSE
    -- Policy without profile_visible (show all profiles)
    DROP POLICY IF EXISTS "anon_view_public_profiles" ON profiles;
    EXECUTE 'CREATE POLICY "anon_view_public_profiles"
      ON profiles
      FOR SELECT
      TO anon
      USING (true)';
  END IF;
END $$;

-- =====================================================================
-- LIKES TABLE - Anonymous SELECT Policy (for like counts)
-- =====================================================================

DROP POLICY IF EXISTS "anon_view_likes" ON likes;
CREATE POLICY "anon_view_likes"
  ON likes
  FOR SELECT
  TO anon
  USING (true);

-- =====================================================================
-- PARTICIPATIONS TABLE - Anonymous SELECT Policy (for participant counts)
-- =====================================================================

DROP POLICY IF EXISTS "anon_view_participations" ON participations;
CREATE POLICY "anon_view_participations"
  ON participations
  FOR SELECT
  TO anon
  USING (true);

-- =====================================================================
-- COMMENTS TABLE - Anonymous SELECT Policy (for viewing comments)
-- =====================================================================

-- Comments table may have different structures across migrations
-- Use dynamic check for soft-delete column
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'comments' AND column_name = 'deleted_at'
  ) THEN
    -- Policy excluding soft-deleted comments
    DROP POLICY IF EXISTS "anon_view_comments" ON comments;
    EXECUTE 'CREATE POLICY "anon_view_comments"
      ON comments
      FOR SELECT
      TO anon
      USING (deleted_at IS NULL)';
  ELSE
    -- Policy without soft-delete check
    DROP POLICY IF EXISTS "anon_view_comments" ON comments;
    EXECUTE 'CREATE POLICY "anon_view_comments"
      ON comments
      FOR SELECT
      TO anon
      USING (true)';
  END IF;
END $$;

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE policyname LIKE 'anon_%';

  IF policy_count >= 5 THEN
    RAISE NOTICE '===================================================';
    RAISE NOTICE 'Anonymous guest access policies created successfully!';
    RAISE NOTICE '';
    RAISE NOTICE 'Created % policies for anon role:', policy_count;
    RAISE NOTICE '  - events: view approved upcoming';
    RAISE NOTICE '  - profiles: view public profiles';
    RAISE NOTICE '  - likes: view like counts';
    RAISE NOTICE '  - participations: view participant counts';
    RAISE NOTICE '  - comments: view comments';
    RAISE NOTICE '';
    RAISE NOTICE 'Apple Guideline 5.1.1 compliance: ENABLED';
    RAISE NOTICE '===================================================';
  ELSE
    RAISE WARNING 'Expected 5 anon policies, found %', policy_count;
  END IF;
END $$;
