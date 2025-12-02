# Quickstart: Sistema Ripetizioni

**Feature Branch**: `012-tutoring-system`
**Date**: 2025-12-01

---

## Prerequisites

- Nova app running locally (`flutter run`)
- Supabase project connected
- Migration `012_tutor_profiles.sql` applied
- At least 2 test user accounts (@galileimoro.edu.it)

---

## Quick Testing Scenarios

### Scenario 1: Diventare Tutor dal Profilo

**Steps:**
1. Login con utente test che NON è tutor
2. Vai a Profilo (bottom nav → icona profilo)
3. Scorri fino alla sezione dopo le statistiche
4. Tap su card "Vuoi dare ripetizioni?"
5. Compila il form:
   - Bio: "Studente di 4A, bravo in matematica"
   - Materie: seleziona "Matematica" e "Fisica"
   - Prezzo: 15 (€/ora)
   - Disponibilità: Lunedì, Mercoledì
   - Fascia oraria: "15:00-18:00"
   - WhatsApp: "393201234567"
6. Tap "Pubblica Profilo"

**Expected Result:**
- Snackbar "Profilo tutor creato!"
- Card nel profilo ora mostra materie + prezzo + bottone "Modifica"

---

### Scenario 2: Cercare Tutor per Materia

**Steps:**
1. Login con utente diverso da Scenario 1
2. Vai a sezione Ripetizioni (bottom nav o home)
3. Vedi lista 12 materie
4. Tap su "Matematica"
5. Vedi lista tutor che insegnano Matematica

**Expected Result:**
- Lista mostra tutor creato in Scenario 1
- Card mostra: avatar, nome, classe, rating, materie, prezzo

---

### Scenario 3: Contattare Tutor via WhatsApp

**Steps:**
1. Dalla lista tutor (Scenario 2)
2. Tap sulla card del tutor
3. Bottom sheet "Contatta [Nome]" si apre
4. Tap bottone WhatsApp (verde)

**Expected Result:**
- Si apre app WhatsApp con chat pre-compilata
- Se WhatsApp non installato: browser web.whatsapp.com

---

### Scenario 4: Contattare Tutor via Instagram

**Prerequisites:** Tutor con instagram_username configurato

**Steps:**
1. Dalla lista tutor o dal profilo del tutor
2. Tap sulla card del tutor
3. Bottom sheet mostra bottone Instagram
4. Tap bottone Instagram (viola/rosa)

**Expected Result:**
- Si apre app Instagram sul profilo del tutor
- Se Instagram non installato: browser instagram.com

---

### Scenario 5: Vedere Tutor su Profilo Altri

**Steps:**
1. Vai al profilo di un altro utente che è tutor
2. Cerca sezione "Ripetizioni" nel profilo

**Expected Result:**
- Sezione mostra materie offerte e prezzo
- Bottone "Contatta per Ripetizioni" presente
- Tap bottone apre lo stesso modal contatto

---

### Scenario 6: Disattivare Profilo Tutor

**Steps:**
1. Login come tutor attivo
2. Vai a Profilo → sezione Ripetizioni
3. Tap "Modifica"
4. Scorri fino in fondo
5. Tap bottone rosso "Disattiva Profilo"
6. Conferma l'azione

**Expected Result:**
- Profilo tutor diventa `is_active = false`
- Non compare più nelle ricerche
- Nel proprio profilo: card grigia "Profilo Tutor Disattivato"

---

### Scenario 7: Riattivare Profilo Tutor

**Steps:**
1. Login come tutor con profilo disattivato
2. Vai a Profilo → sezione Ripetizioni
3. Tap "Riattiva" sulla card grigia

**Expected Result:**
- Profilo tutor diventa `is_active = true`
- Torna visibile nelle ricerche
- Card nel profilo torna normale con materie e prezzo

---

### Scenario 8: Filtrare Tutor

