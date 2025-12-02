# Feature Specification: Push Notifications

**Feature Branch**: `009-push-notifications`
**Created**: 2025-11-30
**Status**: Draft
**Input**: User description: "Push notifications per Nova: integrare FCM per inviare notifiche push quando l'app è chiusa. Registrazione FCM token al login/startup, salvataggio token in profiles table, Supabase Edge Function che riceve webhook da database trigger e chiama FCM API, gestione permessi iOS (APNs) e Android, badge count su app icon, tap su notifica apre target (evento/commento), rispetto preferenze utente (se canale disabilitato, no push), silent notifications per aggiornare badge count. Supporto foreground/background/terminated states. Success criteria: 95%+ push delivered entro 5 secondi, zero notifiche duplicate, deep link funzionante da push."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ricevere Push con App Chiusa (Priority: P1) 🎯 MVP

Come studente con l'app chiusa, quando qualcuno commenta sul mio evento, voglio ricevere una notifica push sul mio dispositivo così posso essere informato anche senza aprire l'app.

**Why this priority**: Questo è il core value della feature - informare gli utenti di attività importanti quando non stanno usando l'app. Senza questo, la feature non ha senso.

**Independent Test**: Chiudere completamente l'app, generare un evento che crea una notifica (es. commento su evento), verificare che il dispositivo riceva la push notification entro 5 secondi.

**Acceptance Scenarios**:

1. **Given** studente con app installata e permessi notifiche concessi, **When** qualcuno commenta sul suo evento mentre l'app è chiusa, **Then** riceve push notification sul dispositivo entro 5 secondi
2. **Given** studente con app in background, **When** il suo evento viene approvato, **Then** riceve push notification con titolo "Evento Approvato! 🎉"
3. **Given** studente con app terminata (killed), **When** riceve una push notification, **Then** il badge dell'app mostra il conteggio notifiche non lette

---

### User Story 2 - Navigazione da Push a Contenuto (Priority: P1)

Come studente che riceve una push notification, quando tocco la notifica, voglio essere portato direttamente al contenuto rilevante (evento o commento) così posso vedere i dettagli senza cercare.

**Why this priority**: Senza deep linking funzionante, le push sono solo alert senza azione - l'utente deve cercare manualmente il contenuto, causando frustrazione.

**Independent Test**: Ricevere push notification con app chiusa, toccare la notifica, verificare che l'app si apra direttamente sulla schermata del target (evento o commento).

**Acceptance Scenarios**:

1. **Given** push notification per "nuovo commento su evento X", **When** utente tocca la notifica con app chiusa, **Then** l'app si apre direttamente sulla schermata dell'evento X con commenti visibili
2. **Given** push notification per "evento approvato", **When** utente tocca la notifica con app in background, **Then** l'app naviga alla schermata dettaglio dell'evento approvato
3. **Given** push notification per "risposta al tuo commento", **When** utente tocca la notifica, **Then** l'app naviga all'evento con il commento evidenziato

---

### User Story 3 - Gestione Permessi Notifiche (Priority: P1)

Come studente al primo avvio dell'app (o dopo aggiornamento), quando mi viene chiesto il permesso per le notifiche, voglio capire perché dovrei concederlo così posso prendere una decisione informata.

**Why this priority**: Senza permessi concessi, nessuna push può essere inviata. Una richiesta permessi chiara aumenta il tasso di accettazione.

**Independent Test**: Installare app su dispositivo nuovo, avviare app, verificare che appaia dialog permessi con spiegazione chiara del valore delle notifiche.

**Acceptance Scenarios**:

1. **Given** primo avvio app dopo installazione, **When** l'app richiede permessi notifiche, **Then** mostra dialog con spiegazione chiara ("Ricevi aggiornamenti sui tuoi eventi...")
2. **Given** utente che nega permessi, **When** successivamente vuole abilitarli, **Then** può farlo dalle impostazioni dell'app con link diretto alle impostazioni sistema
3. **Given** utente iOS, **When** l'app richiede permessi, **Then** la richiesta segue le linee guida Apple con opzioni Alert, Badge, Sound

---

### User Story 4 - Rispetto Preferenze Utente (Priority: P2)

Come studente che ha disabilitato le notifiche per "Like agli eventi" nelle impostazioni, quando qualcuno mette like al mio evento, non voglio ricevere push notification per quel tipo di attività.

**Why this priority**: Rispettare le preferenze utente è fondamentale per la privacy e per evitare notifiche spam. Implementabile dopo il flusso base.

**Independent Test**: Disabilitare notifiche "Like agli eventi" nelle preferenze, generare un like su un evento dell'utente, verificare che NON arrivi push notification.

**Acceptance Scenarios**:

1. **Given** utente con "nuovi_commenti_enabled = false", **When** qualcuno commenta sul suo evento, **Then** NON riceve push notification
2. **Given** utente con "eventi_moderati_enabled = true", **When** il suo evento viene approvato, **Then** riceve push notification normalmente
3. **Given** utente che disabilita tutte le preferenze, **When** si verificano eventi che normalmente genererebbero notifiche, **Then** non riceve nessuna push

---

### User Story 5 - Notifiche in Foreground (Priority: P2)

Come studente che sta usando l'app, quando ricevo una notifica mentre l'app è aperta, voglio vedere un banner discreto così sono informato senza interrompere la mia attività.

**Why this priority**: Migliora l'esperienza utente mostrando notifiche in modo non invasivo quando l'app è già in uso.

**Independent Test**: Con app aperta in foreground, generare evento che crea notifica, verificare che appaia banner/toast discreto nella parte superiore dello schermo.

**Acceptance Scenarios**:

