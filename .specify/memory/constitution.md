# Nova Project Constitution

**Version:** 2.0.0
**Ratification Date:** 2025-01-15
**Last Amended:** 2025-01-15
**Project:** Nova - Social School Platform

---

## Mission Statement

Nova è la piattaforma social che connette gli studenti delle scuole superiori italiane attraverso contenuti effimeri, memorie condivise e comunicazione in tempo reale. Risolviamo il problema della frammentazione sociale scolastica creando uno spazio digitale dedicato esclusivamente alla vita scolastica.

**Target:** Studenti 14-19 anni, scuole superiori italiane

**Growth Strategy:** Rappresentanti di istituto come ambasciatori → adozione scuola intera → espansione nazionale

**Business Model:** Advertising-supported (free per studenti, monetizzazione ads)

**Success Metrics:**
- 10+ scuole attive entro 6 mesi dal lancio
- 70%+ studenti attivi per scuola adottante
- DAU/MAU ratio >50% (engagement giornaliero)
- 10+ aperture app/giorno per utente attivo
- Revenue: €X CPM su inventory ads

---

## Core Principles

### Principle 1: Engagement First

**Name:** ENGAGEMENT_FIRST

**Statement:** Nova è progettata per massimizzare il tempo e la frequenza di utilizzo. L'engagement è la metrica primaria che guida tutte le decisioni di prodotto.

**Rules:**
- Ogni feature deve aumentare DAU/MAU o session frequency
- Pattern di engagement (streak, FOMO, sblocco) sono strumenti legittimi
- "The Thing" - il meccanismo di ossessività - è obiettivo di design esplicito
- Notifiche push ottimizzate per re-engagement
- Loop quotidiano progettato per multiple sessioni giornaliere

**Key Mechanisms:**
- **Streak:** Giorni consecutivi di costellazioni, visibile pubblicamente
- **Feed Lock:** Devi postare per sbloccare il feed "Oggi"
- **Midnight Reset:** Contenuti effimeri creano urgenza
- **View Tracking:** Sapere chi ti guarda incentiva controllo frequente

**Metrics:**
- App opens/day: target 10+
- Session duration: target 5+ minuti
- DAU/MAU: target >50%
- Streak retention: >30% utenti con streak >7 giorni

---

### Principle 2: School-Native Identity

**Name:** SCHOOL_IDENTITY

**Statement:** L'identità scolastica è il fondamento di Nova. Ogni utente è identificato dalla sua scuola, classe e nome reale.

**Rules:**
- Email scolastica richiesta per registrazione (verifica appartenenza)
- Nome reale obbligatorio (no nickname, no anonimato)
- Classe visibile nel profilo
- Contenuti segregati per scuola (vedi solo la tua scuola)
- Rappresentanti di istituto come admin/ambasciatori

**Rationale:** L'identità reale:
- Riduce comportamenti tossici (accountability)
- Crea senso di community scolastica
- Facilita connessioni IRL
- Differenzia da social anonimi

---

### Principle 3: Ephemeral by Design

**Name:** EPHEMERAL_CONTENT

**Statement:** I contenuti quotidiani sono effimeri. Solo le Costellazioni (memories) persistono.

**Rules:**
- Feed "Oggi a Scuola": reset a mezzanotte
- Foto/video in chat: spariscono dopo visualizzazione
- Meteore: view-once, poi eliminate
- Buffer costellazioni: svuotato a mezzanotte
- Solo Costellazioni salvate permanentemente nel profilo

**Content Lifecycle:**
```
CREAZIONE → VISIBILITÀ TEMPORANEA → MEZZANOTTE → ELIMINAZIONE
                                          ↓
                              (se salvato in Costellazione)
                                          ↓
                                    PERMANENTE
```

**Rationale:** L'effimero:
- Riduce ansia da "post perfetto"
- Crea urgenza (FOMO)
- Incentiva creazione frequente
- Protegge da contenuti imbarazzanti persistenti

---

### Principle 4: Camera-First Creation

**Name:** CAMERA_FIRST

**Statement:** La camera è il punto di ingresso principale per la creazione di contenuti. Nova è un'app visuale.

**Rules:**
- "Nuovo post" apre sempre la camera prima
- Accesso a galleria secondario (swipe up)
- Editing integrato: filtri, testo, sticker, disegni
- Video max 30 secondi
- Foto profilo scattata con camera Nova (no upload)

