# Feature Specification: Sistema Ripetizioni

**Feature Branch**: `012-tutoring-system`
**Created**: 2025-11-30
**Status**: Draft
**Input**: Sistema di peer tutoring per matchare studenti che cercano aiuto accademico con tutor studenti della stessa scuola (Liceo Galilei Moro, 810 studenti).

---

## Overview

Il Sistema Ripetizioni permette agli studenti di Nova di offrire e cercare aiuto accademico nelle materie scolastiche. I tutor sono studenti della stessa scuola che si rendono disponibili per ripetizioni. Il sistema facilita la discovery e il contatto, ma **non include chat interna né pagamenti** - il contatto avviene tramite WhatsApp o Instagram.

### Anti-Goals (Vincoli Permanenti)

- **NO messaggistica integrata**: Il contatto avviene esclusivamente via WhatsApp/Instagram esterni
- **NO pagamenti in-app**: Tariffe e pagamenti sono responsabilità degli studenti
- **NO sistema recensioni (MVP)**: Feature riservata a Phase B
- **NO moderazione profili tutor**: Auto-pubblicazione basata sulla fiducia nella comunità scolastica
- **NO foto dedicata tutor**: Si usa l'avatar esistente del profilo utente

---

## User Scenarios & Testing

### User Story 1 - Cercare Tutor per Materia (Priority: P1)

Uno studente che ha difficoltà in una materia (es. Matematica) vuole trovare un tutor tra i suoi compagni di scuola. Apre la sezione Ripetizioni, seleziona la materia, e vede la lista dei tutor disponibili.

**Why this priority**: Questa è la funzionalità core del sistema - senza la possibilità di cercare tutor, non c'è valore per gli studenti che cercano aiuto.

**Independent Test**: Aprire la sezione Ripetizioni, selezionare "Matematica" dalla lista materie, visualizzare almeno 1 tutor con nome, classe e prezzo.

**Acceptance Scenarios**:

1. **Given** uno studente autenticato nella home di Nova, **When** apre la sezione Ripetizioni, **Then** vede una lista di 12 materie scolastiche (Matematica, Fisica, Latino, Greco, Inglese, Italiano, Informatica, Storia, Filosofia, Scienze, Arte, Francese)

2. **Given** uno studente nella schermata Selezione Materia, **When** tap su una materia (es. "Matematica"), **Then** viene navigato alla schermata Lista Tutor filtrata per quella materia

3. **Given** uno studente nella Lista Tutor per "Matematica", **When** esistono tutor per quella materia, **Then** vede cards con: avatar, nome, rating, classe, materie offerte, prezzo

4. **Given** uno studente nella Lista Tutor per una materia, **When** non esistono tutor per quella materia, **Then** vede un empty state "Nessun tutor disponibile per questa materia"

---

### User Story 2 - Contattare Tutor (Priority: P1)

Uno studente ha trovato un tutor interessante e vuole contattarlo per organizzare una sessione di ripetizioni. Tap sulla card del tutor e sceglie se contattarlo via WhatsApp o Instagram.

**Why this priority**: Senza la possibilità di contatto, trovare un tutor non ha utilità pratica. Questa è la call-to-action principale.

**Independent Test**: Selezionare un tutor dalla lista, aprire il modal contatto, tap su WhatsApp/Instagram e verificare che si apra l'app esterna corretta.

**Acceptance Scenarios**:

1. **Given** uno studente visualizza una tutor card, **When** tap sulla card, **Then** si apre un bottom sheet "Contatta [Nome Tutor]" con le opzioni di contatto disponibili

2. **Given** un bottom sheet contatto aperto con tutor che ha WhatsApp, **When** tap sul bottone WhatsApp, **Then** si apre l'app WhatsApp con deep link `whatsapp://send?phone=[numero]`

3. **Given** un bottom sheet contatto aperto con tutor che ha Instagram, **When** tap sul bottone Instagram, **Then** si apre l'app Instagram con deep link `instagram://user?username=[username]`

4. **Given** un tutor ha solo WhatsApp (no Instagram), **When** studente apre il modal contatto, **Then** vede solo il bottone WhatsApp (Instagram non mostrato)

5. **Given** un tutor ha solo Instagram (no WhatsApp), **When** studente apre il modal contatto, **Then** vede solo il bottone Instagram (WhatsApp non mostrato)

---

### User Story 3 - Diventare Tutor dal Profilo (Priority: P1)

Uno studente bravo in una materia vuole offrire ripetizioni ai compagni. Dal proprio profilo, accede alla sezione Ripetizioni e compila il form per diventare tutor.

**Why this priority**: Senza tutor, non c'è supply nel sistema. L'accesso dal profilo è il punto di ingresso più naturale ("gestisco il mio profilo, incluso il mio ruolo come tutor").

