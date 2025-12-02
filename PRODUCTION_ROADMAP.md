# Nova MVP Production Roadmap

**Target**: Full Constitutional MVP Launch
**Timeline**: 8-10 weeks
**Status**: Planning Phase

---

## Executive Summary

This roadmap details the path to production-ready Nova with all 5 constitutional core features:
1. ✅ Events (implemented)
2. ❌ Bacheche (to implement)
3. ❌ Global Chat (to implement)
4. ✅ Profile (implemented)
5. ✅ Moderation (implemented)

Plus critical legal compliance for GDPR (minors in EU).

---

## Phase 1: Legal Compliance (Weeks 1-2)

### 1.1 Privacy Policy & Terms of Service
**Priority**: P0 BLOCKER
**Owner**: Legal consultation required
**Deliverables**:
- [ ] Draft Privacy Policy (Italian, GDPR Article 13 compliant)
- [ ] Draft Terms of Service (Italian)
- [ ] Legal review with school administration
- [ ] Host at nova.galileimoro.edu.it/privacy
- [ ] Add in-app link (Settings → Privacy → Privacy Policy)

**Content Requirements** (GDPR Article 13):
- Identity of data controller (Liceo Galilei Moro)
- Purpose of data processing (school event coordination)
- Legal basis (legitimate interest + consent for minors)
- Data retention periods (24h chat, 30d soft delete, 90d notifications)
- Rights explanation (access, erasure, portability, rectification)
- Contact for data protection queries

### 1.2 Parental Consent System
**Priority**: P0 BLOCKER (GDPR Article 8)
**Estimated Effort**: 2 weeks

#### Database Changes
```sql
-- Add to profiles table
ALTER TABLE profiles
  ADD COLUMN parental_consent_status TEXT
    CHECK (parental_consent_status IN ('pending', 'granted', 'denied', 'not_required'))
    DEFAULT 'pending',
  ADD COLUMN parental_email TEXT,
  ADD COLUMN parental_consent_date TIMESTAMPTZ,
  ADD COLUMN birth_date DATE;

-- Create consent_requests table
CREATE TABLE consent_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
  parent_email TEXT NOT NULL,
  token TEXT UNIQUE NOT NULL,
  status TEXT CHECK (status IN ('pending', 'granted', 'denied', 'expired')) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '7 days'
);
```

#### User Flow
1. During signup, ask birth date
2. If age < 16, require parent email
3. Send magic link to parent email with consent request
4. Parent clicks link → consent landing page
5. Parent grants/denies consent
6. Student account activated only if granted
7. Store consent proof (timestamp, IP, parent email verification)

#### Edge Cases
- Student turns 16 during use → auto-upgrade to self-consent
- Parent withdraws consent → 30-day account deletion grace period
- Parent email bounces → retry 3x, then block signup

### 1.3 Firebase Cloud Messaging Setup
**Priority**: P0 BLOCKER
**Estimated Effort**: 1-2 days

#### Tasks
- [ ] Create Firebase project (nova-galileimoro-prod)
- [ ] Download google-services.json → nova/android/app/
- [ ] Download GoogleService-Info.plist → nova/ios/Runner/
- [ ] Configure AndroidManifest.xml for FCM
- [ ] Configure Info.plist for push notifications
- [ ] Implement FCM token registration on login
- [ ] Store FCM tokens in profiles table
- [ ] Create Edge Function for push notification dispatch
- [ ] Test on physical devices (iOS + Android)

#### Code Changes (main.dart)
```dart
// Uncomment and configure FCM initialization
await Firebase.initializeApp();
final fcmToken = await FirebaseMessaging.instance.getToken();
// Store token in Supabase
```

---

## Phase 2: Global Chat Feature (Weeks 3-5)

### 2.1 Specification
**Command**: `/speckit.specify "Global Chat - ephemeral school-wide messaging"`

**Core Requirements** (from Constitution):
- School-wide chat room (single channel for MVP)
- Messages auto-delete after 24 hours (GDPR compliance)
- Real-time delivery via Supabase Realtime
- Content moderation (report inappropriate messages)
- No private DMs (prevent harassment, simplicity principle)

**User Stories**:
- US1 [P1]: Student views global chat feed
- US2 [P1]: Student sends message to global chat
- US3 [P1]: Messages auto-delete after 24 hours
- US4 [P2]: Student reports inappropriate message
- US5 [P2]: Moderator removes reported messages
- US6 [P3]: Message reactions (emoji only, no text replies)

### 2.2 Technical Design

#### Database Schema
```sql
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(user_id) ON DELETE SET NULL,
  content TEXT NOT NULL CHECK (LENGTH(content) <= 500),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours',
  reported BOOLEAN DEFAULT FALSE,
  deleted_by_mod UUID REFERENCES profiles(user_id)
);

-- Auto-delete expired messages (cron job)
CREATE OR REPLACE FUNCTION delete_expired_messages()
RETURNS void AS $$
BEGIN
  DELETE FROM chat_messages WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Schedule: Run every hour via pg_cron
SELECT cron.schedule('delete-expired-chat', '0 * * * *', 'SELECT delete_expired_messages();');
```

