# Feature Specification: Chat Message Actions (Edit & Delete)

**Feature Branch**: `013-chat-message-actions`
**Created**: 2026-01-17
**Status**: Draft
**Input**: User description: "Possibilità di eliminare e modificare i messaggi nella chat - gli utenti devono poter eliminare i propri messaggi (con indicazione 'messaggio eliminato' visibile agli altri) e modificare i propri messaggi entro un certo tempo limite, con indicazione 'modificato' visibile"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Delete Own Message (Priority: P1)

Come utente della chat, voglio poter eliminare i miei messaggi inviati per errore o inappropriati, così da mantenere la conversazione pulita e correggere eventuali errori.

**Why this priority**: L'eliminazione è la funzionalità più critica perché permette agli utenti di rimuovere contenuti inviati per errore, messaggi con informazioni sensibili o contenuti inappropriati. È essenziale per la privacy e la gestione degli errori.

**Independent Test**: Può essere testato inviando un messaggio, eliminandolo, e verificando che appaia "Messaggio eliminato" agli altri partecipanti della chat.

**Acceptance Scenarios**:

1. **Given** un utente ha inviato un messaggio nella chat, **When** l'utente seleziona l'opzione "Elimina" sul proprio messaggio, **Then** il messaggio viene sostituito con il placeholder "Messaggio eliminato" visibile a tutti i partecipanti
2. **Given** un utente visualizza una chat, **When** un altro utente ha eliminato un messaggio, **Then** l'utente vede "Messaggio eliminato" al posto del contenuto originale
3. **Given** un utente tenta di eliminare un messaggio di un altro utente, **When** seleziona il messaggio, **Then** l'opzione "Elimina" non è disponibile
4. **Given** un utente elimina un messaggio, **When** l'eliminazione viene confermata, **Then** il contenuto originale non è più recuperabile da nessun utente

---

### User Story 2 - Edit Own Message Within Time Limit (Priority: P2)

Come utente della chat, voglio poter modificare i miei messaggi entro un tempo limite per correggere errori di battitura o aggiornare informazioni, con un indicatore visibile che il messaggio è stato modificato.

**Why this priority**: La modifica è importante per correggere errori minori senza dover eliminare e riscrivere il messaggio. Ha priorità inferiore all'eliminazione perché l'eliminazione copre anche i casi d'uso della modifica (si può sempre eliminare e riscrivere).

**Independent Test**: Può essere testato inviando un messaggio, modificandolo entro il tempo limite, e verificando che il messaggio aggiornato mostri l'indicatore "Modificato".

**Acceptance Scenarios**:

1. **Given** un utente ha inviato un messaggio meno di 15 minuti fa, **When** l'utente seleziona "Modifica" e salva le modifiche, **Then** il messaggio viene aggiornato con il nuovo contenuto e mostra l'etichetta "Modificato"
2. **Given** un utente ha inviato un messaggio più di 15 minuti fa, **When** l'utente tenta di modificare il messaggio, **Then** l'opzione "Modifica" non è disponibile o è disabilitata con messaggio esplicativo
3. **Given** un messaggio è stato modificato, **When** qualsiasi utente visualizza il messaggio, **Then** vede l'indicatore "Modificato" accanto al timestamp
4. **Given** un utente sta modificando un messaggio, **When** annulla la modifica, **Then** il messaggio rimane invariato

---

### User Story 3 - Visual Feedback and Confirmation (Priority: P3)

Come utente della chat, voglio ricevere feedback visivo chiaro durante le azioni di modifica/eliminazione e conferma prima di eliminare, così da evitare azioni accidentali.

**Why this priority**: Il feedback e le conferme migliorano l'esperienza utente ma non sono funzionalità core. L'app funziona anche senza conferme, ma con rischio di azioni accidentali.

**Independent Test**: Può essere testato tentando di eliminare un messaggio e verificando che appaia una dialog di conferma prima dell'azione.

**Acceptance Scenarios**:

1. **Given** un utente seleziona "Elimina" su un proprio messaggio, **When** viene richiesta conferma, **Then** l'utente può confermare o annullare l'eliminazione
2. **Given** un utente sta modificando un messaggio, **When** il tempo limite sta per scadere (ultimi 2 minuti), **Then** l'utente vede un indicatore visivo del tempo rimanente
3. **Given** un'azione di modifica/eliminazione è in corso, **When** l'azione viene completata, **Then** l'utente riceve feedback visivo immediato del successo

