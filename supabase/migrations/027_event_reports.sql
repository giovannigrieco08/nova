-- Migration: Create event_reports table for event reporting functionality
-- Purpose: Allow users to report inappropriate events (US-008)
-- Date: 2024-12-07

-- Create event_reports table
CREATE TABLE IF NOT EXISTS event_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (reason IN ('inappropriate', 'spam', 'harassment', 'misleading', 'other')),
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed', 'action_taken')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES profiles(user_id),
  review_notes TEXT,
  UNIQUE(event_id, reporter_id) -- Un utente può segnalare un evento solo una volta
);

-- Enable RLS
ALTER TABLE event_reports ENABLE ROW LEVEL SECURITY;

-- Policy: Users can create reports for events they haven't reported yet
CREATE POLICY "Users can create reports" ON event_reports
  FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

-- Policy: Users can view their own reports
CREATE POLICY "Users can view their own reports" ON event_reports
  FOR SELECT
  USING (auth.uid() = reporter_id);

-- Policy: Moderators can view all reports
CREATE POLICY "Moderators can view all reports" ON event_reports
  FOR SELECT
  USING (is_moderator());

-- Policy: Moderators can update reports (mark as reviewed)
CREATE POLICY "Moderators can update reports" ON event_reports
  FOR UPDATE
  USING (is_moderator())
  WITH CHECK (is_moderator());

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_event_reports_event_id ON event_reports(event_id);
CREATE INDEX IF NOT EXISTS idx_event_reports_status ON event_reports(status);
CREATE INDEX IF NOT EXISTS idx_event_reports_reporter_id ON event_reports(reporter_id);

-- Add comment for documentation
COMMENT ON TABLE event_reports IS 'Stores event reports from users for moderation review';
COMMENT ON COLUMN event_reports.reason IS 'Report reason: inappropriate, spam, harassment, misleading, other';
COMMENT ON COLUMN event_reports.status IS 'Report status: pending, reviewed, dismissed, action_taken';
