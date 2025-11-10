# Feature Specification: Event Creation and Moderation System

**Feature Branch**: `004-event-creation-moderation`
**Created**: 2025-01-09
**Status**: Draft
**Input**: User description: "Crea evento e sistema di moderazione - Sistema completo per la creazione di eventi scolastici da parte degli studenti con workflow di moderazione obbligatoria prima della pubblicazione."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Student Creates School Event (Priority: P1)

Un studente desidera organizzare un evento scolastico (es. torneo calcetto, festa di classe, gruppo studio) e deve poterlo creare rapidamente compilando un form semplice con le informazioni essenziali: titolo, descrizione, quando e dove si svolge, e opzionalmente un'immagine per renderlo più attraente. Il form deve essere veloce da completare (<2 minuti) per rispettare l'attenzione limitata dei teenager.

**Why this priority**: Questa è la funzionalità core che abilita tutto il value loop. Senza la capacità di creare eventi, gli studenti non possono utilizzare la piattaforma per organizzare attività scolastiche. È il punto di partenza indispensabile.

**Independent Test**: Può essere testato completamente permettendo a uno studente autenticato di accedere al form di creazione evento, compilare i campi obbligatori (titolo, descrizione, data/ora) e opzionalmente luogo e immagine, e salvare. Il sistema deve salvare l'evento con status 'pending' e mostrare conferma visiva all'utente.

**Acceptance Scenarios**:

1. **Given** uno studente autenticato è sulla home feed, **When** preme il bottone "+" (central FAB) nella bottom navigation, **Then** si apre il form di creazione evento con 5 campi: titolo, descrizione, data/ora, luogo, immagine (opzionale)

2. **Given** lo studente sta compilando il form, **When** inserisce un titolo di 90 caratteri e una descrizione di 300 caratteri, **Then** il form accetta entrambi i valori senza errori

3. **Given** lo studente ha compilato tutti i campi obbligatori (titolo, descrizione, data/ora), **When** preme "Crea Evento", **Then** l'evento viene salvato con status='pending' e appare un messaggio "Evento creato! Sarà visibile dopo l'approvazione del moderatore"

4. **Given** lo studente seleziona un'immagine da galleria/camera, **When** l'immagine supera 200KB, **Then** il sistema la comprime automaticamente a max 200KB mantenendo proporzioni 16:9 (800x450px)

5. **Given** lo studente inserisce una data evento nel passato, **When** prova a salvare, **Then** appare errore "La data dell'evento deve essere futura"

6. **Given** lo studente perde connessione durante la compilazione, **When** torna online, **Then** il form draft è ancora presente con tutti i dati inseriti (offline-first)

---

### User Story 2 - Student Tracks Event Status and Receives Notifications (Priority: P1)

Uno studente che ha creato un evento deve poter vedere in ogni momento lo stato di moderazione del suo evento (pending/approved/rejected) con visual feedback chiaro (colori e icone). In caso di approvazione o rifiuto, deve ricevere una notifica push istantanea per essere informato senza dover controllare manualmente l'app.

**Why this priority**: La trasparenza del processo di moderazione è fondamentale per la fiducia degli studenti nella piattaforma. Senza visibilità dello stato e notifiche tempestive, gli studenti perderebbero interesse e non capirebbero se i loro eventi sono stati pubblicati.

**Independent Test**: Può essere testato creando un evento come studente, verificando che appaia nella sezione "I Miei Eventi" con badge giallo "In Revisione", poi facendo approvare/rifiutare l'evento da un moderatore e verificando che: (1) lo status cambi visualmente (verde/rosso), (2) arrivi notifica push entro 30 secondi, (3) in caso di rifiuto il motivo sia visibile.

**Acceptance Scenarios**:

1. **Given** uno studente ha creato un evento, **When** va nella sezione "Profilo" → "I Miei Eventi", **Then** vede l'evento con badge giallo "In Revisione" e icona orologio

2. **Given** un moderatore approva l'evento dello studente, **When** l'approvazione viene salvata, **Then** lo studente riceve notifica push "✅ Evento '[titolo]' approvato! È ora visibile a tutti" entro 30 secondi

3. **Given** un moderatore rifiuta l'evento con motivo "Descrizione troppo vaga", **When** il rifiuto viene salvato, **Then** lo studente riceve notifica push "❌ Evento '[titolo]' non approvato" e vede il motivo nel dettaglio evento con badge rosso

