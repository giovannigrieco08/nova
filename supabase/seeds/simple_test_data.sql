-- =====================================================================
-- SEED DATA: Simplified test data (no direct notification inserts)
-- Date: 2025-12-04
-- =====================================================================
-- Run in Supabase SQL Editor
-- =====================================================================

DO $$
DECLARE
  v_user_id UUID;
  v_event_id_1 UUID;
  v_event_id_2 UUID;
BEGIN
  -- Get first user from profiles
  SELECT user_id INTO v_user_id FROM profiles LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No users found. Please create a user first.';
  END IF;

  RAISE NOTICE 'Using user_id: %', v_user_id;

  -- =====================================================================
  -- CREATE EVENTS
  -- =====================================================================

  INSERT INTO events (id, creator_id, title, description, event_date, location, status, created_at)
  VALUES (
    gen_random_uuid(),
    v_user_id,
    'Torneo di Calcetto Interclasse',
    'Grande torneo di calcetto tra le classi! Iscriviti con la tua squadra.',
    NOW() + INTERVAL '7 days',
    'Campo sportivo della scuola',
    'approved',
    NOW() - INTERVAL '2 days'
  ) RETURNING id INTO v_event_id_1;

  INSERT INTO events (id, creator_id, title, description, event_date, location, status, created_at)
  VALUES (
    gen_random_uuid(),
    v_user_id,
    'Cineforum: Film di Natale',
    'Serata cinema con popcorn e bibite offerti!',
    NOW() + INTERVAL '14 days',
    'Aula Magna',
    'approved',
    NOW() - INTERVAL '1 day'
  ) RETURNING id INTO v_event_id_2;

  RAISE NOTICE 'Created 2 events';

  -- =====================================================================
  -- CREATE COMMENTS (if table exists)
  -- =====================================================================

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'comments') THEN
    INSERT INTO comments (event_id, author_id, content, created_at)
    VALUES (v_event_id_1, v_user_id, 'Non vedo l''ora! Sarà divertentissimo!', NOW() - INTERVAL '1 hour');

    INSERT INTO comments (event_id, author_id, content, created_at)
    VALUES (v_event_id_2, v_user_id, 'Che film vedremo?', NOW() - INTERVAL '30 minutes');

    RAISE NOTICE 'Created 2 comments';
  END IF;

  -- =====================================================================
  -- CREATE EVENT LIKES (if table exists)
  -- =====================================================================

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'event_likes') THEN
    INSERT INTO event_likes (event_id, user_id, created_at)
    VALUES (v_event_id_1, v_user_id, NOW())
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Created event like';
  END IF;

  -- =====================================================================
  -- CREATE CHAT MESSAGES (without mentions - no trigger issues)
  -- =====================================================================

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'chat_messages') THEN
    INSERT INTO chat_messages (user_id, content, mentions, created_at)
    VALUES (v_user_id, 'Ciao a tutti! Come state?', '[]'::jsonb, NOW() - INTERVAL '2 hours');

    INSERT INTO chat_messages (user_id, content, mentions, created_at)
    VALUES (v_user_id, 'Qualcuno viene al torneo?', '[]'::jsonb, NOW() - INTERVAL '1 hour');

    RAISE NOTICE 'Created 2 chat messages';
  END IF;

  -- =====================================================================
  -- NOTIFICATIONS: Skipped - will be created by app triggers
  -- =====================================================================
  -- Note: Direct notification inserts have constraint conflicts.
  -- Notifications will be created naturally when users interact with
  -- events (likes, comments, participation, etc.)

  RAISE NOTICE 'Skipping notifications (created by app triggers)';

  RAISE NOTICE '✅ Test data creation complete!';

END $$;

-- Verification
SELECT 'Events: ' || COUNT(*) FROM events;
SELECT 'Comments: ' || COUNT(*) FROM comments;
