-- =====================================================================
-- Seed: banned_words.sql
-- Purpose: Initial Italian profanity word list for content filtering
-- Date: 2025-02-12
-- Feature: 015-ugc-safety
-- =====================================================================
--
-- NOTE: This seed requires an admin user to exist.
-- Run after migration 057_ugc_safety_system.sql
-- =====================================================================

-- Get first admin user for created_by field
DO $$
DECLARE
  admin_id UUID;
BEGIN
  SELECT user_id INTO admin_id
  FROM user_roles
  WHERE role = 'admin'
  LIMIT 1;

  -- If no admin, use first moderator
  IF admin_id IS NULL THEN
    SELECT user_id INTO admin_id
    FROM user_roles
    WHERE role = 'moderator'
    LIMIT 1;
  END IF;

  -- If still no user, skip seeding
  IF admin_id IS NULL THEN
    RAISE NOTICE 'No admin/moderator found. Skipping banned_words seed.';
    RETURN;
  END IF;

  -- Insert Italian profanity words
  -- These are common offensive words that should be blocked in a school environment
  INSERT INTO banned_words (word, pattern_type, severity, language, created_by)
  VALUES
    -- Strong profanity (block)
    ('cazzo', 'exact', 'block', 'it', admin_id),
    ('cazzi', 'exact', 'block', 'it', admin_id),
    ('minchia', 'exact', 'block', 'it', admin_id),
    ('merda', 'exact', 'block', 'it', admin_id),
    ('stronzo', 'exact', 'block', 'it', admin_id),
    ('stronza', 'exact', 'block', 'it', admin_id),
    ('stronzi', 'exact', 'block', 'it', admin_id),
    ('vaffanculo', 'contains', 'block', 'it', admin_id),
    ('fanculo', 'contains', 'block', 'it', admin_id),
    ('coglione', 'exact', 'block', 'it', admin_id),
    ('coglioni', 'exact', 'block', 'it', admin_id),
    ('puttana', 'exact', 'block', 'it', admin_id),
    ('puttane', 'exact', 'block', 'it', admin_id),
    ('troia', 'exact', 'block', 'it', admin_id),
    ('troie', 'exact', 'block', 'it', admin_id),
    ('bastardo', 'exact', 'block', 'it', admin_id),
    ('bastarda', 'exact', 'block', 'it', admin_id),
    ('figa', 'exact', 'block', 'it', admin_id),
    ('fica', 'exact', 'block', 'it', admin_id),
    ('porco', 'exact', 'block', 'it', admin_id),
    ('porca', 'exact', 'block', 'it', admin_id),
    ('cretino', 'exact', 'block', 'it', admin_id),
    ('cretina', 'exact', 'block', 'it', admin_id),
    ('idiota', 'exact', 'block', 'it', admin_id),
    ('deficiente', 'exact', 'block', 'it', admin_id),
    ('imbecille', 'exact', 'block', 'it', admin_id),
    ('ritardato', 'exact', 'block', 'it', admin_id),
    ('ritardata', 'exact', 'block', 'it', admin_id),
    ('handicappato', 'exact', 'block', 'it', admin_id),

    -- Discriminatory terms (block)
    ('negro', 'exact', 'block', 'it', admin_id),
    ('negra', 'exact', 'block', 'it', admin_id),
    ('negri', 'exact', 'block', 'it', admin_id),
    ('frocio', 'exact', 'block', 'it', admin_id),
    ('froci', 'exact', 'block', 'it', admin_id),
    ('finocchio', 'exact', 'block', 'it', admin_id),
    ('ricchione', 'exact', 'block', 'it', admin_id),
    ('terrone', 'exact', 'block', 'it', admin_id),
    ('terroni', 'exact', 'block', 'it', admin_id),
    ('polentone', 'exact', 'block', 'it', admin_id),
    ('zingaro', 'exact', 'block', 'it', admin_id),
    ('zingara', 'exact', 'block', 'it', admin_id),
    ('zingari', 'exact', 'block', 'it', admin_id),
    ('extracomunitario', 'exact', 'block', 'it', admin_id),

    -- Sexual content (block)
    ('scopare', 'exact', 'block', 'it', admin_id),
    ('scopata', 'exact', 'block', 'it', admin_id),
    ('scopami', 'exact', 'block', 'it', admin_id),
    ('pompino', 'exact', 'block', 'it', admin_id),
    ('pompini', 'exact', 'block', 'it', admin_id),
    ('sega', 'exact', 'block', 'it', admin_id),
    ('seghe', 'exact', 'block', 'it', admin_id),
    ('incesto', 'exact', 'block', 'it', admin_id),
    ('pedofilo', 'exact', 'block', 'it', admin_id),
    ('pedofilia', 'exact', 'block', 'it', admin_id),
    ('stupro', 'exact', 'block', 'it', admin_id),
    ('stuprare', 'exact', 'block', 'it', admin_id),

    -- Threats and violence (block)
    ('ammazzare', 'exact', 'block', 'it', admin_id),
    ('ammazzarti', 'exact', 'block', 'it', admin_id),
    ('uccidere', 'exact', 'block', 'it', admin_id),
    ('ucciderti', 'exact', 'block', 'it', admin_id),
    ('suicidio', 'exact', 'block', 'it', admin_id),
    ('suicidarti', 'exact', 'block', 'it', admin_id),
    ('suicidati', 'exact', 'block', 'it', admin_id),
    ('muori', 'exact', 'block', 'it', admin_id),
    ('crepa', 'exact', 'block', 'it', admin_id),

    -- Bullying terms (block)
    ('ciccione', 'exact', 'block', 'it', admin_id),
    ('cicciona', 'exact', 'block', 'it', admin_id),
    ('grasso', 'exact', 'warning', 'it', admin_id),
    ('brutto', 'exact', 'warning', 'it', admin_id),
    ('schifo', 'exact', 'warning', 'it', admin_id),
    ('fallito', 'exact', 'warning', 'it', admin_id),
    ('fallita', 'exact', 'warning', 'it', admin_id),
    ('sfigato', 'exact', 'warning', 'it', admin_id),
    ('sfigata', 'exact', 'warning', 'it', admin_id),
    ('nerd', 'exact', 'warning', 'it', admin_id),
    ('secchione', 'exact', 'warning', 'it', admin_id),
    ('secchiona', 'exact', 'warning', 'it', admin_id),

    -- Mild profanity (warning only)
    ('cacca', 'exact', 'warning', 'it', admin_id),
    ('pipì', 'exact', 'warning', 'it', admin_id),
    ('culo', 'exact', 'warning', 'it', admin_id),
    ('cavolo', 'exact', 'warning', 'it', admin_id),
    ('accidenti', 'exact', 'warning', 'it', admin_id),
    ('dannazione', 'exact', 'warning', 'it', admin_id)

  ON CONFLICT (word, language) WHERE deleted_at IS NULL DO NOTHING;

  RAISE NOTICE 'Banned words seeded successfully';
END $$;
