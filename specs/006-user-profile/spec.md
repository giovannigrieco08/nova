# Feature Specification: Sistema Profilo Utente

**Feature Branch**: `006-user-profile`
**Created**: 2025-01-22
**Status**: Draft
**Input**: User description: "Sistema Profilo Utente completo per Nova: visualizzazione profilo proprio e altrui (header con avatar, nome, username auto-generated da email, classe, badge moderatore, stats eventi creati/partecipazioni, bio opzionale max 150 char, tabs Eventi/Partecipazioni grid 3 colonne), modifica profilo (upload avatar con crop circolare max 2MB, nome, classe dropdown, bio con validazione), settings (account info read-only, privacy con toggle profilo visibile e GDPR compliance: download dati JSON e delete account con 30 giorni grace period, notifiche, sezione moderazione se role=moderator), condivisione profilo via deep link nova://profile/{user_id} e share in chat. Design Instagram-inspired ma anti-social: NO follower/following, NO feed personale, NO like sul profilo, focus su contributo comunitario tramite eventi organizzati. UI platform-adaptive: Cupertino per iOS, Material Design 3 per Android, usando ESCLUSIVAMENTE colori già definiti nel design system Nova (viola brand, pink brand, gradient). Backend Supabase con profiles table estesa e avatars storage. Success criteria: 90%+ studenti completano profilo entro 1 settimana, 70%+ aggiungono bio, zero errori upload avatar, GDPR export generato entro 10 secondi."

## Clarifications

### Session 2025-01-22

- **Q**: Quali sono esattamente le classi del Liceo Galilei Moro e come sono organizzate? → **A**: 38 classi totali - Liceo Scientifico: sezioni A-E complete (1A-5A, 1B-5B, 1C-5C, 1D-5D, 1E-5E = 25 classi), sezione F parziale (solo 1F, 3F, 4F = 3 classi, no 2F e 5F); Liceo Classico: sezioni Ac e Bc complete (1Ac-5Ac, 1Bc-5Bc = 10 classi). Dropdown include opzione "Altro" per edge case.
- **Q**: Avatar custom è obbligatorio per completare il profilo o le iniziali auto-generate sono accettabili? → **A**: Avatar custom (foto caricata) è OBBLIGATORIO. Le iniziali su gradient brand sono solo placeholder temporaneo mostrato al primo login. Utente DEVE caricare foto reale per completare profilo e accedere a tutte le funzionalità (es. creare eventi).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Visualizzazione e Completamento Profilo Proprio (Priority: P1)

Marco, studente di 5A, apre Nova per la prima volta dopo l'autenticazione. Accede alla tab "Profilo" dalla bottom navigation e vede il suo profilo ancora incompleto: avatar con sole iniziali, nome preso dall'email, ma nessuna classe e bio. Vuole completare il suo profilo per presentarsi alla comunità scolastica. Tap su "Modifica Profilo", carica una sua foto dalla galleria, la ritaglia in formato circolare, seleziona la classe "5A" dal dropdown, e aggiunge una bio: "Appassionato di basket 🏀 | Capitano squadra". Salva le modifiche e torna al profilo, dove ora vede tutti i suoi dati aggiornati.

**Why this priority**: Profilo completo è fondamentale per l'identità digitale dello studente all'interno della scuola. Senza profilo, lo studente non può essere riconosciuto dagli altri e la piattaforma perde valore sociale. È il prerequisito per tutte le altre funzionalità.

**Independent Test**: Può essere testato autonomamente creando un account nuovo, accedendo al profilo, modificando avatar/nome/classe/bio, e verificando che le modifiche vengano salvate e visualizzate correttamente. Deliverabile: studente può personalizzare completamente la propria identità digitale.

**Acceptance Scenarios**:

