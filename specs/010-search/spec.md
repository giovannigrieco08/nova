# Feature Specification: Search (Cerca)

**Feature Branch**: `010-search`
**Created**: 2025-01-30
**Status**: Draft
**Input**: Ricerca eventi e profili con live search, cronologia, offline support

---

## Overview

### Problem Statement

Gli studenti non hanno un modo rapido per trovare eventi specifici o altri studenti all'interno dell'app Nova. Devono scorrere manualmente il feed degli eventi o navigare tra le schermate per trovare ciò che cercano.

### Proposed Solution

Implementare una funzionalità di ricerca unificata accessibile tramite un'icona lente nell'AppBar che permetta di cercare sia eventi che profili studenti. I risultati sono organizzati in due sezioni separate ("Eventi" e "Utenti") con ricerca live debounced per un'esperienza fluida.

### Key Decisions (from Brainstorming)

| Aspetto | Decisione |
|---------|-----------|
| **Cosa cercare** | Eventi + Profili |
| **Accesso** | Icona lente in AppBar → schermata dedicata |
| **Layout** | Due sezioni separate: "Eventi" / "Utenti" |
| **Cronologia** | Sì, ultime 10 ricerche (Hive locale) |
| **Comportamento** | Live search (debounced 500ms) |
| **Database** | GIN Full-Text Search (italiano) |
| **Offline** | Sì, cerca su dati cached |
| **Cache risultati** | Sì, 5 min TTL |

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ricerca Eventi (Priority: P1)

Uno studente vuole trovare rapidamente un evento specifico digitando parte del titolo, descrizione o luogo senza dover scorrere tutto il feed.

**Why this priority**: Core feature - la ricerca eventi è il caso d'uso principale che permette agli studenti di trovare attività di loro interesse.

**Independent Test**: Può essere testata cercando "basket" e verificando che appaiano eventi con "basket" nel titolo/descrizione/location.

**Acceptance Scenarios**:

1. **Given** lo studente è nella SearchScreen, **When** digita "basket" e attende 500ms, **Then** vede una lista di eventi contenenti "basket" nella sezione "Eventi"
2. **Given** ci sono risultati eventi, **When** lo studente tap su un evento, **Then** naviga a EventDetailScreen con i dettagli dell'evento
3. **Given** lo studente cerca "xyz123", **When** non esistono eventi corrispondenti, **Then** vede messaggio "Nessun risultato" con suggerimenti

---

### User Story 2 - Ricerca Profili Studenti (Priority: P1)

Uno studente vuole trovare un compagno di scuola cercandolo per nome, username o classe per vedere il suo profilo.

**Why this priority**: Core feature - permette agli studenti di connettersi e trovare compagni specifici.

**Independent Test**: Può essere testata cercando "Marco" e verificando che appaiano profili con "Marco" nel nome.

**Acceptance Scenarios**:

1. **Given** lo studente è nella SearchScreen, **When** digita "Marco", **Then** vede profili con "Marco" nel nome/username nella sezione "Utenti"
2. **Given** ci sono risultati profili, **When** lo studente tap su un profilo, **Then** naviga a ProfileScreen
3. **Given** un profilo ha profile_visible=false, **When** viene cercato, **Then** non appare nei risultati

---

### User Story 3 - Live Search con Debouncing (Priority: P1)

Uno studente vuole vedere i risultati mentre digita senza dover premere un pulsante "cerca", con feedback immediato.

**Why this priority**: UX essenziale - il live search è stato scelto come comportamento principale durante il brainstorming.

**Independent Test**: Digitare caratteri rapidamente e verificare che la ricerca parta solo dopo 500ms di pausa.

**Acceptance Scenarios**:

1. **Given** lo studente digita velocemente "basket", **When** si ferma per 500ms, **Then** la ricerca viene eseguita
2. **Given** la ricerca è in corso, **When** lo studente vede la UI, **Then** è visibile un indicatore di caricamento (shimmer)
3. **Given** la query ha meno di 2 caratteri, **When** lo studente si ferma, **Then** non viene eseguita nessuna ricerca

---

### User Story 4 - Sezioni Separate nei Risultati (Priority: P1)

Uno studente vuole vedere eventi e utenti chiaramente separati per distinguere i tipi di risultato.

**Why this priority**: Decisione di design scelta durante brainstorming - due sezioni invece di filtri.

**Independent Test**: Cercare un termine che matcha sia eventi che profili e verificare due sezioni distinte.

**Acceptance Scenarios**:

1. **Given** la ricerca trova 5 eventi e 3 profili, **When** lo studente vede i risultati, **Then** vede header "Eventi (5)" e "Utenti (3)"
2. **Given** la ricerca trova solo eventi, **When** lo studente vede i risultati, **Then** la sezione "Utenti" mostra "(0)" o è nascosta
3. **Given** entrambe le sezioni hanno risultati, **When** lo studente scrolla, **Then** vede prima Eventi, poi Utenti

---

### User Story 5 - Navigazione da Risultato (Priority: P1)

Uno studente vuole tappare su un risultato per accedere ai dettagli dell'evento o profilo trovato.

**Why this priority**: Completa il flusso di ricerca - senza navigazione la ricerca sarebbe inutile.

**Independent Test**: Tap su un risultato evento e verificare che si apra EventDetailScreen.

**Acceptance Scenarios**:

1. **Given** lo studente vede un evento nei risultati, **When** tap sull'evento, **Then** naviga a EventDetailScreen(eventId)
2. **Given** lo studente vede un profilo nei risultati, **When** tap sul profilo, **Then** naviga a ProfileScreen(userId)
3. **Given** lo studente ha navigato a un dettaglio, **When** preme back, **Then** torna alla SearchScreen con query e risultati preservati

---

### User Story 6 - Cronologia Ricerche (Priority: P2)

Uno studente vuole vedere le sue ultime ricerche per poterle ripetere velocemente senza riscrivere.

**Why this priority**: Migliora UX ma non è essenziale per il funzionamento base.

**Independent Test**: Effettuare 3 ricerche, chiudere e riaprire SearchScreen, verificare che appaiano come chip.

**Acceptance Scenarios**:

1. **Given** lo studente ha cercato "basket", "festa", "marco", **When** apre SearchScreen, **Then** vede 3 chip con le ricerche recenti
2. **Given** ci sono chip cronologia, **When** lo studente tap su "basket", **Then** viene eseguita la ricerca "basket"
3. **Given** ci sono 12 ricerche in cronologia, **When** lo studente vede i chip, **Then** vede solo le ultime 10 (FIFO)
4. **Given** c'è un chip cronologia, **When** lo studente swipe o tap su X, **Then** quella ricerca viene rimossa

---

### User Story 7 - Evidenziazione Testo Corrispondente (Priority: P2)

Uno studente vuole vedere evidenziato il testo che corrisponde alla sua ricerca per capire perché un risultato è stato trovato.

**Why this priority**: Migliora comprensione risultati ma non è essenziale.

**Independent Test**: Cercare "basket" e verificare che la parola sia in bold nei titoli evento.

**Acceptance Scenarios**:

1. **Given** lo studente cerca "basket", **When** vede "Torneo Basket 3v3" nei risultati, **Then** "Basket" è evidenziato in bold
2. **Given** lo studente cerca "BASKET" (maiuscolo), **When** vede risultati, **Then** l'evidenziazione è case-insensitive

---

### User Story 8 - Stati UI Chiari (Priority: P2)

Uno studente vuole feedback visivo chiaro durante la ricerca per capire cosa sta succedendo.

**Why this priority**: Migliora UX generale ma la funzione base funziona anche senza.

**Independent Test**: Verificare visivamente i diversi stati durante una ricerca.

**Acceptance Scenarios**:

1. **Given** la SearchScreen si apre, **When** non c'è query, **Then** vede stato iniziale con "Cerca eventi e studenti"
2. **Given** la ricerca è in corso, **When** lo studente vede la UI, **Then** vede shimmer skeleton loading
3. **Given** la ricerca fallisce (errore rete), **When** lo studente vede la UI, **Then** vede messaggio errore con pulsante "Riprova"

---

### User Story 9 - Ricerca Offline (Priority: P3)

Uno studente vuole poter cercare anche senza connessione, usando i dati già scaricati.

**Why this priority**: Nice-to-have - migliora esperienza in zone con scarsa copertura.

**Independent Test**: Attivare modalità aereo, cercare, verificare risultati da cache.

**Acceptance Scenarios**:

1. **Given** lo studente è offline, **When** cerca "basket", **Then** vede risultati dai dati cached localmente
2. **Given** lo studente è offline con risultati, **When** vede la UI, **Then** c'è banner "Ricerca offline - risultati limitati"
3. **Given** lo studente è offline senza dati in cache, **When** cerca, **Then** vede messaggio appropriato

---

### User Story 10 - Cache Risultati (Priority: P3)

Uno studente vuole che ricerche ripetute siano istantanee senza dover attendere di nuovo.

