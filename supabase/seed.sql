-- =====================================================================
-- Seed File: Test Data for Nova Platform
-- Purpose: Create test profiles, events, tutors, and chat messages
-- Date: 2025-12-03
-- =====================================================================
--
-- IMPORTANT: Run this AFTER all migrations have been applied.
-- This file creates test data to verify system functionality.
--
-- Test Users (6 total):
-- 1. Marco Rossi (3A Scientifico) - Student, Event Creator, Tutor
-- 2. Giulia Bianchi (4B Scientifico) - Student, Moderator
-- 3. Luca Verdi (5A Classico) - Student, Tutor
-- 4. Sofia Ferrari (2C Scientifico) - Student
-- 5. Alessandro Conte (3B Classico) - Student, Event Creator
-- 6. Emma Romano (4A Scientifico) - Student
--
-- =====================================================================

-- Define test UUIDs (these will be used consistently across all tables)
DO $$
DECLARE
  -- Test user UUIDs
  user_marco UUID := '11111111-1111-1111-1111-111111111111';
  user_giulia UUID := '22222222-2222-2222-2222-222222222222';
  user_luca UUID := '33333333-3333-3333-3333-333333333333';
  user_sofia UUID := '44444444-4444-4444-4444-444444444444';
  user_alessandro UUID := '55555555-5555-5555-5555-555555555555';
  user_emma UUID := '66666666-6666-6666-6666-666666666666';

  -- Event UUIDs
  event_festa UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  event_torneo UUID := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  event_teatro UUID := 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  event_coding UUID := 'dddddddd-dddd-dddd-dddd-dddddddddddd';
  event_musica UUID := 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
  event_pending UUID := 'ffffffff-ffff-ffff-ffff-ffffffffffff';

  -- Chat message UUIDs
  msg_1 UUID := 'aaaa1111-1111-1111-1111-111111111111';
  msg_2 UUID := 'aaaa2222-2222-2222-2222-222222222222';
  msg_3 UUID := 'aaaa3333-3333-3333-3333-333333333333';
  msg_4 UUID := 'aaaa4444-4444-4444-4444-444444444444';
  msg_5 UUID := 'aaaa5555-5555-5555-5555-555555555555';
  msg_6 UUID := 'aaaa6666-6666-6666-6666-666666666666';
  msg_7 UUID := 'aaaa7777-7777-7777-7777-777777777777';
  msg_8 UUID := 'aaaa8888-8888-8888-8888-888888888888';