4. **Given** lo studente ha disattivato le notifiche push per "Eventi Propri" nelle impostazioni, **When** il suo evento viene approvato, **Then** NON riceve notifica push ma vede comunque lo status aggiornato in app

---

### User Story 3 - Moderator Reviews and Approves/Rejects Events (Priority: P1)

Un moderatore (docente o studente rappresentante) deve poter vedere una coda ordinata di eventi pending da revisionare (più vecchi prima), approvarli con un singolo tap se appropriati, oppure rifiutarli fornendo una motivazione obbligatoria che spiega allo studente perché l'evento non è stato approvato. Il moderatore deve anche vedere statistiche giornaliere per monitorare il carico di lavoro.

**Why this priority**: La moderazione è il controllo qualità che garantisce che solo contenuti appropriati vengano pubblicati. Senza questo workflow, la piattaforma violerebbe il principio CONTENT_MODERATION della constitution e rischierebbe di pubblicare contenuti inappropriati.

**Independent Test**: Può essere testato completamente assegnando ruolo moderatore a un utente, facendo creare 3 eventi da studenti, e verificando che il moderatore veda la coda pending, possa approvare con single tap, possa rifiutare inserendo motivo obbligatorio, e veda badge con count pending + statistiche giornaliere.

**Acceptance Scenarios**:

1. **Given** un moderatore autenticato, **When** va nella sezione "Moderazione", **Then** vede lista eventi pending ordinati dal più vecchio, con preview: immagine, titolo, descrizione (prime 2 righe), data evento, creator name

2. **Given** il moderatore vede un evento appropriato nella coda, **When** swipe right o tap su "Approva", **Then** l'evento cambia status='approved' e scompare dalla coda, il creator riceve notifica

3. **Given** il moderatore vede un evento inappropriato, **When** swipe left o tap su "Rifiuta", **Then** appare dialog con campo testo obbligatorio "Motivo rifiuto" (min 10 caratteri)

4. **Given** il moderatore ha rifiutato inserendo motivo "Descrizione contiene insulti", **When** conferma, **Then** evento cambia status='rejected', creator riceve notifica con motivo visibile

5. **Given** ci sono 7 eventi pending, **When** il moderatore apre l'app, **Then** vede badge rosso con numero "7" sull'icona notifica e nella tab "Moderazione"

6. **Given** il moderatore va nella sezione "Statistiche" oggi alle 20:00, **When** visualizza il dashboard, **Then** vede: "Eventi approvati oggi: 12", "Eventi rifiutati oggi: 3", "Tempo medio moderazione: 45 secondi"

---

### User Story 4 - Student Shares Event via Deep Link (Priority: P2)

