-- Migration: 061_fix_reports_table_structure
-- Purpose: Fix reports table structure - make legacy columns nullable
-- Date: 2026-03-11
-- Issue: Reports table has legacy NOT NULL columns conflicting with
--        new content_type/content_id structure from migration 057

-- ============================================================================
-- FIX REPORTS TABLE STRUCTURE
-- ============================================================================

-- Make all legacy columns nullable
DO $$
BEGIN
  -- Make event_id nullable (if it exists)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reports' AND column_name = 'event_id'
  ) THEN
    ALTER TABLE reports ALTER COLUMN event_id DROP NOT NULL;
    RAISE NOTICE 'Made event_id nullable';
  END IF;

  -- Make reason nullable (if it exists) - new system uses category instead
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reports' AND column_name = 'reason'
  ) THEN
    ALTER TABLE reports ALTER COLUMN reason DROP NOT NULL;
    RAISE NOTICE 'Made reason nullable';
  END IF;

  -- Make explanation nullable (if it exists) - new system uses note instead
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reports' AND column_name = 'explanation'
  ) THEN
    ALTER TABLE reports ALTER COLUMN explanation DROP NOT NULL;
    RAISE NOTICE 'Made explanation nullable';
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
  RAISE NOTICE '  - Made reason column nullable (if existed)';
  RAISE NOTICE '  - Made explanation column nullable (if existed)';
  RAISE NOTICE '=====================================================';
END $$;
