# Quickstart: Sistema Profilo Utente

**Feature**: 006-user-profile
**Date**: 2025-01-22
**Purpose**: Integration test scenarios and development quickstart guide

---

## Overview

Questo documento fornisce scenari step-by-step per testare il Sistema Profilo Utente end-to-end. Ogni scenario è eseguibile manualmente (QA testing) o automatizzabile (integration tests Flutter).

---

## Prerequisites

**Before testing**:
- [ ] Supabase migration `006_user_profile_system.sql` applicata
- [ ] Storage bucket `avatars` creato con RLS policies
- [ ] Flutter app con Riverpod providers configurati
- [ ] Almeno 2 test users creati:
  - User A: `marco.rossi@galileimoro.edu.it` (student)
  - User B: `sofia.bianchi@galileimoro.edu.it` (moderator per test badge)

**Test data setup**:
```sql
-- Create test users (run in Supabase SQL editor)
INSERT INTO profiles (id, email, full_name, username, class, bio, role)
VALUES
  ('test-user-a-uuid', 'marco.rossi@galileimoro.edu.it', 'Marco Rossi', 'marco.rossi', '5A', 'Appassionato di basket 🏀', 'student'),
  ('test-user-b-uuid', 'sofia.bianchi@galileimoro.edu.it', 'Sofia Bianchi', 'sofia.bianchi', '4B', 'Moderatrice e organizzatrice eventi', 'moderator');

-- Create test event by User A
INSERT INTO events (id, creator_id, title, emoji, description, status, created_at)
VALUES ('test-event-uuid', 'test-user-a-uuid', 'Torneo Basket 3v3', '🏀', 'Torneo interno basket', 'approved', NOW());
```

---

## Scenario 1: Complete Profile Flow (New User)

**User Story**: Marco (new student) completa il proprio profilo per la prima volta.

**Prerequisites**: User A logged in, profilo incompleto (no classe, no avatar, no bio)

**Steps**:

| # | Action | Expected Result | Verification |
|---|--------|-----------------|--------------|
| 1 | Open Nova app, login as `marco.rossi@galileimoro.edu.it` | Magic link sent to email | Check email inbox |
| 2 | Tap magic link in email | Login successful, redirect to Home/Feed | App opens to feed screen |
| 3 | Tap "Profilo" tab (bottom nav, 5th tab) | Profilo screen opens | See profile with empty fields |
| 4 | Observe profile header | Avatar shows iniziali "MR" su gradient brand, nome "Marco Rossi", username "marco.rossi", classe EMPTY, bio EMPTY | Verify avatar placeholder, username auto-generated |
| 5 | Observe stats | "0 eventi creati \| 0 partecipazioni" | Verify counts are zero |
| 6 | Observe empty state | Tabs "Eventi" (active), "Partecipazioni", empty state "Nessun evento ancora. Crea il tuo primo evento!" | Verify CTA button present |
| 7 | Tap "Modifica Profilo" button (top-right or header) | Edit profilo screen/modal opens | See editable fields |
| 8 | Tap avatar circle | Image picker opens (gallery/camera options) | iOS: CupertinoActionSheet, Android: BottomSheet |
| 9 | Select photo from gallery (test image 3MB, 1200×1200px) | Image cropper opens with circular crop overlay | Verify pinch-to-zoom works |
| 10 | Pinch-to-zoom, pan image, tap "Confirm" | Cropped image shown in avatar preview (edit screen) | Verify preview updates |
| 11 | Edit "Classe" field, select "5A" from dropdown | Dropdown closes, "5A" selected | Verify dropdown has all classes 1A-5Z + Altro |
| 12 | Edit "Bio" field, type "Appassionato di basket 🏀 \| Capitano squadra" (55 char) | Text appears in bio field, character counter shows "55/150" | Verify emoji renders correctly |
| 13 | Tap "Salva" button (top-right) | Loading indicator appears | Verify button disabled during save |
| 14 | Wait for save (compression + upload) | Toast "Profilo aggiornato!" appears, navigate back to profilo screen | Target <3s total save time |
| 15 | Verify avatar uploaded | Avatar shows uploaded photo (not iniziali), URL pattern `avatars/test-user-a-uuid/avatar.jpg?v={timestamp}` | Check avatar_url in profiles table |
| 16 | Verify classe saved | Header shows "5A" under username | Check profiles.class in database |
| 17 | Verify bio saved | Bio section shows "Appassionato di basket 🏀 \| Capitano squadra" | Check profiles.bio in database |
| 18 | Pull-to-refresh profilo | Avatar re-fetches from CDN, fields refresh | Verify cached avatar served (Cache-Control: max-age=604800) |