BEGIN
  -- =====================================================================
  -- STEP 1: Create test users in auth.users
  -- =====================================================================
  -- Note: In production Supabase, users are created via Auth.
  -- For testing, we insert directly into auth.users

  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_user_meta_data)
  VALUES
    (user_marco, 'marco.rossi@galileimoro.edu.it', crypt('Test123!', gen_salt('bf')), NOW(), NOW(), NOW(), '{"full_name": "Marco Rossi"}'::jsonb),
    (user_giulia, 'giulia.bianchi@galileimoro.edu.it', crypt('Test123!', gen_salt('bf')), NOW(), NOW(), NOW(), '{"full_name": "Giulia Bianchi"}'::jsonb),
    (user_luca, 'luca.verdi@galileimoro.edu.it', crypt('Test123!', gen_salt('bf')), NOW(), NOW(), NOW(), '{"full_name": "Luca Verdi"}'::jsonb),
    (user_sofia, 'sofia.ferrari@galileimoro.edu.it', crypt('Test123!', gen_salt('bf')), NOW(), NOW(), NOW(), '{"full_name": "Sofia Ferrari"}'::jsonb),
    (user_alessandro, 'alessandro.conte@galileimoro.edu.it', crypt('Test123!', gen_salt('bf')), NOW(), NOW(), NOW(), '{"full_name": "Alessandro Conte"}'::jsonb),
    (user_emma, 'emma.romano@galileimoro.edu.it', crypt('Test123!', gen_salt('bf')), NOW(), NOW(), NOW(), '{"full_name": "Emma Romano"}'::jsonb)
  ON CONFLICT (id) DO NOTHING;

  -- =====================================================================
  -- STEP 2: Create profiles
  -- =====================================================================

  INSERT INTO profiles (user_id, full_name, class, pronouns, bio, created_at, updated_at)
  VALUES
    (user_marco, 'Marco Rossi', '3A Scientifico', 'Lui', 'Appassionato di matematica e fisica. Organizzo eventi di studio e aiuto i compagni!', NOW(), NOW()),
    (user_giulia, 'Giulia Bianchi', '4B Scientifico', 'Lei', 'Rappresentante di classe. Amo la letteratura e il teatro.', NOW(), NOW()),
    (user_luca, 'Luca Verdi', '5A Classico', 'Lui', 'Ultimo anno! Esperto di latino e greco, offro ripetizioni.', NOW(), NOW()),
    (user_sofia, 'Sofia Ferrari', '2C Scientifico', 'Lei', 'Mi piace la musica e lo sport. Sempre pronta per nuove avventure!', NOW(), NOW()),
    (user_alessandro, 'Alessandro Conte', '3B Classico', 'Lui', 'Programmatore e gamer. Organizzo tornei di gaming!', NOW(), NOW()),
    (user_emma, 'Emma Romano', '4A Scientifico', 'Lei', 'Fotografa amatoriale. Cerco sempre nuovi eventi da documentare.', NOW(), NOW())
  ON CONFLICT (user_id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    class = EXCLUDED.class,
    pronouns = EXCLUDED.pronouns,
    bio = EXCLUDED.bio,
    updated_at = NOW();

  -- =====================================================================
  -- STEP 3: Create user roles (moderators/admins)
  -- =====================================================================

  -- Giulia is a moderator
  INSERT INTO user_roles (user_id, role, granted_at, granted_by)
  VALUES
    (user_marco, 'student', NOW(), NULL),
    (user_giulia, 'student', NOW(), NULL),
    (user_giulia, 'moderator', NOW(), NULL),  -- Giulia is also a moderator
    (user_luca, 'student', NOW(), NULL),
    (user_sofia, 'student', NOW(), NULL),
    (user_alessandro, 'student', NOW(), NULL),
    (user_emma, 'student', NOW(), NULL)
  ON CONFLICT (user_id, role) DO NOTHING;

  -- =====================================================================
  -- STEP 4: Create test events (5 approved, 1 pending)
  -- =====================================================================

  INSERT INTO events (id, title, description, event_date, location, image_url, creator_id, status, co_organizers, moderated_by, moderated_at, created_at, updated_at)
  VALUES
    -- Event 1: Festa di Fine Anno (Marco) - APPROVED
    (
      event_festa,
      'Festa di Fine Anno 2025',
      'Grande festa per celebrare la fine dell''anno scolastico! DJ set, buffet e tanti giochi. Portate buon umore e voglia di divertirvi. L''evento si terrà nel cortile della scuola.',
      NOW() + INTERVAL '30 days',
      'Cortile principale - Liceo Galilei Moro',
      'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?w=800',
      user_marco,
      'approved',
      ARRAY[user_emma]::UUID[],
      user_giulia,
      NOW(),
      NOW() - INTERVAL '5 days',
      NOW()
    ),

    -- Event 2: Torneo di Scacchi (Alessandro) - APPROVED
    (
      event_torneo,
      'Torneo di Scacchi Inter-Classe',
      'Il primo torneo di scacchi tra le classi del liceo! Formazione squadre da 4 persone. Premi per i primi 3 classificati. Iscrivetevi nei commenti!',
      NOW() + INTERVAL '14 days',
      'Aula Magna',
      'https://images.unsplash.com/photo-1529699211952-734e80c4d42b?w=800',
      user_alessandro,
      'approved',
      '{}'::UUID[],
      user_giulia,
      NOW(),
      NOW() - INTERVAL '3 days',
      NOW()
    ),

    -- Event 3: Spettacolo Teatrale (Giulia) - APPROVED
    (
      event_teatro,
      'Spettacolo Teatrale: Romeo e Giulietta',
      'Il gruppo teatrale della scuola presenta Romeo e Giulietta di Shakespeare. Regia di Prof.ssa Martini. Ingresso libero ma posti limitati!',
      NOW() + INTERVAL '21 days',
      'Teatro Comunale',
      'https://images.unsplash.com/photo-1503095396549-807759245b35?w=800',
      user_giulia,
      'approved',
      ARRAY[user_luca]::UUID[],
      user_giulia, -- Self-approved as moderator
      NOW(),
      NOW() - INTERVAL '7 days',
      NOW()
    ),

    -- Event 4: Workshop Coding (Alessandro) - APPROVED
    (
      event_coding,
      'Workshop: Impara a Programmare',
      'Workshop introduttivo alla programmazione con Python. Perfetto per principianti! Portatevi il vostro laptop. Vedremo le basi e creeremo un piccolo gioco insieme.',
      NOW() + INTERVAL '7 days',
      'Laboratorio Informatica',
      'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?w=800',
      user_alessandro,
      'approved',
      ARRAY[user_marco]::UUID[],
      user_giulia,
      NOW(),
      NOW() - INTERVAL '2 days',
      NOW()
    ),

    -- Event 5: Jam Session Musicale (Sofia) - APPROVED
    (
      event_musica,
      'Jam Session: Musica dal Vivo',
      'Portate i vostri strumenti e unitevi alla jam session! Tutti i livelli sono benvenuti. Chitarre, batteria, tastiere, voce... tutto è permesso!',
      NOW() + INTERVAL '10 days',
      'Sala Musica',
      'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800',
      user_sofia,
      'approved',
      '{}'::UUID[],
      user_giulia,
      NOW(),
      NOW() - INTERVAL '1 day',
      NOW()
    ),

    -- Event 6: Evento in attesa di approvazione (Marco) - PENDING
    (
      event_pending,
      'Maratona di Studio Pre-Esami',
      'Studiamo insieme per gli esami di fine trimestre! Materie: matematica, fisica, latino. Ci saranno sessioni di gruppo e tutoring individuale.',
      NOW() + INTERVAL '45 days',
      'Biblioteca',
      'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=800',
      user_marco,
      'pending',
      ARRAY[user_luca]::UUID[],
      NULL,
      NULL,
      NOW(),
      NOW()
    )
  ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    event_date = EXCLUDED.event_date,
    status = EXCLUDED.status,
    updated_at = NOW();

  -- =====================================================================
  -- STEP 5: Create likes and participations
  -- =====================================================================

  -- Likes (various users like various events)
  INSERT INTO likes (user_id, event_id, created_at)
  VALUES
    (user_giulia, event_festa, NOW() - INTERVAL '4 days'),
    (user_luca, event_festa, NOW() - INTERVAL '3 days'),
    (user_sofia, event_festa, NOW() - INTERVAL '2 days'),
    (user_emma, event_festa, NOW() - INTERVAL '1 day'),
    (user_alessandro, event_festa, NOW()),
    (user_marco, event_torneo, NOW() - INTERVAL '2 days'),
    (user_giulia, event_torneo, NOW() - INTERVAL '1 day'),
    (user_emma, event_torneo, NOW()),
    (user_marco, event_teatro, NOW() - INTERVAL '5 days'),
    (user_sofia, event_teatro, NOW() - INTERVAL '4 days'),
    (user_emma, event_teatro, NOW() - INTERVAL '3 days'),
    (user_giulia, event_coding, NOW() - INTERVAL '1 day'),
    (user_luca, event_coding, NOW()),
    (user_marco, event_musica, NOW()),
    (user_alessandro, event_musica, NOW())
  ON CONFLICT (user_id, event_id) DO NOTHING;

  -- Participations (users joining events)
  INSERT INTO participations (user_id, event_id, created_at)
  VALUES
    (user_giulia, event_festa, NOW() - INTERVAL '4 days'),
    (user_luca, event_festa, NOW() - INTERVAL '3 days'),
    (user_sofia, event_festa, NOW() - INTERVAL '2 days'),
    (user_emma, event_festa, NOW() - INTERVAL '1 day'),
    (user_marco, event_torneo, NOW() - INTERVAL '2 days'),
    (user_giulia, event_torneo, NOW() - INTERVAL '1 day'),
    (user_luca, event_torneo, NOW()),
    (user_marco, event_teatro, NOW() - INTERVAL '5 days'),
    (user_sofia, event_teatro, NOW() - INTERVAL '3 days'),
    (user_emma, event_teatro, NOW() - INTERVAL '2 days'),
    (user_sofia, event_coding, NOW() - INTERVAL '1 day'),
    (user_emma, event_coding, NOW()),
    (user_marco, event_musica, NOW() - INTERVAL '1 day'),
    (user_alessandro, event_musica, NOW()),
    (user_giulia, event_musica, NOW())
  ON CONFLICT (user_id, event_id) DO NOTHING;

  -- =====================================================================
  -- STEP 6: Create comments on events
  -- =====================================================================
  -- Note: Using actual schema: author_id and content

  INSERT INTO comments (id, event_id, author_id, content, created_at)
  VALUES
    -- Comments on Festa di Fine Anno
    (gen_random_uuid(), event_festa, user_giulia, 'Fantastico! Non vedo l''ora!', NOW() - INTERVAL '4 days'),
    (gen_random_uuid(), event_festa, user_luca, 'Ci sarà anche musica dal vivo?', NOW() - INTERVAL '3 days'),
    (gen_random_uuid(), event_festa, user_marco, '@Luca stiamo ancora organizzando, ma speriamo di sì!', NOW() - INTERVAL '3 days'),
    (gen_random_uuid(), event_festa, user_sofia, 'Posso portare dei biscotti fatti in casa?', NOW() - INTERVAL '2 days'),
    (gen_random_uuid(), event_festa, user_marco, '@Sofia certo! Ogni contributo è benvenuto!', NOW() - INTERVAL '2 days'),

    -- Comments on Torneo Scacchi
    (gen_random_uuid(), event_torneo, user_marco, 'La mia classe è pronta a vincere!', NOW() - INTERVAL '2 days'),
    (gen_random_uuid(), event_torneo, user_giulia, 'Sfida accettata! La 4B non si arrende mai', NOW() - INTERVAL '1 day'),
    (gen_random_uuid(), event_torneo, user_luca, 'Ci sono premi?', NOW()),
    (gen_random_uuid(), event_torneo, user_alessandro, '@Luca Sì! Medaglie per i primi 3 e un buono Amazon per il vincitore!', NOW()),

    -- Comments on Teatro
    (gen_random_uuid(), event_teatro, user_emma, 'Ho fatto le foto alle prove, lo spettacolo sarà bellissimo!', NOW() - INTERVAL '5 days'),
    (gen_random_uuid(), event_teatro, user_sofia, 'Posso venire anche se non sono dello stesso anno?', NOW() - INTERVAL '4 days'),
    (gen_random_uuid(), event_teatro, user_giulia, '@Sofia Certo! È aperto a tutti gli studenti!', NOW() - INTERVAL '4 days'),

    -- Comments on Workshop Coding
    (gen_random_uuid(), event_coding, user_sofia, 'Perfetto per me che non so nulla di programmazione!', NOW() - INTERVAL '1 day'),
    (gen_random_uuid(), event_coding, user_luca, 'Alessandro è bravissimo, imparerete tanto!', NOW()),

    -- Comments on Jam Session
    (gen_random_uuid(), event_musica, user_marco, 'Porto la chitarra!', NOW()),
    (gen_random_uuid(), event_musica, user_alessandro, 'Io vengo solo ad ascoltare, va bene lo stesso?', NOW())
  ON CONFLICT DO NOTHING;

  -- =====================================================================
  -- STEP 7: Create tutor profiles
  -- =====================================================================

  INSERT INTO tutor_profiles (id, user_id, bio, subjects, price_per_hour, availability_days, time_slot, whatsapp_phone, instagram_username, rating, total_reviews, is_active, created_at, updated_at)
  VALUES
    -- Marco: Tutor di Matematica e Fisica
    (
      gen_random_uuid(),
      user_marco,
      'Studente di 3A con media del 9. Offro ripetizioni di matematica e fisica per biennio e triennio.',
      ARRAY['Matematica', 'Fisica'],
      15.00,
      ARRAY['Lunedì', 'Mercoledì', 'Venerdì'],
      'Pomeriggio (15-18)',
      '+39 333 1234567',
      NULL,
      4.8,
      12,
      true,
      NOW() - INTERVAL '30 days',
      NOW()
    ),

    -- Luca: Tutor di Latino e Greco
    (
      gen_random_uuid(),
      user_luca,
      'Maturando classico, 5 anni di esperienza. Specializzato in traduzione e grammatica latina/greca.',
      ARRAY['Latino', 'Greco', 'Italiano'],
      20.00,
      ARRAY['Martedì', 'Giovedì', 'Sabato'],
      'Mattina (9-12)',
      NULL,
      '@luca.verdi.tutor',
      4.9,
      25,
      true,
      NOW() - INTERVAL '60 days',
      NOW()
    ),

    -- Giulia: Tutor di Letteratura (inattivo per esami)
    (
      gen_random_uuid(),
      user_giulia,
      'Appassionata di letteratura italiana ed europea. Al momento non disponibile per esami.',
      ARRAY['Italiano', 'Storia'],
      12.00,
      ARRAY['Lunedì', 'Mercoledì'],
      'Pomeriggio (15-18)',
      '+39 340 9876543',
      '@giulia.bianchi',
      4.5,
      8,
      false,  -- Inattivo
      NOW() - INTERVAL '90 days',
      NOW()
    )
  ON CONFLICT (user_id) DO UPDATE SET
    bio = EXCLUDED.bio,
    subjects = EXCLUDED.subjects,
    rating = EXCLUDED.rating,
    total_reviews = EXCLUDED.total_reviews,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

  -- =====================================================================
  -- STEP 8: Create chat messages (Global Chat)
  -- =====================================================================

  INSERT INTO chat_messages (id, user_id, content, mentions, reply_to_id, reaction_count, reply_count, created_at)
  VALUES
    -- Message 1: Marco starts a conversation
    (
      msg_1,
      user_marco,
      'Ciao a tutti! Qualcuno ha capito gli esercizi di matematica per domani?',
      '[]'::jsonb,
      NULL,
      3,
      2,
      NOW() - INTERVAL '2 hours'
    ),

    -- Message 2: Luca replies
    (
      msg_2,
      user_luca,
      'Quelli sul teorema di Pitagora? Sono abbastanza semplici, ti posso aiutare!',
      '[]'::jsonb,
      msg_1,
      1,
      1,
      NOW() - INTERVAL '1 hour 55 minutes'
    ),

    -- Message 3: Sofia joins
    (
      msg_3,
      user_sofia,
      'Anche io ho bisogno di aiuto! @Marco possiamo studiare insieme?',
      jsonb_build_array(jsonb_build_object('user_id', user_marco, 'username', 'Marco Rossi', 'start_index', 32, 'end_index', 38)),
      msg_1,
      2,
      0,
      NOW() - INTERVAL '1 hour 50 minutes'
    ),

    -- Message 4: Marco responds to mention
    (
      msg_4,
      user_marco,
      '@Sofia certo! Ci vediamo in biblioteca alle 15?',
      jsonb_build_array(jsonb_build_object('user_id', user_sofia, 'username', 'Sofia Ferrari', 'start_index', 0, 'end_index', 6)),
      NULL,
      1,
      1,
      NOW() - INTERVAL '1 hour 45 minutes'
    ),

    -- Message 5: Luca offers tutoring
    (
      msg_5,
      user_luca,
      '@Sofia se hai bisogno di ripetizioni strutturate, sono disponibile! Controlla il mio profilo tutor.',
      jsonb_build_array(jsonb_build_object('user_id', user_sofia, 'username', 'Sofia Ferrari', 'start_index', 0, 'end_index', 6)),
      NULL,
      2,
      0,
      NOW() - INTERVAL '1 hour 40 minutes'
    ),

    -- Message 6: Alessandro talks about the coding workshop
    (
      msg_6,
      user_alessandro,
      'Ragazzi, ricordatevi del workshop di coding venerdì! Portate i laptop carichi!',
      '[]'::jsonb,
      NULL,
      4,
      1,
      NOW() - INTERVAL '1 hour'
    ),

    -- Message 7: Emma is excited
    (
      msg_7,
      user_emma,
      'Non vedo l''ora! Finalmente imparo a programmare!',
      '[]'::jsonb,
      msg_6,
      3,
      0,
      NOW() - INTERVAL '55 minutes'
    ),

    -- Message 8: Giulia moderator message
    (
      msg_8,
      user_giulia,
      'Ricordo a tutti di mantenere un tono rispettoso in chat. Buono studio a tutti!',
      '[]'::jsonb,
      NULL,
      5,
      0,
      NOW() - INTERVAL '30 minutes'
    )
  ON CONFLICT (id) DO NOTHING;

  -- =====================================================================
  -- STEP 9: Create chat reactions
  -- =====================================================================

  INSERT INTO chat_reactions (message_id, user_id, emoji, created_at)
  VALUES
    -- Reactions to Marco's first message
    (msg_1, user_giulia, '👍', NOW() - INTERVAL '1 hour 58 minutes'),
    (msg_1, user_luca, '❤️', NOW() - INTERVAL '1 hour 57 minutes'),
    (msg_1, user_emma, '🔥', NOW() - INTERVAL '1 hour 56 minutes'),

    -- Reactions to Luca's reply
    (msg_2, user_marco, '👍', NOW() - INTERVAL '1 hour 54 minutes'),

    -- Reactions to Sofia's message
    (msg_3, user_marco, '❤️', NOW() - INTERVAL '1 hour 49 minutes'),
    (msg_3, user_giulia, '👍', NOW() - INTERVAL '1 hour 48 minutes'),

    -- Reactions to Marco's response
    (msg_4, user_sofia, '❤️', NOW() - INTERVAL '1 hour 44 minutes'),

    -- Reactions to Luca's tutoring offer
    (msg_5, user_sofia, '👍', NOW() - INTERVAL '1 hour 39 minutes'),
    (msg_5, user_marco, '🔥', NOW() - INTERVAL '1 hour 38 minutes'),

    -- Reactions to Alessandro's workshop reminder
    (msg_6, user_marco, '🔥', NOW() - INTERVAL '58 minutes'),
    (msg_6, user_sofia, '❤️', NOW() - INTERVAL '57 minutes'),
    (msg_6, user_giulia, '👍', NOW() - INTERVAL '56 minutes'),
    (msg_6, user_emma, '😮', NOW() - INTERVAL '55 minutes'),

    -- Reactions to Emma's excitement
    (msg_7, user_alessandro, '❤️', NOW() - INTERVAL '54 minutes'),
    (msg_7, user_marco, '🔥', NOW() - INTERVAL '53 minutes'),
    (msg_7, user_giulia, '👍', NOW() - INTERVAL '52 minutes'),

    -- Reactions to Giulia's moderator message
    (msg_8, user_marco, '❤️', NOW() - INTERVAL '29 minutes'),
    (msg_8, user_luca, '👍', NOW() - INTERVAL '28 minutes'),
    (msg_8, user_sofia, '👍', NOW() - INTERVAL '27 minutes'),
    (msg_8, user_alessandro, '🔥', NOW() - INTERVAL '26 minutes'),
    (msg_8, user_emma, '❤️', NOW() - INTERVAL '25 minutes')
  ON CONFLICT (message_id, user_id, emoji) DO NOTHING;

  RAISE NOTICE 'Seed data created successfully!';
  RAISE NOTICE 'Created: 6 users, 6 events, 3 tutors, 8 chat messages with reactions';
END $$;

-- =====================================================================
-- VERIFICATION QUERIES (Run manually to verify seed data)
-- =====================================================================

-- Count all test data
SELECT 'Profiles' as table_name, COUNT(*) as count FROM profiles
UNION ALL
SELECT 'Events', COUNT(*) FROM events
UNION ALL
SELECT 'Tutor Profiles', COUNT(*) FROM tutor_profiles
UNION ALL
SELECT 'Chat Messages', COUNT(*) FROM chat_messages
UNION ALL
SELECT 'Chat Reactions', COUNT(*) FROM chat_reactions
UNION ALL
SELECT 'Likes', COUNT(*) FROM likes
UNION ALL
SELECT 'Participations', COUNT(*) FROM participations
UNION ALL
SELECT 'Comments', COUNT(*) FROM comments
UNION ALL
SELECT 'User Roles', COUNT(*) FROM user_roles;

-- Show approved events with like/participation counts
SELECT
  e.title,
  e.status,
  e.event_date,
  p.full_name as creator,
  (SELECT COUNT(*) FROM likes WHERE event_id = e.id) as likes,
  (SELECT COUNT(*) FROM participations WHERE event_id = e.id) as participants,
  (SELECT COUNT(*) FROM comments WHERE event_id = e.id) as comments
FROM events e
JOIN profiles p ON e.creator_id = p.user_id
ORDER BY e.created_at DESC;

-- Show active tutors
SELECT
  p.full_name,
  tp.subjects,
  tp.price_per_hour,
  tp.rating,
  tp.total_reviews,
  tp.is_active
FROM tutor_profiles tp
JOIN profiles p ON tp.user_id = p.user_id
ORDER BY tp.rating DESC;

-- Show recent chat messages
SELECT
  p.full_name as author,
  cm.content,
  cm.reaction_count,
  cm.reply_count,
  cm.created_at
FROM chat_messages cm
JOIN profiles p ON cm.user_id = p.user_id
WHERE cm.hidden_at IS NULL
ORDER BY cm.created_at DESC
LIMIT 10;

-- =====================================================================
-- END OF SEED FILE
-- =====================================================================
