# 🚀 Nova - Development Roadmap

**Last Updated**: 23 Novembre 2025
**Current Branch**: `007-event-comments`
**Project Status**: MVP Core Complete, Comments System In Progress

---

## 📊 Executive Summary

| Metric | Value |
|--------|-------|
| **Features Completed** | 6/7 (86%) |
| **Database Migrations** | 7/8 complete |
| **Specs Written** | 7 total |
| **Code Implementation** | ~70 files across 6 features |
| **Current Focus** | Event Comments System (Spec 007) |

---

## ✅ COMPLETATO (6 Features)

### 1. Magic Link Authentication (Spec 001)
**Status**: ✅ FULLY IMPLEMENTED
**Database**: Migration 002, 003
**Implementation**: `lib/features/auth/`

- ✅ Magic link email authentication (@galileimoro.edu.it only)
- ✅ Session management (30-day refresh tokens)
- ✅ Email validation and verification
- ✅ Login/logout flows with error states
- ✅ Platform-adaptive UI (Cupertino/Material)

**Key Files**:
- `auth_notifier.dart` - Riverpod state management
- `login_screen.dart` - Platform-adaptive authentication UI

---

### 2. Profile Setup & Onboarding (Spec 002)
**Status**: ✅ FULLY IMPLEMENTED
**Database**: Migration 002
**Implementation**: `lib/features/profile/`

- ✅ First-time user onboarding flow
- ✅ Avatar upload with circular crop (max 2MB)
- ✅ Class selection (1A-5L dropdown)
- ✅ Bio field (max 150 characters, optional)
- ✅ Profile completion check before app access
- ✅ Avatar storage via Supabase Storage

**Key Files**:
- `profile_setup_screen.dart` - Onboarding wizard
- `avatar_upload_service.dart` - Image compression and upload

---

### 3. Events Feed - Instagram-Style Infinite Scroll (Spec 003)
**Status**: ✅ FULLY IMPLEMENTED
**Database**: Migration 004
**Implementation**: `lib/features/events/`

- ✅ Infinite scroll with pagination (20 events/page)
- ✅ Pull-to-refresh
- ✅ Event cards with glassmorphism design
- ✅ Like button (❤️ optimistic UI)
- ✅ Participation button (👥 counter)
- ✅ Image gallery with swipe
- ✅ Real-time updates via Supabase Realtime
- ✅ Offline-first caching with Hive
- ✅ Performance: <1s cached, <3s first load

**Key Files**:
- `events_feed_screen.dart` - Main feed UI
- `event_card.dart` - Individual event display
- `events_feed_provider.dart` - Riverpod state management
- `events_repository.dart` - Data layer with RLS

---

### 4. Event Creation & Management (Spec 004)
**Status**: ✅ FULLY IMPLEMENTED
**Database**: Migration 004, 005
**Implementation**: `lib/features/events/`

