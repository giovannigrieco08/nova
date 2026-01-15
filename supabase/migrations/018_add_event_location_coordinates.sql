-- Migration: 018_add_event_location_coordinates
-- Feature: Maps integration for event locations
-- Purpose: Store GPS coordinates to enable map navigation from event cards

-- Add coordinate columns to events table
ALTER TABLE events ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE events ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE events ADD COLUMN IF NOT EXISTS place_id TEXT; -- OpenStreetMap Place ID (optional)

-- Add comment for documentation
COMMENT ON COLUMN events.latitude IS 'GPS latitude coordinate for map integration';
COMMENT ON COLUMN events.longitude IS 'GPS longitude coordinate for map integration';
COMMENT ON COLUMN events.place_id IS 'OpenStreetMap Nominatim place_id for location lookup';

-- Create index for potential geospatial queries (optional, for future use)
CREATE INDEX IF NOT EXISTS idx_events_coordinates ON events(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