**Editing Features:**
- Filtri colore
- Testo sovrapposto (font, colori, posizione)
- Disegno a mano libera
- Sticker/emoji
- (Futuro) Filtri facciali AR

---

### Principle 5: Growth Through Ambassadors

**Name:** AMBASSADOR_GROWTH

**Statement:** La crescita avviene attraverso rappresentanti di istituto che portano Nova nella loro scuola.

**Rules:**
- Rappresentanti = primi utenti + admin della loro scuola
- Onboarding scuola richiede minimo 1 rappresentante attivo
- Rappresentanti hanno poteri di moderazione base
- Incentivi per rappresentanti che raggiungono adoption target
- No marketing diretto a studenti individuali

**Growth Funnel:**
```
RAPPRESENTANTE SCOPRE NOVA
         ↓
RAPPRESENTANTE SI REGISTRA (primo della scuola)
         ↓
RAPPRESENTANTE INVITA COMPAGNI
         ↓
MASSA CRITICA RAGGIUNTA (>20% scuola)
         ↓
VIRAL LOOP INTERNO (FOMO fa iscrivere altri)
         ↓
70%+ ADOPTION
```

---

### Principle 6: Monetization via Ads

**Name:** AD_SUPPORTED

**Statement:** Nova è gratuita per gli studenti. La monetizzazione avviene esclusivamente tramite advertising.

**Rules:**
- Zero costi per studenti (mai paywall, mai premium)
- Ads non intrusivi (no interstitial che bloccano)
- Ads contestuali e age-appropriate
- No vendita dati a terzi (ads serviti internamente o via partner trusted)
- Frequency cap per evitare saturazione

**Ad Placements:**
- Feed "Oggi": native ads ogni N post
- Feed "Ieri": native ads tra costellazioni
- Stories/full-screen: da valutare con cautela

**Constraints:**
- Ads must be clearly labeled
- No ads in chat private
- No ads durante creazione contenuti
- Rispetto normative ads per minori (COPPA-like, DSA)

---

### Principle 7: Performance First

**Name:** PERFORMANCE_FIRST

**Statement:** Nova deve essere veloce. 60fps, caricamenti istantanei, zero lag.

**Rules:**
- Feed load: <1s cached, <3s first load
- Camera launch: <500ms
- Video playback: instant start (preload)
- 60fps sustained durante scroll
- Offline support per contenuti cached

**Budgets:**
- APK size: <80MB (più grande per features camera/editing)
- Image max: 500KB (compressione automatica)
- Video max: 10MB (compressione automatica)

---

## Future Features (Roadmap)

Le seguenti feature saranno specificate e implementate in fasi successive:

- **Camera** (stile Snapchat) - creazione contenuti visivi
- **Feed "Oggi a Scuola"** - contenuti effimeri del giorno
- **Feed "Ieri"** - costellazioni degli altri
- **Costellazioni** - memories permanenti
- **Streak** - engagement giornaliero
- **Chat System** - comunicazione diretta e gruppi
- **Meteore** - contenuti view-once
- **Profilo** - identità e calendario costellazioni
- **Onboarding Forzato** - conversione garantita

Ogni feature sarà specificata tramite il workflow SpecKit prima dell'implementazione.

---

## Technical Stack

### Required Technologies

**Frontend:**
- **Language:** Dart (Flutter SDK 3.x+)
- **State Management:** Riverpod
- **Camera:** camera package + custom editing
- **Video:** video_player, video_compress
- **Storage:** Hive (local cache)

**Backend:**
- **Platform:** Supabase Cloud
- **Database:** PostgreSQL 15+
- **Auth:** Magic Link (email scolastica)
- **Storage:** Supabase Storage (CDN)
- **Realtime:** Supabase Realtime (WebSocket)
- **Functions:** Supabase Edge Functions

**Ads:**
- **Provider:** Google AdMob (o alternativa age-appropriate)
- **Format:** Native ads, banner
- **Compliance:** GDPR, DSA per minori

**Push Notifications:**
- **Provider:** Firebase Cloud Messaging (FCM)

---

### Architecture

```
lib/
├── core/
│   ├── theme/           # Design system
│   ├── services/        # Supabase, notifications, ads
│   ├── providers/       # Riverpod core
│   └── utils/           # Helpers
├── features/
│   ├── auth/            # Magic link auth
│   ├── onboarding/      # Forced onboarding flow
│   ├── camera/          # Camera + editing
│   ├── feed_today/      # Feed "Oggi a Scuola"
│   ├── feed_yesterday/  # Feed "Ieri" (costellazioni)
│   ├── constellations/  # Costellazioni creation
│   ├── chat/            # All chat types
│   ├── meteors/         # View-once content
│   ├── profile/         # User profiles
│   ├── streak/          # Streak tracking
│   ├── notifications/   # Push + in-app
│   └── ads/             # Ad integration
└── shared/
    └── widgets/         # Reusable components
```

