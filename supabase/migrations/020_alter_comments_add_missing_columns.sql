-- ============================================================================
-- Migration: Add missing columns to comments table
-- Purpose: Upgrade existing comments table to support full feature set
-- Created: 2025-01-23
--
-- EXISTING SCHEMA: id, event_id, author_id, content, created_at
-- ADDING: parent_comment_id, like_count, reply_count, report_count,
--         deleted_at, updated_at, hidden_at, hidden_reason, moderator_id
-- ============================================================================

-- Add parent_comment_id for threading (nullable - top-level comments have NULL)
ALTER TABLE comments
ADD COLUMN IF NOT EXISTS parent_comment_id UUID REFERENCES comments(id) ON DELETE CASCADE;

-- Add counter columns with defaults
ALTER TABLE comments
ADD COLUMN IF NOT EXISTS like_count INT NOT NULL DEFAULT 0;

ALTER TABLE comments
ADD COLUMN IF NOT EXISTS reply_count INT NOT NULL DEFAULT 0;

ALTER TABLE comments
ADD COLUMN IF NOT EXISTS report_count INT NOT NULL DEFAULT 0;

-- Add soft delete support (GDPR Right to Erasure)
ALTER TABLE comments
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

ALTER TABLE comments
ADD COLUMN IF NOT EXISTS deleted_by_user_id UUID REFERENCES profiles(user_id);

-- Add edit tracking
ALTER TABLE comments
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

-- Add moderation support
ALTER TABLE comments
ADD COLUMN IF NOT EXISTS hidden_at TIMESTAMPTZ;

ALTER TABLE comments
ADD COLUMN IF NOT EXISTS hidden_reason TEXT;

ALTER TABLE comments
ADD COLUMN IF NOT EXISTS moderator_id UUID REFERENCES profiles(user_id);

-- Add check constraints (using DO block to handle if already exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'like_count_non_negative'
  ) THEN
    ALTER TABLE comments ADD CONSTRAINT like_count_non_negative CHECK (like_count >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'reply_count_non_negative'
  ) THEN
    ALTER TABLE comments ADD CONSTRAINT reply_count_non_negative CHECK (reply_count >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'report_count_non_negative'
  ) THEN
    ALTER TABLE comments ADD CONSTRAINT report_count_non_negative CHECK (report_count >= 0);
  END IF;
END $$;

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_comments_parent_replies
  ON comments(parent_comment_id, created_at ASC)
  WHERE parent_comment_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_comments_moderation_queue
  ON comments(created_at DESC)
  WHERE hidden_at IS NOT NULL;

-- ============================================================================
-- Note: This migration preserves existing data and column names (author_id, content)
-- The Flutter code has been adapted to use the actual schema
-- ============================================================================
