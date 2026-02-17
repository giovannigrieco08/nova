# Research: UGC Safety System

**Feature**: 015-ugc-safety
**Date**: 2025-02-12
**Purpose**: Resolve technical unknowns and validate design decisions

## Research Summary

### 1. Existing Report System Analysis

**Decision**: Unificare i sistemi di report esistenti in un'unica tabella `reports` polimorfica.

**Rationale**: Attualmente esistono 3 tabelle separate:
- `event_reports` (migration 027)
- `comment_reports` (migration 007)
- `chat_reports` (migration 015)

Tutte seguono pattern simili ma con categorie diverse. Un sistema unificato:
- Riduce duplicazione di codice
- Semplifica la dashboard di moderazione
- Permette statistiche aggregate

**Alternatives Considered**:
1. ❌ Mantenere tabelle separate → Più codice da mantenere
2. ❌ View SQL unificata → Performance issues con UNION ALL
3. ✅ Nuova tabella polimorfica → Migrazione pulita, backward compatible

**Integration Strategy**: Le tabelle esistenti vengono mantenute per compatibilità. I nuovi report usano la tabella unificata. Futura migrazione per consolidare.

---

### 2. User Blocking Implementation

**Decision**: Creare tabella `user_blocks` con filtro RLS automatico su tutte le query.