**Independent Test**: Andare nel proprio profilo, trovare la sezione "Ripetizioni", tap su "Diventa Tutor", compilare il form con almeno 1 materia e 1 contatto, pubblicare e verificare che il profilo tutor sia attivo.

**Acceptance Scenarios**:

1. **Given** uno studente nel proprio ProfileScreen che NON è tutor, **When** visualizza la sezione sotto le statistiche, **Then** vede una card "Vuoi dare ripetizioni?" con bottone "Diventa Tutor"

2. **Given** uno studente tap su "Diventa Tutor", **When** si apre il form, **Then** vede i campi: Bio (max 200 char), Materie (multi-select max 5), Prezzo (€/ora, default 0), Disponibilità giorni (checkboxes), Fascia oraria, WhatsApp, Instagram

3. **Given** uno studente compila il form con 2 materie (Matematica, Fisica), prezzo 15€/h, e WhatsApp, **When** tap "Pubblica Profilo", **Then** il profilo tutor viene creato e diventa visibile nella sezione Ripetizioni

4. **Given** uno studente prova a pubblicare senza materie selezionate, **When** tap "Pubblica Profilo", **Then** vede errore di validazione "Seleziona almeno una materia"

5. **Given** uno studente prova a pubblicare senza WhatsApp né Instagram, **When** tap "Pubblica Profilo", **Then** vede errore di validazione "Inserisci almeno un contatto (WhatsApp o Instagram)"

---

### User Story 4 - Diventare Tutor dalla Sezione Ripetizioni (Priority: P1)

Uno studente sta esplorando la sezione Ripetizioni per cercare un tutor, ma decide che potrebbe anche offrire ripetizioni in una materia in cui è bravo. Tap sul FAB (+) per diventare tutor.

**Why this priority**: Entry point alternativo che cattura l'interesse nel momento in cui lo studente è già nel contesto delle ripetizioni.

**Independent Test**: Aprire la sezione Ripetizioni, tap sul FAB (+), verificare che si apra lo stesso form "Diventa Tutor".

**Acceptance Scenarios**:

1. **Given** uno studente nella schermata Selezione Materia, **When** vede la UI, **Then** c'è un FAB (+) in basso a destra con tooltip "Diventa Tutor"

2. **Given** uno studente tap sul FAB (+), **When** non è già tutor, **Then** si apre il form "Diventa Tutor" (stesso di US3)

3. **Given** uno studente già tutor tap sul FAB (+), **When** ha già un profilo tutor attivo, **Then** si apre la schermata "Modifica Profilo Tutor" con i dati pre-compilati

---

### User Story 5 - Filtrare Tutor (Priority: P2)

Uno studente cerca un tutor ma la lista è lunga. Vuole filtrare per trovare tutor della sua classe, o ordinare per prezzo/rating.

**Why this priority**: Migliora significativamente l'esperienza di discovery, ma il sistema funziona anche senza filtri (scroll manuale).

**Independent Test**: Nella lista tutor per una materia, applicare un filtro (es. "Solo Gratis") e verificare che la lista si aggiorni mostrando solo tutor con prezzo 0.

**Acceptance Scenarios**:

1. **Given** uno studente nella Lista Tutor, **When** vede l'UI, **Then** sotto la AppBar c'è una row di filter chips scrollabile orizzontalmente: "Tutte" (default), "Classi", "Valutazione", "Prezzo"

2. **Given** uno studente tap sul chip "Classi", **When** si apre il filtro, **Then** può selezionare una o più classi (1A-5L) e vedere solo tutor di quelle classi

3. **Given** uno studente tap sul chip "Prezzo", **When** seleziona "Gratis", **Then** la lista mostra solo tutor con price_per_hour = 0

4. **Given** uno studente tap sul chip "Valutazione", **When** seleziona "4.5+", **Then** la lista mostra solo tutor con rating >= 4.5

5. **Given** uno studente ha applicato filtri, **When** tap sul chip "Tutte", **Then** tutti i filtri vengono resettati e vede la lista completa

---

### User Story 6 - Modificare Profilo Tutor (Priority: P2)

Un tutor vuole aggiornare le sue informazioni (aggiungere una materia, cambiare prezzo, aggiornare disponibilità).

**Why this priority**: Necessario per gestire il profilo nel tempo, ma non blocking per il lancio MVP.

**Independent Test**: Da tutor attivo, accedere al proprio profilo, modificare il prezzo da 15€ a 20€, salvare e verificare che la modifica sia visibile nella lista Ripetizioni.

**Acceptance Scenarios**:

1. **Given** un tutor attivo nel proprio ProfileScreen, **When** visualizza la sezione Ripetizioni, **Then** vede una mini-card con le sue materie, prezzo, e bottone "Modifica"

2. **Given** un tutor tap su "Modifica", **When** si apre il form, **Then** tutti i campi sono pre-compilati con i dati attuali