#### RLS Policies
```sql
-- Everyone can read non-deleted messages
CREATE POLICY "Chat messages readable by authenticated users"
  ON chat_messages FOR SELECT
  USING (auth.uid() IS NOT NULL AND deleted_by_mod IS NULL);

-- Users can insert their own messages
CREATE POLICY "Users can send messages"
  ON chat_messages FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own messages
CREATE POLICY "Users can delete own messages"
  ON chat_messages FOR DELETE
  USING (auth.uid() = user_id);
```

#### Flutter Implementation
- `lib/features/chat/` - Feature module
  - `data/chat_repository.dart` - Supabase operations
  - `domain/chat_message.dart` - Message model
  - `presentation/chat_screen.dart` - Main UI
  - `presentation/chat_bubble.dart` - Message widget
  - `presentation/chat_input.dart` - Input field
  - `presentation/providers/chat_providers.dart` - Riverpod state

### 2.3 Implementation Tasks
Estimated: 15-20 tasks over 2 weeks

---

## Phase 3: Bacheche Feature (Weeks 6-8)

### 3.1 Specification
**Command**: `/speckit.specify "Bacheche - student collaboration request board"`

**Core Requirements** (from Constitution):
- Request board for student collaboration
- Categories: Study groups, Ride sharing, Lost & found, General
- Posts expire after 30 days (or manually closed)
- Contact via in-app messaging (no personal info exposed)
- Moderation queue for new posts

**User Stories**:
- US1 [P1]: Student views bacheche feed filtered by category
- US2 [P1]: Student creates new request post
- US3 [P1]: Student responds to existing request
- US4 [P2]: Student closes their own request (resolved)
- US5 [P2]: Moderator reviews/approves new posts
- US6 [P3]: Student searches requests by keyword

### 3.2 Technical Design

