# Feature Specification: Profile Banner

**Feature Branch**: `014-profile-banner`
**Created**: 2025-01-20
**Status**: Draft
**Input**: User description: "Aggiungere banner personalizzato al profilo utente. L'utente può caricare un'immagine personalizzata come sfondo/banner che appare dietro la foto profilo (simile a Twitter/X). Il banner deve avere aspect ratio 3:1, essere compresso per performance, e avere un fallback se non impostato (gradient o blur della foto profilo). Include funzionalità di upload, crop, e preview."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Upload Banner Image (Priority: P1)

L'utente vuole personalizzare il proprio profilo caricando un'immagine banner che appare come sfondo dietro la foto profilo. L'utente accede alla schermata di modifica profilo, seleziona l'opzione per cambiare il banner, sceglie un'immagine dalla galleria o scatta una foto, la ritaglia con aspect ratio 3:1, visualizza un'anteprima e conferma il caricamento.

**Why this priority**: Il caricamento del banner è la funzionalità core della feature. Senza questa, la feature non ha valore. Permette agli utenti di esprimere la propria identità visiva.

**Independent Test**: Può essere testato caricando un'immagine come banner e verificando che appaia correttamente nel profilo.

**Acceptance Scenarios**:

1. **Given** un utente autenticato nella schermata modifica profilo, **When** tocca l'area banner e seleziona un'immagine dalla galleria, **Then** viene mostrato l'editor di ritaglio con aspect ratio 3:1 fisso
2. **Given** un utente nell'editor di ritaglio, **When** conferma il ritaglio, **Then** viene mostrata un'anteprima del banner nel contesto del profilo
3. **Given** un utente nell'anteprima banner, **When** conferma il salvataggio, **Then** il banner viene caricato, compresso e salvato nel profilo
4. **Given** un utente con banner salvato, **When** visita il proprio profilo, **Then** il banner appare come sfondo dietro la foto profilo

---

### User Story 2 - View Profile with Banner (Priority: P1)

Gli utenti vedono il banner nel profilo proprio e altrui. Il banner appare come sfondo nella parte superiore del profilo, con la foto profilo sovrapposta. Se non c'è banner, viene mostrato un fallback visivamente gradevole.

**Why this priority**: La visualizzazione è essenziale quanto il caricamento - senza visualizzazione, il banner non ha scopo.

**Independent Test**: Può essere testato visitando profili con e senza banner per verificare la corretta visualizzazione.

**Acceptance Scenarios**:

1. **Given** un profilo con banner personalizzato, **When** un utente visita il profilo, **Then** il banner appare come sfondo con aspect ratio 3:1 nella parte superiore
2. **Given** un profilo senza banner, **When** un utente visita il profilo, **Then** viene mostrato un fallback gradient basato sui colori del design system
3. **Given** un profilo con banner, **When** il banner non riesce a caricarsi (errore rete), **Then** viene mostrato il fallback gradient

---

### User Story 3 - Remove/Change Banner (Priority: P2)

L'utente vuole rimuovere il banner esistente o sostituirlo con uno nuovo. Dalla schermata modifica profilo, può scegliere di rimuovere il banner (tornando al fallback) o caricarne uno nuovo.

**Why this priority**: Funzionalità secondaria ma importante per dare controllo completo all'utente sulla propria identità visiva.

**Independent Test**: Può essere testato rimuovendo un banner esistente e verificando che il profilo mostri il fallback.

**Acceptance Scenarios**:

1. **Given** un utente con banner esistente nella schermata modifica profilo, **When** tocca l'opzione "Rimuovi banner", **Then** viene richiesta conferma
2. **Given** un utente che conferma la rimozione, **When** conferma, **Then** il banner viene rimosso e il profilo mostra il fallback
3. **Given** un utente con banner esistente, **When** carica un nuovo banner, **Then** il vecchio banner viene sostituito

---

### User Story 4 - Preview Before Save (Priority: P2)

L'utente vuole vedere come apparirà il banner nel contesto del profilo prima di salvarlo definitivamente. Dopo il ritaglio, viene mostrata un'anteprima realistica con la foto profilo sovrapposta.

