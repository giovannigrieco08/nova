# Feature Specification: UGC Safety System

**Feature Branch**: `015-ugc-safety`
**Created**: 2025-02-12
**Status**: Draft
**Input**: UGC Safety System per conformità Apple Guideline 1.2 - Report system, Block system, Moderation dashboard, Content filtering, EULA acceptance

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Segnalare Contenuto Inappropriato (Priority: P1)

Un utente vede un post offensivo nel feed. Tocca il menu (⋮) sul post e seleziona "Segnala". Sceglie una categoria (es. "Bullismo") e conferma. Il sistema registra la segnalazione anonimamente e mostra conferma all'utente.

**Why this priority**: Requisito critico Apple - senza sistema di segnalazione l'app viene rifiutata. Fondamentale per la sicurezza degli utenti minorenni.

**Independent Test**: Può essere testato creando un post di test, segnalando e verificando che la segnalazione arrivi al sistema di moderazione.

**Acceptance Scenarios**:

1. **Given** un utente autenticato visualizza un post, **When** tocca menu → "Segnala" → seleziona categoria → conferma, **Then** la segnalazione viene salvata e l'utente vede messaggio di conferma
2. **Given** un utente ha segnalato un contenuto, **When** visualizza lo stesso contenuto, **Then** vede indicazione che è già stato segnalato (non può segnalare due volte)
3. **Given** un utente segnala un contenuto, **When** il proprietario del contenuto visualizza il proprio post, **Then** non vede alcuna indicazione della segnalazione (anonimato)

---

### User Story 2 - Bloccare un Utente (Priority: P1)

Un utente riceve messaggi molesti da un altro utente. Va sul profilo dell'utente molesto, tocca menu → "Blocca". Conferma il blocco. Immediatamente tutti i contenuti dell'utente bloccato spariscono dal suo feed e l'utente bloccato non può più contattarlo.

**Why this priority**: Requisito critico Apple - il blocco deve rimuovere immediatamente i contenuti dal feed e notificare lo sviluppatore.

**Independent Test**: Può essere testato bloccando un utente di test e verificando che i suoi contenuti non appaiano più nel feed.

**Acceptance Scenarios**:

1. **Given** un utente visualizza il profilo di un altro utente, **When** tocca menu → "Blocca" → conferma, **Then** l'utente viene bloccato e i suoi contenuti spariscono dal feed
2. **Given** un utente ha bloccato un altro utente, **When** l'utente bloccato cerca di inviare un messaggio, **Then** il messaggio non viene consegnato
3. **Given** un utente ha bloccato un altro utente, **When** l'utente bloccato cerca di visualizzare il profilo del bloccante, **Then** vede messaggio "Profilo non disponibile"
4. **Given** un utente blocca qualcuno, **When** il blocco viene effettuato, **Then** il sistema notifica i moderatori/sviluppatori del blocco
5. **Given** un utente ha bloccato qualcuno, **When** l'utente bloccato usa l'app, **Then** NON riceve alcuna notifica di essere stato bloccato

---

### User Story 3 - Accettare Terms of Service (Priority: P1)

Un nuovo utente completa la registrazione. Prima di poter creare qualsiasi contenuto (post, commenti, messaggi), deve accettare i Terms of Service che includono la policy di tolleranza zero per contenuti offensivi.

**Why this priority**: Requisito Apple - EULA obbligatoria con tolleranza zero per contenuti offensivi.

**Independent Test**: Può essere testato registrando un nuovo utente e verificando che non possa postare senza accettare i ToS.

**Acceptance Scenarios**:

1. **Given** un utente ha completato la registrazione, **When** tenta di creare il primo post, **Then** viene mostrata la schermata di accettazione ToS
2. **Given** un utente visualizza i ToS, **When** legge e accetta, **Then** può procedere a creare contenuti
3. **Given** un utente non ha accettato i ToS, **When** tenta di commentare o inviare messaggi, **Then** viene bloccato e mostrata la schermata ToS
4. **Given** i ToS vengono aggiornati, **When** un utente esistente accede all'app, **Then** deve ri-accettare i nuovi ToS

---

### User Story 4 - Moderazione Segnalazioni (Priority: P2)

Un moderatore accede alla dashboard di moderazione. Vede la lista delle segnalazioni ordinate per data. Può visualizzare i dettagli di ogni segnalazione, il contenuto segnalato, e prendere azioni: rimuovi contenuto, avvisa utente, sospendi utente, banna utente.

