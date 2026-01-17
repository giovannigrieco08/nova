-- Migration: 036_increase_comment_nesting
-- Purpose: Increase comment nesting from 1 level to 3 levels
-- Date: 2025-01-17
-- Changes:
--   1. Remove parent_must_be_top_level constraint
--   2. Add depth column to track nesting level
--   3. Add trigger to auto-calculate depth on insert
--   4. Add constraint to limit max depth to 3

-- ============================================================================
-- STEP 1: REMOVE OLD CONSTRAINT
-- ============================================================================

ALTER TABLE comments DROP CONSTRAINT IF EXISTS parent_must_be_top_level;

-- ============================================================================
-- STEP 2: ADD DEPTH COLUMN
-- ============================================================================

ALTER TABLE comments ADD COLUMN IF NOT EXISTS depth INT DEFAULT 0;

-- ============================================================================
-- STEP 3: POPULATE DEPTH FOR EXISTING COMMENTS
-- ============================================================================

-- Set depth=0 for top-level comments
UPDATE comments SET depth = 0 WHERE parent_comment_id IS NULL AND depth IS NULL;

-- Set depth=1 for existing replies (all current replies are 1-level deep)
UPDATE comments SET depth = 1 WHERE parent_comment_id IS NOT NULL AND depth IS NULL;

-- ============================================================================
-- STEP 4: ADD MAX DEPTH CONSTRAINT
-- ============================================================================

ALTER TABLE comments ADD CONSTRAINT max_nesting_depth
  CHECK (depth >= 0 AND depth <= 3);

-- ============================================================================
-- STEP 5: CREATE TRIGGER FOR AUTO-CALCULATING DEPTH
-- ============================================================================

-- Drop existing trigger/function if they exist
DROP TRIGGER IF EXISTS set_comment_depth ON comments;
DROP FUNCTION IF EXISTS check_comment_depth();

-- Create function to calculate depth based on parent
CREATE OR REPLACE FUNCTION check_comment_depth()
RETURNS TRIGGER AS $$
DECLARE
  parent_depth INT;
BEGIN
  IF NEW.parent_comment_id IS NULL THEN
    -- Top-level comment
    NEW.depth := 0;
  ELSE
    -- Get parent's depth
    SELECT depth INTO parent_depth
    FROM comments
    WHERE id = NEW.parent_comment_id;

    IF parent_depth IS NULL THEN
      -- Parent not found, treat as top-level
      NEW.depth := 0;
    ELSE
      NEW.depth := parent_depth + 1;
    END IF;

    -- Check max depth (redundant with CHECK constraint but provides better error)
    IF NEW.depth > 3 THEN
      RAISE EXCEPTION 'Maximum comment nesting depth (3) exceeded. Cannot reply to this comment.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to run before insert
CREATE TRIGGER set_comment_depth
  BEFORE INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION check_comment_depth();

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE 'Migration 036 complete: Comment nesting increased to 3 levels';
  RAISE NOTICE '  - Removed parent_must_be_top_level constraint';
  RAISE NOTICE '  - Added depth column (0-3)';
  RAISE NOTICE '  - Added trigger for auto-calculating depth';
END $$;
