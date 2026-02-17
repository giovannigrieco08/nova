-- =====================================================================
-- Migration: 057_appstore_demo_account.sql
-- Purpose: Create demo account for Apple App Store review
-- Date: 2025-02-12
-- =====================================================================
--
-- This creates a demo account with full app access for Apple reviewers.
-- Email: appstore.demo@galileimoro.edu.it
-- Password: AppStoreDemo2025!
--
-- =====================================================================

DO $$
DECLARE
  demo_user_id UUID := '00000000-0000-0000-0000-000000000001';
  demo_email TEXT := 'appstore.demo@galileimoro.edu.it';
  demo_password TEXT := 'AppStoreDemo2025!';

  -- Demo events
  demo_event_1 UUID := '00000001-0001-0001-0001-000000000001';
  demo_event_2 UUID := '00000001-0001-0001-0001-000000000002';
  demo_event_3 UUID := '00000001-0001-0001-0001-000000000003';
BEGIN
  -- =====================================================================
  -- STEP 1: Create demo user in auth.users
  -- =====================================================================

  INSERT INTO auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    raw_app_meta_data,
    raw_user_meta_data,
    is_super_admin,
    role,
    aud,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  )
  VALUES (
    demo_user_id,
    '00000000-0000-0000-0000-000000000000',
    demo_email,
    crypt(demo_password, gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    '{"full_name": "Demo AppStore"}'::jsonb,
    false,
    'authenticated',
    'authenticated',
    '',
    '',
    '',
    ''
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    encrypted_password = EXCLUDED.encrypted_password,
    email_confirmed_at = NOW(),
    updated_at = NOW();

  -- Also add identity for the user
  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  )
  VALUES (
    demo_user_id,
    demo_user_id,
    jsonb_build_object('sub', demo_user_id::text, 'email', demo_email),
    'email',
    demo_user_id::text,
    NOW(),
    NOW(),
    NOW()
  )
  ON CONFLICT (provider, provider_id) DO UPDATE SET
    identity_data = EXCLUDED.identity_data,
    updated_at = NOW();

  -- =====================================================================
  -- STEP 2: Create demo profile
  -- =====================================================================

  INSERT INTO profiles (
    user_id,
    full_name,
    username,
    class,
    pronouns,
    bio,
    profile_visible,
    created_at,
    updated_at
  )
  VALUES (
    demo_user_id,
    'Demo AppStore',
    'demo.appstore',
    '5A Scientifico',
    'Preferisco non dire',
    'Account demo per la revisione App Store. Questo account ha accesso completo a tutte le funzionalita dell''app.',
    true,
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    username = EXCLUDED.username,
    class = EXCLUDED.class,
    pronouns = EXCLUDED.pronouns,
    bio = EXCLUDED.bio,
    profile_visible = EXCLUDED.profile_visible,
    updated_at = NOW();

  -- =====================================================================
  -- STEP 3: Create demo events (owned by demo user)
  -- =====================================================================

  INSERT INTO events (
    id,
    title,
    description,
    event_date,
    location,
    image_url,
    creator_id,
    status,
    co_organizers,
    created_at,
    updated_at
  )
  VALUES
    -- Demo Event 1: Study Group (event_date is TIMESTAMPTZ, includes time)
    (
      demo_event_1,
      'Gruppo Studio Matematica',
      'Sessione di studio di gruppo per prepararsi al compito di matematica. Portatevi libri e appunti!',
      (NOW() + INTERVAL '7 days')::date + TIME '15:00:00',
      'Biblioteca - Liceo Galilei Moro',
      'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=800',
      demo_user_id,
      'approved',
      '{}'::UUID[],
      NOW() - INTERVAL '2 days',
      NOW()
    ),
    -- Demo Event 2: Sport Activity
    (
      demo_event_2,
      'Partita di Pallavolo Inter-Classe',
      'Torneo amichevole di pallavolo tra le classi. Tutti sono benvenuti, dai principianti ai giocatori esperti!',
      (NOW() + INTERVAL '14 days')::date + TIME '14:00:00',
      'Palestra - Liceo Galilei Moro',
      'https://images.unsplash.com/photo-1547347298-4074fc3086f0?w=800',
      demo_user_id,
      'approved',
      '{}'::UUID[],
      NOW() - INTERVAL '1 day',
      NOW()
    ),
    -- Demo Event 3: Pending (to show moderation)
    (
      demo_event_3,
      'Cineforum: Film d''Autore',
      'Proiezione di un film d''autore con discussione finale. Il film verra comunicato una settimana prima.',
      (NOW() + INTERVAL '21 days')::date + TIME '16:30:00',
      'Aula Magna - Liceo Galilei Moro',
      'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800',
      demo_user_id,
      'pending',
      '{}'::UUID[],
      NOW(),
      NOW()
    )
  ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    event_date = EXCLUDED.event_date,
    location = EXCLUDED.location,
    status = EXCLUDED.status,
    updated_at = NOW();

  -- =====================================================================
  -- STEP 4: Add interactions (likes, participations)
  -- =====================================================================

  -- Demo user likes their own events (for UI visibility)
  INSERT INTO likes (user_id, event_id, created_at)
  VALUES
    (demo_user_id, demo_event_1, NOW() - INTERVAL '1 day'),
    (demo_user_id, demo_event_2, NOW())
  ON CONFLICT (user_id, event_id) DO NOTHING;

  -- Demo user participates in their events
  INSERT INTO participations (user_id, event_id, created_at)
  VALUES
    (demo_user_id, demo_event_1, NOW() - INTERVAL '1 day'),
    (demo_user_id, demo_event_2, NOW())
  ON CONFLICT (user_id, event_id) DO NOTHING;

  -- =====================================================================
  -- STEP 5: Add sample comments
  -- =====================================================================

  INSERT INTO comments (id, event_id, author_id, content, created_at)
  VALUES
    (gen_random_uuid(), demo_event_1, demo_user_id, 'Chi viene? Scrivetemi nei commenti!', NOW() - INTERVAL '1 day'),
    (gen_random_uuid(), demo_event_2, demo_user_id, 'Cercasi giocatori per completare le squadre!', NOW())
  ON CONFLICT DO NOTHING;

  RAISE NOTICE '=====================================================';
  RAISE NOTICE 'Demo account created successfully!';
  RAISE NOTICE '';
  RAISE NOTICE 'LOGIN CREDENTIALS:';
  RAISE NOTICE '  Email: appstore.demo@galileimoro.edu.it';
  RAISE NOTICE '  Password: AppStoreDemo2025!';
  RAISE NOTICE '';
  RAISE NOTICE 'This account has:';
  RAISE NOTICE '  - Complete profile (class, bio, etc.)';
  RAISE NOTICE '  - 2 approved events';
  RAISE NOTICE '  - 1 pending event (for moderation demo)';
  RAISE NOTICE '  - Likes and participations';
  RAISE NOTICE '  - Sample comments';
  RAISE NOTICE '=====================================================';
END $$;

-- =====================================================================
-- VERIFICATION
-- =====================================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE user_id = '00000000-0000-0000-0000-000000000001'
    AND class IS NOT NULL
    AND bio IS NOT NULL
  ) THEN
    RAISE NOTICE 'Verification PASSED: Demo profile exists with required fields';
  ELSE
    RAISE EXCEPTION 'Verification FAILED: Demo profile missing or incomplete';
  END IF;
END $$;
