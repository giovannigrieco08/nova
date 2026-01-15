# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project: Nova - Social School Platform

**Purpose:** Nova è la piattaforma social che connette gli studenti delle scuole superiori italiane attraverso contenuti effimeri, memorie condivise (Costellazioni) e comunicazione in tempo reale.

**Target Users:** Studenti 14-19 anni, scuole superiori italiane (espansione nazionale)

**Core Features (Future):** Camera, Feed "Oggi a Scuola", Feed "Ieri", Costellazioni, Streak, Chat, Meteore, Profilo

**Business Model:** Advertising-supported (free per studenti)

**Growth Strategy:** Rappresentanti di istituto come ambasciatori → adozione scuola → espansione nazionale

**Current Status:** Pivot phase - Constitution 2.0.0 ratified, transitioning from events platform to social platform

---

## SpecKit Workflow (Critical Section)

Nova uses the **SpecKit methodology** for specification-driven development. All features MUST be specified before implementation.

### Available Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| [/speckit.specify](./claude/commands/speckit.specify.md) | Create feature specification from natural language | Start of every new feature |
| [/speckit.clarify](./claude/commands/speckit.clarify.md) | Ask up to 5 targeted clarification questions | When spec has ambiguities marked `[NEEDS CLARIFICATION]` |
| [/speckit.plan](./claude/commands/speckit.plan.md) | Generate technical design (research, data model, contracts) | After spec is clarified and approved |
| [/speckit.tasks](./claude/commands/speckit.tasks.md) | Generate dependency-ordered task list | After plan is complete |
| [/speckit.analyze](./claude/commands/speckit.analyze.md) | Validate cross-artifact consistency (read-only) | Before implementation or periodically |
| [/speckit.implement](./claude/commands/speckit.implement.md) | Execute all tasks from tasks.md | When ready to build the feature |
| [/speckit.checklist](./claude/commands/speckit.checklist.md) | Generate custom requirement quality checklists | Any time to validate spec quality |
| [/speckit.constitution](./claude/commands/speckit.constitution.md) | Update project governance document | When amending principles or constraints |

### Workflow Sequence

```
1. /speckit.specify "Feature description"
   → Creates: specs/[###-feature-name]/spec.md
   → Generates: User stories (P1/P2/P3), requirements (FR-###), success criteria
   → Output: Branch created, spec file with clarification questions

2. /speckit.clarify (if needed)
   → Resolves: Max 5 [NEEDS CLARIFICATION] markers in spec
   → Updates: spec.md with user-provided answers
   → Output: Fully specified feature ready for planning

3. /speckit.plan
   → Creates: research.md, data-model.md, contracts/, quickstart.md, plan.md
   → Validates: Constitution Check (ensures compliance with principles)
   → Output: Complete technical design

4. /speckit.tasks
   → Creates: tasks.md with phase-based organization
   → Organizes: By user story (P1 → P2 → P3), with [P] parallel markers
   → Output: Executable task list with dependencies

5. /speckit.analyze (optional)
   → Validates: Consistency across spec/plan/tasks
   → Reports: Gaps, conflicts, constitution violations
   → Output: Quality report (non-destructive)

6. /speckit.implement
   → Executes: All tasks from tasks.md in dependency order
   → Verifies: Checklists complete before starting
   → Output: Fully implemented feature with tests
```

### Branch Naming Conventions

```bash
feature/[###]-<short-name>    # New features (merge via PR)
fix/[###]-<short-name>        # Bug fixes (merge via PR)
spec/[###]-<short-name>       # Spec-only changes (merge directly)
prototype/[###]-<short-name>  # Exploratory code (max 1 week)
spike/[###]-<short-name>      # Technical research (max 1 week)
```

---

## Constitution - Supreme Governance Document

**Location:** [.specify/memory/constitution.md](.specify/memory/constitution.md)
**Version:** 2.0.0 (ratified 2025-01-15)
**Authority:** Constitution supersedes all other documents. When in doubt, consult the constitution.

### The 7 Core Principles (v2.0.0)

