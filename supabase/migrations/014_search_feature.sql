-- Migration: 011_search_feature.sql
-- Feature: Search (Cerca)
-- Description: Add Full-Text Search columns and GIN indexes for events and profiles
-- Spec: specs/010-search/spec.md

-- ============================================================================
-- EVENTS TABLE: Add FTS column with Italian configuration
-- ============================================================================

-- Add tsvector column for full-text search on events
ALTER TABLE events
ADD COLUMN IF NOT EXISTS search_vector tsvector
GENERATED ALWAYS AS (
  setweight(to_tsvector('italian', coalesce(title, '')), 'A') ||
  setweight(to_tsvector('italian', coalesce(description, '')), 'B') ||
  setweight(to_tsvector('italian', coalesce(location, '')), 'C')
) STORED;

-- Create GIN index for fast FTS queries on events
CREATE INDEX IF NOT EXISTS idx_events_search_vector
ON events USING GIN(search_vector);

-- ============================================================================
-- PROFILES TABLE: Add FTS column with Italian configuration
-- ============================================================================

-- Add tsvector column for full-text search on profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS search_vector tsvector
GENERATED ALWAYS AS (
  setweight(to_tsvector('italian', coalesce(full_name, '')), 'A') ||
  setweight(to_tsvector('italian', coalesce(bio, '')), 'B') ||
  setweight(to_tsvector('italian', coalesce(class, '')), 'C')
) STORED;

-- Create GIN index for fast FTS queries on profiles
CREATE INDEX IF NOT EXISTS idx_profiles_search_vector
ON profiles USING GIN(search_vector);

-- ============================================================================
-- HELPER FUNCTION: Unified search across events and profiles
-- ============================================================================

-- Function to search events with FTS
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
  organizer_id uuid,
  rank real
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id,
    e.title,
    e.description,
    e.location,
    e.event_date,
    e.image_url,
    e.organizer_id,
    ts_rank(e.search_vector, websearch_to_tsquery('italian', search_query)) as rank
  FROM events e
  WHERE
    e.status = 'approved'
    AND e.search_vector @@ websearch_to_tsquery('italian', search_query)
  ORDER BY rank DESC, e.event_date DESC
  LIMIT result_limit;
END;
$$;

-- Function to search profiles with FTS
CREATE OR REPLACE FUNCTION search_profiles(
  search_query text,
  result_limit int DEFAULT 20
)
RETURNS TABLE (
  id uuid,
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
    p.id,
    p.full_name,
    p.bio,
    p.class AS class_name,
    p.avatar_url,
    ts_rank(p.search_vector, websearch_to_tsquery('italian', search_query)) as rank
  FROM profiles p
  WHERE
    p.profile_visible = true
    AND p.search_vector @@ websearch_to_tsquery('italian', search_query)
  ORDER BY rank DESC, p.full_name ASC
  LIMIT result_limit;
END;
$$;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION search_events(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION search_profiles(text, int) TO authenticated;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON COLUMN events.search_vector IS 'Full-text search vector for events (Italian language). Weights: A=title, B=description, C=location';
COMMENT ON COLUMN profiles.search_vector IS 'Full-text search vector for profiles (Italian language). Weights: A=full_name, B=bio, C=class';
COMMENT ON FUNCTION search_events IS 'Search approved events using PostgreSQL FTS with Italian stemming. Returns max 20 results ranked by relevance.';
COMMENT ON FUNCTION search_profiles IS 'Search visible profiles using PostgreSQL FTS with Italian stemming. Returns max 20 results ranked by relevance.';