3. **Given** un tutor modifica il prezzo e tap "Salva", **When** la richiesta ha successo, **Then** vede conferma "Profilo aggiornato" e le modifiche sono immediate

4. **Given** un tutor accede a Settings, **When** è già tutor attivo, **Then** vede una voce "Profilo Tutor" che apre la stessa schermata di modifica

---

### User Story 7 - Disattivare/Riattivare Profilo Tutor (Priority: P2)

Un tutor vuole temporaneamente non essere visibile nella sezione Ripetizioni (es. periodo esami, vacanze).

**Why this priority**: Controllo sulla propria disponibilità, importante per UX ma non blocking.

**Independent Test**: Da tutor attivo, disattivare il profilo e verificare che non compaia più nelle ricerche. Riattivare e verificare che torni visibile.

**Acceptance Scenarios**:

1. **Given** un tutor nella schermata Modifica Profilo Tutor, **When** profilo è attivo, **Then** vede in fondo un bottone rosso "Disattiva Profilo"

2. **Given** un tutor tap "Disattiva Profilo", **When** conferma l'azione, **Then** il profilo diventa is_active=false e non compare più nelle ricerche

3. **Given** un tutor con profilo disattivato nel proprio ProfileScreen, **When** vede la sezione Ripetizioni, **Then** vede una card grigia "Profilo Tutor Disattivato" con bottone "Riattiva"

4. **Given** un tutor tap "Riattiva", **When** conferma l'azione, **Then** il profilo diventa is_active=true e torna visibile nelle ricerche

---

### User Story 8 - Vedere Tutor su Profilo Altri (Priority: P3)

Uno studente sta guardando il profilo di un compagno e scopre che offre ripetizioni. Può contattarlo direttamente dal profilo.

**Why this priority**: Discovery secondaria, nice-to-have per creare connessioni organiche.

**Independent Test**: Aprire il profilo di un altro studente che è tutor, verificare che compaia la sezione Ripetizioni con bottone "Contatta per Ripetizioni".

**Acceptance Scenarios**:

1. **Given** uno studente visualizza OtherProfileScreen di un utente che È tutor attivo, **When** vede il profilo, **Then** compare una sezione "Ripetizioni" con materie offerte e prezzo

2. **Given** uno studente vede la sezione Ripetizioni su un altro profilo, **When** tap "Contatta per Ripetizioni", **Then** si apre lo stesso bottom sheet di contatto (WhatsApp/Instagram)

3. **Given** uno studente visualizza OtherProfileScreen di un utente che NON è tutor, **When** vede il profilo, **Then** la sezione Ripetizioni non compare

---

### Edge Cases

- **Cosa succede quando un tutor ha entrambi i contatti ma uno è vuoto?** Solo il contatto con valore viene mostrato nel modal.
- **Cosa succede quando un tutor elimina il proprio account?** Il profilo tutor viene eliminato con cascade delete.
- **Cosa succede quando WhatsApp/Instagram non è installato sul device?** Il sistema tenta di aprire il deep link; se fallisce, mostra errore "App non installata" e offre di copiare il contatto.
- **Cosa succede quando un tutor seleziona più di 5 materie?** UI impedisce selezione oltre 5, con messaggio "Massimo 5 materie".
- **Cosa succede quando due tutor hanno lo stesso prezzo/rating?** Ordinamento secondario per data creazione (più recenti prima).
- **Cosa succede su connessione lenta?** Loading state con skeleton cards durante fetch.

---

## Requirements

### Functional Requirements - Browsing Tutor

- **FR-001**: Sistema DEVE mostrare una lista di 12 materie scolastiche nella schermata Selezione Materia (Matematica, Fisica, Latino, Greco, Inglese, Italiano, Informatica, Storia, Filosofia, Scienze, Arte, Francese)

- **FR-002**: Sistema DEVE filtrare e mostrare solo i tutor che offrono la materia selezionata (query: `subjects @> '{materia}'`)

- **FR-003**: Sistema DEVE supportare filtri per: classe (dropdown multi-select), valutazione (range slider), prezzo (range o "Gratis")

- **FR-004**: Sistema DEVE implementare pagination con 20 tutor per pagina per garantire performance 60fps

- **FR-005**: Sistema DEVE mostrare empty state "Nessun tutor disponibile per questa materia" quando la lista è vuota

### Functional Requirements - Contatto

- **FR-006**: Sistema DEVE mostrare un bottom sheet con opzioni di contatto quando l'utente tap su una tutor card

- **FR-007**: Sistema DEVE supportare deep link WhatsApp nel formato `whatsapp://send?phone=[numero]`

- **FR-008**: Sistema DEVE supportare deep link Instagram nel formato `instagram://user?username=[username]`

- **FR-009**: Ogni profilo tutor DEVE avere almeno un contatto (WhatsApp O Instagram) - constraint database

