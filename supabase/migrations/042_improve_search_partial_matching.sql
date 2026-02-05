-- Migration: 042_improve_search_partial_matching
-- Purpose: Improve search to support partial word matching (not requiring full words)
-- Date: 2026-02-05
-- Description: Combines ILIKE for prefix/substring matching with FTS for ranking

-- ============================================================================
-- IMPROVED: search_profiles function - Supports partial name matching
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
DECLARE
  normalized_query text;
BEGIN
  -- Normalize query: trim and lowercase
  normalized_query := LOWER(TRIM(search_query));

  -- Return empty if query is too short
  IF LENGTH(normalized_query) < 2 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    p.user_id,
    p.full_name::text,
    p.bio::text,
    p.class::text AS class_name,
    p.avatar_url::text,
    -- Ranking: FTS match gets highest priority, then ILIKE prefix, then ILIKE contains
    (CASE
      -- Exact FTS match (highest priority)
      WHEN p.search_vector @@ websearch_to_tsquery('italian', search_query)
        THEN ts_rank(p.search_vector, websearch_to_tsquery('italian', search_query)) + 2.0
      -- Name starts with query (high priority)
      WHEN LOWER(p.full_name) LIKE normalized_query || '%'
        THEN 1.5
      -- Name contains query (medium priority)
      WHEN LOWER(p.full_name) LIKE '%' || normalized_query || '%'
        THEN 1.0
      -- Bio or class contains query (lower priority)
      ELSE 0.5
    END)::real as rank
  FROM profiles p
  WHERE
    p.class IS NOT NULL  -- Profile is complete (has class)
    AND p.profile_visible = true  -- Only visible profiles
    AND (
      -- FTS match
      p.search_vector @@ websearch_to_tsquery('italian', search_query)
      -- OR partial name match (case-insensitive)
      OR LOWER(p.full_name) LIKE '%' || normalized_query || '%'
      -- OR partial class match
      OR LOWER(p.class) LIKE '%' || normalized_query || '%'
      -- OR partial bio match
      OR LOWER(COALESCE(p.bio, '')) LIKE '%' || normalized_query || '%'
    )
  ORDER BY rank DESC, p.full_name ASC
  LIMIT result_limit;
END;
$$;

-- ============================================================================
-- IMPROVED: search_events function - Supports partial word matching
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
DECLARE
  normalized_query text;
BEGIN
  -- Normalize query: trim and lowercase
  normalized_query := LOWER(TRIM(search_query));

  -- Return empty if query is too short
  IF LENGTH(normalized_query) < 2 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    e.id,
    e.title::text,
    e.description::text,
    e.location::text,
    e.event_date,
    e.image_url::text,
    e.creator_id,
    -- Ranking: FTS match gets highest priority, then ILIKE prefix, then ILIKE contains
    (CASE
      -- Exact FTS match (highest priority)
      WHEN e.search_vector @@ websearch_to_tsquery('italian', search_query)
        THEN ts_rank(e.search_vector, websearch_to_tsquery('italian', search_query)) + 2.0
      -- Title starts with query (high priority)
      WHEN LOWER(e.title) LIKE normalized_query || '%'
        THEN 1.5
      -- Title contains query (medium priority)
      WHEN LOWER(e.title) LIKE '%' || normalized_query || '%'
        THEN 1.0
      -- Description or location contains query (lower priority)
      ELSE 0.5
    END)::real as rank
  FROM events e
  WHERE
    e.status = 'approved'
    AND (
      -- FTS match
      e.search_vector @@ websearch_to_tsquery('italian', search_query)
      -- OR partial title match (case-insensitive)
      OR LOWER(e.title) LIKE '%' || normalized_query || '%'
      -- OR partial location match
      OR LOWER(COALESCE(e.location, '')) LIKE '%' || normalized_query || '%'
      -- OR partial description match
      OR LOWER(COALESCE(e.description, '')) LIKE '%' || normalized_query || '%'
    )
  ORDER BY rank DESC, e.event_date DESC
  LIMIT result_limit;
END;
$$;

-- ============================================================================
-- GRANT PERMISSIONS (re-apply after function replacement)
-- ============================================================================

GRANT EXECUTE ON FUNCTION search_events(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION search_profiles(text, int) TO authenticated;

-- ============================================================================
-- Add indexes for ILIKE performance (if not exists)
-- ============================================================================

-- Trigram extension for faster LIKE queries (if available)
-- Note: This requires the pg_trgm extension to be enabled
-- Uncomment if extension is available:
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;
-- CREATE INDEX IF NOT EXISTS idx_profiles_full_name_trgm ON profiles USING gin(full_name gin_trgm_ops);
-- CREATE INDEX IF NOT EXISTS idx_events_title_trgm ON events USING gin(title gin_trgm_ops);

-- Simple btree indexes for prefix matching (faster for LIKE 'query%')
CREATE INDEX IF NOT EXISTS idx_profiles_full_name_lower ON profiles(LOWER(full_name) varchar_pattern_ops);
CREATE INDEX IF NOT EXISTS idx_events_title_lower ON events(LOWER(title) varchar_pattern_ops);

-- Verification
DO $$
BEGIN
  RAISE NOTICE 'Migration 042 complete: Search now supports partial word matching';
END $$;
