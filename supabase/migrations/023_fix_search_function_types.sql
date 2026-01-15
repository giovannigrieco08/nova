-- Migration: 023_fix_search_function_types
-- Purpose: Fix type mismatch in search functions (varchar vs text)
-- Date: 2024-12-06
-- Error: "Returned type character varying(50) does not match expected type text"

-- ============================================================================
-- FIX: search_profiles function - Cast varchar columns to text
-- ============================================================================

CREATE OR REPLACE FUNCTION search_profiles(
  search_query text,
  result_limit int DEFAULT 20
)
RETURNS TABLE (
  user_id uuid,
  full_name text,
  bio text,
  class_name text,
  avatar_url text,
  rank real
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.user_id,
    p.full_name::text,
    p.bio::text,
    p.class::text AS class_name,
    p.avatar_url::text,
    ts_rank(p.search_vector, websearch_to_tsquery('italian', search_query)) as rank
  FROM profiles p
  WHERE
    p.class IS NOT NULL  -- Profile is complete (has class)
    AND p.search_vector @@ websearch_to_tsquery('italian', search_query)
  ORDER BY rank DESC, p.full_name ASC
  LIMIT result_limit;
END;
$$;

-- ============================================================================
-- FIX: search_events function - Cast varchar columns to text
-- ============================================================================

CREATE OR REPLACE FUNCTION search_events(
  search_query text,
  result_limit int DEFAULT 20
)
RETURNS TABLE (
  id uuid,
  title text,
  description text,
  location text,
  event_date timestamptz,
  image_url text,
  creator_id uuid,
  rank real
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id,
    e.title::text,
    e.description::text,
    e.location::text,
    e.event_date,
    e.image_url::text,
    e.creator_id,
    ts_rank(e.search_vector, websearch_to_tsquery('italian', search_query)) as rank
  FROM events e
  WHERE
    e.status = 'approved'
    AND e.search_vector @@ websearch_to_tsquery('italian', search_query)
  ORDER BY rank DESC, e.event_date DESC
  LIMIT result_limit;
END;
$$;

-- ============================================================================
-- GRANT PERMISSIONS (re-apply after function replacement)
-- ============================================================================

GRANT EXECUTE ON FUNCTION search_events(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION search_profiles(text, int) TO authenticated;

-- Verification
DO $$
BEGIN
  RAISE NOTICE 'Migration 023 complete: Fixed search function type casts';
END $$;