- **FR-010**: Sistema DEVE utilizzare url_launcher per aprire app esterne (WhatsApp, Instagram)

### Functional Requirements - Diventare Tutor

- **FR-011**: Form "Diventa Tutor" DEVE includere campo Bio con limite 200 caratteri

- **FR-012**: Form DEVE permettere selezione multipla di materie con massimo 5 items

- **FR-013**: Form DEVE includere campo Prezzo in €/ora con default 0 (gratuito)

- **FR-014**: Form DEVE includere checkboxes per disponibilità giorni (Lun, Mar, Mer, Gio, Ven, Sab)

- **FR-015**: Form DEVE includere campo testo per fascia oraria (es. "15:00-18:00")

- **FR-016**: Form DEVE includere campi per WhatsApp (telefono) e Instagram (username)

- **FR-017**: Validazione form DEVE richiedere: minimo 1 materia E minimo 1 contatto (WhatsApp O Instagram)

### Functional Requirements - Gestione Profilo

- **FR-018**: Tutor DEVE poter modificare tutti i campi del proprio profilo

- **FR-019**: Tutor DEVE poter disattivare il proprio profilo (is_active=false) per non essere visibile

- **FR-020**: Tutor DEVE poter riattivare un profilo disattivato (is_active=true)

- **FR-021**: Accesso modifica profilo tutor DEVE essere disponibile dalla sezione Ripetizioni nel ProfileScreen

- **FR-022**: Accesso modifica profilo tutor DEVE essere disponibile da Settings (se già tutor)

### Functional Requirements - Integrazione Profilo

- **FR-023**: ProfileScreen DEVE mostrare una sezione Ripetizioni dopo ProfileStats

- **FR-024**: Se utente NON è tutor, ProfileScreen DEVE mostrare card "Vuoi dare ripetizioni?" con CTA "Diventa Tutor"

- **FR-025**: Se utente È tutor attivo, ProfileScreen DEVE mostrare mini-card con materie + prezzo + bottone "Modifica"

- **FR-026**: OtherProfileScreen DEVE mostrare sezione Ripetizioni SE l'utente visualizzato è tutor attivo

- **FR-027**: OtherProfileScreen DEVE includere bottone "Contatta per Ripetizioni" che apre il modal contatto

### Key Entities

- **TutorProfile**: Rappresenta un profilo tutor con: id (UUID), user_id (FK a profiles, unique), bio (testo max 200 char), subjects (array di stringhe, max 5), price_per_hour (decimale, default 0), availability_days (array di stringhe), time_slot (testo), whatsapp_phone (testo nullable), instagram_username (testo nullable), rating (decimale, default 0.0 - per future), total_reviews (intero, default 0 - per future), is_active (boolean, default true), created_at, updated_at

- **Subject**: Enumerazione delle 12 materie scolastiche supportate: matematica, fisica, latino, greco, inglese, italiano, informatica, storia, filosofia, scienze, arte, francese

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: Studente trova tutor per materia in meno di 10 secondi (2 tap: Ripetizioni → Materia → Lista Tutor)

- **SC-002**: Almeno 30% degli studenti si registrano come tutor entro 2 mesi dal lancio della feature

- **SC-003**: Scroll fluido a 60fps nella lista tutor anche con 50+ tutor per materia

- **SC-004**: Zero privacy incidents (contatti gestiti esternamente via WhatsApp/Instagram, nessun dato sensibile nel database)

- **SC-005**: Meno del 5% degli studenti segnala problemi nell'apertura di WhatsApp/Instagram tramite deep link

- **SC-006**: 50% degli studenti che diventano tutor lo fanno dalla sezione Profilo (vs FAB nella schermata Ripetizioni)

---

## Assumptions

- Firebase Cloud Messaging (FCM) non è richiesto per questa feature (no notifiche push per nuovi tutor)
- Gli studenti hanno WhatsApp o Instagram installato sui loro device
- Il design system Nova (NovaColors, NovaSpacing, NovaTypography, NovaRadius) è già implementato
- La feature Profile (006-user-profile) è già implementata e funzionante
- Row-Level Security è già configurato per la tabella profiles

---

## Phase B - Future Features (Out of Scope MVP)

Le seguenti features sono esplicitamente rimandate a una fase successiva:

1. **Sistema Recensioni**: Chi ha ricevuto ripetizioni può lasciare rating (1-5 stelle) + commento
2. **Tutor Preferiti**: Salvataggio tutor in lista preferiti (heart icon)
3. **Notifiche Push**: Notifica quando nuovo tutor disponibile per materia seguita
4. **Filtro "Solo Gratuiti"**: Toggle rapido per mostrare solo tutor gratuiti
5. **Calendar Integration**: Vista calendario disponibilità tutor con Google Calendar