**Why this priority**: Necessario per rispettare il requisito Apple di azione entro 24h. Può essere una web dashboard inizialmente.

**Independent Test**: Può essere testato creando segnalazioni di test e verificando che appaiano nella dashboard con tutte le azioni disponibili.

**Acceptance Scenarios**:

1. **Given** un moderatore accede alla dashboard, **When** visualizza la lista segnalazioni, **Then** vede tutte le segnalazioni pending ordinate per data (più vecchie prima)
2. **Given** un moderatore visualizza una segnalazione, **When** sceglie "Rimuovi contenuto", **Then** il contenuto viene rimosso e la segnalazione marcata come risolta
3. **Given** un moderatore visualizza una segnalazione, **When** sceglie "Banna utente", **Then** l'utente viene bannato e non può più accedere all'app
4. **Given** una segnalazione è pending da più di 20 ore, **When** il moderatore visualizza la dashboard, **Then** vede un warning visivo che indica urgenza

---

### User Story 5 - Filtro Contenuti Automatico (Priority: P2)

Un utente scrive un post contenente parole offensive. Il sistema rileva le parole vietate e blocca la pubblicazione, mostrando un messaggio che invita a modificare il contenuto.

**Why this priority**: Supporta la moderazione automatica ma non è bloccante per Apple se presente il sistema manuale.

**Independent Test**: Può essere testato tentando di postare contenuti con parole nella blacklist.

**Acceptance Scenarios**:

1. **Given** un utente scrive un post con parola vietata, **When** tenta di pubblicare, **Then** il post viene bloccato e l'utente vede messaggio "Il contenuto contiene linguaggio non consentito"
2. **Given** un utente scrive un messaggio chat con parola vietata, **When** tenta di inviare, **Then** il messaggio viene bloccato
3. **Given** un moderatore aggiorna la lista parole vietate, **When** la lista viene salvata, **Then** il filtro si applica immediatamente ai nuovi contenuti

---

### User Story 6 - Sbloccare un Utente (Priority: P3)

Un utente ha bloccato qualcuno per errore. Va nelle impostazioni → "Utenti bloccati", trova l'utente e tocca "Sblocca". L'utente viene sbloccato e i suoi contenuti riappaiono nel feed.

**Why this priority**: Funzionalità complementare, non richiesta esplicitamente da Apple ma necessaria per UX completa.

**Independent Test**: Può essere testato bloccando e poi sbloccando un utente, verificando che i contenuti riappaiano.

**Acceptance Scenarios**:

1. **Given** un utente ha bloccato qualcuno, **When** va in Impostazioni → Utenti bloccati, **Then** vede la lista degli utenti bloccati
2. **Given** un utente visualizza la lista bloccati, **When** tocca "Sblocca" su un utente, **Then** l'utente viene sbloccato e i suoi contenuti riappaiono

---

### Edge Cases

- Cosa succede quando un utente segnala un contenuto già rimosso? → Mostrare messaggio "Contenuto non più disponibile"
- Cosa succede quando un utente bloccato tenta di menzionare (@) il bloccante? → La menzione non viene notificata
- Cosa succede quando un moderatore è anche l'autore del contenuto segnalato? → Non può moderare le proprie segnalazioni
- Cosa succede quando un utente bannato tenta di registrarsi nuovamente? → Il ban è legato all'email, nuovo account bloccato
- Cosa succede se la lista parole vietate è vuota? → Il filtro è disabilitato, tutti i contenuti passano

## Requirements *(mandatory)*

### Functional Requirements

#### Report System
- **FR-001**: Sistema DEVE permettere di segnalare post, commenti, messaggi chat e profili
- **FR-002**: Sistema DEVE offrire categorie predefinite: Spam, Contenuto offensivo, Bullismo, Contenuto inappropriato, Altro
- **FR-003**: Sistema DEVE permettere una nota opzionale (max 500 caratteri) nella segnalazione
- **FR-004**: Sistema DEVE mantenere anonima l'identità del segnalante verso l'utente segnalato
- **FR-005**: Sistema DEVE impedire segnalazioni duplicate dallo stesso utente sullo stesso contenuto
- **FR-006**: Sistema DEVE tracciare timestamp, reporter, contenuto, categoria e stato di ogni segnalazione