---

### Edge Cases

- Cosa succede se l'utente perde la connessione durante l'eliminazione? Il sistema ritenta automaticamente quando la connessione è ripristinata e mostra stato "in attesa" nel frattempo.
- Cosa succede se un utente modifica un messaggio mentre un altro lo sta leggendo? L'aggiornamento viene propagato in tempo reale a tutti i partecipanti.
- Cosa succede se un messaggio viene eliminato mentre qualcuno sta scrivendo una risposta? Il placeholder "Messaggio eliminato" appare e l'utente può decidere se continuare a rispondere.
- Cosa succede se il tempo limite scade mentre l'utente sta modificando? La modifica in corso può essere completata, ma il timer inizia al momento dell'invio del messaggio originale, non dell'apertura dell'editor.
- Cosa succede con messaggi contenenti media (immagini/video)? L'eliminazione rimuove anche i media associati; la modifica del testo è possibile ma i media non possono essere modificati.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Il sistema DEVE permettere agli utenti di eliminare i propri messaggi in qualsiasi momento dopo l'invio
- **FR-002**: Il sistema DEVE sostituire i messaggi eliminati con il placeholder "Messaggio eliminato" visibile a tutti i partecipanti della chat
- **FR-003**: Il sistema DEVE rendere irrecuperabile il contenuto originale di un messaggio eliminato
- **FR-004**: Il sistema DEVE permettere agli utenti di modificare i propri messaggi entro 15 minuti dall'invio
- **FR-005**: Il sistema DEVE mostrare l'indicatore "Modificato" accanto ai messaggi che sono stati modificati
- **FR-006**: Il sistema DEVE disabilitare l'opzione di modifica dopo il superamento del tempo limite
- **FR-007**: Il sistema DEVE impedire l'eliminazione o modifica di messaggi altrui
- **FR-008**: Il sistema DEVE richiedere conferma prima di eliminare un messaggio
- **FR-009**: Il sistema DEVE propagare le modifiche e eliminazioni in tempo reale a tutti i partecipanti della chat
- **FR-010**: Il sistema DEVE mostrare il contesto del menu azioni (modifica/elimina) tramite long-press o swipe sul messaggio
- **FR-011**: Il sistema DEVE preservare la cronologia della conversazione (i messaggi eliminati mantengono il loro posto come placeholder)

### Key Entities

- **ChatMessage**: Rappresenta un singolo messaggio nella chat. Include contenuto, autore, timestamp di invio, timestamp di ultima modifica (se modificato), stato (attivo/eliminato), e flag di modifica.
- **MessageAction**: Rappresenta un'azione eseguita su un messaggio (modifica o eliminazione). Include tipo di azione, timestamp, e autore dell'azione.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Gli utenti possono eliminare un messaggio in meno di 3 secondi (dal tap al feedback di conferma)
- **SC-002**: Gli utenti possono modificare un messaggio in meno di 5 secondi (dal tap all'apertura dell'editor)
- **SC-003**: Le modifiche e eliminazioni vengono propagate agli altri utenti in meno di 1 secondo
- **SC-004**: Il 95% degli utenti comprende che un messaggio è stato eliminato/modificato al primo sguardo (UX chiara)
- **SC-005**: Zero messaggi eliminati risultano recuperabili dopo l'eliminazione (privacy garantita)
- **SC-006**: L'indicatore del tempo rimanente per la modifica è visibile e accurato

## Assumptions

- Il tempo limite di 15 minuti per la modifica è stato scelto come standard comune nelle app di messaggistica (WhatsApp usa 15 minuti, Telegram 48 ore, Slack nessun limite). 15 minuti bilancia la necessità di correggere errori con l'integrità della conversazione.
- L'eliminazione è sempre disponibile senza limite di tempo per garantire la privacy degli utenti.
- I media allegati ai messaggi vengono eliminati insieme al messaggio.
- La modifica permette solo di cambiare il testo, non di aggiungere/rimuovere media.
- Le notifiche push già inviate per un messaggio poi eliminato non vengono ritirate (limitazione tecnica standard).
