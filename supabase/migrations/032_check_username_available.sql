-- Migration: 032_check_username_available
-- Purpose: Add RPC function to check if username is available (case-insensitive)
-- Feature: Username selection during onboarding

-- Create function to check username availability
CREATE OR REPLACE FUNCTION check_username_available(p_username TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if username already exists (case-insensitive)
  RETURN NOT EXISTS (
    SELECT 1 FROM profiles WHERE LOWER(username) = LOWER(p_username)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION check_username_available(TEXT) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION check_username_available(TEXT) IS
  'Checks if a username is available for registration (case-insensitive check)';