#### Block System
- **FR-007**: Sistema DEVE permettere di bloccare utenti dal loro profilo
- **FR-008**: Sistema DEVE rimuovere immediatamente (< 1 secondo) tutti i contenuti dell'utente bloccato dal feed del bloccante
- **FR-009**: Sistema DEVE impedire all'utente bloccato di inviare messaggi al bloccante
- **FR-010**: Sistema DEVE impedire all'utente bloccato di visualizzare il profilo del bloccante
- **FR-011**: Sistema DEVE notificare moderatori/sviluppatori quando avviene un blocco
- **FR-012**: Sistema NON DEVE notificare l'utente bloccato del blocco
- **FR-013**: Sistema DEVE permettere di sbloccare utenti precedentemente bloccati
- **FR-014**: Sistema DEVE ripristinare la visibilità dei contenuti dopo lo sblocco

#### EULA/ToS
- **FR-015**: Sistema DEVE richiedere accettazione ToS prima della creazione di qualsiasi contenuto
- **FR-016**: I ToS DEVONO includere clausola esplicita di tolleranza zero per contenuti offensivi
- **FR-017**: Sistema DEVE tracciare versione ToS accettata e timestamp per ogni utente
- **FR-018**: Sistema DEVE richiedere ri-accettazione quando i ToS vengono aggiornati

#### Content Filtering
- **FR-019**: Sistema DEVE filtrare testi in tempo reale durante la composizione
- **FR-020**: Sistema DEVE mantenere una lista configurabile di parole/pattern vietati
- **FR-021**: Sistema DEVE bloccare la pubblicazione di contenuti con parole vietate
- **FR-022**: Sistema DEVE mostrare messaggio user-friendly quando il contenuto viene bloccato

#### Moderation Dashboard
- **FR-023**: Dashboard DEVE mostrare lista segnalazioni con filtri per stato e categoria
- **FR-024**: Dashboard DEVE evidenziare segnalazioni vicine alla scadenza 24h
- **FR-025**: Dashboard DEVE permettere azioni: Rimuovi contenuto, Avvisa utente, Sospendi utente, Banna utente
- **FR-026**: Dashboard DEVE tracciare chi ha preso l'azione e quando
- **FR-027**: Dashboard DEVE inviare email automatica all'utente quando il suo contenuto viene rimosso

### Key Entities

- **Report**: Segnalazione con reporter_id, content_type, content_id, category, note, status, created_at, resolved_at, resolved_by
- **Block**: Relazione di blocco con blocker_id, blocked_id, created_at, notified_moderator
- **ToSAcceptance**: Accettazione ToS con user_id, tos_version, accepted_at
- **BannedWord**: Parola vietata con word, pattern_type (exact/contains/regex), severity, created_by
- **UserSanction**: Sanzione utente con user_id, type (warning/suspension/ban), reason, issued_by, issued_at, expires_at

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% dei contenuti (post, commenti, chat, profili) hanno opzione "Segnala" accessibile in max 2 tap
- **SC-002**: I contenuti degli utenti bloccati spariscono dal feed in meno di 1 secondo
- **SC-003**: 100% delle segnalazioni vengono gestite entro 24 ore dalla creazione
- **SC-004**: 0 utenti possono creare contenuti senza aver accettato i ToS
- **SC-005**: Il filtro contenuti blocca il 100% delle parole nella blacklist configurata
- **SC-006**: I moderatori ricevono notifica entro 5 minuti da ogni nuovo blocco utente
- **SC-007**: La dashboard mostra warning visivo per segnalazioni pending da più di 20 ore

## Assumptions

- La moderazione sarà gestita manualmente dal team Nova (no AI moderation inizialmente)
- La lista parole vietate sarà in italiano, con possibilità di aggiungere altre lingue in futuro
- La dashboard di moderazione sarà web-based, accessibile solo a utenti con ruolo moderatore
- I ToS saranno un documento statico hostato, non generato dinamicamente
- Le notifiche ai moderatori saranno via email (possibile integrazione Slack futura)
- Il ban è permanente a meno di appello manuale

## Out of Scope

- Moderazione automatica con AI/ML
- Appello automatizzato per utenti bannati
- Sistema di reputazione utenti
- Moderazione contenuti multimediali (solo testo nella v1)
- Integrazione con servizi esterni di content moderation
