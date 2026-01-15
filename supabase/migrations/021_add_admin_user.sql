-- Migration: Add Admin User
-- Created: 2024-12-05
-- Description: Add griecogiovanni08@gmail.com as admin and create email whitelist for domain bypass

BEGIN;

-- =============================================================================
-- EMAIL WHITELIST TABLE (for domain bypass)
-- =============================================================================

-- Create email whitelist table for users who can bypass school domain restriction
CREATE TABLE IF NOT EXISTS email_whitelist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

COMMENT ON TABLE email_whitelist IS 'Emails that can bypass the school domain (@galileimoro.edu.it) restriction';
COMMENT ON COLUMN email_whitelist.email IS 'Email address allowed to bypass domain restriction';
COMMENT ON COLUMN email_whitelist.reason IS 'Reason for whitelist (e.g., "Project founder", "External advisor")';

ALTER TABLE email_whitelist ENABLE ROW LEVEL SECURITY;

-- Only admins can view/manage whitelist
CREATE POLICY "Admins can manage email whitelist"
ON email_whitelist FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

-- =============================================================================
-- ADD ADMIN USER
-- =============================================================================

-- Add griecogiovanni08@gmail.com to whitelist
INSERT INTO email_whitelist (email, reason)
VALUES ('griecogiovanni08@gmail.com', 'Project founder and main administrator')
ON CONFLICT (email) DO NOTHING;

-- Add admin role for griecogiovanni08@gmail.com
-- This uses a DO block to handle the case where user might not exist yet
DO $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Try to find the user by email
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = 'griecogiovanni08@gmail.com';

  IF v_user_id IS NOT NULL THEN
    -- User exists, add admin role
    INSERT INTO user_roles (user_id, role)
    VALUES (v_user_id, 'admin')
    ON CONFLICT (user_id, role) DO NOTHING;

    RAISE NOTICE 'Admin role added for griecogiovanni08@gmail.com (user_id: %)', v_user_id;
  ELSE
    RAISE NOTICE 'User griecogiovanni08@gmail.com not found in auth.users. Admin role will be added when user signs up.';
  END IF;
END $$;

-- =============================================================================
-- AUTO-ASSIGN ADMIN ON SIGNUP (for whitelisted emails)
-- =============================================================================

-- Function to auto-assign admin role when whitelisted user signs up
CREATE OR REPLACE FUNCTION auto_assign_admin_role()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if user's email is in the whitelist
  IF EXISTS (
    SELECT 1 FROM email_whitelist WHERE email = NEW.email
  ) THEN
    -- Auto-assign admin role
    INSERT INTO user_roles (user_id, role)
    VALUES (NEW.id, 'admin')
    ON CONFLICT (user_id, role) DO NOTHING;

    RAISE NOTICE 'Auto-assigned admin role to whitelisted user: %', NEW.email;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to run when new user is created
DROP TRIGGER IF EXISTS trigger_auto_assign_admin ON auth.users;
CREATE TRIGGER trigger_auto_assign_admin
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION auto_assign_admin_role();

COMMENT ON FUNCTION auto_assign_admin_role IS 'Auto-assigns admin role to users with whitelisted emails when they sign up';

-- =============================================================================
-- VERIFICATION
-- =============================================================================

DO $$
BEGIN
  -- Verify whitelist table exists
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'email_whitelist') THEN
    RAISE EXCEPTION 'email_whitelist table was not created';
  END IF;

  -- Verify email is in whitelist
  IF NOT EXISTS (SELECT 1 FROM email_whitelist WHERE email = 'griecogiovanni08@gmail.com') THEN
    RAISE EXCEPTION 'Admin email not added to whitelist';
  END IF;

  RAISE NOTICE 'Migration completed successfully!';
  RAISE NOTICE 'Created: email_whitelist table';
  RAISE NOTICE 'Added: griecogiovanni08@gmail.com to whitelist and user_roles (if user exists)';
  RAISE NOTICE 'Created: auto_assign_admin_role trigger for future signups';
END $$;

COMMIT;