- ✅ Event creation form (title, description, datetime, location, images)
- ✅ Image picker with compression (max 200KB, WebP, 16:9)
- ✅ Draft system (offline support)
- ✅ My Events screen (Created/Participating tabs)
- ✅ Event status tracking (pending/approved/rejected)
- ✅ Rejection flow with resubmit option
- ✅ Moderation queue integration
- ✅ Deep link support (nova://event/{id})
- ✅ Share event functionality

**Key Files**:
- `event_creation_screen.dart` - Creation form
- `my_events_screen.dart` - User's events dashboard
- `rejected_event_edit_screen.dart` - Resubmission flow
- `event_creation_provider.dart` - Form state management
- `image_optimizer.dart` - Image compression logic

---

### 5. Admin Panel & Moderation Queue (Spec 005)
**Status**: ✅ FULLY IMPLEMENTED
**Database**: Migration 005, 20251114_moderation_system
**Implementation**: `lib/features/admin/` + `lib/features/moderation/`

- ✅ Admin Panel UI for role management
- ✅ Moderator assignment (admin-only)
- ✅ Moderation Queue (pending events)
- ✅ Approve/Reject with reason
- ✅ User roles system (admin/moderator/student)
- ✅ Activity logging (moderation actions)
- ✅ Moderator statistics dashboard
- ✅ RLS policies for role-based access
- ✅ Real-time queue updates

**Key Files**:
- `admin_panel_screen.dart` - Role management UI
- `moderation_queue_screen.dart` - Event approval workflow
- `moderator_stats_screen.dart` - Performance dashboard
- `moderation_card.dart` - Event review component

**Database**:
- `user_roles` table with RLS policies
- `moderation_logs` for audit trail
- Triggers for automatic notification on approval/rejection

---

### 6. User Profile System (Spec 006)
**Status**: ✅ FULLY IMPLEMENTED
**Database**: Migration 006_user_profile_system
**Implementation**: `lib/features/profile/`

- ✅ View own profile / other users' profiles
- ✅ Profile header (avatar, name, username, class, badge)
- ✅ Stats: events created + participations count
- ✅ Event grid (3 columns, tab-based: Created/Participating)
- ✅ Edit profile (avatar, name, class, bio)
- ✅ Settings screen (account info, privacy, notifications)
- ✅ Profile visibility toggle
- ✅ GDPR compliance: Data export (JSON) + Account deletion (30-day grace)
- ✅ Deep link support (nova://profile/{user_id})
- ✅ Share profile functionality

**Key Files**:
- `profile_screen.dart` - Profile viewing
- `edit_profile_screen.dart` - Profile editing
- `settings_screen.dart` - User preferences
- `profile_repository.dart` - Data layer
- `profile_stats_model.dart` - Statistics tracking

**Database**:
- `profiles` table extensions (bio, visibility, stats)
- `profile_stats` for event counts
- GDPR export/delete procedures

---

## 🔄 IN PROGRESS (1 Feature)

### 7. Event Comments System (Spec 007)
**Status**: 🔄 SPEC COMPLETE, IMPLEMENTATION IN PROGRESS
**Branch**: `007-event-comments` (current)
**Database**: Migration 007 PLANNED (not yet created)
**Tasks**: 548 tasks defined in `specs/007-event-comments/tasks.md`

**What's Done**:
- ✅ Complete specification written
- ✅ Technical plan and research complete
- ✅ Domain entities defined (`Comment`, `CommentLike`, `CommentReport`)
- ✅ Data models created (`comment_model.dart`)
- ⚠️ Integration points identified in existing code

**What's Missing**:
- ❌ Supabase migration for comments tables
- ❌ Comments repository implementation
- ❌ All presentation layer (screens, widgets, providers)
- ❌ UI integration with `EventDetailScreen`
- ❌ Real-time subscriptions for live updates
- ❌ Rate limiting and spam prevention
- ❌ Profanity filter integration

**Planned Features** (from spec):
- Bottom sheet comments UI
- Comment cards with avatar, name, timestamp, like button
- Reply system (@mentions, 48px indent)
- Thread collapse/expand
- Like comments (❤️ optimistic UI)
- Report/Delete comments
- Pagination (20 comments/page)
- Real-time updates via Supabase Realtime
- Push notifications for comment replies

**Git Status**: ~70 files modified, integrating comments into event workflows

**Next Immediate Steps**:
1. Create Supabase migration for comments tables (T004)
2. Implement `CommentsRepository` with RLS policies (T010-T015)
3. Build Comments Bottom Sheet UI (T045-T060)
4. Add Riverpod providers for state management (T061-T070)
5. Integrate with `EventDetailScreen` (T067)
6. Implement real-time subscriptions (T080-T085)
7. Add rate limiting (max 10 comments/minute) (T090)

**Estimated Completion**: 2-3 days (if focused implementation)

---

## ⏳ DA IMPLEMENTARE (Future Roadmap)

### Priority 1 (MVP Extended)

#### 8. Sistema Notifiche Push
**Status**: ⏳ NOT STARTED
**Estimated Effort**: 2-3 giorni

**Scope**:
- In-app notification center (bell icon con badge)
- Push notifications (Firebase Cloud Messaging / Supabase Edge Functions)
- Notification types:
  - Evento approvato/rifiutato
  - Nuovo commento su tuo evento
  - Reply al tuo commento
  - Nuovo like su evento
  - Nuovo partecipante
- Deep links (tap notifica → destination screen)
- Settings notifiche (toggle per tipo)
- Mark as read / Clear all
- Real-time badge counter

**Dependencies**: Comments System (genera notifiche reply)

**Database Needs**:
- `notifications` table (già parzialmente in migration 005)
- `notification_preferences` per user settings

---

#### 9. Likes & Partecipazioni (Enhanced)
**Status**: ⏳ PARTIALLY IMPLEMENTED (basic like exists)
**Estimated Effort**: 0.5-1 giorno

**Current State**: Basic like button exists in event cards

**Enhancements Needed**:
- Lista completa partecipanti (modal bottom sheet)
- Avatar stack preview (primi 3 partecipanti)
- Tap counter → show full list
- Notifica al creator quando like/partecipazione
- Export partecipanti list (admin/creator only)

**Dependencies**: Profile System (already complete)

---

#### 10. Chat Globale Scuola
**Status**: ⏳ NOT STARTED
**Estimated Effort**: 2-3 giorni

**Scope**:
- Single chat room per tutta la scuola
- Messaggi effimeri (auto-delete 24 ore)
- Real-time messaging (Supabase Realtime)
- Reply to message
- Report message (moderazione)
- Typing indicator
- Platform-adaptive UI (Cupertino/Material)
- Send button con validation
- Message pagination (50/page)
- Image/emoji support (optional)

**Dependencies**: Profile System (avatar/nome), Notifiche (optional)

**Database Needs**:
- `chat_messages` table con auto-delete trigger
- `chat_reports` per segnalazioni
- RLS policies per visibilità

---

#### 11. Bacheche (Request Board)
**Status**: ⏳ NOT STARTED
**Estimated Effort**: 2-3 giorni

**Scope**:
- Feed richieste collaborative (simile eventi)
- Categorie: Tutoring, Libri, Trasporti, Studio, Altro
- Create post bacheca (titolo, descrizione, categoria)
- Commenti su post (riusa Comment System)
- Moderazione (pending → approved)
- Search/Filter per categoria
- "Contatta autore" button
- Mark as "Risolto"
- Auto-expiration (30 giorni)

**Dependencies**: Comments System, Moderation System

**Database Needs**:
- `board_posts` table
- Moderation flow integration
- Categories enum

---

### Priority 2 (UX Refinement)

#### 12. Feed Eventi Avanzato
**Status**: ⏳ PARTIALLY IMPLEMENTED (basic feed exists)
**Estimated Effort**: 1 giorno

**Current State**: Infinite scroll feed exists

**Enhancements Needed**:
- Filter eventi per categoria (sport, cultura, studio, etc.)
- Sort: Recenti, Popolari, In arrivo
- Search eventi (text search)
- Calendar view (optional)
- Empty states refinement
- Error states refinement

---

#### 13. Sistema Ricerca Globale
**Status**: ⏳ NOT STARTED
**Estimated Effort**: 1-2 giorni

**Scope**:
- Search bar top app
- Search across: Eventi, Bacheche, Profili
- Autocomplete suggestions
- Recent searches (Hive local storage)
- Filter results per tipo
- Highlight search terms
- Empty state "Nessun risultato"

**Dependencies**: All content features implemented

---

#### 14. Settings Avanzate
**Status**: ⏳ PARTIALLY IMPLEMENTED (basic settings exist)
**Estimated Effort**: 0.5-1 giorno

**Current State**: Settings screen exists con GDPR options

**Enhancements Needed**:
- Notifiche granulari (toggle per tipo)
- Privacy avanzata (chi vede profilo, eventi)
- Theme toggle (light/dark - optional)
- Accessibility settings (font size, contrast)
- About app + Credits
- Feedback/Bug report form
- Rate app prompt (dopo 10+ eventi visti)

---

#### 15. Admin Dashboard Statistiche
**Status**: ⏳ NOT STARTED
**Estimated Effort**: 1-2 giorni

**Scope** (admin/founder only):
- Analytics dashboard:
  - Active users (DAU, WAU, MAU)
  - Eventi creati/giorno
  - Adoption rate (% studenti registrati / 810 totali)
  - Engagement metrics (comments, likes, participations)
  - Moderation stats (pending, approved, rejected, avg time)
  - Top creators, top events
- Export reports (CSV)
- Time-range filters (7d, 30d, 90d, all-time)
- Charts/Graphs (optional, using fl_chart package)

**Dependencies**: All features implemented (genera dati)

---

### Priority 3 (Delight & Innovation)

#### 16. Stories (Instagram-Style)
**Status**: ⏳ NOT STARTED
**Estimated Effort**: 3-5 giorni
**Planned Timeline**: Gennaio 2025

**Scope**:
- Stories 24h auto-delete
- Camera integrata
- Stickers, text overlay
- Story link to event
- Story replies (DM-style)
- Story ring in profile/feed
- Views counter
- Share to story from event

---

#### 17. Widgets Android
**Status**: ⏳ NOT STARTED
**Estimated Effort**: 2-3 giorni
**Planned Timeline**: Febbraio 2025

**Scope**:
- Widget calendario eventi (next 3 events)
- Widget prossimo evento (single event countdown)
- Widget chat unread counter
- Auto-update (periodic refresh)
- Tap widget → open app

---

#### 18. Widgets iOS (WidgetKit)
**Status**: ⏳ NOT STARTED
**Estimated Effort**: 2-3 giorni
**Planned Timeline**: Aprile 2025

**Scope**:
- iOS native WidgetKit implementation
- Sizes: Small, Medium, Large
- Timeline provider for events
- Live Activities (per eventi in corso)
- Deep link integration

---

### Continuous Improvement

#### 19. Performance Optimization
**Status**: ⏳ ONGOING
**Priority**: P2

**Areas**:
- Image optimization (WebP, caching, lazy loading)
- Pagination optimization (adjust page sizes)
- Database indexes (query performance)
- Bundle size reduction (code splitting)
- Memory management (dispose providers)
- Startup time optimization

---

#### 20. Testing Suite
**Status**: ⏳ ONGOING
**Priority**: P2

**Coverage Needed**:
- Widget tests (critical components: EventCard, GlassContainer, etc.)
- Integration tests (user flows: create event → moderate → publish)
- Golden tests (UI regression detection)
- E2E tests (critical paths: auth → onboard → create event → like → comment)
- Supabase RLS tests (security validation)

**Current Status**: Basic tests exist, comprehensive coverage needed

---

## 📈 Database Migration Status

| Migration | Feature | Status |
|-----------|---------|--------|
| 002 | Auth Setup (profiles table) | ✅ Complete |
| 003 | Auth Cleanup (RLS fixes) | ✅ Complete |
| 004 | Events Feed (events, likes, participations) | ✅ Complete |
| 005 | Event Moderation (status, notifications) | ✅ Complete |
| 006a | Co-organizer Notifications | ✅ Complete |
| 006b | User Profile System | ✅ Complete |
| 20251114 | Moderation System (user_roles, logs) | ✅ Complete |
| 007 | Event Comments System | ⏳ Planned |

---

## 🎯 Implementation Summary

| Feature | Spec | Plan | Tasks | DB | Domain | Data | Presentation | Status |
|---------|:----:|:----:|:-----:|:--:|:------:|:----:|:------------:|:------:|
| Auth | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **COMPLETE** |
| Profile Setup | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **COMPLETE** |
| Events Feed | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **COMPLETE** |
| Event Creation | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **COMPLETE** |
| Moderation | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **COMPLETE** |
| User Profiles | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **COMPLETE** |
| **Comments** | **✅** | **✅** | **✅** | **❌** | **⚠️** | **⚠️** | **❌** | **IN PROGRESS** |
| Notifications | ❌ | ❌ | ❌ | ⚠️ | ❌ | ❌ | ❌ | **NOT STARTED** |
| Chat | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **NOT STARTED** |
| Bacheche | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **NOT STARTED** |

**Legend**: ✅ Complete | ⚠️ Partial | ❌ Not Started

---

## 🚦 Next Immediate Priorities

### Short-term (This Week)
1. **Complete Event Comments System (Spec 007)**
   - Create Supabase migration
   - Implement CommentsRepository
   - Build UI components (bottom sheet, comment cards)
   - Add Riverpod providers
   - Integrate with EventDetailScreen
   - Test moderation flows

### Medium-term (Next 2 Weeks)
2. **Sistema Notifiche Push**
   - Spec creation
   - FCM/Supabase Edge Functions setup
   - Notification center UI
   - Deep link integration

3. **Chat Globale Scuola**
   - Spec creation
   - Real-time messaging implementation
   - Moderation integration

### Long-term (Next Month)
4. **Bacheche System**
5. **Advanced Search & Filters**
6. **Admin Analytics Dashboard**

---

## 📊 Key Metrics & Goals

### Constitution Success Criteria

| Metric | Target | Current Status |
|--------|--------|----------------|
| Student Adoption | 70% within 6 months | TBD (pre-launch) |
| Events Created | 50+/month | TBD (pre-launch) |
| User Rating | 4.5+ stars | TBD (pre-launch) |
| Inappropriate Content | <1% | ✅ Moderation system ready |
| Privacy Incidents | 0 | ✅ Zero tracking, GDPR compliant |
| Moderation Queue Time | <24 hours | ✅ Real-time queue |
| False Positive Rate | <5% | TBD (post-launch monitoring) |
| Feed Load Time (cached) | <1 second | ✅ Implemented |
| Feed Load Time (first) | <3 seconds (4G) | ✅ Implemented |
| Sustained FPS | 60fps | ✅ No jank in testing |
| APK Size | <50MB | TBD (build not yet created) |
| IPA Size | <60MB | TBD (build not yet created) |

---

## 🎓 Architecture Compliance

**✅ Design System**: All UI uses `NovaColors`, `NovaSpacing`, `NovaTypography`, `NovaRadius` constants
**✅ Platform-Native Widgets**: Cupertino (iOS) + Material (Android) with adaptive wrappers
**✅ State Management**: Riverpod providers exclusively
**✅ Clean Architecture**: Feature-first structure with data/domain/presentation layers
**✅ RLS Security**: All Supabase tables have Row-Level Security policies
**✅ GDPR Compliance**: Data export/delete implemented
**✅ Zero Tracking**: No Google Analytics, Facebook SDK, or third-party analytics
**✅ Spec-First**: All features (1-7) have written specifications before implementation

---

## 📝 Notes

- **Current Git Branch**: `007-event-comments` (active development)
- **Last Major Merge**: Spec 006 User Profile System
- **Constitution Version**: v1.1.0 (referenced in all specs)
- **Flutter SDK**: 3.x+ (check `pubspec.yaml` for exact version)
- **Backend**: Supabase Cloud (EU Frankfurt for GDPR)
- **Database**: PostgreSQL 15+ via Supabase

---

**Document Version**: 2.0
**Generated**: 23 Novembre 2025
**Next Review**: After completion of Spec 007 (Event Comments)