**Why this priority**: Migliora l'esperienza utente riducendo tentativi ed errori, ma non è bloccante per la funzionalità base.

**Independent Test**: Può essere testato verificando che l'anteprima mostri una rappresentazione accurata del risultato finale.

**Acceptance Scenarios**:

1. **Given** un utente che ha ritagliato un'immagine, **When** viene mostrata l'anteprima, **Then** l'anteprima mostra il banner con la foto profilo sovrapposta
2. **Given** un utente nell'anteprima, **When** tocca "Annulla", **Then** torna all'editor di ritaglio senza salvare
3. **Given** un utente nell'anteprima, **When** tocca "Salva", **Then** il banner viene caricato e salvato

---

### Edge Cases

- Cosa succede quando l'utente seleziona un'immagine troppo piccola? Sistema mostra errore con dimensioni minime richieste (es. 600x200px)
- Cosa succede se il caricamento fallisce? Sistema mostra messaggio di errore con opzione di riprovare, l'immagine precedente rimane
- Cosa succede se l'utente perde connessione durante il caricamento? Sistema notifica l'errore e permette di riprovare quando online
- Cosa succede con immagini in formati non supportati? Sistema accetta JPEG, PNG, HEIC/HEIF e converte automaticamente
- Cosa succede se l'utente annulla durante il caricamento? Caricamento viene cancellato, nessuna modifica al profilo

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Sistema DEVE permettere all'utente di caricare un'immagine banner dalla galleria del dispositivo
- **FR-002**: Sistema DEVE permettere all'utente di scattare una nuova foto da usare come banner
- **FR-003**: Sistema DEVE mostrare un editor di ritaglio con aspect ratio 3:1 fisso (larghezza:altezza)
- **FR-004**: Sistema DEVE comprimere l'immagine per rispettare il budget performance (target: <300KB)
- **FR-005**: Sistema DEVE ridimensionare l'immagine a dimensioni standard (1200x400px)
- **FR-006**: Sistema DEVE mostrare un'anteprima del banner nel contesto del profilo prima del salvataggio
- **FR-007**: Sistema DEVE persistere il banner e associarlo al profilo utente
- **FR-008**: Sistema DEVE mostrare un fallback gradient quando il banner non è presente
- **FR-009**: Sistema DEVE permettere all'utente di rimuovere il banner esistente
- **FR-010**: Sistema DEVE mostrare indicatore di caricamento durante upload e compressione
- **FR-011**: Sistema DEVE validare dimensioni minime dell'immagine (600x200px minimo)
- **FR-012**: Sistema DEVE supportare formati immagine comuni (JPEG, PNG, HEIC/HEIF)
- **FR-013**: Sistema DEVE mostrare il banner nei profili visualizzati da altri utenti (rispettando visibilità profilo)
- **FR-014**: Sistema DEVE eliminare il vecchio banner quando ne viene caricato uno nuovo (pulizia storage)

### Key Entities

- **Banner**: Immagine di sfondo del profilo con URL di storage, associata a un singolo profilo utente. Attributi chiave: URL immagine, dimensioni, data caricamento.
- **Profile**: Entità esistente estesa con riferimento opzionale al banner. Relazione 1:0..1 con Banner.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Utente completa il flusso di caricamento banner (selezione -> ritaglio -> anteprima -> salvataggio) in meno di 30 secondi
- **SC-002**: Banner si carica e viene visualizzato in meno di 2 secondi su connessione 4G
- **SC-003**: 90% degli utenti che iniziano il caricamento completano il flusso con successo
- **SC-004**: Dimensione file banner dopo compressione non supera 300KB
- **SC-005**: Fallback gradient viene mostrato entro 100ms quando banner non presente
- **SC-006**: Editor di ritaglio mantiene 60fps durante le operazioni di pan/zoom

## Assumptions

- L'utente ha già completato l'onboarding e ha un profilo attivo
- Il dispositivo ha accesso alla galleria foto o alla fotocamera
- Il design system Nova ha gradient definiti per il fallback
- Lo storage Supabase è configurato e accessibile
- Il servizio di upload avatar esistente può essere esteso per i banner
