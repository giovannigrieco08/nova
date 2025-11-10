-- =====================================================================
-- Migration: 005_create_events_tables.sql
-- Feature: Event Creation and Moderation System
-- Branch: 004-event-creation-moderation
-- =====================================================================
-- Purpose: Create events and notifications tables with RLS policies
-- Dependencies: Requires auth.users table (migration 001 or 002)
-- =====================================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================================
-- Table: events
-- =====================================================================

CREATE TABLE events (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Content Fields (from FR-001)
  title TEXT NOT NULL CHECK (char_length(title) >= 5 AND char_length(title) <= 100),
  description TEXT NOT NULL CHECK (char_length(description) >= 20 AND char_length(description) <= 500),
  event_date TIMESTAMP WITH TIME ZONE NOT NULL CHECK (event_date > now()),
  location TEXT, -- Optional field
  image_url TEXT, -- Optional, Supabase Storage public URL

  -- Ownership & Collaboration
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  co_organizers UUID[] DEFAULT '{}', -- Array of user IDs (max 3, enforced in app)

  -- Moderation Fields
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  rejection_reason TEXT, -- Populated only when status='rejected'
  moderated_by UUID REFERENCES auth.users(id), -- Moderator who approved/rejected
  moderated_at TIMESTAMP WITH TIME ZONE, -- When moderation decision was made

  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Indexes for Performance
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_creator_id ON events(creator_id);
CREATE INDEX idx_events_event_date ON events(event_date) WHERE status = 'approved';
CREATE INDEX idx_events_created_at ON events(created_at) WHERE status = 'pending';
CREATE INDEX idx_events_co_organizers ON events USING GIN (co_organizers);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_events_updated_at
  BEFORE UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_updated_at();

-- =====================================================================
-- Table: notifications
-- =====================================================================

CREATE TABLE notifications (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Recipient
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Notification Content
  channel TEXT NOT NULL CHECK (channel IN (
    'event_approved',
    'event_rejected',
    'new_pending_event',
    'added_as_coorganizer',
    'event_modified'
  )),
  title TEXT NOT NULL,
  body TEXT NOT NULL,

  -- Event Reference
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,

  -- Metadata
  sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  read BOOLEAN NOT NULL DEFAULT false,
  delivered BOOLEAN NOT NULL DEFAULT false -- FCM delivery confirmation
);

-- Indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(user_id, read) WHERE read = false;
CREATE INDEX idx_notifications_sent_at ON notifications(sent_at DESC);

-- =====================================================================
-- Row-Level Security (RLS) Policies - Events Table
-- =====================================================================

ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Policy 1: Public can read approved events
CREATE POLICY "Public can read approved events"
  ON events
  FOR SELECT
  USING (status = 'approved');

-- Policy 2: Moderators can read all events
CREATE POLICY "Moderators can read all events"
  ON events
  FOR SELECT
  USING (
    (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'moderator'
  );

-- Policy 3: Creators can read their own events (any status)
CREATE POLICY "Creators can read their own events"
  ON events
  FOR SELECT
  USING (creator_id = auth.uid());

-- Policy 4: Co-organizers can read their events
CREATE POLICY "Co-organizers can read their events"
  ON events
  FOR SELECT
  USING (auth.uid() = ANY(co_organizers));

-- Policy 5: Authenticated users can create events
CREATE POLICY "Authenticated users can create events"
  ON events
  FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated'
    AND creator_id = auth.uid()
    AND status = 'pending'
  );

-- Policy 6: Creators and co-organizers can update events (except status)
CREATE POLICY "Creators and co-organizers can update events"
  ON events
  FOR UPDATE
  USING (
    creator_id = auth.uid()
    OR auth.uid() = ANY(co_organizers)
  )
  WITH CHECK (
    (OLD.status IS NOT DISTINCT FROM NEW.status)
    OR ((SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'moderator')
  );

-- Policy 7: Only moderators can change event status
CREATE POLICY "Only moderators can change event status"
  ON events
  FOR UPDATE
  USING ((SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'moderator')
  WITH CHECK (
    (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()) = 'moderator'
    AND (OLD.status = NEW.status OR (moderated_by IS NOT NULL AND moderated_at IS NOT NULL))
  );

-- Policy 8: Creators can delete own pending/rejected events
CREATE POLICY "Creators can delete own pending/rejected events"
  ON events
  FOR DELETE
  USING (
    creator_id = auth.uid()
    AND status IN ('pending', 'rejected')
  );

-- =====================================================================
-- Row-Level Security (RLS) Policies - Notifications Table
-- =====================================================================

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can only read their own notifications
CREATE POLICY "Users can read own notifications"
  ON notifications
  FOR SELECT
  USING (user_id = auth.uid());

-- Policy 2: System can insert notifications (service role only)
CREATE POLICY "System can insert notifications"
  ON notifications
  FOR INSERT
  WITH CHECK (true);

-- Policy 3: Users can mark their notifications as read
CREATE POLICY "Users can update own notifications"
  ON notifications
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- =====================================================================
-- Database Functions for Notifications
-- =====================================================================

-- Function: Notify event approval
CREATE OR REPLACE FUNCTION notify_event_approval()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'approved' AND OLD.status = 'pending' THEN
    INSERT INTO notifications (user_id, channel, title, body, event_id)
    VALUES (
      NEW.creator_id,
      'event_approved',
      'Evento Approvato!',
      '✅ Evento "' || NEW.title || '" approvato! È ora visibile a tutti',
      NEW.id
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_event_approval
  AFTER UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION notify_event_approval();

-- Function: Notify event rejection
CREATE OR REPLACE FUNCTION notify_event_rejection()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'rejected' AND OLD.status = 'pending' THEN
    INSERT INTO notifications (user_id, channel, title, body, event_id)
    VALUES (
      NEW.creator_id,
      'event_rejected',
      'Evento Non Approvato',
      '❌ Evento "' || NEW.title || '" non approvato',
      NEW.id
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_event_rejection
  AFTER UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION notify_event_rejection();

-- Function: Notify co-organizer addition
CREATE OR REPLACE FUNCTION notify_co_organizer_addition()
RETURNS TRIGGER AS $$
DECLARE
  added_user_id UUID;
  creator_name TEXT;
BEGIN
  FOR added_user_id IN
    SELECT unnest(NEW.co_organizers)
    EXCEPT
    SELECT unnest(COALESCE(OLD.co_organizers, '{}'))
  LOOP
    SELECT raw_user_meta_data->>'full_name' INTO creator_name
    FROM auth.users WHERE id = NEW.creator_id;

    INSERT INTO notifications (user_id, channel, title, body, event_id)
    VALUES (
      added_user_id,
      'added_as_coorganizer',
      'Aggiunto come Co-Organizzatore',
      creator_name || ' ti ha aggiunto come co-organizer dell''evento "' || NEW.title || '"',
      NEW.id
    );
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_co_organizer_addition
  AFTER UPDATE ON events
  FOR EACH ROW
  WHEN (OLD.co_organizers IS DISTINCT FROM NEW.co_organizers)
  EXECUTE FUNCTION notify_co_organizer_addition();

-- Function: Notify event modification
CREATE OR REPLACE FUNCTION notify_event_modification()
RETURNS TRIGGER AS $$
DECLARE
  recipient_id UUID;
  modifier_name TEXT;
BEGIN
  -- Only notify if content changed (not just status/moderation fields)
  IF (OLD.title IS DISTINCT FROM NEW.title)
     OR (OLD.description IS DISTINCT FROM NEW.description)
     OR (OLD.event_date IS DISTINCT FROM NEW.event_date)
     OR (OLD.location IS DISTINCT FROM NEW.location)
     OR (OLD.image_url IS DISTINCT FROM NEW.image_url) THEN

    SELECT raw_user_meta_data->>'full_name' INTO modifier_name
    FROM auth.users WHERE id = auth.uid();

    -- Notify creator (if not the modifier)
    IF NEW.creator_id != auth.uid() THEN
      INSERT INTO notifications (user_id, channel, title, body, event_id)
      VALUES (
        NEW.creator_id,
        'event_modified',
        'Evento Modificato',
        modifier_name || ' ha modificato l''evento "' || NEW.title || '"',
        NEW.id
      );
    END IF;

    -- Notify all co-organizers (except the modifier)
    FOR recipient_id IN SELECT unnest(NEW.co_organizers) WHERE unnest != auth.uid()
    LOOP
      INSERT INTO notifications (user_id, channel, title, body, event_id)
      VALUES (
        recipient_id,
        'event_modified',
        'Evento Modificato',
        modifier_name || ' ha modificato l''evento "' || NEW.title || '"',
        NEW.id
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_event_modification
  AFTER UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION notify_event_modification();

-- =====================================================================
-- Grant Permissions
-- =====================================================================

-- Grant usage on tables to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON events TO authenticated;
GRANT ALL ON notifications TO authenticated;

-- =====================================================================
-- Migration Complete
-- =====================================================================
