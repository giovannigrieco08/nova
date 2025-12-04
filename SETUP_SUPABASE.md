# Setup Manuale Supabase

Questa guida elenca i passaggi manuali necessari per configurare Supabase per Nova.

---

## 1. Applicare le Migrazioni

Le migrazioni sono in `supabase/migrations/`. Eseguile in ordine dal Dashboard Supabase o via CLI:

```bash
# Se usi Supabase CLI
supabase db push

# Oppure manualmente dal Dashboard:
# 1. Vai su SQL Editor
# 2. Incolla ed esegui ogni file in ordine numerico
```

### Migrazioni principali:
| File | Descrizione |
|------|-------------|
| `013_tutor_profiles.sql` | Tabella profili tutor |
| `015_global_chat_system.sql` | Tabelle chat globale |
| `016_migrate_notifications_schema.sql` | Schema notifiche aggiornato |
| `017_fix_notify_chat_mentions_trigger.sql` | Fix trigger menzioni |
| `20241204_chat_media_view_count.sql` | Contatore visualizzazioni media |

---

## 2. Creare Storage Bucket

### Bucket: `ephemeral-media`

Dal Dashboard Supabase:
1. Vai su **Storage** → **New bucket**
2. Nome: `ephemeral-media`
3. Opzioni:
   - ✅ Public bucket: **NO** (privato)
   - File size limit: `10MB`
   - Allowed MIME types: `image/*, video/*`

### Policy RLS per il bucket:

```sql
-- Permettere upload agli utenti autenticati
CREATE POLICY "Users can upload their own media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'ephemeral-media' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Permettere lettura ai destinatari (tramite signed URL)
CREATE POLICY "Users can read media via signed URL"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'ephemeral-media');

-- Permettere cancellazione solo al proprietario
CREATE POLICY "Users can delete their own media"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'ephemeral-media' AND auth.uid()::text = (storage.foldername(name))[1]);
```

---

## 3. Configurare Edge Functions (Opzionale)

### Funzione: `cleanup-viewed-media`

Questa funzione pulisce i media visualizzati dopo 24h.

1. Crea la funzione in `supabase/functions/cleanup-viewed-media/index.ts`
2. Deploy: `supabase functions deploy cleanup-viewed-media`
3. Configura un cron job (ogni ora):

```sql
-- Nel Dashboard, crea un cron job
SELECT cron.schedule(
  'cleanup-viewed-media',
  '0 * * * *',  -- Ogni ora
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT.supabase.co/functions/v1/cleanup-viewed-media',
    headers := '{"Authorization": "Bearer YOUR_SERVICE_KEY"}'::jsonb
  );
  $$
);
```

---

## 4. Configurare Realtime

Abilita Realtime per le tabelle necessarie:

1. Vai su **Database** → **Replication**
2. Abilita per:
   - `chat_messages`
   - `chat_reactions`
   - `notifications`
   - `typing_indicators` (se esiste)

---

## 5. Variabili d'Ambiente

Assicurati che `nova/lib/core/config/` abbia le credenziali corrette:

```dart
// In environment.dart o .env
const supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
const supabaseAnonKey = 'YOUR_ANON_KEY';
```

---

## Checklist Finale

- [ ] Migrazioni applicate (013, 015, 016, 017, 20241204)
- [ ] Bucket `ephemeral-media` creato
- [ ] Policy RLS per storage configurate
- [ ] Realtime abilitato per chat_messages, chat_reactions, notifications
- [ ] Variabili d'ambiente configurate
- [ ] (Opzionale) Edge Function cleanup-viewed-media deployata

---

*Ultimo aggiornamento: 2025-12-04*