1. **Given** app aperta sulla schermata eventi, **When** arriva notifica per nuovo commento, **Then** appare banner nella parte alta dello schermo per 4 secondi
2. **Given** banner notifica visibile, **When** utente tocca il banner, **Then** naviga al contenuto della notifica
3. **Given** banner notifica visibile, **When** utente swipa via il banner, **Then** il banner scompare e la notifica resta nell'elenco notifiche

---

### User Story 6 - Aggiornamento Badge Count (Priority: P3)

Come studente, quando ho notifiche non lette, voglio vedere il badge sull'icona dell'app così so che ci sono novità anche senza aprire l'app.

**Why this priority**: Feature "nice to have" che migliora la visibilità delle notifiche ma non è critica per il funzionamento base.

**Independent Test**: Generare 3 notifiche per un utente, verificare che il badge dell'app mostri "3", aprire e leggere le notifiche, verificare che il badge si azzeri.

**Acceptance Scenarios**:

1. **Given** utente con 5 notifiche non lette, **When** guarda l'icona app sulla home screen, **Then** vede badge con numero "5"
2. **Given** utente che legge tutte le notifiche nell'app, **When** torna alla home screen, **Then** il badge scompare
3. **Given** silent push per aggiornare badge count, **When** nuova notifica arriva, **Then** badge si incrementa senza mostrare alert

---

### Edge Cases

- **Token FCM scaduto/invalido**: Il sistema deve gestire token non più validi rimuovendoli e richiedendo nuovo token al prossimo avvio app
- **Dispositivo offline**: Le notifiche devono essere consegnate quando il dispositivo torna online (gestito da FCM)
- **Notifica per contenuto eliminato**: Se l'utente tocca notifica per evento/commento eliminato, mostrare messaggio "Contenuto non più disponibile"
- **Utente disconnesso**: Dopo logout, il token FCM deve essere invalidato/rimosso per non ricevere notifiche
- **Cambio dispositivo**: Utente che accede da nuovo dispositivo deve registrare nuovo token, il vecchio deve essere rimosso
- **Rate limiting**: Evitare flood di notifiche - max 1 notifica per tipo per evento in finestra temporale
- **App reinstallata**: Nuovo token FCM deve essere registrato automaticamente

## Requirements *(mandatory)*

### Functional Requirements

#### Token Management
- **FR-001**: Sistema DEVE registrare il token FCM del dispositivo al login/startup dell'app
- **FR-002**: Sistema DEVE salvare il token FCM associato al profilo utente nel database
- **FR-003**: Sistema DEVE aggiornare il token FCM quando cambia (token refresh)
- **FR-004**: Sistema DEVE rimuovere il token FCM al logout dell'utente
- **FR-005**: Sistema DEVE supportare multipli token per utente (multi-device)

#### Push Delivery
- **FR-006**: Sistema DEVE inviare push notification quando viene creata una notifica nel database
- **FR-007**: Sistema DEVE rispettare le preferenze utente (canali disabilitati = no push per quel tipo)
- **FR-008**: Sistema DEVE includere payload per deep linking (target_type, target_id)
- **FR-009**: Sistema DEVE supportare notifiche su iOS tramite APNs e Android tramite FCM
- **FR-010**: Sistema DEVE gestire i tre stati dell'app: foreground, background, terminated

#### Deep Linking
- **FR-011**: Sistema DEVE navigare al contenuto corretto quando utente tocca notifica
- **FR-012**: Sistema DEVE gestire deep link per tipo "event" (apre EventDetailScreen)
- **FR-013**: Sistema DEVE gestire deep link per tipo "comment" (apre EventDetailScreen con scroll a commento)
- **FR-014**: Sistema DEVE mostrare errore appropriato se il contenuto target non esiste più

#### Badge Management
- **FR-015**: Sistema DEVE aggiornare il badge count dell'app icon con numero notifiche non lette
- **FR-016**: Sistema DEVE azzerare il badge quando l'utente legge tutte le notifiche
- **FR-017**: Sistema DEVE supportare silent push per aggiornare solo il badge count

#### Permission Handling
- **FR-018**: Sistema DEVE richiedere permessi notifiche con spiegazione chiara del valore
- **FR-019**: Sistema DEVE fornire link a impostazioni sistema per utenti che hanno negato permessi
- **FR-020**: Sistema DEVE gestire gracefully il caso di permessi negati (app funziona senza push)

### Key Entities

- **FCM Token**: Identificatore univoco del dispositivo per ricevere push, associato a user_id, con timestamp di creazione/aggiornamento
- **Push Payload**: Struttura dati inviata con la push contenente: title, body, target_type, target_id, notification_id, badge_count
- **Permission State**: Stato dei permessi notifiche (granted, denied, not_determined) per gestire UI appropriata

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 95% delle push notification vengono consegnate entro 5 secondi dalla creazione della notifica nel database
- **SC-002**: Zero notifiche duplicate ricevute dallo stesso utente per lo stesso evento
- **SC-003**: 100% delle notifiche toccate navigano correttamente al contenuto target (o mostrano errore appropriato se eliminato)
- **SC-004**: Tasso di accettazione permessi notifiche superiore all'80% al primo prompt
- **SC-005**: Badge count accurato al 100% (corrisponde sempre al numero effettivo di notifiche non lette)
- **SC-006**: Supporto completo per tutti e tre gli stati app (foreground, background, terminated) su iOS e Android
- **SC-007**: Rispetto 100% delle preferenze utente (canale disabilitato = zero push per quel canale)

## Assumptions

- Firebase Cloud Messaging (FCM) è già configurato nel progetto (firebase_core e firebase_messaging presenti in pubspec.yaml)
- Il sistema di notifiche in-app (008-realtime-notifications) è già implementato con tabella notifications e preferenze utente
- Deep linking base è già implementato per la navigazione agli eventi
- APNs certificates per iOS sono configurati nel progetto Firebase
