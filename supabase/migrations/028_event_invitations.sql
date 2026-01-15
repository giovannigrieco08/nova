-- Migration: Create event_invitations table for event invitation functionality
-- Purpose: Allow users to invite other users to events
-- Date: 2024-12-07

-- Create event_invitations table
CREATE TABLE IF NOT EXISTS event_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  invitee_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at TIMESTAMPTZ,
  UNIQUE(event_id, invitee_id) -- Un utente può essere invitato a un evento solo una volta
);

-- Enable RLS
ALTER TABLE event_invitations ENABLE ROW LEVEL SECURITY;

-- Policy: Any authenticated user can create invitations
CREATE POLICY "Users can create invitations" ON event_invitations
  FOR INSERT
  WITH CHECK (auth.uid() = inviter_id);

-- Policy: Users can view invitations they sent or received
CREATE POLICY "Users can view their invitations" ON event_invitations
  FOR SELECT
  USING (auth.uid() = inviter_id OR auth.uid() = invitee_id);

-- Policy: Invitees can update (accept/decline) their invitations
CREATE POLICY "Invitees can respond to invitations" ON event_invitations
  FOR UPDATE
  USING (auth.uid() = invitee_id)
  WITH CHECK (auth.uid() = invitee_id);

-- Policy: Inviters can delete pending invitations they sent
CREATE POLICY "Inviters can cancel pending invitations" ON event_invitations
  FOR DELETE
  USING (auth.uid() = inviter_id AND status = 'pending');

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_event_invitations_event_id ON event_invitations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_invitations_invitee_id ON event_invitations(invitee_id);
CREATE INDEX IF NOT EXISTS idx_event_invitations_inviter_id ON event_invitations(inviter_id);
CREATE INDEX IF NOT EXISTS idx_event_invitations_status ON event_invitations(status);

-- Add comment for documentation
COMMENT ON TABLE event_invitations IS 'Stores event invitations between users';
COMMENT ON COLUMN event_invitations.status IS 'Invitation status: pending, accepted, declined';