| ID | Principle | Summary | Key Metric |
|----|-----------|---------|------------|
| 1 | **ENGAGEMENT_FIRST** | Massimizzare tempo e frequenza di utilizzo | DAU/MAU >50%, 10+ app opens/day |
| 2 | **SCHOOL_IDENTITY** | Email scolastica + nome reale obbligatori | 100% verified users |
| 3 | **EPHEMERAL_CONTENT** | Contenuti quotidiani effimeri, solo Costellazioni persistono | Reset a mezzanotte |
| 4 | **CAMERA_FIRST** | Camera come punto di ingresso principale | Camera launch <500ms |
| 5 | **AMBASSADOR_GROWTH** | Crescita tramite rappresentanti di istituto | 70%+ adoption per scuola |
| 6 | **AD_SUPPORTED** | Monetizzazione ads, zero costi studenti | Revenue via CPM |
| 7 | **PERFORMANCE_FIRST** | 60fps, <1s load, zero lag | Feed <1s cached |

### Key Engagement Mechanisms

- **Streak:** Giorni consecutivi di costellazioni (visibile pubblicamente)
- **Feed Lock:** Devi postare per sbloccare il feed "Oggi"
- **Midnight Reset:** Contenuti effimeri creano urgenza
- **View Tracking:** Sapere chi ti guarda incentiva controllo frequente

### Anti-Goals (v2.0.0)

Nova will **NEVER:**
1. Vendere dati a terzi (ads serviti internamente)
2. Diventare surveillance tool per admin/genitori
3. Permettere anonimato (nome reale obbligatorio)

**Removed from v1:** No ads, no social dynamics, no expansion, no addictive patterns - questi sono ora obiettivi espliciti.

---

## Technology Stack

### Required Stack

**Frontend:**
- **Language:** Dart (Flutter SDK 3.x+)
- **State Management:** Riverpod
- **Camera:** camera package + custom editing
- **Video:** video_player, video_compress
- **Local Storage:** Hive

**Backend:**
- **Platform:** Supabase Cloud
- **Database:** PostgreSQL 15+
- **Auth:** Magic Link (email scolastica)
- **Storage:** Supabase Storage (CDN)
- **Realtime:** Supabase Realtime (WebSocket)
- **Functions:** Supabase Edge Functions

**Monetization:**
- **Ads:** Google AdMob (o alternativa age-appropriate)
- **Compliance:** GDPR, DSA per minori

**Push Notifications:**
- **Provider:** Firebase Cloud Messaging (FCM)

---

## Architecture Pattern

### Feature-First Clean Architecture

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

### Mandatory Architectural Rules

1. **Features are self-contained:** Minimal cross-feature imports
2. **Data layer Supabase-only:** No direct UI to database calls
3. **Presentation uses Riverpod exclusively:** No direct repository instantiation
4. **Shared widgets are pure presentation:** No business logic, only UI rendering
5. **Domain layer is framework-agnostic:** Can be tested without Flutter

---

## Common Development Commands

### SpecKit Commands (In Conversation)

```
/speckit.specify "Create camera feature with filters"
/speckit.clarify
/speckit.plan
/speckit.tasks
/speckit.implement
/speckit.analyze
/speckit.checklist
/speckit.constitution
```

### Flutter Commands (Terminal)

```bash
# Setup & Dependencies
flutter pub get                  # Install dependencies
flutter doctor                   # Check Flutter environment

# Development
flutter run                      # Run app on connected device
flutter run -d <device-id>       # Run on specific device
flutter clean                    # Clean build artifacts

# Testing
flutter test                     # Run all tests
flutter test --coverage          # Run tests with coverage

# Code Quality
dart analyze                     # Run static analysis
dart format lib/                 # Format Dart code

# Building
flutter build apk                # Build Android APK
flutter build ios                # Build iOS app
```

### Git Workflow

```bash
# Commit with Conventional Commits format
git commit -m "feat(camera): add color filters"
git commit -m "feat(feed): implement midnight reset"
git commit -m "fix(streak): correct counter logic"

# Commit types: feat, fix, spec, docs, refactor, test, chore, perf, style, ci
# Scope: Feature name (camera, feed, chat, profile, streak, ads)
```

---

## Code Review Checklist

Before merging any code to `main` branch, verify:

