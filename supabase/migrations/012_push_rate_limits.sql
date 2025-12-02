-- =====================================================================
-- Migration: 012_push_rate_limits
-- Purpose: Rate limiting table for push notifications (T077)
-- =====================================================================
-- Tracks recent push notifications to prevent spam:
-- - Max 1 push per notification type per event per hour
-- - Old records auto-cleaned by Edge Function
-- =====================================================================

-- Create push_rate_limits table
CREATE TABLE IF NOT EXISTS push_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    notification_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Unique constraint for upsert
    CONSTRAINT push_rate_limits_unique UNIQUE (user_id, notification_type, target_id)
);

-- Index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_push_rate_limits_lookup
    ON push_rate_limits (user_id, notification_type, target_id, sent_at);

-- Index for cleanup queries
CREATE INDEX IF NOT EXISTS idx_push_rate_limits_sent_at
    ON push_rate_limits (sent_at);

-- RLS: Only service role can access this table (Edge Function uses service role)
ALTER TABLE push_rate_limits ENABLE ROW LEVEL SECURITY;

-- No user-facing RLS policies needed - only service role accesses this table
-- Service role bypasses RLS by default

-- Comments
COMMENT ON TABLE push_rate_limits IS 'Rate limiting for push notifications - prevents notification spam';
COMMENT ON COLUMN push_rate_limits.notification_type IS 'Type of notification (e.g., comment, like, participation)';
COMMENT ON COLUMN push_rate_limits.target_id IS 'Target entity ID (event_id or comment_id)';
COMMENT ON COLUMN push_rate_limits.sent_at IS 'When the push was last sent';