**Why this priority**: Ottimizzazione performance, non essenziale per MVP.

**Independent Test**: Cercare "basket", aspettare, cercare di nuovo "basket", verificare risposta immediata.

**Acceptance Scenarios**:

1. **Given** lo studente ha cercato "basket" 1 minuto fa, **When** cerca di nuovo "basket", **Then** risultati appaiono istantaneamente dalla cache
2. **Given** lo studente ha cercato "basket" 6 minuti fa (TTL scaduto), **When** cerca di nuovo, **Then** viene eseguita nuova query al server

---

### User Story 11 - Animazioni Smooth (Priority: P3)

Uno studente vuole transizioni fluide nei risultati per un'esperienza piacevole.

**Why this priority**: Polish finale, non necessario per funzionalità.

**Independent Test**: Osservare animazioni durante caricamento risultati.

**Acceptance Scenarios**:

1. **Given** i risultati arrivano, **When** vengono visualizzati, **Then** appaiono con fade-in staggered
2. **Given** lo studente scrolla i risultati, **When** osserva la UI, **Then** mantiene 60fps senza jank

---

### Edge Cases

- **Query vuota o solo spazi**: Non eseguire ricerca, mostrare stato iniziale
- **Query < 2 caratteri**: Non eseguire ricerca, mostrare hint "Digita almeno 2 caratteri"
- **Caratteri speciali in query**: Sanitizzare per prevenire SQL injection
- **Troppi risultati**: Limitare a 20 per sezione, non implementare paginazione (out of scope)
- **Nessun evento futuro**: Mostrare solo eventi con event_date >= oggi
- **Profilo cancellato durante ricerca**: Gestire gracefully se ProfileScreen non trova il profilo
- **Timeout rete**: Mostrare errore dopo 10 secondi, offrire retry

---

## Requirements *(mandatory)*

### Functional Requirements

#### Search Engine
- **FR-001**: Sistema DEVE supportare ricerca full-text su eventi (title, description, location)
- **FR-002**: Sistema DEVE supportare ricerca full-text su profili (full_name, username, class)
- **FR-003**: Sistema DEVE usare GIN Full-Text Search con configurazione "italian"
- **FR-004**: Sistema DEVE eseguire query eventi e profili in parallelo (Future.wait)
- **FR-005**: Sistema DEVE limitare risultati a 20 per categoria
- **FR-006**: Sistema DEVE filtrare solo eventi con status='approved' e event_date >= oggi
- **FR-007**: Sistema DEVE filtrare solo profili con profile_visible=true e deleted_at IS NULL

#### User Interface
- **FR-008**: UI DEVE mostrare icona lente in MainFeedScreen AppBar
- **FR-009**: UI DEVE aprire SearchScreen dedicata al tap sull'icona
- **FR-010**: UI DEVE implementare search bar platform-adaptive (CupertinoSearchTextField / Material SearchBar)
- **FR-011**: UI DEVE mostrare risultati in due sezioni: "Eventi" con conteggio, "Utenti" con conteggio
- **FR-012**: UI DEVE mostrare EventSearchTile con: immagine, titolo, data formattata, luogo
- **FR-013**: UI DEVE mostrare ProfileSearchTile con: avatar, full_name, classe
- **FR-014**: UI DEVE debounce input di 500ms prima di eseguire ricerca
- **FR-015**: UI DEVE mostrare cronologia ricerche come chip tappabili sotto search bar (P2)
- **FR-016**: UI DEVE evidenziare testo corrispondente in bold nei risultati (P2)
- **FR-017**: UI DEVE mostrare stati: initial, loading (shimmer), results, empty, error (P2)
- **FR-018**: UI DEVE usare shimmer skeleton durante loading (P2)

#### Caching & Offline
- **FR-019**: Sistema DEVE salvare ultime 10 ricerche in Hive box "search_history" (P2)
- **FR-020**: Sistema DEVE cachare risultati per 5 minuti in Hive box "search_results_cache" (P3)
- **FR-021**: Sistema DEVE supportare ricerca offline con filtro contains() su dati cached (P3)
- **FR-022**: UI DEVE mostrare indicatore "Risultati offline" quando cerca senza rete (P3)

#### Navigation
- **FR-023**: Tap su EventSearchTile DEVE navigare a EventDetailScreen(eventId: id)
- **FR-024**: Tap su ProfileSearchTile DEVE navigare a ProfileScreen(userId: id)
- **FR-025**: Navigazione DEVE essere platform-adaptive (CupertinoPageRoute / MaterialPageRoute)
- **FR-026**: Back navigation DEVE preservare query e risultati nella SearchScreen

