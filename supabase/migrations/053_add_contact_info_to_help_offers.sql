-- =====================================================================
-- Migration: 053_add_contact_info_to_help_offers.sql
-- Purpose: Add mandatory contact_info field to event_help_offers
-- Date: 2025-02-07
-- =====================================================================
--
-- When someone offers to help, they MUST provide contact info
-- (Instagram or WhatsApp) so the event creator can reach them.
-- =====================================================================

-- =====================================================================
-- ADD CONTACT_INFO COLUMN
-- =====================================================================

-- Add contact_info column (nullable for now to not break existing data)
ALTER TABLE event_help_offers
ADD COLUMN IF NOT EXISTS contact_info TEXT;

-- Add contact_type column to know which platform
ALTER TABLE event_help_offers
ADD COLUMN IF NOT EXISTS contact_type TEXT CHECK (contact_type IN ('instagram', 'whatsapp'));

-- =====================================================================
-- UPDATE NOTIFICATION TRIGGER TO INCLUDE CONTACT INFO
-- =====================================================================

CREATE OR REPLACE FUNCTION notify_help_offer()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id UUID;
  v_creator_id UUID;
  v_event_title TEXT;
  v_request_description TEXT;
  v_offerer_name TEXT;
BEGIN
  -- Get event info
  SELECT e.id, e.creator_id, e.title, hr.description
  INTO v_event_id, v_creator_id, v_event_title, v_request_description
  FROM event_help_requests hr
  JOIN events e ON e.id = hr.event_id
  WHERE hr.id = NEW.request_id;

  -- Get offerer name
  SELECT full_name INTO v_offerer_name
  FROM profiles WHERE user_id = NEW.user_id;

  -- Don't notify if creator offers to their own request (edge case)
  IF v_creator_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  -- Insert notification for event creator
  INSERT INTO notifications (
    recipient_id,
    sender_id,
    type,
    title,
    description,
    target_type,
    target_id,
    metadata,
    created_at
  ) VALUES (
    v_creator_id,
    NEW.user_id,
    'help_offer',
    'Nuova offerta di aiuto!',
    COALESCE(v_offerer_name, 'Qualcuno') || ' vuole aiutarti con: ' || LEFT(v_request_description, 30),
    'event',
    v_event_id,
    jsonb_build_object(
      'event_id', v_event_id,
      'event_title', v_event_title,
      'request_id', NEW.request_id,
      'request_description', v_request_description,
      'offer_id', NEW.id,
      'offerer_id', NEW.user_id,
      'offerer_name', v_offerer_name,
      'contact_type', NEW.contact_type,
      'contact_info', NEW.contact_info,
      'message', NEW.message
    ),
    NOW()
  );

  RETURN NEW;
END;
$$;

-- Recreate trigger (drop first if exists)
DROP TRIGGER IF EXISTS trg_notify_help_offer ON event_help_offers;
CREATE TRIGGER trg_notify_help_offer
AFTER INSERT ON event_help_offers
FOR EACH ROW EXECUTE FUNCTION notify_help_offer();

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  -- Verify columns exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'event_help_offers' AND column_name = 'contact_info'
  ) THEN
    RAISE EXCEPTION 'Migration failed: contact_info column not created';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'event_help_offers' AND column_name = 'contact_type'
  ) THEN
    RAISE EXCEPTION 'Migration failed: contact_type column not created';
  END IF;

  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'Migration 053_add_contact_info_to_help_offers completed';
  RAISE NOTICE '  - Added contact_info column';
  RAISE NOTICE '  - Added contact_type column (instagram/whatsapp)';
  RAISE NOTICE '  - Updated notification trigger with contact info';
  RAISE NOTICE '=====================================================';
END $$;