Uno studente che vede un evento approvato interessante deve poter condividerlo facilmente con amici tramite il bottone "Condividi" che genera un deep link univoco. Quando un amico clicca il link, l'app Nova si apre direttamente sulla pagina dettaglio di quell'evento (se l'app è installata), oppure mostra una pagina web con prompt per scaricare l'app.

**Why this priority**: La condivisione virale è il meccanismo di crescita organica della piattaforma. Più studenti condividono eventi interessanti, più altri studenti vengono attratti nell'ecosistema Nova. È P2 perché non blocca l'utilizzo base ma amplifica significativamente il valore.

**Independent Test**: Può essere testato completamente aprendo un evento approved, tappando "Condividi", copiando il link generato (nova://events/[id]), inviandolo via WhatsApp a un altro device con Nova installato, e verificando che l'app si apra direttamente su Event Detail Screen.

**Acceptance Scenarios**:

1. **Given** uno studente visualizza un evento approved nel feed, **When** tap sull'icona "Condividi" nel dettaglio evento, **Then** si apre lo share sheet nativo iOS/Android con deep link `nova://events/{event_id}`

2. **Given** uno studente riceve il link nova://events/ABC123 via WhatsApp, **When** tap sul link e ha Nova installato, **Then** l'app si apre e naviga direttamente all'Event Detail Screen dell'evento ABC123

3. **Given** uno studente riceve il link ma NON ha Nova installato, **When** tap sul link, **Then** si apre pagina web temporanea con: immagine evento, titolo, descrizione (prime 3 righe), bottone "Scarica NOVA" che reindirizza agli store iOS/Android

4. **Given** uno studente condivide un evento via share sheet, **When** seleziona "WhatsApp" come destinazione, **Then** il messaggio contiene il deep link cliccabile + anteprima immagine evento (se supportato dalla piattaforma)

---

### User Story 5 - Student Adds Co-Organizers to Event (Priority: P2)

Uno studente creator di un evento deve poter aggiungere fino a 3 co-organizers (altri studenti) che possono modificare i dettagli dell'evento (titolo, descrizione, data, immagine) insieme al creator. I co-organizers ricevono notifica quando vengono aggiunti e quando qualcuno modifica l'evento. Se un co-organizer modifica un evento già approvato, l'evento torna automaticamente in pending per nuova moderazione.

**Why this priority**: Molti eventi scolastici sono organizzati da gruppi di studenti (es. rappresentanti di classe, gruppi studio). Permettere collaborazione riduce friction organizzativa e migliora la qualità degli eventi. È P2 perché eventi possono essere creati anche da singoli, ma la collaborazione aumenta engagement.

**Independent Test**: Può essere testato completamente creando un evento come studente A, aggiungendo studente B come co-organizer, verificando che B riceva notifica, che B possa modificare l'evento, che A riceva notifica della modifica, e che se l'evento era approved torni in pending dopo la modifica di B.

**Acceptance Scenarios**:

1. **Given** uno studente ha creato un evento, **When** va in Edit Event e tap su "Aggiungi Co-Organizer", **Then** appare search field dove può cercare studenti per nome/classe (max 3 co-organizers)

2. **Given** lo studente ha selezionato "Mario Rossi" come co-organizer, **When** conferma, **Then** Mario riceve notifica push "Giovanni ti ha aggiunto come co-organizer dell'evento '[titolo]'" e vede l'evento nella sua lista "Eventi Organizzati"

3. **Given** Mario è co-organizer, **When** modifica la descrizione dell'evento e salva, **Then**: (1) Giovanni riceve notifica "Mario ha modificato l'evento '[titolo]'", (2) se evento era approved, status torna a 'pending' per nuova moderazione

4. **Given** Mario è co-organizer, **When** prova a rimuovere Giovanni (creator originale) dalla lista organizers, **Then** il sistema blocca l'azione con messaggio "Solo il creator originale può essere rimosso"

5. **Given** Giovanni è creator, **When** rimuove Mario da co-organizers, **Then** Mario riceve notifica "Giovanni ti ha rimosso come co-organizer dell'evento '[titolo]'" e l'evento scompare dalla sua lista "Eventi Organizzati"

---

### Edge Cases

- **Cosa succede se uno studente carica un'immagine di 5MB?** Il sistema la comprime automaticamente lato client a max 200KB (WebP) prima dell'upload, mantenendo dimensioni 800x450px (16:9). Se la compressione fallisce, mostra errore "Immagine troppo grande, riduci dimensioni o scegli un'altra foto".

- **Cosa succede se un moderatore approva un evento la cui data è già passata?** Il sistema impedisce l'approvazione mostrando alert "Impossibile approvare: data evento già trascorsa. Suggerisci al creator di aggiornare la data."

- **Cosa succede se uno studente modifica un evento pending?** L'evento rimane pending (non resetta la coda), il moderatore vede la versione aggiornata. Se modifica un evento rejected, può risottometterlo (torna pending).

- **Cosa succede se la connessione cade durante l'upload dell'immagine?** Il sistema salva il form draft in locale (Hive), quando torna online mostra dialog "Riprendere upload immagine?" con opzioni [Riprendi] [Scegli Altra Immagine] [Continua Senza Immagine].

- **Cosa succede se un moderatore riceve 50 nuovi eventi pending in un giorno?** Invece di 50 notifiche push separate, riceve 1 singola notifica batch "15 nuovi eventi da moderare" (max 1 al giorno per evitare spam, come da principle PERFORMANCE_FIRST).

- **Cosa succede se un co-organizer viene eliminato come studente dall'app (GDPR)?** Il sistema rimuove automaticamente il suo user_id dall'array co_organizers di tutti gli eventi, senza invalidare gli eventi stessi.

- **Cosa succede se uno studente prova a creare un evento con titolo "aaa" o descrizione vuota?** Il form mostra errori di validazione real-time: "Titolo troppo corto (min 5 caratteri)" e "Descrizione richiesta (min 20 caratteri)" e disabilita il bottone "Crea Evento" finché non sono validi.

- **Cosa succede se un deep link punta a un evento eliminato o rejected?** L'app mostra schermata "Evento non disponibile" con bottone "Torna al Feed". Se l'evento è pending e l'utente non è creator/co-organizer, mostra "Evento in attesa di moderazione".

- **Come viene assegnato il ruolo di moderatore?** Per il soft launch, l'amministratore scolastico assegna manualmente il ruolo tramite Supabase dashboard (UPDATE users SET role='moderator' WHERE email='docente@galileimoro.edu.it'). Non esiste workflow in-app per richiedere il ruolo moderatore in questa versione. Una futura feature separata (admin panel) gestirà richieste di moderazione, approvazioni, e gestione ruoli utenti.

## Requirements *(mandatory)*

### Functional Requirements

#### Event Creation (Student)

- **FR-001**: Il sistema DEVE permettere agli studenti autenticati di creare eventi compilando un form con 5 campi: titolo (obbligatorio, 5-100 caratteri), descrizione (obbligatorio, 20-500 caratteri), data/ora evento (obbligatorio, futuro), luogo (opzionale, testo libero), immagine (opzionale)

- **FR-002**: Il sistema DEVE salvare automaticamente tutti gli eventi creati con status iniziale='pending' (non visibili nel feed pubblico fino ad approvazione)

- **FR-003**: Il sistema DEVE validare in real-time i campi del form e mostrare errori chiari: "Titolo troppo corto/lungo", "Descrizione troppo corta/lunga", "La data deve essere futura", "Campo obbligatorio"

- **FR-004**: Il sistema DEVE permettere upload immagini da camera o galleria, con compressione automatica lato client a max 200KB, formato WebP (preferito) con fallback JPEG se piattaforma non supporta WebP o compressione fallisce, dimensioni 800x450px (16:9)

- **FR-005**: Il sistema DEVE rimuovere tutti i metadata EXIF dalle immagini caricate (privacy: nessuna geolocalizzazione o info dispositivo)

- **FR-006**: Il sistema DEVE salvare il form draft in locale (offline-first) se l'utente perde connessione, e sincronizzare quando torna online

- **FR-007**: Il sistema DEVE completare il processo di upload immagine + creazione evento in <3 secondi su connessione 4G (performance budget)

#### Event Status Tracking (Student)

- **FR-008**: Il sistema DEVE mostrare nella sezione "Profilo" → "I Miei Eventi" tutti gli eventi creati dallo studente, con visual status chiaro: badge giallo "In Revisione" (pending), verde "Approvato" (approved), rosso "Rifiutato" (rejected)

- **FR-009**: Il sistema DEVE mostrare il rejection_reason nel dettaglio evento se status=rejected, con label "Motivo rifiuto:" seguita dal testo fornito dal moderatore

- **FR-010**: Il sistema DEVE inviare notifica push allo studente entro 30 secondi quando un suo evento viene approvato, con testo "✅ Evento '[titolo]' approvato! È ora visibile a tutti"

- **FR-011**: Il sistema DEVE inviare notifica push allo studente entro 30 secondi quando un suo evento viene rifiutato, con testo "❌ Evento '[titolo]' non approvato" (il motivo è visibile in-app, non nella notifica per brevità)

- **FR-012**: Il sistema DEVE rispettare le preferenze notifiche dell'utente: se ha disattivato "Eventi Propri" in Settings, non invia push per approval/rejection (ma aggiorna status in-app)

#### Moderation Queue (Moderator)

- **FR-013**: Il sistema DEVE mostrare ai moderatori una sezione "Moderazione" con lista eventi pending ordinati per created_at ASC (più vecchi prima, FIFO)

- **FR-014**: Il sistema DEVE mostrare per ogni evento pending: immagine preview, titolo, descrizione (prime 2 righe troncate), data evento, nome creator, timestamp creazione (es. "2 ore fa")

- **FR-015**: Il sistema DEVE permettere al moderatore di approvare un evento con singolo tap/swipe (azione rapida), cambiando immediatamente status='approved' e rimuovendolo dalla coda

- **FR-016**: Il sistema DEVE permettere al moderatore di rifiutare un evento, aprendo dialog con campo testo "Motivo rifiuto" (obbligatorio, min 10 caratteri), salvando il motivo in rejection_reason

- **FR-017**: Il sistema DEVE impedire approvazione di eventi la cui data è già passata, mostrando alert "Impossibile approvare: data evento già trascorsa"

- **FR-018**: Il sistema DEVE mostrare badge con count eventi pending sull'icona notifiche e nella tab "Moderazione" (es. badge rosso con numero "7")

- **FR-019**: Il sistema DEVE inviare notifica push ai moderatori quando arriva un nuovo evento pending, ma con batching: max 1 notifica al giorno con count aggregato (es. "5 nuovi eventi da moderare")

- **FR-020**: Il sistema DEVE mostrare statistiche giornaliere ai moderatori: "Eventi approvati oggi: X", "Eventi rifiutati oggi: Y", "Tempo medio moderazione: Z secondi"

#### Event Sharing (Student)

- **FR-021**: Il sistema DEVE mostrare bottone "Condividi" nel dettaglio di ogni evento con status='approved'

- **FR-022**: Il sistema DEVE generare deep link univoco nel formato `nova://events/{event_id}` quando studente tap su "Condividi"

- **FR-023**: Il sistema DEVE aprire lo share sheet nativo iOS/Android con il deep link, permettendo condivisione via WhatsApp, Instagram, Messages, etc.

- **FR-024**: Il sistema DEVE gestire deep link in entrata: se utente tap su `nova://events/{event_id}` con app installata, navigare direttamente a Event Detail Screen di quell'evento

- **FR-025**: Il sistema DEVE mostrare pagina web fallback (HTML statico ospitato su Supabase Storage) se utente tap su deep link senza app installata, con: immagine evento, titolo, descrizione (prime 3 righe), bottone "Scarica NOVA" → app stores (iOS/Android). La pagina usa JavaScript per recuperare dati evento via Supabase REST API

- **FR-026**: Il sistema DEVE gestire deep link a eventi non accessibili: se evento deleted/rejected e utente non è creator, mostrare "Evento non disponibile"; se evento pending e utente non è creator/co-organizer, mostrare "Evento in attesa di moderazione"

#### Co-Organizers (Student)

- **FR-027**: Il sistema DEVE permettere al creator di un evento di aggiungere co-organizers tramite search field (cerca per nome/classe), con limite massimo 3 co-organizers

- **FR-028**: Il sistema DEVE salvare i co_organizers come array di UUID nella tabella events, insieme al creator_id

- **FR-029**: Il sistema DEVE inviare notifica push ai co-organizers aggiunti: "[Creator] ti ha aggiunto come co-organizer dell'evento '[titolo]'"

- **FR-030**: Il sistema DEVE mostrare eventi con co-organizer nella sezione "Profilo" → "Eventi Organizzati" (insieme agli eventi created)

- **FR-031**: Il sistema DEVE permettere ai co-organizers di modificare: titolo, descrizione, data/ora, luogo, immagine (stessi permessi del creator)

- **FR-032**: Il sistema NON DEVE permettere ai co-organizers di: rimuovere il creator originale, cambiare status moderazione (approve/reject), eliminare l'evento

- **FR-033**: Il sistema DEVE riportare evento status='pending' per nuova moderazione se un co-organizer modifica un evento già approved

- **FR-034**: Il sistema DEVE inviare notifica push a tutti co-organizers e creator quando uno di loro modifica l'evento: "[Nome] ha modificato l'evento '[titolo]'"

- **FR-035**: Il sistema DEVE permettere al creator di rimuovere co-organizers, inviando notifica "[Creator] ti ha rimosso come co-organizer dell'evento '[titolo]'"

#### Push Notifications

- **FR-036**: Il sistema DEVE richiedere opt-in esplicito per notifiche push al primo avvio app, con schermata permissions che spiega chiaramente i 4 canali: Eventi Propri, Co-Organizer Updates, Moderazione (solo moderatori), General

- **FR-037**: Il sistema DEVE utilizzare canali notifiche separati: 'event_approved', 'event_rejected', 'new_pending_event' (moderatori), 'added_as_coorganizer', 'event_modified'

- **FR-038**: Il sistema DEVE permettere in Settings → Notifiche di disattivare selettivamente ogni canale (es. disattivare "Co-Organizer Updates" ma mantenere "Eventi Propri")

- **FR-039**: Il sistema DEVE garantire delivery rate >90% entro 30 secondi dall'evento trigger (verificabile via analytics FCM)

- **FR-040**: Il sistema DEVE implementare batching per moderatori: aggregare "new pending event" in 1 singola notifica al giorno con count (es. "5 nuovi eventi da moderare")

### Key Entities

- **Event**: Rappresenta un evento scolastico creato da studenti. Attributi chiave: id (UUID), titolo, descrizione, image_url, luogo, data_evento, creator_id (UUID studente creator), co_organizers (array UUID studenti), status ('pending'|'approved'|'rejected'), rejection_reason (testo motivo se rejected), created_at, updated_at. Relazioni: appartiene a User (creator), può avere più User (co_organizers).

- **User/Student**: Rappresenta uno studente del Liceo Galilei Moro. Attributi rilevanti: id (UUID), full_name, email (@galileimoro.edu.it), class (classe scolastica), role ('student'|'moderator'). Un User può creare molti Events, essere co-organizer di molti Events.

- **Moderator**: Sottotipo di User con role='moderator' (docente o rappresentante studenti). Ha permessi aggiuntivi: vedere tutti Events pending, cambiare status Events da pending → approved/rejected, vedere statistiche moderazione. **Assegnazione ruolo (MVP)**: Il ruolo moderatore viene assegnato manualmente dall'amministratore via Supabase dashboard aggiornando il campo `role='moderator'` nella tabella users. Questo approccio è sufficiente per il soft launch. Una futura feature separata implementerà un workflow in-app per la richiesta e approvazione del ruolo moderatore.

- **Notification**: Rappresenta una notifica push inviata a un User. Attributi: id, user_id, channel ('event_approved'|'event_rejected'|'new_pending_event'|'added_as_coorganizer'|'event_modified'), title, body, event_id (riferimento evento), sent_at, read (boolean). Relazioni: appartiene a User, riferisce a Event.

- **EventImage**: Rappresenta l'immagine di un Event, salvata in Supabase Storage bucket "event-images". Attributi: path (storage path), url (signed URL con 1 ora expiry), size (bytes, max 200KB), dimensions (800x450px), format (WebP). Relazioni: appartiene a Event (one-to-one).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Gli studenti possono creare un evento compilando il form in <2 minuti (misurato tramite user testing con 10 studenti, tempo medio dalla prima apertura form a conferma "Evento creato")

- **SC-002**: Il tasso di successo upload immagine è >95% su connessione 4G (misurato come: upload completati con successo / totale tentativi upload, escludendo errori utente come "file non immagine")

- **SC-003**: I moderatori approvano o rifiutano un evento in <30 secondi (misurato come: timestamp ricezione evento pending → timestamp approvazione/rifiuto, mediana su 100 eventi)

- **SC-004**: La coda moderazione non supera mai 24 ore (SLA: 100% degli eventi pending vengono revisionati entro 24 ore dalla creazione, misurato come max(timestamp ora - created_at) per eventi pending)

- **SC-005**: Le notifiche push hanno delivery rate >90% entro 30 secondi dall'evento trigger (misurato via Firebase Cloud Messaging analytics: notifiche delivered / notifiche sent, time-to-delivery <30s)

- **SC-006**: I deep link event sharing funzionano correttamente in >95% dei casi (misurato come: deep link cliccati che aprono correttamente Event Detail Screen / totale deep link cliccati, testato su iOS e Android)

- **SC-007**: Zero eventi approvati contengono contenuto inappropriato durante soft launch (misurato come: eventi approvati flagged per review da admin / totale eventi approvati = 0%, con review manuale random sample 10% eventi)

- **SC-008**: Gli studenti che ricevono notifica di approvazione riaprono l'app entro 24 ore nel 60% dei casi (misurato come: user sessions entro 24h da notifica approved / totale notifiche approved inviate)

- **SC-009**: Il 40% degli eventi approved vengono condivisi almeno 1 volta (misurato come: eventi con >0 share actions / totale eventi approved)

- **SC-010**: Il tempo medio di upload immagine + creazione evento è <3 secondi su 4G (misurato end-to-end: tap "Crea Evento" → conferma "Evento creato" visibile, connessione 4G simulata, p50 <3s)
