-- Migration: 038_disable_email_domain_restriction
-- Purpose: Remove school email domain restriction from auth hook
-- Date: 2026-01-20

-- Modify the auth hook to allow any email domain
CREATE OR REPLACE FUNCTION public.hook_restrict_signup_by_email_domain()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Email domain restriction disabled - allow any valid email
  RETURN jsonb_build_object();
END;
$$;

COMMENT ON FUNCTION public.hook_restrict_signup_by_email_domain IS 'Auth hook: Email domain restriction disabled';
