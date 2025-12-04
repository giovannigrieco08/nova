-- =====================================================================
-- SEED DATA: Test data for Nova app testing
-- Date: 2025-12-03
-- =====================================================================
-- Run this in Supabase SQL Editor to populate test data
-- =====================================================================

-- Get the current user's ID (you must be logged in)
-- Replace this with your actual user_id if running manually
DO $$
DECLARE
  v_current_user_id UUID;
  v_test_user_id UUID;
  v_event_id_1 UUID;
  v_event_id_2 UUID;
  v_event_id_3 UUID;
  v_comment_id UUID;
BEGIN
  -- Get a user from profiles (use the first one found)
  SELECT user_id INTO v_current_user_id FROM profiles LIMIT 1;

  IF v_current_user_id IS NULL THEN
    RAISE EXCEPTION 'No users found in profiles table. Please create a user first.';
  END IF;

  RAISE NOTICE 'Using user_id: %', v_current_user_id;

  -- =====================================================================
  -- CREATE TEST EVENTS
  -- =====================================================================

  -- Event 1: Approved event (visible in feed)
  INSERT INTO events (id, creator_id, title, description, event_date, location, category, status, created_at)
  VALUES (
    gen_random_uuid(),
    v_current_user_id,
    'Torneo di Calcetto Interclasse',
    'Grande torneo di calcetto tra le classi del liceo! Iscriviti con la tua squadra e vinci fantastici premi. Portate acqua e voglia di divertirvi!',
    NOW() + INTERVAL '7 days',
    'Campo sportivo della scuola',
    'sport',
    'approved',
    NOW() - INTERVAL '2 days'
  ) RETURNING id INTO v_event_id_1;

  -- Event 2: Another approved event
  INSERT INTO events (id, creator_id, title, description, event_date, location, category, status, created_at)
  VALUES (
    gen_random_uuid(),
    v_current_user_id,
    'Cineforum: Film di Natale',
    'Serata cinema con film natalizio! Popcorn e bibite offerti. Vieni a passare una serata rilassante con i compagni prima delle vacanze.',
    NOW() + INTERVAL '14 days',
    'Aula Magna',
    'cultura',
    'approved',
    NOW() - INTERVAL '1 day'
  ) RETURNING id INTO v_event_id_2;

  -- Event 3: Pending event (in moderation queue)
  INSERT INTO events (id, creator_id, title, description, event_date, location, category, status, created_at)
  VALUES (
    gen_random_uuid(),
    v_current_user_id,
    'Sessione di Studio Collettiva',
    'Studiamo insieme per i compiti di matematica! Porterò esercizi extra e appunti. Tutti sono benvenuti.',
    NOW() + INTERVAL '3 days',
    'Biblioteca scolastica',
    'studio',
    'pending',
    NOW()
  ) RETURNING id INTO v_event_id_3;

  RAISE NOTICE 'Created 3 test events';

  -- =====================================================================
  -- CREATE TEST NOTIFICATIONS
  -- =====================================================================

  -- Notification 1: Event approved
  INSERT INTO notifications (recipient_id, sender_id, type, title, description, target_type, target_id, is_read, created_at)
  VALUES (
    v_current_user_id,
    NULL,
    'event_moderation',
    'Il tuo evento è stato approvato!',
    'Il tuo evento "Torneo di Calcetto Interclasse" è ora visibile a tutti gli studenti.',
    'event',
    v_event_id_1,
    FALSE,
    NOW() - INTERVAL '1 hour'
  );

  -- Notification 2: New comment
  INSERT INTO notifications (recipient_id, sender_id, type, title, description, target_type, target_id, is_read, created_at)
  VALUES (
    v_current_user_id,
    v_current_user_id,
    'new_comment',
    'Marco Rossi ha commentato sul tuo evento',
    'Bellissima idea! Ci sarò sicuramente con la mia squadra 🏆',
    'event',
    v_event_id_1,
    FALSE,
    NOW() - INTERVAL '30 minutes'
  );

  -- Notification 3: Event like
  INSERT INTO notifications (recipient_id, sender_id, type, title, description, target_type, target_id, is_read, created_at)
  VALUES (
    v_current_user_id,
    v_current_user_id,
    'event_like',
    'Giulia Bianchi ha messo like al tuo evento',
    '"Cineforum: Film di Natale"',
    'event',
    v_event_id_2,
    FALSE,
    NOW() - INTERVAL '15 minutes'
  );

  -- Notification 4: Event participation
  INSERT INTO notifications (recipient_id, sender_id, type, title, description, target_type, target_id, is_read, created_at)
  VALUES (
    v_current_user_id,
    v_current_user_id,
    'event_participation',
    'Luca Verdi parteciperà al tuo evento',
    '"Torneo di Calcetto Interclasse"',
    'event',
    v_event_id_1,
    TRUE,
    NOW() - INTERVAL '2 hours'
  );

  -- Notification 5: Comment reply
  INSERT INTO notifications (recipient_id, sender_id, type, title, description, target_type, target_id, is_read, created_at)
  VALUES (
    v_current_user_id,
    v_current_user_id,
    'comment_reply',
    'Sofia Neri ha risposto al tuo commento',
    'Grazie! Ci vediamo là! 😊',
    'event',
    v_event_id_2,
    FALSE,
    NOW() - INTERVAL '5 minutes'
  );

  RAISE NOTICE 'Created 5 test notifications';

  -- =====================================================================
  -- CREATE TEST TUTOR PROFILES
  -- =====================================================================

  -- Check if tutor_profiles table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tutor_profiles') THEN
    -- Tutor 1: Math tutor (current user)
    INSERT INTO tutor_profiles (user_id, bio, subjects, price_per_hour, is_active, created_at)
    VALUES (
      v_current_user_id,
      'Appassionato di matematica e fisica. Aiuto studenti di tutte le classi a migliorare i loro voti!',
      ARRAY['matematica', 'fisica'],
      15.00,
      TRUE,
      NOW() - INTERVAL '1 month'
    )
    ON CONFLICT (user_id) DO UPDATE SET
      bio = EXCLUDED.bio,
      subjects = EXCLUDED.subjects,
      price_per_hour = EXCLUDED.price_per_hour,
      is_active = EXCLUDED.is_active;

    RAISE NOTICE 'Created/updated tutor profile';
  ELSE
    RAISE NOTICE 'tutor_profiles table does not exist, skipping tutor creation';
  END IF;

  -- =====================================================================
  -- CREATE TEST CHAT MESSAGES
  -- =====================================================================

  -- Check if chat_messages table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'chat_messages') THEN
    -- Message 1
    INSERT INTO chat_messages (user_id, content, created_at)
    VALUES (
      v_current_user_id,
      'Ciao a tutti! Come state? 👋',
      NOW() - INTERVAL '2 hours'
    );

    -- Message 2
    INSERT INTO chat_messages (user_id, content, created_at)
    VALUES (
      v_current_user_id,
      'Qualcuno viene al torneo di calcetto?',
      NOW() - INTERVAL '1 hour'
    );

    -- Message 3
    INSERT INTO chat_messages (user_id, content, created_at)
    VALUES (
      v_current_user_id,
      'Io ci sarò! Chi fa squadra con me?',
      NOW() - INTERVAL '30 minutes'
    );

    RAISE NOTICE 'Created 3 test chat messages';
  ELSE
    RAISE NOTICE 'chat_messages table does not exist, skipping chat messages';
  END IF;

  -- =====================================================================
  -- CREATE TEST COMMENTS
  -- =====================================================================

  -- Check if comments table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'comments') THEN
    -- Comment 1 on Event 1
    INSERT INTO comments (id, event_id, user_id, content, created_at)
    VALUES (
      gen_random_uuid(),
      v_event_id_1,
      v_current_user_id,
      'Non vedo l''ora! Sarà divertentissimo 🎉',
      NOW() - INTERVAL '1 hour'
    ) RETURNING id INTO v_comment_id;

    -- Comment 2 (reply)
    INSERT INTO comments (event_id, user_id, content, parent_comment_id, created_at)
    VALUES (
      v_event_id_1,
      v_current_user_id,
      'Anche io! Facciamo squadra insieme?',
      v_comment_id,
      NOW() - INTERVAL '45 minutes'
    );

    -- Comment 3 on Event 2
    INSERT INTO comments (event_id, user_id, content, created_at)
    VALUES (
      v_event_id_2,
      v_current_user_id,
      'Che film vedremo?',
      NOW() - INTERVAL '30 minutes'
    );

    RAISE NOTICE 'Created 3 test comments';
  ELSE
    RAISE NOTICE 'comments table does not exist, skipping comments';
  END IF;

  -- =====================================================================
  -- CREATE TEST EVENT LIKES
  -- =====================================================================

  -- Check if event_likes table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'event_likes') THEN
    INSERT INTO event_likes (event_id, user_id, created_at)
    VALUES (v_event_id_1, v_current_user_id, NOW() - INTERVAL '1 hour')
    ON CONFLICT DO NOTHING;

    INSERT INTO event_likes (event_id, user_id, created_at)
    VALUES (v_event_id_2, v_current_user_id, NOW() - INTERVAL '30 minutes')
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Created test event likes';
  ELSE
    RAISE NOTICE 'event_likes table does not exist, skipping likes';
  END IF;

  -- =====================================================================
  -- CREATE TEST EVENT PARTICIPANTS
  -- =====================================================================

  -- Check if event_participants table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'event_participants') THEN
    INSERT INTO event_participants (event_id, user_id, created_at)
    VALUES (v_event_id_1, v_current_user_id, NOW() - INTERVAL '1 hour')
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Created test event participation';
  ELSE
    RAISE NOTICE 'event_participants table does not exist, skipping participation';
  END IF;

  RAISE NOTICE '✅ Test data creation complete!';

END $$;

-- =====================================================================
-- VERIFICATION QUERIES
-- =====================================================================

SELECT 'Events' as table_name, COUNT(*) as count FROM events;
SELECT 'Notifications' as table_name, COUNT(*) as count FROM notifications;
SELECT 'Profiles' as table_name, COUNT(*) as count FROM profiles;
