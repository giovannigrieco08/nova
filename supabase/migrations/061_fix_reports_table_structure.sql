-- Migration: 061_fix_reports_table_structure
-- Purpose: Fix reports table structure - remove old event_id column
-- Date: 2026-03-11
-- Issue: Reports table has legacy event_id NOT NULL column conflicting with
--        new content_type/content_id structure from migration 057

-- ============================================================================
-- FIX REPORTS TABLE STRUCTURE
-- ============================================================================

-- Drop the old event_id constraint and column if they exist
DO $$
BEGIN
  -- Make event_id nullable first (if it exists)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reports' AND column_name = 'event_id'
  ) THEN
    ALTER TABLE reports ALTER COLUMN event_id DROP NOT NULL;
    RAISE NOTICE 'Made event_id nullable';
  END IF;
END $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'Migration 061_fix_reports_table_structure completed';
  RAISE NOTICE '  - Made event_id column nullable (if existed)';
  RAISE NOTICE '=====================================================';
END $$;