**Success Criteria**:
- ✅ Avatar upload completes in <3s (SC-010)
- ✅ Profile save updates database and UI reflects changes
- ✅ Character counter works correctly (55/150)
- ✅ Avatar cached for 7 days (check network tab: 304 Not Modified on refresh)

**Edge Cases Tested**:
- [ ] Avatar >2MB rejected with error "Immagine troppo grande. Max 2MB"
- [ ] Avatar <200×200px rejected with error "Immagine troppo piccola. Min 200×200px"
- [ ] Bio >150 char rejected with error "Bio troppo lunga. Max 150 caratteri"
- [ ] Classe not selected shows error "Seleziona la tua classe"

---

## Scenario 2: View Other User Profile

**User Story**: Sofia vuole vedere il profilo di Marco (organizzatore torneo basket) per capire chi organizza l'evento.

**Prerequisites**:
- User A (Marco) profilo completo con avatar, classe "5A", bio, 1 evento creato ("Torneo Basket 3v3")
- User B (Sofia) logged in

**Steps**:

| # | Action | Expected Result | Verification |
|---|--------|-----------------|--------------|
| 1 | Login as Sofia (`sofia.bianchi@galileimoro.edu.it`) | Feed screen opens | See events feed |
| 2 | Scroll feed, find event "Torneo Basket 3v3" created by Marco | Event card visible with creator "Marco Rossi" | Verify creator name clickable |
| 3 | Tap creator name "Marco Rossi" | Navigate to Marco's profile screen | See other user profile (not own) |
| 4 | Observe profile header | Avatar (Marco's uploaded photo), nome "Marco Rossi", username "marco.rossi", classe "5A", bio "Appassionato di basket 🏀 \| Capitano squadra", NO badge moderatore (Marco is student) | Verify all fields visible |
| 5 | Observe stats | "1 evento creato" (NO partecipazioni count - privacy) | Verify partecipazioni hidden for other users |
| 6 | Observe tabs | Only "Eventi" tab visible (NO "Partecipazioni" tab) | Verify privacy: partecipazioni hidden |
| 7 | Observe buttons | "Condividi Profilo" visible, NO "Modifica Profilo" button | Verify cannot edit other user profile |
| 8 | Tap "Eventi" tab | Grid 3 colonne shows 1 event: "Torneo Basket 3v3" | Verify event card clickable |
| 9 | Tap event card | Navigate to event detail screen | Verify event opens correctly |
| 10 | Navigate back to Marco's profile | Profile still displayed (state preserved) | Verify navigation stack |

**Success Criteria**:
- ✅ Profile loads <1s (SC-005)
- ✅ Partecipazioni tab NOT visible to other users (privacy FR-005)
- ✅ Cannot edit other user profile (no "Modifica Profilo" button)

**Edge Cases Tested**:
- [ ] Marco sets `profile_visible = FALSE` → Sofia sees "Profilo non disponibile" BUT event still visible in feed
- [ ] Marco soft-deletes account (`deleted_at` not null) → Sofia sees "Profilo non disponibile", event shows creator "Utente eliminato"

---

## Scenario 3: Share Profile via Deep Link

**User Story**: Sofia vuole condividere il profilo di Marco con i suoi amici in chat.

**Prerequisites**: User B (Sofia) viewing User A (Marco) profile

**Steps**:

| # | Action | Expected Result | Verification |
|---|--------|-----------------|--------------|
| 1 | On Marco's profile screen, tap "Condividi Profilo" button | Bottom sheet opens with options: "Copia Link", "Condividi in Chat", "Annulla" | Verify platform-adaptive: CupertinoActionSheet (iOS), ModalBottomSheet (Android) |
| 2 | Tap "Copia Link" | Toast "Link copiato!" appears, bottom sheet closes | Verify clipboard contains `nova://profile/test-user-a-uuid` |
| 3 | Paste clipboard content | Link format: `nova://profile/{uuid}` | Verify UUID matches Marco's user ID |
| 4 | Tap "Condividi Profilo" again → "Condividi in Chat" | Navigate to Chat tab with pre-filled message: "Guarda il profilo di Marco Rossi: nova://profile/{uuid}" | Verify message pre-filled, cursor at end |
| 5 | Add personal text: "Marco organizza torneo basket questo weekend!" | Text appended to pre-filled message | Verify can edit message |
| 6 | Send message | Message appears in global chat | Verify link clickable in chat |
| 7 | Logout Sofia, login as User C (new user, Luca) | Login successful | Verify different user |
| 8 | Open Chat tab, scroll to Sofia's message | Message visible: "Guarda il profilo di Marco Rossi: nova://profile/{uuid} Marco organizza torneo basket questo weekend!" | Verify link highlighted |
| 9 | Tap deep link `nova://profile/{uuid}` | go_router intercepts, navigates to Marco's profile | Verify direct navigation (no manual URL paste) |
| 10 | Verify profile opens | Marco's profile displayed correctly | Verify all fields visible to Luca |

**Success Criteria**:
- ✅ Deep link format correct: `nova://profile/{uuid}` (FR-029)
- ✅ Tap link navigates directly to profile (FR-031)
- ✅ 100% deep links functional (SC-009)

**Edge Cases Tested**:
- [ ] Tap deep link when NOT logged in → Redirect to login screen with message "Accedi per visualizzare profilo", then navigate to profile after login (FR-032)
- [ ] Tap deep link to non-existent user (`nova://profile/invalid-uuid`) → Error screen "Profilo non trovato" with button "Torna al Feed" (FR-033)

---

## Scenario 4: GDPR Export

**User Story**: Marco vuole scaricare tutti i suoi dati (GDPR Right to Access).

**Prerequisites**: User A (Marco) has created 1 event, made 2 comments, participated in 3 events, sent 5 chat messages

**Steps**:

| # | Action | Expected Result | Verification |
|---|--------|-----------------|--------------|
| 1 | Login as Marco, open Profilo tab | Profile screen opens | Verify logged in |
| 2 | Tap settings icon (⚙️) top-right | Settings screen opens | Verify sections: Account, Privacy, Notifiche, Info |
| 3 | Scroll to "Privacy" section | See toggles and buttons: "Profilo visibile" (ON), "Scarica i tuoi dati", "Elimina account" | Verify buttons visible |
| 4 | Tap "Scarica i tuoi dati" | Loading indicator appears, toast "Generazione dati in corso..." | Verify async job started |
| 5 | Wait <10s | In-app notification appears: "I tuoi dati sono pronti! Tap per scaricare" | Target <10s (SC-004) |
| 6 | Tap notification | Download link opens (browser or in-app webview) | Verify signed URL pattern: `storage/gdpr-exports/{user_id}/export_{timestamp}.json` |
| 7 | Download JSON file | File downloaded: `marco_rossi_dati_2025-01-22.json` | Verify filename format |
| 8 | Open JSON file (text editor/JSON viewer) | See structured data with sections: `export_version`, `export_date`, `user_id`, `profile`, `events_created`, `participations`, `comments`, `chat_messages` | Verify schema matches [contracts/gdpr-export-schema.json](./contracts/gdpr-export-schema.json) |
| 9 | Verify `profile` section | Contains: id, email, full_name, username, class, bio, avatar_url, role, profile_visible, created_at, updated_at | Verify all profile fields present |
| 10 | Verify `events_created` array | Contains 1 event: {"id": "...", "title": "Torneo Basket 3v3", ...} | Verify event included |
| 11 | Verify `participations` array | Contains 3 participations: [{"event_id": "...", "event_title": "...", "participated_at": "..."}, ...] | Verify all participations included |
| 12 | Verify `comments` array | Contains 2 comments | Verify comments included |
| 13 | Verify `chat_messages` array | Contains only messages from last 24h (not all 5 - chat is ephemeral) | Verify 24h filter applied |
| 14 | Verify avatar_url in JSON | URL valid and downloadable (same 24h expiry as export link) | Verify avatar link works |
| 15 | Wait 25 hours, try to re-download export link | Link expired error (403 Forbidden) | Verify 24h expiry enforced |

**Success Criteria**:
- ✅ Export generated in <10s (SC-004)
- ✅ JSON schema valid (matches contracts/gdpr-export-schema.json)
- ✅ All data included: profile, events, participations, comments, chat (last 24h)
- ✅ Link expires after 24h (GDPR compliance)

---

## Scenario 5: Delete Account (Soft Delete + Grace Period)

**User Story**: Marco si diploma e vuole eliminare il suo account Nova. Poi cambia idea entro 30 giorni e riattiva.

**Prerequisites**: User A (Marco) fully set up, has created 1 event, participated in 2 events

**Steps - Part 1: Soft Delete**:

| # | Action | Expected Result | Verification |
|---|--------|-----------------|--------------|
| 1 | Login as Marco, go to Settings → Privacy | Privacy section opens | See "Elimina account" button (red/destructive color) |
| 2 | Tap "Elimina account" | Confirmation dialog opens: "Sei sicuro? Account eliminato dopo 30 giorni. Puoi annullare entro 30 giorni." Buttons: "Annulla", "Conferma eliminazione" (red) | Verify CupertinoAlertDialog (iOS), AlertDialog (Android) |
| 3 | Tap "Conferma eliminazione" | Dialog closes, loading indicator, then banner appears: "Account eliminato. Hai 30 giorni per annullare." | Verify soft delete executed |
| 4 | Verify database | `profiles.deleted_at = NOW()` (not null), profile still exists | Check SQL: `SELECT deleted_at FROM profiles WHERE id = 'test-user-a-uuid'` |
| 5 | Logout Marco | Logout successful | App returns to login screen |
| 6 | Login as Sofia (User B), go to Marco's profile (via deep link or event creator) | See message "Profilo non disponibile" | Verify RLS hides deleted profiles (`WHERE deleted_at IS NULL`) |
| 7 | Go to Feed, find "Torneo Basket 3v3" event created by Marco | Event still visible, creator shows "Utente eliminato" | Verify events persist after soft delete (FR-027) |
| 8 | Tap event, view participants list | Marco NOT in list (participation deleted) | Verify participations CASCADE deleted (data-model.md) |

**Steps - Part 2: Reactivate Account (within 30 days)**:

| # | Action | Expected Result | Verification |
|---|--------|-----------------|--------------|
| 9 | Login as Marco again (same email `marco.rossi@galileimoro.edu.it`) | Magic link sent | Verify can still login (account soft-deleted, not hard-deleted) |
| 10 | Tap magic link | Login successful, dialog appears: "Vuoi riattivare il tuo account?" Buttons: "Annulla", "Riattiva" | Verify reactivation prompt |
| 11 | Tap "Riattiva" | `profiles.deleted_at = NULL`, banner "Account riattivato!" | Verify soft delete cleared |
| 12 | Go to Marco's profile | Profile visible again (avatar, bio, stats) | Verify profile restored |
| 13 | Sofia refreshes Marco's profile | Profile now accessible (no "Profilo non disponibile") | Verify visibility restored |
| 14 | Feed shows "Torneo Basket 3v3" with creator "Marco Rossi" (not "Utente eliminato") | Creator name restored | Verify event creator updated |

**Steps - Part 3: Hard Delete (after 30 days)**:

| # | Action | Expected Result | Verification |
|---|--------|-----------------|--------------|
| 15 | Manually set `profiles.deleted_at` to 31 days ago | `UPDATE profiles SET deleted_at = NOW() - INTERVAL '31 days' WHERE id = 'test-user-a-uuid'` | Simulate 31 days passed |
| 16 | Run hard delete cron job | `DELETE FROM profiles WHERE deleted_at < NOW() - INTERVAL '30 days'` | Execute SQL |
| 17 | Verify Marco's profile deleted | Profile row removed from `profiles` table | Check SQL: `SELECT * FROM profiles WHERE id = 'test-user-a-uuid'` returns empty |
| 18 | Verify avatar deleted | `avatars/test-user-a-uuid/avatar.jpg` removed from Storage | Check Supabase Storage bucket |
| 19 | Try to login as Marco | Error "Account non trovato" or "Email non registrata" | Verify cannot login (auth user removed) |
| 20 | Check "Torneo Basket 3v3" event | Creator still shows "Utente eliminato" (permanent) | Verify events persist after hard delete |

**Success Criteria**:
- ✅ Soft delete hides profile immediately (deleted_at not null)
- ✅ Grace period 30 giorni allows reactivation (FR-025)
- ✅ Hard delete removes profile + avatar after 30 days (FR-026)
- ✅ Events persist with creator "Utente eliminato" (FR-027)

---

## Scenario 6: Moderator Badge Visibility

**User Story**: Anna (moderatrice) visualizza il proprio profilo e altri vedono il suo badge "Moderatore 🛡️".

**Prerequisites**: User B (Sofia) has `role = 'moderator'` in database

**Steps**:

| # | Action | Expected Result | Verification |
|---|--------|-----------------|--------------|
| 1 | Login as Sofia (moderator), go to Profilo tab | Profile screen opens | See own profile |
| 2 | Observe header | Badge "Moderatore 🛡️" visible under username, avatar has gradient border viola→pink (2px width) | Verify badge + gradient border (FR-034) |
| 3 | Go to Settings | Settings screen opens | See sections |
| 4 | Scroll to "Moderazione" section | Extra section visible with link "Dashboard Moderazione" and stats "Review fatte: X \| Tasso approval: Y%" | Verify moderator-only section (FR-021) |
| 5 | Logout Sofia, login as Marco (student) | Login successful | Different user |
| 6 | View Sofia's profile (via event creator or deep link) | Profile opens | See other user profile |
| 7 | Observe badge | Badge "Moderatore 🛡️" visible publicly, gradient border avatar visible | Verify badge public (FR-035) |
| 8 | View Marco's profile (student, no moderator role) | Profile opens | See student profile |
| 9 | Observe header | NO badge, NO gradient border (normal avatar) | Verify badge NOT visible for non-moderators |

**Success Criteria**:
- ✅ Badge "Moderatore 🛡️" visible to moderators in own profile + to others (public)
- ✅ Gradient border viola→pink (2px) on moderator avatars
- ✅ Settings has "Moderazione" section only if role=moderator

---

## Performance Benchmarks

**Target Metrics** (from spec.md Success Criteria):

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Profile load time | <1s | Time from tap creator name → profile fully rendered |
| Avatar upload time | <3s | Time from tap "Salva" → toast "Profilo aggiornato!" |
| GDPR export generation | <10s | Time from tap "Scarica dati" → notification "I tuoi dati sono pronti!" |
| Scroll grid 3 colonne | 60fps | Flutter DevTools timeline: zero dropped frames |

**How to measure**:

```dart
// Profile load time
final stopwatch = Stopwatch()..start();
await ref.read(otherProfileProvider(userId).future);
stopwatch.stop();
print('Profile load: ${stopwatch.elapsedMilliseconds}ms');  // Target <1000ms

// Avatar upload time
final uploadStopwatch = Stopwatch()..start();
await uploadAvatar(file);  // Compress + upload + update profile
uploadStopwatch.stop();
print('Avatar upload: ${uploadStopwatch.elapsedMilliseconds}ms');  // Target <3000ms
```

**DevTools Profiling**:
1. Open Flutter DevTools → Performance tab
2. Start recording
3. Scroll eventi grid 3 colonne (fast scroll up/down)
4. Stop recording
5. Check timeline: NO red bars (dropped frames), sustained 60fps

---

## Integration Test Automation

**Example Flutter integration test** (automated version of Scenario 1):

```dart
// test/integration/profile_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Complete profile flow', (tester) async {
    // 1. Login
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // 2. Navigate to Profilo tab
    await tester.tap(find.text('Profilo'));
    await tester.pumpAndSettle();

    // 3. Verify empty profile
    expect(find.text('0 eventi creati | 0 partecipazioni'), findsOneWidget);

    // 4. Tap "Modifica Profilo"
    await tester.tap(find.text('Modifica Profilo'));
    await tester.pumpAndSettle();

    // 5. Edit classe
    await tester.tap(find.byKey(Key('class_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5A'));
    await tester.pumpAndSettle();

    // 6. Edit bio
    await tester.enterText(find.byKey(Key('bio_field')), 'Appassionato di basket 🏀');

    // 7. Save
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    // 8. Verify toast
    expect(find.text('Profilo aggiornato!'), findsOneWidget);

    // 9. Verify classe saved
    expect(find.text('5A'), findsOneWidget);

    // 10. Verify bio saved
    expect(find.text('Appassionato di basket 🏀'), findsOneWidget);
  });
}
```

---

## Troubleshooting

**Common issues during testing**:

| Issue | Likely Cause | Fix |
|-------|--------------|-----|
| Avatar upload fails with "403 Forbidden" | RLS policy blocks upload to other user folder | Verify `(storage.foldername(name))[1] = auth.uid()::TEXT` in RLS |
| Profile shows old avatar after update | Cache not invalidated | Append `?v={timestamp}` to avatar_url, clear Hive cache |
| GDPR export timeout (>10s) | Large dataset (thousands of events/comments) | Optimize query with indexes, batch export generation |
| Deep link doesn't open profile | go_router route not registered | Verify `GoRoute(path: '/profile/:userId')` in app_router.dart |
| Soft-deleted profile still visible | RLS policy missing `deleted_at IS NULL` check | Update RLS: `WHERE profile_visible = TRUE AND deleted_at IS NULL` |

---

## Next Steps

✅ **Phase 1 Complete**: data-model.md, contracts/, quickstart.md ready

**Proceed to**:
1. Update agent context (`.claude/context.md`)
2. Re-evaluate Constitution Check (Phase 2)
3. Generate tasks.md (`/speckit.tasks`)
4. Implement feature (`/speckit.implement`)