---

### Key Entities

#### SearchResults
Rappresenta i risultati di una ricerca combinata.
- **events**: Lista di EventModel trovati (max 20)
- **profiles**: Lista di ProfileModel trovati (max 20)
- **query**: Stringa di ricerca originale
- **isOffline**: Boolean, true se risultati da cache locale
- **timestamp**: DateTime per calcolo TTL cache

#### SearchHistoryItem
Rappresenta una ricerca salvata in cronologia.
- **query**: Testo cercato (normalizzato lowercase/trimmed)
- **timestamp**: Quando è stata effettuata

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Query response time <100ms (cached), <300ms (network) misurato con stopwatch in debug mode
- **SC-002**: >40% degli utenti attivi usa la ricerca almeno una volta a settimana (analytics locale)
- **SC-003**: >60% delle ricerche portano a tap su un risultato (event tracking locale)
- **SC-004**: UI mantiene 60fps durante scroll risultati (Flutter DevTools profiler)
- **SC-005**: Ricerca trova risultati rilevanti per query comuni ("festa", "basket", nomi comuni)
- **SC-006**: Zero crash/error durante normale utilizzo ricerca (crash analytics)

---

## Constitution Compliance

### Principle Alignment

| Principle | Compliance | Notes |
|-----------|------------|-------|
| STUDENTS_FIRST | ✅ | Ricerca migliora esperienza studente, trova eventi/compagni velocemente |
| PRIVACY_FOUNDATION | ✅ | Cronologia solo locale (Hive), nessun tracking query su server |
| SIMPLICITY_FIRST | ✅ | UI minimale, due sezioni chiare, no filtri complessi |
| PERFORMANCE_FIRST | ✅ | GIN FTS (<60ms), caching 5min, debouncing 500ms, parallel queries |
| SPEC_FIRST | ✅ | Specifica completa prima di implementazione |
| DESIGN_SYSTEM_STRICT | ✅ | Tutti i valori UI da NovaColors, NovaSpacing, NovaTextStyles, NovaRadius |
| CONTENT_MODERATION | ✅ | Solo eventi approved visibili, profili rispettano profile_visible |

### Anti-Goals Check

- ✅ Non crea dinamiche social network (no follower/following nella ricerca)
- ✅ Non traccia comportamento utente (cronologia solo locale)
- ✅ Non aggiunge complessità non necessaria (no filtri avanzati, no paginazione)

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Filtri avanzati (data, categoria, location) | Complessità MVP, valutare in v2 se richiesto |
| Ricerca vocale | Richiede permessi aggiuntivi, bassa priorità |
| Suggerimenti autocomplete | Richiede infrastruttura server separata |
| Ricerca in chat messages | Chat è effimera (24h), non indicizzata by design |
| Sorting risultati | Default by relevance sufficiente per MVP |
| Paginazione risultati | 20 risultati per sezione coprono 95% casi d'uso |
| Ricerca Bacheche | Feature Bacheche non ancora implementata |

---

## Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Query lente con molti dati | High | Low | GIN indexes, limit 20 risultati, parallel queries |
| Cache stale mostra dati vecchi | Medium | Medium | TTL 5 min, invalidazione su refresh feed |
| Offline search risultati poveri | Low | High | Disclaimer "risultati limitati", funziona solo su cached |
| FTS italiano impreciso | Medium | Low | Test con query reali, fallback ILIKE se necessario |
| UI jank durante scroll | Medium | Low | Ottimizzazione ListView.builder, 60fps target |

---

## Database Migration Required

```sql
-- 011_search_feature.sql

-- GIN Full-Text Search index per eventi (italiano)
CREATE INDEX IF NOT EXISTS idx_events_fts_italian
  ON events USING gin(
    to_tsvector('italian',
      COALESCE(title, '') || ' ' ||
      COALESCE(description, '') || ' ' ||
      COALESCE(location, '')
    )
  )
  WHERE status = 'approved';

-- GIN Full-Text Search index per profili (italiano)
CREATE INDEX IF NOT EXISTS idx_profiles_fts_italian
  ON profiles USING gin(
    to_tsvector('italian',
      COALESCE(full_name, '') || ' ' ||
      COALESCE(username, '') || ' ' ||
      COALESCE(class, '')
    )
  )
  WHERE deleted_at IS NULL AND profile_visible = TRUE;
```

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-01-30 | Initial specification from brainstorming session |