#### Database Schema
```sql
CREATE TYPE bacheca_category AS ENUM (
  'studio',      -- Study groups
  'passaggi',    -- Ride sharing
  'smarriti',    -- Lost & found
  'generale'     -- General
);

CREATE TABLE bacheca_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (LENGTH(title) <= 100),
  description TEXT NOT NULL CHECK (LENGTH(description) <= 500),
  category bacheca_category NOT NULL,
  status TEXT CHECK (status IN ('pending', 'approved', 'rejected', 'closed')) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '30 days',
  closed_at TIMESTAMPTZ,
  moderated_by UUID REFERENCES profiles(user_id),
  moderated_at TIMESTAMPTZ,
  rejection_reason TEXT
);

CREATE TABLE bacheca_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES bacheca_posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
  message TEXT NOT NULL CHECK (LENGTH(message) <= 300),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### Flutter Implementation
- `lib/features/bacheche/` - Feature module
  - `data/bacheche_repository.dart`
  - `domain/bacheca_post.dart`
  - `domain/bacheca_response.dart`
  - `presentation/bacheche_screen.dart` - Main feed
  - `presentation/bacheca_detail_screen.dart` - Post detail
  - `presentation/create_post_screen.dart` - New post form
  - `presentation/providers/bacheche_providers.dart`

### 3.3 Implementation Tasks
Estimated: 20-25 tasks over 2.5 weeks

---

## Phase 4: Testing & Quality Assurance (Parallel, Weeks 3-8)

### 4.1 Comprehensive Test Suite

#### Critical Path Tests (P0)
- [ ] Authentication flow (magic link → verify → session → login)
- [ ] Event lifecycle (create → moderate → approve → display → interact)
- [ ] Profile GDPR (export data → verify JSON → delete account → verify removal)
- [ ] Parental consent flow (request → email → grant → activation)
- [ ] RLS policy security (verify unauthorized access blocked)

#### Feature Tests (P1)
- [ ] Comments system (create, like, reply, report, delete)
- [ ] Notifications (create, deliver, mark read, preferences)
- [ ] Global Chat (send, receive, auto-delete, report)
- [ ] Bacheche (create post, respond, close, moderate)

#### Integration Tests (P2)
- [ ] Offline queue sync (queue actions → reconnect → sync)
- [ ] Real-time subscriptions (events, comments, chat)
- [ ] Deep linking (event://nova/events/{id})

### 4.2 Performance Profiling

#### Constitutional Budgets to Validate
| Metric | Budget | Test Method |
|--------|--------|-------------|
| Feed load (cached) | <1s | Flutter DevTools timeline |
| Feed load (network) | <3s | Network throttle to 4G |
| UI frame rate | 60fps sustained | Performance overlay |
| Image size | <200KB each | Asset audit |
| APK size | <50MB | Build release, check size |
| IPA size | <60MB | Build release, check size |
| API response p95 | <500ms | Supabase dashboard |

#### Profiling Tasks
- [ ] Record feed scroll performance (identify jank)
- [ ] Measure cold start time (target <3s)
- [ ] Audit image compression (WebP, max dimensions)
- [ ] Check bundle size (remove unused packages)
- [ ] Test on low-end device (Android Go target)

### 4.3 CI/CD Pipeline

#### GitHub Actions Workflow
```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: dart analyze
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3

  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v3
        with:
          name: app-release.apk
          path: build/app/outputs/flutter-apk/app-release.apk

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter build ios --release --no-codesign
```

---

## Phase 5: Pre-Launch (Weeks 9-10)

### 5.1 App Store Assets

#### Android (Google Play)
- [ ] App icon: 512x512 PNG
- [ ] Feature graphic: 1024x500 PNG
- [ ] Screenshots: Phone (16:9), Tablet (16:10) - min 4 each
- [ ] Short description: 80 chars max (Italian)
- [ ] Full description: 4000 chars max (Italian)
- [ ] Privacy policy URL
- [ ] Content rating questionnaire
- [ ] Target audience: 13+ (students)

#### iOS (App Store)
- [ ] App icon: 1024x1024 PNG (no transparency)
- [ ] Screenshots: 6.5" iPhone, 5.5" iPhone, 12.9" iPad
- [ ] App preview video (optional, 15-30s)
- [ ] Description: 4000 chars max (Italian)
- [ ] Keywords: 100 chars max
- [ ] Privacy policy URL
- [ ] App Privacy labels (data collection disclosure)
- [ ] Age rating: 12+ (Infrequent/Mild User Generated Content)

### 5.2 Documentation

- [ ] README.md (setup instructions, architecture overview)
- [ ] CHANGELOG.md (release history, semantic versioning)
- [ ] DEPLOYMENT.md (how to release to stores)
- [ ] MODERATOR_GUIDE.md (content guidelines, queue workflow)
- [ ] Update CLAUDE.md with production status

### 5.3 Security Audit

- [ ] RLS policy penetration testing (attempt unauthorized access)
- [ ] SQL injection checks (parameterized queries verified)
- [ ] JWT token expiration testing (30-day refresh)
- [ ] Rate limiting implementation (prevent spam)
- [ ] HTTPS certificate pinning (optional, advanced)
- [ ] Secrets audit (no keys in code, .env in .gitignore)

### 5.4 Soft Launch

#### Beta Test Plan
- **Participants**: 50 students (diverse: classes 1-5, all sections)
- **Duration**: 1 week
- **Feedback channels**: In-app feedback form, WhatsApp group
- **Metrics to track**:
  - Signup completion rate
  - Events created
  - Moderation queue throughput
  - Crash reports
  - Performance on various devices

#### Go/No-Go Criteria
- [ ] Zero P0 bugs (crashes, data loss, security)
- [ ] <5 P1 bugs (can ship with known issues)
- [ ] Performance budgets met (validated)
- [ ] Legal documents live and accessible
- [ ] Parental consent system working
- [ ] Moderation queue staffed (min 2 moderators trained)

---

## Timeline Summary

```
Week 1-2:  Legal Compliance
           ├── Privacy Policy draft & review
           ├── Parental Consent system implementation
           └── Firebase FCM setup

Week 3-5:  Global Chat Feature
           ├── /speckit.specify + /speckit.plan
           ├── /speckit.tasks + /speckit.implement
           └── [Parallel] Start test suite

Week 6-8:  Bacheche Feature
           ├── /speckit.specify + /speckit.plan
           ├── /speckit.tasks + /speckit.implement
           └── [Parallel] CI/CD pipeline + performance audit

Week 9-10: Pre-Launch
           ├── App Store assets creation
           ├── Documentation
           ├── Security audit
           ├── Soft launch (50 students, 1 week)
           └── Bug fixes from beta feedback

Week 11:   Production Launch 🚀
           ├── Submit to App Store + Play Store
           ├── School announcement
           └── Monitor metrics
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Legal review delays | Start week 1, allow 2 weeks buffer |
| Parental consent complexity | MVP: simple email verification, iterate later |
| Feature creep in Chat/Bacheche | Strict adherence to P1 user stories only |
| App Store rejection | Pre-review checklist, follow guidelines exactly |
| Low beta adoption | Incentivize: early adopters get "Pioneer" badge |
| Performance issues on low-end devices | Test on Android Go device early |

---

## Success Criteria (Constitutional)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Student adoption | 70%+ in 6 months | Active users / total students |
| Events created | 50+/month | Database count |
| User rating | 4.5+ stars | App Store reviews |
| Privacy incidents | Zero | Incident reports |
| Moderation queue time | <24 hours | Avg time to review |
| Feed load time | <1s cached | Performance monitoring |

---

## Next Steps

1. **Immediate**: Legal consultation for privacy policy
2. **This week**: Implement parental consent database schema
3. **This week**: Setup Firebase project and FCM
4. **Next week**: `/speckit.specify` Global Chat

---

*Last Updated*: 2025-01-29
*Version*: 1.0.0
*Status*: PLANNING → Ready to Execute
