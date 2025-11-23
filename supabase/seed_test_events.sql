-- =====================================================================
-- Seed Test Events
-- Purpose: Create test events to populate the Instagram-style feed
-- =====================================================================

-- Insert test events with status='approved' (visible in feed)
INSERT INTO events (
  id,
  creator_id,
  title,
  description,
  event_date,
  location,
  status,
  created_at
) VALUES
-- Event 1: Festa di fine anno 🎉
(
  gen_random_uuid(),
  (SELECT user_id FROM profiles LIMIT 1), -- Use first profile as creator
  'Festa di Fine Anno 2024',
  'Grande festa per celebrare la fine dell''anno scolastico! Musica, cibo e tanto divertimento. Non mancare! 🎉🎊',
  (NOW() + INTERVAL '7 days')::TIMESTAMPTZ, -- 1 week from now
  'Aula Magna - Liceo Galilei Moro',
  'approved',
  NOW() - INTERVAL '2 hours'
),
-- Event 2: Torneo di calcetto ⚽
(
  gen_random_uuid(),
  (SELECT user_id FROM profiles LIMIT 1),
  'Torneo di Calcetto Inter-Classi',
  'Torneo di calcetto a 5 tra le classi del liceo. Iscrizioni aperte fino a domani! Ci vediamo in campo! ⚽🏆',
  (NOW() + INTERVAL '3 days')::TIMESTAMPTZ, -- 3 days from now
  'Campo sportivo scolastico',
  'approved',
  NOW() - INTERVAL '5 hours'
),
-- Event 3: Workshop coding 💻
(
  gen_random_uuid(),
  (SELECT user_id FROM profiles LIMIT 1),
  'Workshop: Introduzione a Flutter',
  'Workshop gratuito di programmazione mobile con Flutter. Impara a creare la tua prima app Android/iOS! Porta il tuo laptop 💻',
  (NOW() + INTERVAL '10 days')::TIMESTAMPTZ, -- 10 days from now
  'Laboratorio Informatica',
  'approved',
  NOW() - INTERVAL '1 day'
),
-- Event 4: Concerto live 🎸
(
  gen_random_uuid(),
  (SELECT user_id FROM profiles LIMIT 1),
  'Concerto Band Studentesca',
  'La band della nostra scuola suonerà dal vivo! Rock, pop e cover dei nostri artisti preferiti. Ingresso libero 🎸🎤',
  (NOW() + INTERVAL '14 days')::TIMESTAMPTZ, -- 2 weeks from now
  'Cortile principale',
  'approved',
  NOW() - INTERVAL '3 days'
),
-- Event 5: Mostra fotografica 📷
(
  gen_random_uuid(),
  (SELECT user_id FROM profiles LIMIT 1),
  'Mostra: "Il Nostro Liceo in 100 Scatti"',
  'Esposizione fotografica realizzata dagli studenti del corso di fotografia. Verranno esposte le migliori foto dell''anno! 📷✨',
  (NOW() + INTERVAL '5 days')::TIMESTAMPTZ, -- 5 days from now
  NULL, -- No location (optional)
  'approved',
  NOW() - INTERVAL '6 hours'
)
ON CONFLICT (id) DO NOTHING;

-- Verify insertion
SELECT COUNT(*) as total_approved_events FROM events WHERE status = 'approved';
