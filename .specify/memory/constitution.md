<!--
Sync Impact Report:
Version: 1.0.0 → 1.1.0 (MINOR bump)
Amendment Date: 2024-10-29
Amendment Rationale: Add operational clarity for governance, legal compliance, and development workflow

Modified Principles:
- Principle 5 (SPEC_FIRST): Expanded with prototype guidelines for exploratory development
- Principle 7 (CONTENT_MODERATION): Expanded with detailed moderator accountability system

Added Sections:
- Governance → Emergency Override Procedure (existential risk safety valve)
- Technical Constraints → Security Requirements → GDPR Compliance Requirements (legal mandate)
- Core Principles → Principle 7 → Moderator Selection & Accountability (governance detail)
- Core Principles → Principle 5 → Prototype Guidelines (development workflow flexibility)

Removed Sections: None

Templates Status:
  ✅ plan-template.md - No changes required (principles still align)
  ✅ spec-template.md - No changes required (scope requirements unchanged)
  ✅ tasks-template.md - No changes required (task categories unchanged)
  ✅ Command files (.claude/commands/*.md) - No changes required (references still valid)

Follow-up TODOs:
- [ ] Create git tag: constitution-v1.1.0 after committing changes
- [ ] Schedule next constitution review: 2024-11-12 (2 weeks)
- [ ] Implement GDPR data export feature in roadmap (Right to Access requirement)
- [ ] Draft Privacy Policy document before MVP launch
- [ ] Create moderator training materials (content guidelines with examples)
-->

# Nova Project Constitution

**Version:** 1.1.0
**Ratification Date:** 2024-10-29
**Last Amended:** 2024-10-29
**Project:** Nova - School Events Platform for Liceo Galilei Moro

---

## Mission Statement

Nova connects Liceo Galilei Moro students through a transparent, safe, and engaging platform for school events, collaboration requests, and community communication. We solve the problem of scattered event information and low student participation by providing a single, beautiful, privacy-respecting mobile application built specifically for our school community.

**Success is measured by:**
- 70%+ student adoption within 6 months of launch
- 50+ events created per month across all categories
- <1% inappropriate content (effective moderation working)
- 4.5+ star average rating from student users
- Zero privacy incidents or data breaches

---

## Core Principles

### Principle 1: Students First

**Name:** STUDENTS_FIRST

**Statement:** Every product, design, and technical decision MUST prioritize student benefit over administrative convenience or other stakeholder interests.

**Rules:**
- Features are designed for ages 14-19, not for adults
- User flows optimized for speed: create event in <2 minutes maximum
- UI uses teenage-friendly language and modern aesthetics (space-themed, glassmorphic)
- Feature requests from students take priority over institutional requests
- "What do students actually want?" is asked before every feature discussion
- Admin users are student representatives, not teachers or staff

**Rationale:** Students are our users. An app that serves administrators but frustrates students will fail. Student adoption is the primary success metric, therefore student needs are the primary design input.

**Testing/Validation:**
- User testing with actual Galilei Moro students before major releases
- Student feedback collected via in-app surveys every 2 weeks post-launch
- Feature usage analytics reviewed: if <30% adoption after 1 month, feature is reconsidered
- Design decisions documented with student benefit justification

---

### Principle 2: Privacy Foundation

**Name:** PRIVACY_FOUNDATION

**Statement:** Student privacy is non-negotiable. Nova MUST collect minimal data, never sell or share data, and implement privacy-first architecture from day one.

**Rules:**
- School email-only authentication (verified @galileimoro.edu.it domain)
- Data collected limited to: name, class, email, optional Instagram handle. Nothing more without explicit constitutional amendment.
- Zero third-party tracking (no Google Analytics, Facebook SDK, or similar)
- Zero advertising ever (not now, not later, not "privacy-respecting" ads)
- Chat messages auto-delete after 24 hours (ephemeral by design)
- Local-first architecture: app works offline, syncs when online
- All database access logged and auditable
- GDPR and privacy-by-design principles enforced in code review

**Rationale:** Students are minors (14-18 years old). Privacy violations damage trust irreparably and violate legal requirements (GDPR). Being privacy-first is both an ethical requirement and competitive advantage. We build trust by never exploiting it.

**Testing/Validation:**
- Privacy audit before v1.0 launch (self-audit against GDPR checklist)
- Data access logs reviewed monthly
- Zero telemetry except aggregate, anonymized usage statistics
- Every new feature requires "Privacy Impact Assessment" section in spec
- Code review checklist includes "New data collected? Justified?"

---

### Principle 3: Simplicity First

**Name:** SIMPLICITY_FIRST

**Statement:** Nova MUST remain simple and focused. Every feature added increases complexity cost. Default answer to new features is "no" unless compelling student need is proven.

**Rules:**
- MVP launches with exactly 5 core features: Events, Bacheche (Request Board), Global Chat, Profile, Moderation Queue
- New features require written spec with: problem statement, user research evidence, complexity cost analysis
- YAGNI principle enforced: "You Aren't Gonna Need It" until proven otherwise
- Code complexity monitored: no file exceeds 500 lines, no function exceeds 50 lines without explicit justification
- Remove features faster than adding them: if <20% adoption after 3 months, feature is deprecated
- "Could we solve this without code?" asked before every implementation

**Rationale:** Feature bloat kills apps. Simple apps are maintainable, debuggable, and actually get used. Complexity is technical debt. We compete on polish and user experience, not feature count.

**Testing/Validation:**
- Feature proposal template requires "Why can't users live without this?" section
- Monthly feature usage review: flag features with <20% weekly active user adoption
- Code review rejects files exceeding 500 lines without refactoring plan
- Complexity metrics tracked in CI (cyclomatic complexity, file sizes)

---

### Principle 4: Performance First

**Name:** PERFORMANCE_FIRST

**Statement:** Nova MUST be fast. Speed is a feature, not an optimization. Slow apps feel broken. Target: 60fps UI, <1s load times, instant perceived feedback.

**Rules:**
- Feed screen loads in <1 second on cached data, <3 seconds on first load (4G connection)
- All user interactions have <200ms perceived response time (use optimistic UI updates)
- 60fps minimum sustained frame rate (UI jank is a P0 bug - highest priority)
- Images: WebP format required, cached aggressively, lazy-loaded, maximum 200KB per image
- Offline-first: app functions without network for viewing cached content
- Performance regression tests: fail if load time increases >10% without justification
- Profile before optimizing: measure with Flutter DevTools, don't guess

**Rationale:** Teenagers have zero patience for slow apps. Slow equals broken in their mental model. Speed builds perception of quality and reliability. Performance issues drive user abandonment.

**Testing/Validation:**
- Flutter DevTools timeline reviewed before every release (no dropped frames in critical user paths)
- Real device testing on mid-range Android phones (not just flagship devices)
- Network throttling tests (slow 3G simulation)
- Performance budget enforced in CI: APK size, load times, frame render times

---

### Principle 5: Spec-Driven Development

**Name:** SPEC_FIRST

**Statement:** All features MUST be specified in written specs before implementation. Specs are reviewed before code. Code implements specs exactly, not developer intuition.

**Rules:**
- Production features MUST have written spec before merging to main branch
- **Exploratory prototypes allowed:** Code exploration in feature/* branches permitted without spec (discovery phase)
- **Prototype resolution:** Prototype code must be either:
  - (a) Thrown away after learning (document findings in spec), OR
  - (b) Spec written retroactively covering learnings before merge to main
- Specs reviewed and approved before code review for all main branch merges
- Implementation must match spec exactly (deviations require spec amendment with rationale)
- Specs are living documents: updated when requirements change, not abandoned
- **No "document later" on main branch** - this explicitly violates the principle

**Prototype Guidelines:**
- Maximum prototype lifetime: 1 week (forces decision: spec it or discard it)
- Prototype branch naming: prototype/* or spike/* (distinguishes from production features)
- Prototype documentation: Create spike-[feature].md with: hypothesis tested, learnings, decision (proceed with spec OR discard)

**Rationale:** Specs prevent wasted effort building wrong solutions. Spec review is faster and cheaper than code review. Specs serve as authoritative documentation. SpecKit methodology has proven effectiveness for governance and quality. Prototypes enable discovery without compromising production quality.

**Testing/Validation:**
- Pull request template includes mandatory "Spec reference: specs/path/to/spec.md" field
- Code review checklist item: "Does implementation match spec exactly?"
- Pull requests rejected if: no spec exists, or code contradicts spec without amendment
- Spec compliance audited monthly
- Prototype branches deleted after 1 week if not promoted to spec + implementation

---

### Principle 6: Design System Enforced

**Name:** DESIGN_SYSTEM_STRICT

**Statement:** All UI code MUST follow design system constants. Zero hardcoded colors, spacing, or typography values. Design system is single source of truth for visual design.

**Rules:**
- All colors from `NovaColors` class (no hex color codes in widgets: `Color(0xFF...)` forbidden)
- All spacing from `NovaSpacing` class (no magic numbers like `padding: EdgeInsets.all(16)`)
- All typography from `NovaTypography` class (no inline `TextStyle(fontSize: 18, ...)`)
- All border radius from `NovaRadius` class
- Glassmorphism effect via `GlassContainer` widget only (no inline `BackdropFilter` implementations)
- Design system documented in `specs/design-system.md` with exact pixel-perfect values
- Claude Code prompts always reference design system constants

**Rationale:** Hardcoded values create visual inconsistency, make design changes expensive, and violate single source of truth principle. Design systems enable rapid iteration while maintaining visual consistency and quality.

**Testing/Validation:**
- Automated lint rules flag raw color values (e.g., `Color(0xFF...)`) and reject pull request
- Visual regression tests: golden file tests for key screens
- Design system compliance in pull request checklist: "All values from design system constants? Y/N"
- Random monthly audit: check 3 random widget files for compliance

---

### Principle 7: Content Moderation

**Name:** CONTENT_MODERATION

**Statement:** Nova is a school platform extension, not a generic social network. Content MUST be school-appropriate, educational, or event-related. Human moderation is mandatory for all public content.

**Rules:**
- All events reviewed by student moderators before publication (approval queue required)
- Content guidelines published and enforced: no hate speech, harassment, inappropriate content, spam, or off-topic posts
- Chat is ephemeral (24-hour auto-delete) and monitored (automated flagging plus human review)
- No private messaging feature (only public global school chat) - prevents cyberbullying accumulation and inappropriate private conversations
- Report button on every piece of user-generated content (events, comments, chat messages)
- Moderator dashboard accessible to student representatives (not admin-only, not teachers)
- Appeals process: content creators can request re-review with explanation if rejected

**Rationale:** School environment requires higher content standards than public internet. Students are minors, safety is paramount. Human moderation respects context and nuance better than pure algorithmic filtering. Transparency in moderation process builds community trust.

**Testing/Validation:**
- Moderation queue review time never exceeds 24 hours (measured weekly)
- False positive rate <5% (approved content wrongly flagged - measured monthly)
- Content guidelines user-tested with actual students before launch
- Moderator training materials provided (written guidelines with clear examples)
- Quarterly review of moderation decisions for consistency and fairness

#### Moderator Selection & Accountability

**Selection Process:**
- **Eligibility criteria:** Current enrolled students at Liceo Galilei Moro, good academic standing, no prior content guideline violations
- **Selection method (initial phase):** Student council representatives or class representatives nominated by their class
- **Selection method (mature phase):** Open application process with peer review and founder approval
- **Onboarding required:** Complete moderator training (content guidelines, appeal process, moderation tools tutorial) before receiving access

**Term Limits:**
- **Duration:** 1 academic year (September → June)
- **Renewal:** Eligible for renewal once (max 2 consecutive years)
- **Succession planning:** New moderators onboarded 2 weeks before term end (knowledge transfer period)

**Removal Process:**
- **Voluntary resignation:** Moderator can resign anytime (2-week notice preferred)
- **Removal for cause:** Abuse of power, systematic guideline violations, inactivity >2 weeks without notice
- **Removal procedure:** 2/3 majority vote of other moderators + founder approval (during solo phase) OR team consensus (future team phase)
- **Appeal:** Removed moderator can appeal decision to founder/team with written explanation

**Transparency & Accountability:**
- **Action logging:** All moderation actions logged in database (moderator_id, action_type, target_content_id, timestamp, reason)
- **Monthly audit:** Review moderation decisions for consistency (check for bias, arbitrary rejections, pattern of unfair decisions)
- **Public transparency report:** Quarterly report published (anonymized): total events reviewed, approval rate, rejection reasons breakdown, appeal outcomes
- **Peer review:** Moderators can flag each other's decisions for review if they disagree

**Appeals Process:**
- **Who can appeal:** Any user whose content was rejected or removed
- **How to appeal:** In-app button "Request Review" on rejected content → Opens appeal form with explanation field
- **Review by:** Different moderator than original reviewer (prevents same-person bias)
- **Timeline:** Appeals reviewed within 48 hours
- **Outcome:** Approve (content published), Deny (rejection upheld with detailed explanation), Escalate (founder/team reviews edge case)
- **Appeal tracking:** Users can see appeal status in Settings → My Content → Appeals

---

## Technical Constraints

### Required Technology Stack

**Language:** Dart (Flutter SDK 3.x+)
**State Management:** Riverpod (mandated for consistency and testability)
**Backend:** Supabase Cloud (PostgreSQL database, Authentication, Storage, Realtime subscriptions)
**Database:** PostgreSQL 15+ (via Supabase)
**Authentication:** Magic Link (passwordless email-only authentication via Supabase Auth)
**Image Storage:** Supabase Storage (CDN-backed for performance)
**Deployment:** Supabase Cloud (EU Frankfurt region for GDPR compliance)

**Rationale for stack choices:**
- **Flutter/Dart:** Cross-platform (iOS + Android from single codebase), native 60fps performance, excellent developer experience with hot reload
- **Riverpod:** Type-safe state management, highly testable architecture, compile-time safety
- **Supabase Cloud:** Open-source Firebase alternative with full PostgreSQL power, zero DevOps overhead during MVP phase, generous free tier (500MB database, 1GB storage), can migrate to self-hosted later if needed
- **Magic Link:** Passwordless authentication eliminates password reset flows and is more secure (email as second factor), better UX for students

**Non-Negotiable:** No framework changes mid-project. Technology stack switches destroy momentum and create massive technical debt.

---

### Architecture Requirements

**Pattern:** Feature-first clean architecture with clear separation of concerns

```
lib/
├── core/                    # Shared utilities, theme, constants
│   └── theme/              # Design system (colors, spacing, typography, radius)
│       ├── nova_colors.dart
│       ├── nova_spacing.dart
│       ├── nova_radius.dart
│       ├── nova_typography.dart
│       └── app_theme.dart
├── features/               # Feature modules (eventi, auth, chat, profilo, etc.)
│   └── eventi/
│       ├── data/          # Supabase repositories, data sources
│       ├── domain/        # Models, entities, business logic
│       └── presentation/  # Screens, widgets, Riverpod providers
└── shared/                # Reusable widgets (GlassContainer, etc.)
    └── widgets/
```

**Mandatory architectural rules:**
- Features are self-contained modules with minimal cross-feature imports
- Data layer interacts with Supabase only (no direct UI to database calls)
- Presentation layer uses Riverpod providers exclusively (no direct repository instantiation)
- Shared widgets are pure presentation (no business logic, only UI rendering)
- Domain layer is framework-agnostic (can be tested without Flutter)

---

### Security Requirements

#### **Authentication Security:**
- Email domain validation enforced: reject all non-@galileimoro.edu.it email addresses at both client and server levels
- Magic link expiration: 15 minutes from generation (balance security and UX)
- Session management: 30-day refresh tokens, automatic logout after 30 days inactivity
- No password storage ever (passwordless authentication only)

#### **Authorization:**
- Row-Level Security (RLS) policies in Supabase enforced for all tables (non-negotiable)
- Students see only approved events (status = 'approved' in database query)
- Moderators access pending events via role-based access control (role = 'moderatore')
- Users can only modify their own created content (enforced by creator_id = auth.uid() in RLS policies)
- API endpoints protected: all requests require valid JWT token from Supabase Auth

#### **Data Protection:**
- HTTPS-only connections (HTTP explicitly rejected in app configuration)
- Supabase connection: TLS 1.3 minimum (reject older TLS versions)
- Chat messages encrypted at rest using Supabase native encryption
- No sensitive data in application logs (sanitize before logging - see logging rules below)
- Database backups: automated daily backups by Supabase Cloud with 7-day retention

#### **Logging Rules:**
```dart
// ✅ CORRECT - Log actions and IDs only
logger.info('Event created: ${event.id}');
logger.info('User authenticated: ${user.id}');

// ❌ FORBIDDEN - Never log sensitive data
logger.debug('Login: ${email} ${password}'); // NEVER
logger.debug('User data: ${user.toJson()}'); // Contains email
```

#### **GDPR Compliance Requirements:**

Nova complies with GDPR (EU Regulation 2016/679) as students are EU residents and minors.

**Mandatory Rights Implementation:**
- **Right to Access (Art. 15):** Users export all data in JSON format via Settings → Privacy → Download My Data
- **Right to Erasure (Art. 17):** Users delete account via Settings → Privacy → Delete Account (irreversible after 30 days)
- **Right to Data Portability (Art. 20):** Export includes: profile data, created events, comments, participation history
- **Right to Rectification (Art. 16):** Users edit profile data directly in-app
- **Consent Management (Art. 7):** Clear opt-in for optional data (Instagram handle) with withdrawal option

**Data Retention & Deletion:**
- Deleted accounts: soft-deleted (30-day grace period), then hard-deleted from production database
- Backup purging: Deleted data removed from automated backups after 90 days (Supabase retention policy)
- Chat messages: auto-deleted after 24 hours (ephemeral by design, GDPR compliant by default)

**Documentation Required:**
- Privacy Policy published at nova.galileimoro.edu.it/privacy (accessible without login)
- In-app Privacy Policy link in Settings → Privacy
- Privacy Policy updated before each release if data practices change

---

### Performance Budgets

**Load Time Requirements:**
- Splash screen to Login: <2 seconds
- Login success to Feed screen: <1 second (with cached data) OR <3 seconds (first load from network)
- Feed infinite scroll: sustained 60fps during scroll
- Image loading: progressive (blur placeholder → full resolution)

**Network Performance:**
- API response time: p95 <500ms (95th percentile - meaning 95% of requests faster than 500ms)
- Supabase Realtime updates: <100ms latency for chat messages (websocket connection)
- Offline mode support: Feed cached for 24 hours, user actions queued when offline and synced when connection returns

**Bundle Size Limits:**
- Android APK size: <50MB (Google Play Store download)
- iOS IPA size: <60MB (App Store download)
- Image assets total: <5MB combined (use WebP compression)

**Monitoring:** Performance metrics tracked in production using Supabase analytics and custom logging. Performance regressions trigger investigation and must be resolved before next release.

---

## Development Workflow

### Branch Strategy

```
main          → Production branch (App Store / Play Store releases only)
feature/X     → New features (branch from main, merge back via PR)
fix/X         → Bug fixes (branch from main, merge back via PR)
spec/X        → Specification documents only (no code, merge to main directly)
prototype/X   → Exploratory prototypes (max 1 week lifetime, see Principle 5)
spike/X       → Technical spikes for research (max 1 week lifetime, see Principle 5)
```

**Branch protection rules (enforced when project moves to GitHub):**
- Direct commits to `main` forbidden (must use pull requests)
- Pull requests require self-review checklist completion during solo phase
- Future team phase: minimum 1 approval required before merge
- Hotfixes allowed directly to `main` only in production emergencies (must create follow-up documentation PR immediately after)
- Prototype/spike branches: auto-delete after 1 week if not converted to feature + spec

---

### Commit Convention

Follow Conventional Commits specification (https://www.conventionalcommits.org):

```
type(scope): description

Examples:
feat(eventi): add glassmorphism effect to event cards
fix(auth): resolve magic link expiration edge case
spec(profile): complete profile screen specification
docs(constitution): update privacy principle wording
refactor(widgets): extract GlassContainer to shared widgets
test(eventi): add EventCard widget tests
chore(deps): update Riverpod to version 3.0.0
perf(feed): optimize image loading with caching
```

**Commit message rules:**
- **Type:** feat, fix, spec, docs, refactor, test, chore, perf, style, ci
- **Scope:** Feature name (eventi, auth, chat, profilo) or technical area (widgets, theme, database)
- **Description:** Present tense, imperative mood, lowercase, no period at end
- **Body (optional):** Detailed explanation if needed
- **Footer (optional):** Breaking changes or issue references

---

### Code Review Checklist

Before merging any code to main branch, verify:

- [ ] **Spec compliance:** Implementation matches specification exactly (link to spec in PR description)
- [ ] **Design system:** All colors, spacing, typography from design system constants (zero hardcoded values)
- [ ] **Tests pass:** All existing tests pass, new tests added for new functionality (if applicable)
- [ ] **Performance:** No regressions (profiled if UI changes made)
- [ ] **Privacy:** No new data collection without justification and constitutional alignment
- [ ] **Accessibility:** Contrast ratios checked (WCAG 2.1 AA minimum), semantic labels present
- [ ] **Documentation:** Updated if public API changed or new feature added
- [ ] **Security:** No sensitive data in logs, RLS policies updated if database schema changed

---

### Testing Requirements

#### **Mandatory Tests (Must Have):**
- Authentication complete flow (magic link generation → email verification → session creation → login success)
- Event lifecycle (creation → moderation queue → approval → display in feed → interaction)
- Supabase Row-Level Security policies (security tests verifying RLS rules work correctly)
- Critical user paths (create event, like event, comment on event, join chat, view profile)

#### **Recommended Tests (Nice to Have):**
- Widget tests for all shared components (GlassContainer, EventCard, etc.)
- Integration tests for complete user flows (onboarding → event creation → participation)
- Golden tests for UI regression detection (screenshot comparison)

#### **Testing Philosophy:**
- Test behavior, not implementation (avoid testing private methods or implementation details)
- Prefer integration tests over unit tests (test real user flows, not isolated functions)
- Visual testing via hot reload is valid for UI iteration (screenshot comparison tests are supplementary)
- Test coverage is not a goal in itself - focus on testing critical paths and business logic

---

## Anti-Goals (Permanent Constraints)

These constraints cannot be removed without constitution version 2.0.0 (breaking change). They define what Nova will never become.

**Nova will NEVER:**

1. ❌ **Become a social network** with follower counts, influencer dynamics, or likes-as-popularity metrics
   - *Why:* This creates toxic comparison culture and shifts focus from school events to social status

2. ❌ **Show advertisements or monetize student attention**
   - *Why:* Students are minors, monetizing their attention is ethically wrong and violates trust

3. ❌ **Sell, share, or broker student data to third parties**
   - *Why:* Privacy is fundamental right, data is not a commodity to trade

4. ❌ **Implement addictive engagement patterns** (infinite scroll + dopamine optimization, notification spam, FOMO tactics)
   - *Why:* We facilitate school participation, not create phone addiction

5. ❌ **Replace real human interaction** (we facilitate in-person events, not substitute them with digital-only experiences)
   - *Why:* School is about real community, app is tool to enhance it

6. ❌ **Become surveillance tool** for administration or parents (no location tracking, no read receipts for admins, no activity monitoring)
   - *Why:* Students deserve privacy and autonomy, trust is earned not enforced

7. ❌ **Expand to other schools** without explicit strategic decision and architecture redesign
   - *Why:* Built specifically FOR Galilei Moro BY Galilei Moro students, not generic platform

**Violating any anti-goal requires creating new project, not evolving Nova.**

---

## Governance

### Amendment Process

#### **Who Can Propose Amendments:**
- Solo development phase (current): Giovanni only
- Future team phase: any team member or active contributor

#### **Amendment Procedure:**
1. Propose amendment in GitHub Discussion (not Issue - discussions for governance, issues for bugs)
2. Write detailed rationale: WHY does principle need change? What problem does amendment solve? What are consequences?
3. Mandatory reflection period: minimum 1 week for minor changes, minimum 2 weeks for Core Principles (Section 2)
4. Decision process:
   - Solo phase: Giovanni makes final decision after reflection period
   - Team phase: Consensus required (all team members must approve)
5. Special case for Core Principles: Requires unanimous approval + student council feedback (when student council exists)
6. Amendment merged to main branch with version bump and changelog entry

#### **Version Bump Rules (Semantic Versioning for Governance):**
- **MAJOR (X.0.0):** Core Principle removed or fundamentally redefined, Anti-Goal removed, breaking governance change
- **MINOR (x.Y.0):** New Core Principle added, new Technical Constraint section added, material expansion of guidance
- **PATCH (x.y.Z):** Wording clarification, typo fix, formatting improvement, non-semantic refinement

#### **Effective Date:**
Amendments take effect immediately upon merge to main branch. No delayed implementation.

---

### Emergency Override Procedure

If adhering to a principle creates existential risk to project survival:

1. **Document the crisis:** Write detailed explanation of exact circumstances and why principle blocks solution
2. **Propose temporary exception:** Specify explicit expiration date (maximum 3 months from declaration)
3. **Create amendment proposal:** Draft permanent solution to resolve underlying conflict with principle
4. **Transparency requirement:** Emergency exceptions require community announcement (GitHub Discussion + in-app notification if applicable)
5. **Limitation:** No more than 1 active emergency exception at a time (prevents systemic principle erosion)

**Example Scenario:**
- Crisis: Server costs €200/month, no funding model, principle forbids ads
- Temporary exception: Allow non-tracking sponsor logos in app footer for 3 months
- Permanent solution amendment: Implement school partnership funding model OR premium features for alumni

**Emergency override does NOT:**
- Replace constitutional amendment process (still required for permanent change)
- Permit violations of legal requirements (GDPR, child safety laws)
- Allow violations of multiple principles simultaneously
- Extend beyond 3 months (must resolve or amend constitution before expiration)

---

### Versioning Policy

**Current Version:** 1.1.0

**Version History:**
- **1.1.0** (2024-10-29): Added Emergency Override Procedure, GDPR compliance details, Moderator accountability system, SPEC_FIRST prototype flexibility
- **1.0.0** (2024-10-29): Initial constitution ratified with 7 core principles, technical constraints, and governance model

**Version Tracking:**
- Version changes documented in this section
- Git commit tagged with version: `git tag constitution-v1.1.0`
- Breaking changes (MAJOR bump) announced 2 weeks before effective date (future team phase)
- All versions immutable in git history for audit trail

---

### Compliance Review

#### **Review Schedule:**
- Solo development phase: Self-review every 2 weeks (biweekly sprint retrospective)
- Future team phase: Monthly constitution compliance review in team meeting

#### **Review Questions:**
1. Were any principles violated in recent pull requests? (document violations with justifications)
2. Are all principles still relevant and applicable? (flag outdated principles for amendment discussion)
3. Do feature specifications correctly cite constitution principles?
4. Is design system actually enforced in code? (audit 3 random widget files for hardcoded values)
5. Are performance budgets being met? (check latest metrics)
6. Is privacy commitment maintained? (review any new data collection)

#### **Exception Handling:**
- Principles can be violated with explicit justification documented in pull request description
- Justification format: "Violates [PRINCIPLE_NAME] because [reason], acceptable because [justification], one-time exception: [yes/no]"
- Repeated violations of same principle indicate principle needs amendment or removal (trigger governance discussion)
- Systematic violations indicate principle is not practical (immediate governance review required)

---

### Authority Hierarchy

**Document hierarchy (highest authority first):**
1. **Constitution (this document)** - Supreme governance document, all other documents must align
2. **Specifications** (`specs/` directory) - Feature and component specs, must comply with constitution
3. **Code** (`lib/` directory) - Implementation must follow specs exactly
4. **Comments and inline documentation** - Explain code, must not contradict specs or constitution

**Conflict Resolution Rules:**
- If code contradicts spec → code is incorrect, fix code to match spec
- If spec contradicts constitution → spec is incorrect, amend spec or request constitutional exception
- If constitution contradicts project reality → constitution needs amendment through governance process

**Binding Nature:**
- All contributors (current: Giovanni, future: team members) are bound by constitution
- Constitution violations in pull request = pull request rejected until fixed or exception explicitly justified
- No "we'll fix it later" acceptable - fix before merge or document exception with timeline
- Constitution review is first step in code review process (before checking code quality)

---

## Related Documents

This constitution should be read alongside:

- `specs/design-system.md` - Complete visual design system including glassmorphism formula, color palette, typography scale, spacing grid
- `specs/architecture.md` - Detailed technical architecture document (to be created)
- `README.md` - Project setup instructions, installation guide, how to run locally
- `CHANGELOG.md` - User-facing release history and version notes
- `.specify/templates/spec-template.md` - Template for all feature specifications (SpecKit)

---

## Appendix: Principle Quick Reference

Use this table for quick lookups during development:

| ID | Principle Name | One-Sentence Summary | Key Metric |
|----|----------------|----------------------|------------|
| 1 | STUDENTS_FIRST | Every decision prioritizes student benefit over all other stakeholders | Student satisfaction score >4.5/5 |
| 2 | PRIVACY_FOUNDATION | Minimal data collection, zero tracking, privacy-first architecture mandatory | Zero privacy incidents |
| 3 | SIMPLICITY_FIRST | Default answer to new features is "no" unless proven student need exists | Feature adoption >30% or deprecate |
| 4 | PERFORMANCE_FIRST | <1s load times, 60fps UI, instant perceived feedback non-negotiable | Feed loads <1s cached, 60fps sustained |
| 5 | SPEC_FIRST | All features specified in writing before implementation, specs reviewed before code | 100% features have specs |
| 6 | DESIGN_SYSTEM_STRICT | Zero hardcoded values, design system constants enforced via automated lint | Zero hardcoded color/spacing values |
| 7 | CONTENT_MODERATION | Human moderation mandatory, school-appropriate content only, transparent process | Moderation queue <24h, <5% false positives |

---

*This constitution is the supreme governing document of the Nova project.*
*When facing any decision - design, technical, or product - return to these principles.*
*If principles conflict with reality, amend principles, don't ignore them.*

---

**Ratified by:** Giovanni (Founder & Lead Developer)
**Date:** 2024-10-29
**Digital Signature:** Git commit hash serves as cryptographic signature
**Next Review:** 2024-11-12 (2 weeks)