1. **Given** Marco ha appena fatto login con email verificata, **When** apre tab Profilo, **Then** vede header con avatar iniziali, nome completo estratto da email, username auto-generated (marco.rossi), campo classe vuoto, bio vuota, stats "0 eventi creati | 0 partecipazioni"
2. **Given** Marco è sul suo profilo, **When** tap "Modifica Profilo", **Then** apre schermata/modal edit con campi: avatar (tap per cambiare), nome (pre-filled), classe (dropdown), bio (textarea)
3. **Given** Marco è in edit profilo, **When** tap avatar e seleziona foto da galleria, **Then** apre image picker, sceglie foto, crop circolare con pinch-to-zoom, conferma → avatar aggiornato in preview
4. **Given** Marco ha modificato nome, classe "5A", bio "Appassionato di basket 🏀", **When** tap "Salva", **Then** sistema valida input (nome ≥2 parole, classe selezionata, bio ≤150 char), salva su database, torna a profilo con dati aggiornati, mostra toast "Profilo aggiornato!"
5. **Given** Marco ha avatar >2MB, **When** tap "Salva", **Then** mostra errore "Immagine troppo grande. Max 2MB." e non salva
6. **Given** Marco ha bio con 151 caratteri, **When** tap "Salva", **Then** mostra errore "Bio troppo lunga. Max 150 caratteri." e non salva
7. **Given** Marco ha compilato solo nome (no classe), **When** tap "Salva", **Then** mostra errore "Seleziona la tua classe" e non salva
8. **Given** Marco sta editando profilo, **When** tap "Annulla", **Then** scarta modifiche non salvate e torna a profilo

---

### User Story 2 - Visualizzazione Profilo Altri Utenti e Scoperta Eventi (Priority: P1)

Sofia vede nel feed eventi un torneo di basket organizzato da Marco. È curiosa di sapere chi è Marco e cosa altro organizza. Tap sul nome creatore "Marco Rossi" nella card evento, si apre il profilo di Marco. Vede avatar, nome, classe "5A", bio "Appassionato di basket 🏀 | Capitano squadra", badge "Moderatore 🛡️" (se Marco è moderatore), e stats "3 eventi creati". Swipe a tab "Eventi" (unica tab visibile, no "Partecipazioni" per privacy), vede grid 3 colonne con i 3 eventi pubblici creati da Marco. Tap su uno degli eventi per aprire dettaglio. Decide di condividere il profilo di Marco con amici, tap "Condividi Profilo" → bottom sheet con opzioni "Copia Link", "Condividi in Chat", "Annulla".

**Why this priority**: Scoprire chi organizza eventi è essenziale per la fiducia e il coinvolgimento. Gli studenti vogliono sapere chi c'è dietro un evento prima di partecipare. Questa feature abilita la trasparenza e la reputazione comunitaria basata sul contributo (eventi creati), non su metriche di popolarità.

**Independent Test**: Può essere testato creando due account (utente A e utente B), facendo creare eventi a utente B, e verificando che utente A possa visualizzare il profilo di B con eventi creati, senza vedere le partecipazioni di B. Deliverabile: utente può scoprire organizzatori eventi e portfolio contributi.

**Acceptance Scenarios**:

1. **Given** Sofia vede evento di Marco nel feed, **When** tap nome creatore "Marco Rossi", **Then** apre profilo Marco con header (avatar, nome, username, classe), stats "X eventi creati" (NO partecipazioni visibili), bio se presente, badge moderatore se role=moderator
2. **Given** Sofia è sul profilo Marco, **When** guarda tabs disponibili, **Then** vede solo tab "Eventi" (NO tab "Partecipazioni" per privacy), NO button "Modifica Profilo" (non è suo profilo)
3. **Given** Sofia è su tab Eventi profilo Marco, **When** scroll grid, **Then** vede eventi pubblici (status=approved) creati da Marco in grid 3 colonne, ogni card mostra emoji + immagine evento o gradient brand
4. **Given** Sofia tap su evento nel profilo Marco, **When** click card evento, **Then** apre schermata dettaglio evento
5. **Given** Marco ha profilo nascosto (profile_visible=false), **When** Sofia cerca di aprire profilo Marco, **Then** vede messaggio "Profilo non disponibile" MA eventi creati da Marco restano visibili nel feed (separazione contenuto/identità)