- [ ] **Spec compliance:** Implementation matches specification exactly
- [ ] **Design system:** All colors, spacing, typography from design system constants
- [ ] **Tests pass:** All existing tests pass; new tests added for new functionality
- [ ] **Performance:** No regressions (60fps, <1s loads)
- [ ] **Engagement:** Feature contributes to DAU/MAU or session frequency
- [ ] **Ads compliance:** Ads age-appropriate, clearly labeled, frequency capped
- [ ] **Security:** No sensitive data in logs, RLS policies enforced

---

## Success Metrics & KPIs

From [Constitution 2.0.0](.specify/memory/constitution.md):

**Growth:**
- 10+ scuole attive entro 6 mesi
- 70%+ studenti attivi per scuola adottante

**Engagement:**
- DAU/MAU ratio >50%
- 10+ aperture app/giorno per utente attivo
- Streak retention >30% utenti con streak >7 giorni

**Technical:**
- Feed load <1s cached, <3s first load
- Camera launch <500ms
- 60fps sustained
- APK size <80MB

**Revenue:**
- €X CPM su inventory ads

---

## Compliance & Legal

### GDPR
- Consenso esplicito per minori (14-17: consenso proprio in Italia)
- Data export su richiesta
- Account deletion su richiesta
- Privacy policy chiara

### DSA (Digital Services Act)
- Age verification via email scolastica
- Reporting mechanism obbligatorio
- Transparency reports

### Advertising to Minors
- Ads age-appropriate
- No targeting comportamentale avanzato
- No ads per alcol, gambling, etc.
- Compliance AGCM (Italia)

---

## Notes for Claude Code Instances

### Current Project State

**Status:** Pivot phase (v1.x → v2.0)
- ✅ Constitution 2.0.0 ratified
- ✅ New direction defined (social platform)
- ⚠️ Existing v1 code needs migration/deprecation
- ❌ New features (Camera, Feed, Costellazioni) not yet implemented

### What This Project Is (v2.0)

- **Social school platform** per studenti scuole superiori italiane
- **Engagement-first** con pattern FOMO, streak, sblocco feed
- **Camera-first** per creazione contenuti visuali
- **Ads-supported** (free per studenti, monetizzazione advertising)
- **Multi-school** con espansione nazionale via ambasciatori

### What This Project Is NOT

- ❌ Not anonymous (nome reale obbligatorio sempre)
- ❌ Not a data broker (no vendita dati a terzi)
- ❌ Not surveillance (no tracking per admin/genitori)

### Critical Decision-Making Rules

**When Unsure About Any Decision:**

1. **Check the Constitution first:** [.specify/memory/constitution.md](.specify/memory/constitution.md)
   - Constitution 2.0.0 is supreme authority
   - Focus on engagement metrics (DAU/MAU)
   - Ads are legitimate, but age-appropriate

2. **Check the Feature Spec:** `specs/[###-feature-name]/spec.md`
   - Spec defines WHAT and WHY
   - Implementation must match spec exactly

3. **If Conflict Arises:**
   - Constitution > Spec > Code
   - Amend constitution through governance process if needed

### Common Pitfalls to Avoid

1. **❌ Hardcoded UI values:** Use design system constants
2. **❌ Direct Supabase calls from widgets:** Use repository pattern + Riverpod
3. **❌ Logging sensitive data:** Never log emails or PII
4. **❌ Skipping spec step:** All features need spec.md before implementation
5. **❌ Implementing without RLS:** All Supabase tables must have Row-Level Security
6. **❌ Intrusive ads:** No interstitials, no ads in chat, frequency cap required
7. **❌ Allowing anonymity:** Nome reale sempre obbligatorio

---

## Related Documentation

- **[Constitution v2.0.0](.specify/memory/constitution.md)** - Supreme governance document
- **[Spec Template](.specify/templates/spec-template.md)** - Feature specification structure
- **[Plan Template](.specify/templates/plan-template.md)** - Implementation plan structure
- **[Tasks Template](.specify/templates/tasks-template.md)** - Task list organization pattern
- **[SpecKit Commands](.claude/commands/)** - Slash command definitions

---

**Last Updated:** 2025-01-15
**Constitution Version Referenced:** 2.0.0
**Project Phase:** Pivot (v1 → v2)

---

*Nova 2.0: Social school platform con engagement-first design e monetizzazione ads.*
