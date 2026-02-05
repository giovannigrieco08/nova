-- Migration: 048_remove_email_domain_from_rls
-- Purpose: Remove hardcoded @galileimoro.edu.it domain restriction from RLS policies
-- Date: 2026-02-06
-- Issue: Migration 038 disabled domain restriction for signup, but RLS policies still check domain

-- ============================================================================
-- PROFILES TABLE - Fix SELECT policy
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    -- Drop the domain-restricted policy
    DROP POLICY IF EXISTS "profiles_select" ON profiles;

    -- Create new policy: any authenticated user can see visible profiles
    CREATE POLICY "profiles_select"
      ON profiles FOR SELECT
      TO authenticated
      USING (
        -- Users can always see their own profile
        user_id = (SELECT auth.uid())
        OR
        -- Any authenticated user can see visible, non-deleted profiles
        (
          profile_visible = TRUE
          AND deleted_at IS NULL
        )
      );

    RAISE NOTICE 'Fixed profiles_select policy: removed domain restriction';
  END IF;
END $$;

-- ============================================================================
-- SEARCH FUNCTION - Fix domain check in search_users_and_events
-- ============================================================================

-- Check if the function exists and recreate it without domain restriction
CREATE OR REPLACE FUNCTION search_users_and_events(
  search_query TEXT,
  result_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
  result_type TEXT,
  id TEXT,
  title TEXT,
  subtitle TEXT,
  image_url TEXT,
  relevance_score REAL
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_query TEXT;
  query_parts TEXT[];
  search_pattern TEXT;
BEGIN
  -- Normalize query: lowercase, trim, collapse spaces
  normalized_query := LOWER(TRIM(REGEXP_REPLACE(search_query, '\s+', ' ', 'g')));

  -- Split into parts for multi-word matching
  query_parts := STRING_TO_ARRAY(normalized_query, ' ');

  -- Create pattern for partial matching
  search_pattern := '%' || normalized_query || '%';

  RETURN QUERY
  WITH user_results AS (
    SELECT
      'user'::TEXT AS result_type,
      p.user_id::TEXT AS id,
      COALESCE(p.full_name, p.username, 'Utente') AS title,
      COALESCE(p.class, '') AS subtitle,
      p.avatar_url AS image_url,
      -- Relevance scoring
      CASE
        -- Exact match on username
        WHEN LOWER(p.username) = normalized_query THEN 1.0
        -- Exact match on full_name
        WHEN LOWER(p.full_name) = normalized_query THEN 0.95
        -- Starts with query
        WHEN LOWER(p.full_name) LIKE normalized_query || '%' THEN 0.9
        WHEN LOWER(p.username) LIKE normalized_query || '%' THEN 0.85
        -- Contains query
        WHEN LOWER(p.full_name) LIKE search_pattern THEN 0.7
        WHEN LOWER(p.username) LIKE search_pattern THEN 0.65
        -- Class match
        WHEN LOWER(p.class) LIKE search_pattern THEN 0.5
        ELSE 0.3
      END::REAL AS relevance_score
    FROM profiles p
    WHERE
      p.profile_visible = TRUE
      AND p.deleted_at IS NULL
      AND (
        LOWER(p.full_name) LIKE search_pattern
        OR LOWER(p.username) LIKE search_pattern
        OR LOWER(p.class) LIKE search_pattern
      )
  ),
  event_results AS (
    SELECT
      'event'::TEXT AS result_type,
      e.id::TEXT AS id,
      e.title AS title,
      COALESCE(e.location, TO_CHAR(e.event_date, 'DD/MM/YYYY')) AS subtitle,
      e.image_url AS image_url,
      CASE
        WHEN LOWER(e.title) = normalized_query THEN 1.0
        WHEN LOWER(e.title) LIKE normalized_query || '%' THEN 0.9
        WHEN LOWER(e.title) LIKE search_pattern THEN 0.7
        WHEN LOWER(e.description) LIKE search_pattern THEN 0.5
        WHEN LOWER(e.location) LIKE search_pattern THEN 0.4
        ELSE 0.3
      END::REAL AS relevance_score
    FROM events e
    WHERE
      e.status = 'approved'
      AND e.event_date >= NOW()
      AND (
        LOWER(e.title) LIKE search_pattern
        OR LOWER(e.description) LIKE search_pattern
        OR LOWER(e.location) LIKE search_pattern
      )
  )
  SELECT * FROM user_results
  UNION ALL
  SELECT * FROM event_results
  ORDER BY relevance_score DESC
  LIMIT result_limit;
END;
$$;

COMMENT ON FUNCTION search_users_and_events IS 'Search users and events - no domain restriction';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE 'Migration 048 complete: Removed email domain restrictions from RLS policies';
END $$;