---

### User Story 3 - Gestione Privacy e GDPR Compliance (Priority: P2)

Marco vuole controllare la sua privacy su Nova. Apre Settings (icon ⚙️ in profilo) → sezione "Privacy". Vede toggle "Profilo visibile" (attualmente ON), button "Scarica i tuoi dati" (GDPR Right to Access), button "Elimina account" (rosso, warning). Decide di scaricare i suoi dati per curiosità: tap "Scarica i tuoi dati" → sistema genera JSON con profilo, eventi creati, partecipazioni, commenti. Riceve link download (expire 24h), scarica file marco_dati_2025-01-22.json. Alcuni mesi dopo, Marco si diploma e vuole eliminare account: tap "Elimina account" → dialog conferma "Sei sicuro? Account eliminato dopo 30 giorni. Puoi annullare entro 30 giorni." → conferma → soft delete (deleted_at=NOW()), vede banner "Account eliminato. Hai 30 giorni per annullare." Dopo 30 giorni, background job esegue hard delete automatico.

**Why this priority**: GDPR compliance è mandatorio per legge (studenti minori EU). Trasparenza su dati raccolti e controllo utente (Right to Access, Erasure, Portability) sono requisiti non negoziabili. Privacy-first è principio costituzionale Nova.

**Independent Test**: Può essere testato creando account, generando dati (eventi, commenti, partecipazioni), scaricando export JSON e verificando contenuto completo, poi eseguendo delete e verificando soft delete + grace period + hard delete dopo 30 giorni. Deliverabile: utente ha pieno controllo sui propri dati.

**Acceptance Scenarios**:

1. **Given** Marco è in Settings → Privacy, **When** tap "Scarica i tuoi dati", **Then** sistema avvia async job, genera JSON (profilo, eventi creati, partecipazioni, commenti, messaggi chat ultimi 24h), upload a Supabase Storage, invia link download via notifica in-app entro 10 secondi
2. **Given** Marco riceve link download dati, **When** tap link, **Then** scarica file JSON con nome "marco_dati_YYYY-MM-DD.json", link expira dopo 24h
3. **Given** Marco ha scaricato JSON dati, **When** apre file, **Then** vede tutti dati personali: {profile: {id, full_name, email, username, class, bio, avatar_url, created_at}, events: [], participations: [], comments: [], messages: []}
4. **Given** Marco è in Settings → Privacy, **When** tap "Elimina account", **Then** apre dialog conferma (titolo "Sei sicuro?", messaggio "Account eliminato dopo 30 giorni. Puoi annullare entro 30 giorni.", buttons "Annulla" e "Conferma eliminazione" rosso)
5. **Given** Marco conferma eliminazione account, **When** sistema processa richiesta, **Then** soft delete (profiles.deleted_at = NOW()), mostra banner persistente "Account eliminato. Hai 30 giorni per annullare.", eventi creati restano visibili con creator="Utente eliminato", profilo non accessibile ad altri
6. **Given** Marco ha eliminato account (deleted_at non null), **When** fa login entro 30 giorni, **Then** vede dialog "Vuoi riattivare il tuo account?" con button "Riattiva" → se conferma, deleted_at=NULL, account ripristinato
7. **Given** Marco ha eliminato account, **When** passano 30 giorni, **Then** background job esegue hard delete automatico: DELETE FROM profiles WHERE deleted_at < NOW() - INTERVAL '30 days', avatar rimosso da storage, dati permanentemente cancellati

---

### User Story 4 - Condivisione Profilo e Deep Links (Priority: P2)

