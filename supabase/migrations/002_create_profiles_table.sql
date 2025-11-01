-- Migration: 002_create_profiles_table
-- Feature: Profile Setup (002-profile-setup)
-- Date: 2025-11-01
-- Purpose: Create profiles table with RLS policies, indexes, triggers, and utility functions

-- ============================================================================
-- TABLE CREATION
-- ============================================================================

-- Create profiles table
CREATE TABLE profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name VARCHAR(50) NOT NULL CHECK (LENGTH(TRIM(full_name)) >= 2),
  class VARCHAR(20) NULL CHECK (class IS NULL OR class IN (
    '1A Scientifico', '1B Scientifico', '1C Scientifico', '1D Scientifico', '1F Scientifico',
    '2A Scientifico', '2B Scientifico', '2C Scientifico', '2D Scientifico', '2F Scientifico',
    '3A Scientifico', '3B Scientifico', '3C Scientifico', '3D Scientifico', '3F Scientifico',
    '4A Scientifico', '4B Scientifico', '4C Scientifico', '4D Scientifico', '4F Scientifico',
    '5A Scientifico', '5B Scientifico', '5C Scientifico', '5D Scientifico', '5F Scientifico',
    '1A Classico', '1B Classico', '2A Classico', '2B Classico', '3A Classico', '3B Classico',
    '4A Classico', '4B Classico', '5A Classico', '5B Classico'
  )),
  pronouns VARCHAR(30) NULL CHECK (pronouns IS NULL OR pronouns IN ('Lui', 'Lei', 'They', 'Altro', 'Preferisco non dire')),
  avatar_url TEXT NULL,
  bio VARCHAR(150) NULL CHECK (bio IS NULL OR LENGTH(bio) <= 150),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add table comment
COMMENT ON TABLE profiles IS 'Student user profiles for Nova school events platform';
COMMENT ON COLUMN profiles.user_id IS 'Links to auth.users, one profile per user';
COMMENT ON COLUMN profiles.full_name IS 'Student full name (auto-parsed from email or manual)';
COMMENT ON COLUMN profiles.class IS 'School class (35 values: SCIENTIFICO + CLASSICO), NULL = incomplete profile';
COMMENT ON COLUMN profiles.pronouns IS 'Optional pronouns (NULL = "Non specificato")';
COMMENT ON COLUMN profiles.avatar_url IS 'Supabase Storage signed URL (1-hour expiry)';
COMMENT ON COLUMN profiles.bio IS 'Optional bio text (max 150 chars, sanitized)';

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Index on class for filtering/search
CREATE INDEX idx_profiles_class ON profiles(class);

-- Index on updated_at for recent profiles query
CREATE INDEX idx_profiles_updated_at ON profiles(updated_at DESC);

-- Partial index for incomplete profiles (class IS NULL)
CREATE INDEX idx_profiles_incomplete ON profiles(user_id) WHERE class IS NULL;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Create function for auto-updating updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-update updated_at on profile updates
CREATE TRIGGER update_profiles_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW-LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on profiles table
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can read their own profile
CREATE POLICY "Users can read own profile"
ON profiles FOR SELECT
USING (auth.uid() = user_id);

-- Policy 2: Authenticated students can read other verified profiles
CREATE POLICY "Students can read verified profiles"
ON profiles FOR SELECT
USING (
  auth.email() LIKE '%@galileimoro.edu.it'
  AND EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = profiles.user_id
    AND auth.users.email LIKE '%@galileimoro.edu.it'
  )
);

-- Policy 3: Users can insert their own profile (one-time during setup)
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy 4: Users can update their own profile
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy 5: Users can delete their own profile (GDPR Right to Erasure)
CREATE POLICY "Users can delete own profile"
ON profiles FOR DELETE
USING (auth.uid() = user_id);

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Function: Parse name from email
-- Purpose: Auto-populate name field from email (e.g., giovanni.rossi@galileimoro.edu.it → "Giovanni Rossi")
CREATE OR REPLACE FUNCTION parse_name_from_email(email TEXT)
RETURNS TEXT AS $$
DECLARE
  local_part TEXT;
  name_parts TEXT[];
  parsed_name TEXT;
BEGIN
  -- Extract local part (before @)
  local_part := SPLIT_PART(email, '@', 1);

  -- Check if format is firstname.lastname
  IF local_part LIKE '%.%' THEN
    name_parts := STRING_TO_ARRAY(local_part, '.');
    parsed_name := INITCAP(name_parts[1]) || ' ' || INITCAP(name_parts[2]);
    RETURN parsed_name;
  ELSE
    -- Single word (like student123), return NULL for manual entry
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function: Check if profile is complete
-- Purpose: Verify user has completed profile setup (name AND class exist)
CREATE OR REPLACE FUNCTION is_profile_complete(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  profile_class VARCHAR(20);
BEGIN
  SELECT class INTO profile_class
  FROM profiles
  WHERE user_id = p_user_id;

  RETURN profile_class IS NOT NULL;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Verify migration
SELECT 'Migration 002 complete: profiles table created with ' || COUNT(*) || ' RLS policies'
FROM pg_policies WHERE tablename = 'profiles';
