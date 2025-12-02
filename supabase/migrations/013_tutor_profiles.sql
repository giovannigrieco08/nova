-- ============================================
-- Migration: 013_tutor_profiles
-- Feature: Sistema Ripetizioni (012-tutoring-system)
-- Date: 2025-12-01
-- ============================================

-- 1. Create tutor_profiles table
CREATE TABLE IF NOT EXISTS tutor_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  bio TEXT CHECK (char_length(bio) <= 200),
  subjects TEXT[] DEFAULT '{}' CHECK (array_length(subjects, 1) IS NULL OR array_length(subjects, 1) <= 5),
  price_per_hour DECIMAL(10, 2) DEFAULT 0 CHECK (price_per_hour >= 0),
  availability_days TEXT[] DEFAULT '{}',
  time_slot TEXT,
  whatsapp_phone TEXT,
  instagram_username TEXT,
  rating DECIMAL(3, 2) DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5),
  total_reviews INTEGER DEFAULT 0 CHECK (total_reviews >= 0),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Unique constraint: one tutor profile per user
  CONSTRAINT tutor_profiles_user_id_unique UNIQUE (user_id),

  -- At least one contact method required
  CONSTRAINT tutor_profiles_contact_required CHECK (
    whatsapp_phone IS NOT NULL OR instagram_username IS NOT NULL
  )
);

-- 2. Create indexes for performance
-- GIN index for subject filtering (subjects @> '{matematica}')
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_subjects
  ON tutor_profiles USING GIN (subjects);

-- Partial index for active tutors only
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_active
  ON tutor_profiles (user_id)
  WHERE is_active = true;

-- Index for sorting by rating (future Phase B)
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_rating
  ON tutor_profiles (rating DESC);

-- 3. Create updated_at trigger
CREATE OR REPLACE FUNCTION update_tutor_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tutor_profiles_updated_at ON tutor_profiles;
CREATE TRIGGER tutor_profiles_updated_at
  BEFORE UPDATE ON tutor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_tutor_profiles_updated_at();

-- 4. Enable Row Level Security
ALTER TABLE tutor_profiles ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies

-- Policy: Anyone can read active tutor profiles
CREATE POLICY "read_active_tutors" ON tutor_profiles
  FOR SELECT
  USING (is_active = true);

-- Policy: Users can read their own tutor profile (even if inactive)
CREATE POLICY "read_own_tutor_profile" ON tutor_profiles
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own tutor profile
CREATE POLICY "insert_own_tutor_profile" ON tutor_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own tutor profile
CREATE POLICY "update_own_tutor_profile" ON tutor_profiles
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Policy: Users can delete their own tutor profile
CREATE POLICY "delete_own_tutor_profile" ON tutor_profiles
  FOR DELETE
  USING (auth.uid() = user_id);

-- 6. Grant permissions
GRANT SELECT ON tutor_profiles TO authenticated;
GRANT INSERT, UPDATE, DELETE ON tutor_profiles TO authenticated;

-- 7. Add comment for documentation
COMMENT ON TABLE tutor_profiles IS
  'Tutor profiles for Sistema Ripetizioni (012-tutoring-system).
   One profile per user, must have at least one contact method.';