Sofia vuole condividere il profilo di Marco (organizzatore torneo basket) con i suoi amici in chat. Dal profilo Marco, tap "Condividi Profilo" → bottom sheet con opzioni: "Copia Link", "Condividi in Chat", "Annulla". Sofia sceglie "Condividi in Chat" → apre tab Chat con messaggio pre-filled: "Guarda il profilo di Marco Rossi: nova://profile/abc123". Sofia aggiunge testo personale: "Marco organizza torneo basket questo weekend!" e invia. Altri studenti vedono messaggio in chat, tap su link nova://profile/abc123 → sistema intercept deep link, verifica auth, naviga direttamente a profilo Marco.

**Why this priority**: Condivisione profili abilita word-of-mouth e scoperta organizzatori. Deep links migliorano UX eliminando friction (no copia-incolla URL, navigazione diretta). Facilita connessioni tra studenti che condividono interessi (basket, teatro, etc.).

**Independent Test**: Può essere testato creando due account, condividendo profilo tramite link in chat, e verificando che tap su deep link apra correttamente il profilo. Deliverabile: utente può condividere e scoprire profili via link nativi.

**Acceptance Scenarios**:

1. **Given** Sofia è sul profilo Marco, **When** tap "Condividi Profilo", **Then** apre bottom sheet con opzioni: "Copia Link" (icon 🔗), "Condividi in Chat" (icon 💬), "Annulla"
2. **Given** Sofia tap "Copia Link", **When** sistema copia link, **Then** clipboard contiene "nova://profile/{user_id}" (es. nova://profile/abc123), mostra toast "Link copiato!", chiude bottom sheet
3. **Given** Sofia tap "Condividi in Chat", **When** sistema apre chat, **Then** naviga a tab Chat con messaggio pre-filled: "Guarda il profilo di [Nome Completo]: nova://profile/{user_id}", cursor al fondo per aggiungere testo personalizzato
4. **Given** Sofia ha inviato link profilo in chat, **When** altro studente (Luca) tap su link "nova://profile/abc123" nel messaggio, **Then** sistema intercept deep link, verifica Luca è loggato, naviga a profilo Marco
5. **Given** Luca non è loggato, **When** tap deep link profilo, **Then** redirect a login screen con messaggio "Accedi per visualizzare profilo", dopo login naviga a profilo richiesto
6. **Given** deep link profilo non valido (utente inesistente), **When** tap link, **Then** mostra error screen "Profilo non trovato" con button "Torna al Feed"

---

### User Story 5 - Visualizzazione Badge Moderatore e Credibilità (Priority: P3)

Anna è moderatrice Nova. Quando apre il suo profilo, vede badge "Moderatore 🛡️" sotto username e avatar con gradient border brand (viola→pink). Altri studenti vedono profilo Anna quando lei approva/rifiuta eventi in moderazione. Badge visibile pubblicamente trasmette credibilità e trasparenza ruolo: Anna non è una "spia" anonima, ma membro riconosciuto della comunità con responsabilità moderazione. In Settings, Anna ha sezione extra "Moderazione" con link "Dashboard Moderazione" e statistiche personali (review fatte, tasso approval).

**Why this priority**: Trasparenza ruoli è fondamentale per fiducia. Studenti devono sapere chi sono i moderatori (no moderazione anonima percepita come censura arbitraria). Badge visibile rende moderazione umana e accountable. P3 perché riguarda solo subset utenti (moderatori) e non blocca funzionalità core.

**Independent Test**: Può essere testato creando account con role=moderator, verificando badge visibile in profilo proprio e altrui, e sezione Settings moderazione accessibile solo a moderatori. Deliverabile: moderatori hanno identità pubblica riconoscibile.

**Acceptance Scenarios**:

1. **Given** Anna ha role=moderator nel database, **When** apre suo profilo, **Then** vede badge "Moderatore 🛡️" sotto username (colore viola brand, padding 4×8px, border-radius standard), avatar ha gradient border viola→pink brand (2px width)
2. **Given** Anna è moderatrice, **When** apre Settings, **Then** vede sezione extra "Moderazione" con link "Dashboard Moderazione" e statistiche "Review fatte: 45 | Tasso approval: 78%"
3. **Given** Sofia (non moderatrice) visualizza profilo Anna, **When** guarda header profilo, **Then** vede badge "Moderatore 🛡️" visibile pubblicamente, gradient border avatar visibile
4. **Given** Sofia visualizza profilo altro studente non moderatore (Marco), **When** guarda header, **Then** NO badge, NO gradient border (avatar normale)

---

### Edge Cases

- **Username collision**: Se nome.cognome già esiste (es. "marco.rossi"), sistema aggiunge numero progressivo ("marco.rossi2", "marco.rossi3", etc.) automaticamente al primo login
- **Avatar upload fallito**: Se network error durante upload avatar, sistema mostra errore "Errore caricamento immagine. Riprova." e mantiene avatar precedente
- **Profilo incompleto**: Se studente non completa profilo (no classe, no avatar), può comunque usare app ma vede reminder persistente "Completa il tuo profilo" in profilo tab
- **Account eliminato - eventi orfani**: Eventi creati da account eliminato mostrano creator="Utente eliminato", eventi restano visibili e funzionanti (commenti, partecipazioni permesse)
- **Bio con emoji e caratteri speciali**: Sistema supporta emoji, accenti, caratteri unicode. Sanitizzazione input previene XSS ma preserva formatting innocuo
- **Avatar dimensioni minime**: Se utente carica immagine <200×200px, sistema mostra warning "Immagine troppo piccola. Min 200×200px" e non permette salvataggio
- **Deep link profilo eliminato**: Se utente tap deep link a profilo con deleted_at non null, mostra "Profilo non disponibile"
- **GDPR export timeout**: Se generazione export JSON richiede >10 secondi (es. utente con migliaia di eventi), sistema mostra loader "Generazione dati in corso..." e notifica quando pronto
- **Reattivazione account dopo 29 giorni**: Utente può riattivare account fino al 29° giorno incluso. Dal 30° giorno, hard delete eseguito e reattivazione impossibile
- **Modifica profilo concorrente**: Se utente A modifica profilo da dispositivo 1 e contemporaneamente da dispositivo 2, last write wins (Supabase updated_at timestamp determina versione finale)

## Requirements *(mandatory)*

### Functional Requirements

#### Visualizzazione Profilo

- **FR-001**: Sistema MUST mostrare profilo utente con header contenente: avatar (96×96px circolare), nome completo, username (formato nome.cognome), classe, badge "Moderatore 🛡️" se role=moderator
- **FR-002**: Sistema MUST mostrare statistiche profilo: numero eventi creati (count eventi con status=approved e creator_id=user_id), numero partecipazioni (count participations con user_id=user_id)
- **FR-003**: Sistema MUST mostrare bio utente (max 150 caratteri) se presente, con supporto emoji e caratteri unicode
- **FR-004**: Sistema MUST mostrare due tabs: "Eventi" (eventi creati dall'utente, grid 3 colonne) e "Partecipazioni" (eventi dove utente ha partecipato, grid 3 colonne, visibile SOLO a proprietario profilo)
- **FR-005**: Quando utente visualizza profilo altrui, sistema MUST nascondere tab "Partecipazioni" (privacy) e button "Modifica Profilo"
- **FR-006**: Sistema MUST mostrare avatar come iniziali nome su gradient brand se utente non ha caricato foto custom

#### Modifica Profilo

- **FR-007**: Sistema MUST permettere modifica profilo tramite schermata/modal "Edit Profilo" con campi: avatar (tap per upload), nome completo, classe (dropdown), bio (textarea con character counter)
- **FR-008**: Sistema MUST validare input prima salvataggio: nome min 2 parole e max 50 caratteri, classe obbligatoria (deve essere selezionata), bio max 150 caratteri
- **FR-009**: Sistema MUST permettere upload avatar da galleria o fotocamera, con crop circolare in-app (pinch-to-zoom, rotate), max 2MB, min 200×200px, formati JPG/PNG/WebP
- **FR-010**: Sistema MUST comprimere avatar client-side prima upload: max 500KB, 800×800px, formato WebP (fallback JPG se non supportato)
- **FR-011**: Sistema MUST salvare avatar in Supabase Storage (path: avatars/{user_id}/avatar.jpg) e aggiornare profile.avatar_url
- **FR-012**: Sistema MUST mostrare errori validazione chiari: "Nome troppo corto", "Immagine troppo grande. Max 2MB", "Seleziona la tua classe", "Bio troppo lunga. Max 150 caratteri"
- **FR-013**: Quando utente tap "Annulla" in edit profilo, sistema MUST scartare modifiche non salvate e tornare a profilo

#### Username e Identità

- **FR-014**: Sistema MUST generare username automaticamente da email al primo login: formato nome.cognome (lowercase, no spazi, no accenti), estratto da parte prima di @ (es. giovanni.grieco@galileimoro.edu.it → giovanni.grieco)
- **FR-015**: Sistema MUST gestire collision username: se nome.cognome già esiste, aggiungere numero progressivo (marco.rossi → marco.rossi2 → marco.rossi3)
- **FR-016**: Username MUST essere read-only (non modificabile dall'utente) per evitare confusione identità

#### Settings e Privacy

- **FR-017**: Sistema MUST mostrare schermata Settings con sezioni: Account (email read-only, username read-only, data iscrizione read-only), Privacy, Notifiche, Info
- **FR-018**: Sezione Privacy MUST includere: toggle "Profilo visibile" (default ON), button "Scarica i tuoi dati" (GDPR), button "Elimina account" (colore error/destructive)
- **FR-019**: Toggle "Profilo visibile" OFF MUST nascondere profilo ad altri utenti (mostra "Profilo non disponibile") MA mantenere eventi creati visibili nel feed (separazione contenuto/identità)
- **FR-020**: Sezione Notifiche MUST includere: toggle "Notifiche eventi" (default ON), toggle "Notifiche chat" (default ON), toggle "Notifiche moderazione" (SOLO se role=moderator). Quando toggle OFF: notifiche completamente disabilitate per quella categoria (no push notification, no badge count, no in-app alert). Quando toggle ON: notifiche attive con push notification + badge count + in-app alert.
- **FR-021**: Se utente ha role=moderator, Settings MUST mostrare sezione extra "Moderazione" con link "Dashboard Moderazione" e statistiche personali (review fatte, tasso approval)

#### GDPR Compliance

- **FR-022**: Sistema MUST implementare "Scarica i tuoi dati" (Right to Access): genera JSON con profilo, eventi creati, partecipazioni, commenti, messaggi chat ultimi 24h
- **FR-023**: Export JSON MUST essere generato in <10 secondi, uploadato a Supabase Storage, link download inviato via notifica in-app, link expira dopo 24h
- **FR-024**: Sistema MUST implementare "Elimina account" (Right to Erasure): soft delete con deleted_at=NOW(), grace period 30 giorni, mostra banner "Account eliminato. Hai 30 giorni per annullare."
- **FR-025**: Durante grace period (30 giorni), utente MUST poter riattivare account (deleted_at=NULL) facendo login e confermando riattivazione
- **FR-026**: Dopo 30 giorni, background job MUST eseguire hard delete automatico: DELETE FROM profiles WHERE deleted_at < NOW() - INTERVAL '30 days', rimuovere avatar da storage
- **FR-027**: Eventi creati da account eliminato MUST restare visibili con creator="Utente eliminato", permettere commenti e partecipazioni

#### Condivisione Profilo e Deep Links

- **FR-028**: Sistema MUST permettere condivisione profilo tramite button "Condividi Profilo" con bottom sheet opzioni: "Copia Link", "Condividi in Chat", "Annulla"
- **FR-029**: "Copia Link" MUST copiare deep link formato nova://profile/{user_id} in clipboard e mostrare toast "Link copiato!"
- **FR-030**: "Condividi in Chat" MUST aprire tab Chat con messaggio pre-filled: "Guarda il profilo di [Nome Completo]: nova://profile/{user_id}"
- **FR-031**: Sistema MUST intercettare deep links nova://profile/{user_id}, verificare utente loggato, navigare a profilo richiesto
- **FR-032**: Se utente non loggato tap deep link, sistema MUST redirect a login con messaggio "Accedi per visualizzare profilo", poi navigare a profilo dopo autenticazione
- **FR-033**: Se deep link profilo non valido (utente inesistente o deleted_at not null), sistema MUST mostrare error screen "Profilo non trovato"

#### Badge Moderatore

- **FR-034**: Se utente ha role=moderator, sistema MUST mostrare badge "Moderatore 🛡️" sotto username (colore viola brand, padding 4×8px) e gradient border viola→pink (2px) attorno avatar
- **FR-035**: Badge moderatore MUST essere visibile pubblicamente in profilo utente (non solo a proprietario)

#### UI Platform-Adaptive

- **FR-036**: UI MUST usare componenti platform-native: Cupertino per iOS (CupertinoButton, CupertinoNavigationBar, CupertinoTextField, CupertinoActionSheet, CupertinoSegmentedControl, CupertinoTabBar, CupertinoAlertDialog), Material Design 3 per Android (FilledButton, OutlinedButton, AppBar, TextField, ModalBottomSheet, TabBar, NavigationBar, AlertDialog)
- **FR-037**: Sistema MUST usare ESCLUSIVAMENTE colori da design system Nova esistente: viola brand, pink brand, gradient viola→pink, colori testo primario/secondario, background primario/secondario, border, error/success

### Key Entities *(data model)*

- **Profile**: Identità digitale studente. Attributi: id (uuid), full_name (nome completo max 50 char), username (auto-generated formato nome.cognome, unique), class (classe es. "5A"), bio (testo opzionale max 150 char), avatar_url (Supabase Storage URL o null), role (enum: student/moderator/admin), profile_visible (boolean default true), created_at (timestamp iscrizione), updated_at (timestamp ultima modifica), deleted_at (timestamp soft delete, null se attivo)
- **Avatar**: File immagine profilo. Stored in Supabase Storage path avatars/{user_id}/avatar.jpg, max 2MB, min 200×200px, formato WebP/JPG/PNG, compresso client-side a max 500KB
- **Event**: Evento creato da utente (relazione: event.creator_id → profile.id). Quando profilo eliminato, event.creator_name cambiato a "Utente eliminato" ma evento resta visibile
- **Participation**: Partecipazione utente a evento (relazione: participation.user_id → profile.id). Usato per contare statistiche "X partecipazioni" in profilo

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 90%+ studenti completano profilo (nome, classe, avatar) entro 1 settimana dal primo login
- **SC-002**: 70%+ studenti attivi aggiungono bio personale (campo bio non vuoto)
- **SC-003**: Zero errori upload avatar per file <2MB e >200×200px (100% success rate validazione dimensioni)
- **SC-004**: Export GDPR generato e link disponibile in <10 secondi dal tap "Scarica i tuoi dati"
- **SC-005**: Tempo load profilo <1 secondo (dal tap nome creatore a visualizzazione completa profilo con avatar e stats)
- **SC-006**: 80%+ studenti caricano avatar custom (no avatar default con iniziali) entro 2 settimane
- **SC-007**: Profilo visitato mediamente 5+ volte/settimana per utente attivo (alta engagement scoperta organizzatori)
- **SC-008**: 50%+ studenti condividono profilo altrui almeno 1 volta (funzionalità share utilizzata)
- **SC-009**: Deep links profilo funzionanti 100% (click su nova://profile/{user_id} in chat → apertura profilo senza errori)
- **SC-010**: Avatar upload completato in <3 secondi (incluso compress client-side e upload a Supabase Storage)

## Scope *(optional)*

### Included

- Profilo utente completo (visualizzazione, modifica, stats)
- Avatar upload con crop circolare e compressione
- Username auto-generato da email
- Badge moderatore con distintivo visivo
- Settings e privacy controls
- GDPR compliance (export dati, delete account con grace period)
- Condivisione profilo via deep link e chat
- UI platform-adaptive (Cupertino iOS, Material Android)
- Grid eventi creati e partecipazioni

### Excluded

- Follower/following system (anti-social design)
- Feed personale post (non è Instagram)
- Like/commenti su profilo (solo su eventi)
- Messaggi diretti tra utenti
- Profilo pubblico esterno scuola
- Statistiche avanzate (view count, engagement rate)
- Multiple foto gallery
- Cover photo background
- Badge custom oltre moderatore
- Export dati in formati diversi da JSON

## Constraints *(optional)*

- Avatar max 2MB upload, min 200×200px
- Bio max 150 caratteri
- Nome max 50 caratteri
- Username non modificabile (generato da email)
- Solo email @galileimoro.edu.it permesse
- Profilo visibile solo a utenti autenticati
- GDPR export entro 10 secondi
- Grace period delete 30 giorni fissi
- Colori esclusivamente da design system Nova
- No tracking analytics o pixel esterni

## Assumptions *(optional)*

- Studenti hanno già account creato con email verificata
- Dispositivi studenti supportano camera/gallery access
- Rete scuola permette upload immagini fino a 2MB
- Tutti studenti appartengono a una delle 38 classi definite
- Design system Nova già implementato con colori/font definiti
- Supabase Storage già configurato per avatar bucket
- Deep links registrati nel sistema operativo mobile
- Background job per hard delete configurato (runs daily)
- Moderatori sono studenti selezionati, non esterni
- Non serve approvazione per modifiche profilo (instant publish)

## Dependencies *(optional)*

- Autenticazione Supabase Auth funzionante
- Tabella profiles esistente (creata da Supabase Auth)
- Eventi feature già implementato (per stats eventi creati)
- Partecipazioni feature già implementato (per stats partecipazioni)
- Chat globale per condivisione profilo
- Design system Nova con colori/spacing/typography definiti
- Image picker e image cropper library disponibili
- Deep link handling configurato in app
- Supabase Storage con bucket avatars configurato
- GDPR export background job implementato

## Risks & Mitigations *(optional)*

- **Risk**: Avatar inappropriati (nudità, violenza)
  - **Mitigation**: Moderazione reattiva basata su segnalazioni + eventuale AI content moderation
- **Risk**: Username collision per nomi comuni (es. molti "marco.rossi")
  - **Mitigation**: Algoritmo collision con numeri progressivi (marco.rossi2, marco.rossi3)
- **Risk**: Bio spam con link esterni o contenuti inappropriati
  - **Mitigation**: Sanitizzazione input (no URL), max 150 char, moderazione reattiva
- **Risk**: Abuso GDPR export (DoS con richieste ripetute)
  - **Mitigation**: Rate limiting 1 export/24h per utente
- **Risk**: Avatar upload failure perde modifiche profilo
  - **Mitigation**: Salvataggio separato dati testo e avatar (transazione non atomica)

## Non-Functional Requirements *(optional)*

- **Performance**: Load profilo <1s, avatar upload <3s, GDPR export <10s
- **Scalability**: Supporta 810 studenti concorrenti con profili completi
- **Reliability**: 99.9% uptime profilo view, avatar CDN cached 7 giorni
- **Security**: Avatar validazione server-side tipo/size, bio sanitization XSS
- **Usability**: Zero training richiesto, UI intuitiva Instagram-like
- **Compatibility**: iOS 14+, Android 10+, tutti browser moderni
- **Accessibility**: Labels semantic per screen reader, contrast WCAG 2.1 AA