**Steps:**
1. Vai alla lista tutor per una materia
2. Tap chip "Prezzo"
3. Seleziona "Gratis"
4. Osserva la lista filtrata

**Expected Result:**
- Solo tutor con `price_per_hour = 0` mostrati
- Tap "Tutte" resetta i filtri

---

### Scenario 9: Diventare Tutor da FAB

**Steps:**
1. Vai a sezione Ripetizioni (lista materie)
2. Tap FAB (+) in basso a destra
3. Compila form come Scenario 1

**Expected Result:**
- Stesso form "Diventa Tutor" di Scenario 1
- Se già tutor: apre "Modifica Profilo Tutor"

---

### Scenario 10: Gestire Tutor da Settings

**Steps:**
1. Login come tutor attivo
2. Vai a Settings (ingranaggio nel profilo)
3. Cerca sezione "Tutor"
4. Tap "Gestisci Profilo Tutor"

**Expected Result:**
- Apre schermata modifica profilo tutor
- Pre-compilato con dati esistenti

---

## Validation Test Cases

### Form Validation

| Test | Input | Expected |
|------|-------|----------|
| No materie | Form senza materie | Errore "Seleziona almeno una materia" |
| Troppe materie | 6+ materie | UI impedisce selezione (max 5) |
| No contatto | No WhatsApp, no Instagram | Errore "Inserisci almeno un contatto" |
| Bio lunga | >200 caratteri | Errore "La bio non può superare 200 caratteri" |
| Prezzo negativo | -10 | Impossibile (keyboard numeric, min 0) |
| WhatsApp invalido | "ciao" | Warning formato (opzionale) |

### RLS Policy Tests

| Test | Action | Expected |
|------|--------|----------|
| Read altri tutor | GET tutor attivi | Successo |
| Read tutor inattivi | GET `is_active=false` | Empty (RLS blocks) |
| Read proprio inattivo | GET proprio profilo | Successo |
| Create duplicato | INSERT secondo profilo | Error 23505 |
| Update altro profilo | UPDATE altro user_id | Error 42501 (RLS) |
| Delete altro profilo | DELETE altro user_id | Error 42501 (RLS) |

---

## Debug Commands

### Check tutor_profiles table

```sql
-- In Supabase SQL Editor
SELECT tp.*, p.full_name
FROM tutor_profiles tp
JOIN profiles p ON tp.user_id = p.id
ORDER BY tp.created_at DESC;
```

### Check subjects index usage

```sql
EXPLAIN ANALYZE
SELECT * FROM tutor_profiles
WHERE subjects @> ARRAY['matematica']
AND is_active = true;
```

### Force refresh provider (Dart)

```dart
ref.invalidate(tutorsBySubjectProvider('matematica'));
```

---

## Common Issues

### Issue: Tutor non compare nella lista

**Causes:**
- `is_active = false`
- Subject non in array
- RLS policy blocking

**Debug:**
```sql
SELECT id, user_id, subjects, is_active
FROM tutor_profiles
WHERE user_id = 'uuid-here';
```

### Issue: WhatsApp non si apre

**Causes:**
- Formato numero errato (deve essere `393201234567`)
- App non installata
- Deep link bloccato

**Debug:**
```dart
print('Opening: https://wa.me/$phone');
```

### Issue: Form non valida

**Causes:**
- Meno di 1 materia
- Nessun contatto
- Bio troppo lunga

**Debug:**
Check validation messages in UI.

---

## Performance Benchmarks

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Subject filter query | <50ms | Supabase logs |
| List 20 tutors render | <16ms (60fps) | Flutter DevTools |
| Form submission | <500ms | Network tab |
| Deep link launch | <200ms | Stopwatch in code |

---

## Feature Flags (if needed)

```dart
// In case of gradual rollout
const kTutoringFeatureEnabled = true;

if (kTutoringFeatureEnabled) {
  // Show tutoring section
}
```