**Rationale**: Il blocking non esiste attualmente. Deve:
- Filtrare feed, chat, commenti dell'utente bloccato
- Impedire messaggi diretti
- Nascondere il profilo del bloccante al bloccato
- Notificare moderatori (non l'utente bloccato)

**Implementation Pattern**:
```sql
-- Funzione riutilizzabile per check blocco
CREATE FUNCTION is_blocked_by(target_user_id UUID, viewer_user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_blocks
    WHERE blocker_id = target_user_id AND blocked_id = viewer_user_id
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;
```

**RLS Integration**: Modificare le policy esistenti per includere blocco check:
```sql
-- Esempio per profili
AND NOT is_blocked_by(profiles.user_id, auth.uid())
```

---

### 3. ToS Acceptance Tracking

**Decision**: Aggiungere colonne `tos_accepted_version` e `tos_accepted_at` a `profiles`.

**Rationale**:
- Non serve tabella separata per un dato 1:1 con profilo
- Colonne nullable permettono check "mai accettato"
- Version tracking per ri-accettazione su aggiornamenti

**Alternatives Considered**:
1. ❌ Tabella separata `tos_acceptances` → Over-engineering per 1:1
2. ✅ Colonne in `profiles` → Semplice, performante
3. ❌ Boolean singolo → Non traccia versioni

**ToS Version Format**: Semantic versioning (es. "1.0.0", "1.1.0")

---

### 4. Content Filtering (Banned Words)

**Decision**: Estendere `contains_profanity()` con tabella `banned_words` configurabile.

**Rationale**: Esiste già la funzione `contains_profanity()` con 150+ parole hardcoded. Per conformità Apple serve lista configurabile da dashboard.

**Current Implementation** (migration 007):
```sql
CREATE OR REPLACE FUNCTION contains_profanity(input_text TEXT)
RETURNS BOOLEAN AS $$
-- 150+ Italian profanity words hardcoded
```

**New Implementation**:
```sql
-- Tabella configurabile
CREATE TABLE banned_words (
  id UUID PRIMARY KEY,
  word TEXT NOT NULL,
  pattern_type VARCHAR(20), -- 'exact', 'contains', 'regex'
  severity VARCHAR(20),     -- 'warning', 'block'
  created_by UUID,
  created_at TIMESTAMPTZ
);

-- Funzione aggiornata che legge dalla tabella
CREATE OR REPLACE FUNCTION contains_banned_content(input_text TEXT)
RETURNS JSONB AS $$
  -- Returns {blocked: boolean, matched_words: [...]}
```

---

### 5. Moderation Dashboard

**Decision**: Utilizzare Supabase Studio + Edge Functions per MVP, con opzione future custom dashboard.

**Rationale**:
- User roles già esistono (`user_roles` table con 'moderator', 'admin')
- RLS già configurata per moderatori
- Supabase Studio permette query dirette con RLS
- Edge Functions possono esporre API per azioni batch

**MVP Approach**:
1. Edge Function `moderate-report` → Approva/rigetta singolo report
2. Edge Function `get-pending-reports` → Lista report pending con filtri
3. Edge Function `ban-user` → Banna utente con sanction record
4. Email via Resend/SendGrid per notifiche urgenti (>20h pending)

**Future Enhancement**: React admin dashboard con Supabase Auth

---

### 6. User Sanctions System

**Decision**: Creare tabella `user_sanctions` per tracking warning/suspension/ban.

**Rationale**: Conforme a Apple Guideline 1.2 requisito "ejecting users". Deve tracciare:
- Tipo sanzione (warning, suspension, ban)
- Motivo e contenuto correlato
- Chi ha emesso la sanzione
- Scadenza (per suspension temporanee)

**Ban Enforcement**:
```sql
-- Funzione check ban
CREATE FUNCTION is_user_banned(check_user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_sanctions
    WHERE user_id = check_user_id
    AND type = 'ban'
    AND (expires_at IS NULL OR expires_at > NOW())
  );
$$ LANGUAGE sql STABLE;
```

**Auth Integration**: Edge Function `check-ban-status` chiamata al login via Supabase Auth hook.

---

### 7. Notification to Moderators

**Decision**: Estendere sistema notifiche esistente + email digest per urgenze.

**Rationale**: Tabella `notifications` già esiste con 7 tipi. Aggiungere:
- `type = 'user_block'` → Quando utente blocca
- `type = 'report_urgent'` → Segnalazione >20h pending

**Email Delivery**:
- Supabase Edge Function con schedule (ogni 4h)
- Check reports pending >20h
- Invia digest a moderatori via Resend

---

### 8. Performance Considerations

**Decision**: Usare indici parziali e denormalizzazione come pattern esistenti.

**Key Indexes**:
```sql
-- Reports pending (moderazione)
CREATE INDEX idx_reports_pending ON reports(created_at)
WHERE status = 'pending';

-- User blocks (filtro feed)
CREATE INDEX idx_user_blocks_blocker ON user_blocks(blocker_id);
CREATE INDEX idx_user_blocks_blocked ON user_blocks(blocked_id);

-- Banned words (filtering)
CREATE INDEX idx_banned_words_active ON banned_words(word)
WHERE deleted_at IS NULL;
```

**Denormalization**:
- `profiles.active_blocks_count` → Per UI "N utenti bloccati"
- `profiles.reports_received_count` → Per moderator dashboard

---

## Dependencies Identified

| Dependency | Current State | Action Required |
|------------|---------------|-----------------|
| `user_roles` table | ✅ Exists | None |
| `notifications` table | ✅ Exists | Add 2 new types |
| `contains_profanity()` | ✅ Exists | Extend with table |
| Email service | ❌ Not configured | Setup Resend/SendGrid |
| Supabase Edge Functions | ✅ Available | Create new functions |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| RLS performance with block checks | Medium | Use SECURITY DEFINER functions with indexes |
| Report volume overwhelming moderators | High | Auto-prioritization by severity + report count |
| False positives in content filter | Medium | Severity levels (warning vs block) |
| Email delivery failures | Low | Retry logic + in-app fallback |

---

## Decisions Summary

| Area | Decision | Confidence |
|------|----------|------------|
| Report System | Nuova tabella unificata `reports` | High |
| User Blocking | Tabella `user_blocks` + RLS functions | High |
| ToS Tracking | Colonne in `profiles` | High |
| Content Filter | Tabella `banned_words` + updated function | High |
| Moderation Dashboard | Supabase Studio + Edge Functions MVP | Medium |
| User Sanctions | Tabella `user_sanctions` | High |
| Notifications | Estensione sistema esistente + email | High |
