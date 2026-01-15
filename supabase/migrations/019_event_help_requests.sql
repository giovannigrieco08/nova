-- Migration: 019_event_help_requests.sql
-- Feature: Event Help Requests (Bacheche integration into Events)
-- Purpose: Allow event creators to request help from other students

-- =====================================================================
-- TABLE: event_help_requests
-- Stores help requests created by event organizers
-- =====================================================================
CREATE TABLE IF NOT EXISTS event_help_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  is_fulfilled BOOLEAN DEFAULT FALSE,
  fulfilled_by UUID REFERENCES profiles(user_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for efficient event lookup
CREATE INDEX IF NOT EXISTS idx_event_help_requests_event_id ON event_help_requests(event_id);

-- Index for unfulfilled requests (for feed display)
CREATE INDEX IF NOT EXISTS idx_event_help_requests_unfulfilled ON event_help_requests(event_id) WHERE is_fulfilled = FALSE;

-- =====================================================================
-- TABLE: event_help_offers
-- Stores offers from students to help with requests
-- =====================================================================
CREATE TABLE IF NOT EXISTS event_help_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES event_help_requests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  message TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- Prevent duplicate offers from same user for same request
  UNIQUE(request_id, user_id)
);

-- Index for request lookup
CREATE INDEX IF NOT EXISTS idx_event_help_offers_request_id ON event_help_offers(request_id);

-- Index for user's offers
CREATE INDEX IF NOT EXISTS idx_event_help_offers_user_id ON event_help_offers(user_id);

-- =====================================================================
-- ROW LEVEL SECURITY POLICIES
-- =====================================================================

-- Enable RLS
ALTER TABLE event_help_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_help_offers ENABLE ROW LEVEL SECURITY;

-- event_help_requests policies (drop if exists for idempotency)
DROP POLICY IF EXISTS "Anyone can view help requests for approved events" ON event_help_requests;
CREATE POLICY "Anyone can view help requests for approved events"
ON event_help_requests FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = event_help_requests.event_id
    AND events.status = 'approved'
  )
);

DROP POLICY IF EXISTS "Event creators can insert help requests" ON event_help_requests;
CREATE POLICY "Event creators can insert help requests"
ON event_help_requests FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = event_help_requests.event_id
    AND events.creator_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Event creators can update help requests" ON event_help_requests;
CREATE POLICY "Event creators can update help requests"
ON event_help_requests FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = event_help_requests.event_id
    AND events.creator_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Event creators can delete help requests" ON event_help_requests;
CREATE POLICY "Event creators can delete help requests"
ON event_help_requests FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = event_help_requests.event_id
    AND events.creator_id = auth.uid()
  )
);

-- event_help_offers policies (drop if exists for idempotency)
DROP POLICY IF EXISTS "Event creators can view offers for their requests" ON event_help_offers;
CREATE POLICY "Event creators can view offers for their requests"
ON event_help_offers FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM event_help_requests hr
    JOIN events e ON e.id = hr.event_id
    WHERE hr.id = event_help_offers.request_id
    AND e.creator_id = auth.uid()
  )
  OR user_id = auth.uid() -- Users can see their own offers
);

DROP POLICY IF EXISTS "Authenticated users can make offers" ON event_help_offers;
CREATE POLICY "Authenticated users can make offers"
ON event_help_offers FOR INSERT
WITH CHECK (
  auth.uid() = user_id
  AND EXISTS (
    SELECT 1 FROM event_help_requests hr
    JOIN events e ON e.id = hr.event_id
    WHERE hr.id = event_help_offers.request_id
    AND e.status = 'approved'
    AND hr.is_fulfilled = FALSE
  )
);

DROP POLICY IF EXISTS "Users can update their own offers" ON event_help_offers;
CREATE POLICY "Users can update their own offers"
ON event_help_offers FOR UPDATE
USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Event creators can update offer status" ON event_help_offers;
CREATE POLICY "Event creators can update offer status"
ON event_help_offers FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM event_help_requests hr
    JOIN events e ON e.id = hr.event_id
    WHERE hr.id = event_help_offers.request_id
    AND e.creator_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Users can delete their own offers" ON event_help_offers;
CREATE POLICY "Users can delete their own offers"
ON event_help_offers FOR DELETE
USING (user_id = auth.uid());

-- =====================================================================
-- TRIGGERS FOR UPDATED_AT
-- =====================================================================

-- Trigger for event_help_requests
CREATE OR REPLACE FUNCTION update_event_help_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_event_help_requests_updated_at ON event_help_requests;
CREATE TRIGGER trg_event_help_requests_updated_at
BEFORE UPDATE ON event_help_requests
FOR EACH ROW EXECUTE FUNCTION update_event_help_requests_updated_at();

-- Trigger for event_help_offers
CREATE OR REPLACE FUNCTION update_event_help_offers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_event_help_offers_updated_at ON event_help_offers;
CREATE TRIGGER trg_event_help_offers_updated_at
BEFORE UPDATE ON event_help_offers
FOR EACH ROW EXECUTE FUNCTION update_event_help_offers_updated_at();

-- =====================================================================
-- NOTIFICATION TRIGGER FOR NEW OFFERS
-- =====================================================================

-- Notify event creator when someone offers to help
CREATE OR REPLACE FUNCTION notify_help_offer()
RETURNS TRIGGER AS $$
DECLARE
  v_event_id UUID;
  v_creator_id UUID;
  v_event_title TEXT;
  v_request_description TEXT;
BEGIN
  -- Get event info
  SELECT e.id, e.creator_id, e.title, hr.description
  INTO v_event_id, v_creator_id, v_event_title, v_request_description
  FROM event_help_requests hr
  JOIN events e ON e.id = hr.event_id
  WHERE hr.id = NEW.request_id;

  -- Don't notify if creator offers to their own request (edge case)
  IF v_creator_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  -- Insert notification for event creator
  INSERT INTO notifications (
    user_id,
    type,
    title,
    body,
    data,
    created_at
  ) VALUES (
    v_creator_id,
    'help_offer',
    'Nuova offerta di aiuto',
    'Qualcuno si è offerto per: ' || LEFT(v_request_description, 50),
    jsonb_build_object(
      'event_id', v_event_id,
      'request_id', NEW.request_id,
      'offer_id', NEW.id,
      'offerer_id', NEW.user_id
    ),
    NOW()
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_help_offer ON event_help_offers;
CREATE TRIGGER trg_notify_help_offer
AFTER INSERT ON event_help_offers
FOR EACH ROW EXECUTE FUNCTION notify_help_offer();

-- =====================================================================
-- REALTIME SUBSCRIPTIONS
-- =====================================================================

-- Enable realtime for help requests (for live updates)
-- Use DO blocks to check if tables are already in publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'event_help_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE event_help_requests;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'event_help_offers'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE event_help_offers;
  END IF;
END $$;

-- =====================================================================
-- COMMENTS
-- =====================================================================
COMMENT ON TABLE event_help_requests IS 'Help requests created by event organizers (e.g., "Looking for photographer")';
COMMENT ON TABLE event_help_offers IS 'Offers from students to help with event requests';
COMMENT ON COLUMN event_help_requests.description IS 'Free-text description of help needed (no categories)';
COMMENT ON COLUMN event_help_requests.is_fulfilled IS 'True when someone''s offer has been accepted';
COMMENT ON COLUMN event_help_requests.fulfilled_by IS 'User who fulfilled the request (accepted offer)';
COMMENT ON COLUMN event_help_offers.status IS 'pending (waiting), accepted (by creator), declined (by creator)';