---

## Content Moderation

### Approach: Reactive (Post-Hoc)

**No moderazione preventiva** - contenuti vanno live immediatamente.

**Moderation Tools:**
- Report button su ogni contenuto
- Moderatori (rappresentanti) possono rimuovere
- Auto-detection per contenuti espliciti (nudity, violence)
- Ban temporaneo/permanente per violazioni ripetute

**Response Time:**
- Report reviewed: <24 ore
- Contenuto illegale: rimozione immediata (auto-detect)

**Appeals:**
- Utenti possono contestare rimozioni
- Review da moderatore diverso

---

## Compliance & Legal

### GDPR
- Consenso esplicito per minori (14-17: consenso proprio in Italia)
- Data export su richiesta
- Account deletion su richiesta
- Privacy policy chiara

### DSA (Digital Services Act)
- No dark patterns su minori (interpretazione: pattern devono essere trasparenti)
- Age verification via email scolastica
- Reporting mechanism obbligatorio
- Transparency reports

### Advertising to Minors
- Ads age-appropriate
- No targeting comportamentale avanzato
- No ads per alcol, gambling, etc.
- Compliance AGCM (Italia)

---

## Anti-Goals (Removed/Modified from v1)

**Nova 2.0 RIMUOVE i seguenti anti-goal della v1:**

| Anti-Goal v1 | Status v2 | Rationale |
|--------------|-----------|-----------|
| No social network dynamics | **RIMOSSO** | Nova È un social network |
| No ads | **RIMOSSO** | Ads = business model |
| No addictive patterns | **RIMOSSO** | Engagement = obiettivo |
| No expansion | **RIMOSSO** | Espansione nazionale = goal |

**Nova 2.0 MANTIENE:**

| Anti-Goal | Status |
|-----------|--------|
| No vendita dati a terzi | ✅ Mantenuto |
| No surveillance per admin/genitori | ✅ Mantenuto |
| Nome reale obbligatorio (no anonimato tossico) | ✅ Mantenuto |

---

## Governance

### Amendment Process

**Version 2.0.0** rappresenta un pivot fondamentale del progetto.

**Future amendments:**
- MAJOR (3.0.0): Cambio business model o target audience
- MINOR (2.x.0): Nuove feature principali, nuovi principi
- PATCH (2.0.x): Clarificazioni, bug fix documentazione

**Decision Authority:**
- Solo phase (current): Giovanni
- Future: Team consensus

---

## Open Questions

### "The Thing" - Meccanismo Ossessività

Obiettivo: meccanismo che fa aprire app 10+ volte/giorno.

**Candidati da esplorare:**
1. "Qualcosa Sta Succedendo" - notifica misteriosa
2. "Il Segreto del Giorno" - contenuto sbloccabile
3. "Chi Ti Nota" - chi ha guardato il tuo profilo
4. "Battito" - activity pulse della scuola
5. "La Rete Invisibile" - connessioni nascoste
6. "Il Momento" - evento random giornaliero
7. "Frequenze" - matching con altri studenti

**Status:** Da definire con user research/testing

---

## Migration from Nova 1.x

### Code Reuse
- Auth system: riutilizzabile (magic link)
- Supabase infrastructure: riutilizzabile
- Design system base: da estendere
- Events feature: deprecata o integrata in feed

### Breaking Changes
- Nuovo schema database per contenuti effimeri
- Nuovo sistema notifiche per engagement
- Camera feature completamente nuova
- Feed system completamente nuovo

### Transition
- Nova 1.x per Galilei Moro può continuare separatamente
- Nova 2.0 è nuovo prodotto con nuovo target

---

## Version History

- **2.0.0** (2025-01-15): Pivot completo a social school platform con ads, pattern engagement, espansione multi-scuola
- **1.2.0** (2025-01-13): Ultima versione pre-pivot
- **1.0.0** (2024-10-29): Costituzione originale

---

*Questa costituzione governa Nova 2.0, la piattaforma social per studenti delle scuole superiori italiane.*

---

**Ratified by:** Giovanni (Founder)
**Date:** 2025-01-15
