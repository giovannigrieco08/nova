# Implementation Tasks: Event Creation and Moderation System

**Feature**: 004-event-creation-moderation
**Branch**: `004-event-creation-moderation`
**Generated**: 2025-01-09
**Status**: Ready for Implementation

---

## Task Organization

Tasks are organized by **user story priority** (P1 → P2) with dependency tracking. Each task follows this format:

```
- [ ] [TaskID] [P?] [Story?] Description (file: path/to/file.dart)
```

**Legend**:
- `[TaskID]`: Unique identifier (e.g., T001, T002)
- `[P]`: Parallelizable (can run concurrently with other [P] tasks in same phase)
- `[US#]`: User Story reference (US1, US2, US3, US4, US5)
- `file:`: Target file path for the task

---

## Phase 1: Setup & Infrastructure

**Purpose**: Install dependencies, configure Firebase/Supabase, create project structure

### Dependencies & Configuration

- [X] [T001] [P] Add required packages to pubspec.yaml (file: nova/pubspec.yaml)
  - `flutter_riverpod: ^2.4.0`
  - `supabase_flutter: ^2.0.0`
  - `firebase_messaging: ^14.7.0`
  - `firebase_core: ^2.24.0`
  - `flutter_image_compress: ^2.1.0`
  - `image_picker: ^1.0.0`
  - `share_plus: ^7.2.0`
  - `uni_links: ^0.5.1`
  - `hive_flutter: ^1.1.0`
  - `hive: ^2.2.3`
  - `freezed_annotation: ^2.4.1`
  - `json_annotation: ^4.8.1`

- [X] [T002] [P] Add dev dependencies to pubspec.yaml (file: nova/pubspec.yaml)
  - `build_runner: ^2.4.6`
  - `freezed: ^2.4.5`
  - `json_serializable: ^6.7.1`
  - `hive_generator: ^2.0.1`

- [X] [T003] Run flutter pub get to install all dependencies (command)

- [X] [T004] [P] Configure Firebase for iOS (file: nova/ios/Runner/GoogleService-Info.plist)
  - Download GoogleService-Info.plist from Firebase Console
  - Add to ios/Runner/ directory
  - Update Info.plist with URL schemes

- [X] [T005] [P] Configure Firebase for Android (file: nova/android/app/google-services.json)
  - Download google-services.json from Firebase Console
  - Add to android/app/ directory
  - Update AndroidManifest.xml with permissions

- [X] [T006] Initialize Firebase in main.dart (file: nova/lib/main.dart)
  - Add Firebase.initializeApp() before runApp()
  - Configure FCM background message handler

- [X] [T007] [P] Create Supabase Storage bucket for event images (command)
  - Run: `supabase storage create event-images --public`
  - Configure bucket policies for authenticated upload, public read

- [X] [T008] Run database migration 005_create_events_tables.sql (command)
  - Execute migration in Supabase dashboard or via CLI
  - Verify tables created: events, notifications
  - Verify RLS policies enabled (11 policies)
  - Verify triggers created (4 triggers)

### Project Structure Creation

- [X] [T009] [P] Create feature directory structure (directories)
  - `nova/lib/features/events/data/repositories/`
  - `nova/lib/features/events/data/datasources/`
  - `nova/lib/features/events/data/models/`
  - `nova/lib/features/events/domain/entities/`
  - `nova/lib/features/events/domain/repositories/`
  - `nova/lib/features/events/presentation/providers/`
  - `nova/lib/features/events/presentation/screens/`
  - `nova/lib/features/events/presentation/widgets/`

- [X] [T010] [P] Create core utilities directory structure (directories)
  - `nova/lib/core/utils/`
  - `nova/lib/core/services/`

---

## Phase 2: Foundational (Shared Infrastructure)

**Purpose**: Build shared utilities, database migration, entity models used across all user stories

**Dependencies**: Phase 1 must complete first

### Domain Entities (Freezed Models)

- [ ] [T011] [P] Create Event entity with Freezed (file: nova/lib/features/events/domain/entities/event.dart)
  - Define Event class with all fields from data-model.md
  - Include fromJson/toJson factories
  - Generate code with `flutter pub run build_runner build`

- [ ] [T012] [P] Create EventStatus enum (file: nova/lib/features/events/domain/entities/event_status.dart)
  - Values: pending, approved, rejected
  - JsonValue annotations

- [ ] [T013] [P] Create AppNotification entity with Freezed (file: nova/lib/features/events/domain/entities/app_notification.dart)
  - Define all fields from data-model.md
  - Include NotificationChannel enum

- [ ] [T014] [P] Create NotificationChannel enum (file: nova/lib/features/events/domain/entities/notification_channel.dart)
  - Values: event_approved, event_rejected, new_pending_event, added_as_coorganizer, event_modified

### Data Models (JSON Serialization)

- [ ] [T015] [P] Create EventModel with JSON serialization (file: nova/lib/features/events/data/models/event_model.dart)
  - Extend Event entity
  - Add fromJson/toJson for Supabase integration
  - Map snake_case (DB) to camelCase (Dart)

- [ ] [T016] [P] Create NotificationModel (file: nova/lib/features/events/data/models/notification_model.dart)
  - Extend AppNotification entity
  - Add fromJson/toJson

### Core Utilities

- [ ] [T017] Create ImageCompressor utility (file: nova/lib/core/utils/image_compressor.dart)
  - Implement WebP compression (primary)
  - Implement JPEG fallback compression
  - Target: 800x450px, max 200KB
  - Quality: 85 for WebP, 70 for JPEG
  - EXIF metadata removal (automatic with flutter_image_compress)

- [ ] [T018] Create DeepLinkHandler utility (file: nova/lib/core/utils/deep_link_handler.dart)
  - Parse `nova://events/{event_id}` format
  - Extract event ID from URI
  - Handle initial link (app cold start)
  - Listen to link stream (app warm start)

- [ ] [T019] [P] Create NotificationService (file: nova/lib/core/services/notification_service.dart)
  - Initialize FCM
  - Request notification permissions
  - Save FCM token to Supabase users table
  - Handle foreground/background message callbacks
  - Define notification channels (Android)

- [ ] [T020] [P] Create ShareService (file: nova/lib/core/services/share_service.dart)
  - Generate deep link for event: `nova://events/{id}`
  - Trigger native share sheet via share_plus
  - Format share message text

### Hive Offline Storage

- [ ] [T021] Create EventDraft Hive model (file: nova/lib/features/events/data/models/event_draft.dart)
  - Define HiveType with fields: title, description, eventDate, location, imagePath, lastSaved
  - Generate adapter with hive_generator

- [ ] [T022] Initialize Hive in main.dart (file: nova/lib/main.dart)
  - Register EventDraftAdapter
  - Open box: `Hive.openBox<EventDraft>('eventDrafts')`

### Repository Contracts (Interfaces)

- [ ] [T023] [P] Create EventRepository interface (file: nova/lib/features/events/domain/repositories/event_repository_interface.dart)
  - Define abstract methods:
    - `Future<List<Event>> getApprovedEvents()`
    - `Future<List<Event>> getMyEvents(String userId)`
    - `Future<List<Event>> getPendingEvents()` (moderators only)
    - `Future<Event> createEvent(Event event)`
    - `Future<Event> updateEvent(String id, Map<String, dynamic> updates)`
    - `Future<void> deleteEvent(String id)`
    - `Future<String> uploadEventImage(File imageFile)`

- [ ] [T024] [P] Create NotificationRepository interface (file: nova/lib/features/events/domain/repositories/notification_repository_interface.dart)
  - Define methods:
    - `Future<List<AppNotification>> getMyNotifications(String userId)`
    - `Future<void> markAsRead(String notificationId)`

### Data Sources

- [ ] [T025] Create EventRemoteDataSource (file: nova/lib/features/events/data/datasources/event_remote_datasource.dart)
  - Implement all Supabase REST API calls from supabase-rest-api.md
  - Use SupabaseClient instance
  - Return EventModel instances
  - Handle errors and RLS policy violations

- [ ] [T026] [P] Create EventLocalDataSource (file: nova/lib/features/events/data/datasources/event_local_datasource.dart)
  - Implement Hive draft operations:
    - `saveDraft(EventDraft draft)`
    - `getDraft()`
    - `deleteDraft()`
  - Debounce saves (500ms)

- [ ] [T027] [P] Create NotificationRemoteDataSource (file: nova/lib/features/events/data/datasources/notification_remote_datasource.dart)
  - Implement Supabase notifications table queries

### Repository Implementation

- [ ] [T028] Create EventRepository implementation (file: nova/lib/features/events/data/repositories/event_repository.dart)
  - Inject EventRemoteDataSource and EventLocalDataSource
  - Implement all interface methods
  - Handle offline-first logic for drafts
  - Image upload to Supabase Storage

- [ ] [T029] [P] Create NotificationRepository implementation (file: nova/lib/features/events/data/repositories/notification_repository.dart)
  - Inject NotificationRemoteDataSource
  - Implement all interface methods

### Riverpod Providers (Foundational)

- [ ] [T030] [P] Create Supabase client provider (file: nova/lib/features/events/presentation/providers/supabase_provider.dart)
  - Provide singleton SupabaseClient instance

- [ ] [T031] [P] Create repository providers (file: nova/lib/features/events/presentation/providers/repository_providers.dart)
  - eventRepositoryProvider
  - notificationRepositoryProvider
  - Inject datasources

---

## Phase 3: User Story 1 - Student Creates School Event (P1)

**Purpose**: Implement event creation form with image upload, validation, and offline-first draft persistence

**Dependencies**: Phase 2 must complete first

**Acceptance Criteria**: FR-001 through FR-007

### Event Creation Form State

- [ ] [T032] Create EventFormState class (file: nova/lib/features/events/presentation/providers/event_creation_provider.dart)
  - Fields: title, titleError, description, descriptionError, eventDate, eventDateError, location, imageFile, imagePath
  - Validation logic (real-time)
  - isValid computed property
  - Draft auto-save to Hive (debounced 500ms)

- [ ] [T033] Create EventCreationNotifier (file: nova/lib/features/events/presentation/providers/event_creation_provider.dart)
  - Extend StateNotifier<EventFormState>
  - Methods: updateTitle(), updateDescription(), updateEventDate(), updateLocation(), pickImage(), compressAndSetImage()
  - createEvent() method: compress image → upload to Storage → create event via repository → clear draft

### Image Picker Widget

- [ ] [T034] Create ImagePickerWidget (file: nova/lib/features/events/presentation/widgets/image_picker_widget.dart)
  - Show placeholder if no image selected
  - Show selected image preview (800x450px aspect ratio)
  - Buttons: "Camera" and "Gallery"
  - Tap image to change/remove
  - Loading indicator during compression

### Event Creation Form Widget

- [ ] [T035] Create EventForm widget (file: nova/lib/features/events/presentation/widgets/event_form.dart)
  - Title TextField with validation (5-100 chars)
  - Description TextField with validation (20-500 chars)
  - Event Date/Time Picker with validation (future dates only)
  - Location TextField (optional)
  - ImagePickerWidget integration
  - Real-time error messages below each field
  - Character counters (e.g., "45/100" for title)

### Event Creation Screen

- [ ] [T036] Create EventCreationScreen (file: nova/lib/features/events/presentation/screens/event_creation_screen.dart)
  - Scaffold with NovaAppBar "Crea Evento"
  - EventForm widget
  - Bottom bar with "Crea Evento" button (disabled if !isValid)
  - Show loading overlay during submission
  - Show success SnackBar: "Evento creato! Sarà visibile dopo l'approvazione del moderatore"
  - Navigate back to feed on success
  - Restore draft on screen init (if exists)

### Form Validation Tests

- [ ] [T037] Unit tests for EventFormState validation (file: nova/test/features/events/presentation/providers/event_creation_provider_test.dart)
  - Test title validation (too short, too long, valid)
  - Test description validation (too short, too long, valid)
  - Test date validation (past date, future date)
  - Test isValid computed property

### Image Compression Tests

- [ ] [T038] Unit tests for ImageCompressor (file: nova/test/core/utils/image_compressor_test.dart)
  - Test WebP compression success (output <200KB)
  - Test JPEG fallback when WebP fails
  - Test aspect ratio maintained (16:9)
  - Test EXIF metadata removal

### Integration Test

- [ ] [T039] Integration test: Student creates event end-to-end (file: nova/integration_test/event_creation_flow_test.dart)
  - Open EventCreationScreen
  - Fill all required fields
  - Pick image from test assets
  - Submit form
  - Verify event created with status='pending'
  - Verify success message shown

---

## Phase 4: User Story 2 - Student Tracks Event Status and Receives Notifications (P1)

**Purpose**: Display event status with visual badges, send push notifications on approval/rejection

**Dependencies**: Phase 3 must complete first (needs event creation to exist)

**Acceptance Criteria**: FR-008 through FR-012

### Event Status Badge Widget

- [ ] [T040] [P] Create EventStatusBadge widget (file: nova/lib/features/events/presentation/widgets/event_status_badge.dart)
  - Pending: Yellow badge with "In Revisione" text + clock icon
  - Approved: Green badge with "Approvato" text + check icon
  - Rejected: Red badge with "Rifiutato" text + X icon
  - Use NovaColors constants

### My Events Screen

- [ ] [T041] Create MyEventsProvider (file: nova/lib/features/events/presentation/providers/my_events_provider.dart)
  - FutureProvider that fetches user's created events
  - Filter: `creator_id = auth.uid()`
  - Returns List<Event> sorted by created_at DESC

- [ ] [T042] Create MyEventsScreen (file: nova/lib/features/events/presentation/screens/my_events_screen.dart)
  - Scaffold with NovaAppBar "I Miei Eventi"
  - Watch myEventsProvider
  - Display list of events with EventStatusBadge
  - Show rejection_reason if status='rejected' (expandable card)
  - Empty state: "Nessun evento creato. Crea il tuo primo evento!"

### Push Notification Implementation

- [ ] [T043] Implement FCM message handlers in NotificationService (file: nova/lib/core/services/notification_service.dart)
  - onMessage (foreground): Show in-app notification banner
  - onMessageOpenedApp (background tap): Navigate to Event Detail Screen
  - onBackgroundMessage (background): Handle via static callback

- [ ] [T044] Create Edge Function for FCM push delivery (file: supabase/functions/send-event-notification/index.ts)
  - Subscribe to notifications table inserts (Realtime)
  - Fetch user's FCM token from users table
  - Send FCM message via Firebase Admin SDK
  - Update notification.delivered = true on success
  - Respect user's notification preferences

- [ ] [T045] [P] Update database triggers to call Edge Function (file: supabase/migrations/005_create_events_tables.sql)
  - Modify trigger_notify_event_approval to invoke Edge Function
  - Modify trigger_notify_event_rejection to invoke Edge Function
  - Pass notification channel + event_id

### Notification Preferences Screen

- [ ] [T046] Create NotificationPreferencesScreen (file: nova/lib/features/profile/presentation/screens/notification_preferences_screen.dart)
  - Toggle switches for each channel:
    - "Eventi Propri" (event_approved, event_rejected)
    - "Co-Organizer Updates" (added_as_coorganizer, event_modified)
    - "Moderazione" (new_pending_event) - only visible if user.role='moderator'
  - Save preferences to SharedPreferences
  - Update user metadata in Supabase

### Tests

- [ ] [T047] Unit tests for MyEventsProvider (file: nova/test/features/events/presentation/providers/my_events_provider_test.dart)
  - Mock repository
  - Verify events filtered by creator_id
  - Verify sorting by created_at DESC

- [ ] [T048] [P] Widget test for EventStatusBadge (file: nova/test/features/events/presentation/widgets/event_status_badge_test.dart)
  - Test pending badge renders yellow with clock icon
  - Test approved badge renders green with check icon
  - Test rejected badge renders red with X icon

---

## Phase 5: User Story 3 - Moderator Reviews and Approves/Rejects Events (P1)

**Purpose**: Moderator queue screen with FIFO ordering, approve/reject actions, statistics dashboard

**Dependencies**: Phase 4 must complete first

**Acceptance Criteria**: FR-013 through FR-020

### Moderation Queue Provider

- [ ] [T049] Create ModerationQueueProvider (file: nova/lib/features/events/presentation/providers/moderation_queue_provider.dart)
  - FutureProvider that fetches pending events (moderators only)
  - Query: `status=eq.pending&order=created_at.asc`
  - Returns List<Event> (oldest first)
  - Handle RLS policy (only role='moderator' can access)

- [ ] [T050] [P] Create ModerationStatsProvider (file: nova/lib/features/events/presentation/providers/moderation_stats_provider.dart)
  - Fetch today's statistics:
    - Events approved today (count)
    - Events rejected today (count)
    - Average moderation time (seconds)
  - Use Supabase query with date filters

### Moderation Card Widget

- [ ] [T051] Create ModerationCard widget (file: nova/lib/features/events/presentation/widgets/moderation_card.dart)
  - Display: image preview, title, description (2 lines truncated), event date, creator name, "created X hours ago"
  - Swipe right → Approve action
  - Swipe left → Reject action
  - Tap → Open Event Detail Screen (read-only preview)
  - Use Dismissible widget for swipe gestures

### Rejection Dialog

- [ ] [T052] Create RejectionDialog widget (file: nova/lib/features/events/presentation/widgets/rejection_dialog.dart)
  - TextField for rejection reason (min 10 chars, required)
  - Character counter
  - Validation error if <10 chars
  - Cancel / Confirm buttons
  - Returns rejection reason string on confirm

### Moderation Queue Screen

- [ ] [T053] Create ModerationQueueScreen (file: nova/lib/features/events/presentation/screens/moderation_queue_screen.dart)
  - Scaffold with NovaAppBar "Moderazione" + badge with pending count
  - Watch moderationQueueProvider
  - ListView of ModerationCard widgets
  - Handle approve action: update event status='approved', remove from list, show SnackBar "Evento approvato"
  - Handle reject action: show RejectionDialog, update event with rejection_reason, remove from list
  - Empty state: "Nessun evento da moderare. Ottimo lavoro!"
  - Pull-to-refresh to reload queue

### Moderator Stats Screen

- [ ] [T054] Create ModeratorStatsScreen (file: nova/lib/features/events/presentation/screens/moderator_stats_screen.dart)
  - Scaffold with NovaAppBar "Statistiche Moderazione"
  - Watch moderationStatsProvider
  - Display cards:
    - "Eventi approvati oggi: X"
    - "Eventi rifiutati oggi: Y"
    - "Tempo medio moderazione: Z secondi"
  - Refresh button

### Pending Badge Update

- [ ] [T055] Create pending events count provider (file: nova/lib/features/events/presentation/providers/pending_count_provider.dart)
  - StreamProvider listening to Supabase Realtime
  - Subscribe to events table changes where status='pending'
  - Update badge count in real-time

- [ ] [T056] Update bottom navigation bar (file: nova/lib/shared/widgets/nova_bottom_nav_bar.dart)
  - Add badge to "Moderazione" tab (only visible if user.role='moderator')
  - Watch pendingCountProvider
  - Show badge with count if >0

### Moderation Action Prevention

- [ ] [T057] Add client-side validation for past event dates (file: nova/lib/features/events/presentation/providers/moderation_queue_provider.dart)
  - Before approve: check if event_date > now()
  - If past: show alert "Impossibile approvare: data evento già trascorsa"
  - Suggest contacting creator to update date

### Tests

- [ ] [T058] Unit tests for ModerationQueueProvider (file: nova/test/features/events/presentation/providers/moderation_queue_provider_test.dart)
  - Mock repository with RLS enforcement
  - Verify only role='moderator' can fetch pending events
  - Verify FIFO ordering (created_at ASC)

- [ ] [T059] [P] Widget test for ModerationCard swipe gestures (file: nova/test/features/events/presentation/widgets/moderation_card_test.dart)
  - Test swipe right triggers approve callback
  - Test swipe left triggers reject callback

### Notification Batching for Moderators

- [ ] [T060] Implement daily batched notification for moderators (file: supabase/functions/batch-moderator-notifications/index.ts)
  - Cron job (runs once daily at 9 AM)
  - Count new pending events created in last 24 hours
  - If count >0: send single FCM notification "X nuovi eventi da moderare"
  - Mark notification as sent to prevent duplicates

---

## Phase 6: User Story 4 - Student Shares Event via Deep Link (P2)

**Purpose**: Event sharing via native share sheet, deep link handling, web fallback page

**Dependencies**: Phase 5 must complete first (needs approved events to share)

**Acceptance Criteria**: FR-021 through FR-026

### Event Detail Screen Updates

- [ ] [T061] Add "Condividi" button to EventDetailScreen (file: nova/lib/features/events/presentation/screens/event_detail_screen.dart)
  - Only visible if event.status == 'approved'
  - Icon: Share icon from NovaIcons
  - Tap → call ShareService.shareEvent()

### Share Service Implementation

- [ ] [T062] Implement shareEvent method in ShareService (file: nova/lib/core/services/share_service.dart)
  - Generate deep link: `nova://events/{event.id}`
  - Format message: "Guarda questo evento su Nova: {event.title}\n{deepLink}"
  - Call Share.share() with message and subject

### Deep Link Handler Implementation

- [ ] [T063] Implement deep link routing in DeepLinkHandler (file: nova/lib/core/utils/deep_link_handler.dart)
  - Parse `nova://events/{id}` format
  - Extract event ID
  - Navigate to EventDetailScreen with eventId parameter
  - Handle errors: event not found, event not accessible

- [ ] [T064] Integrate DeepLinkHandler in main.dart (file: nova/lib/main.dart)
  - Initialize uni_links in app startup
  - Listen to getInitialLink() for cold start
  - Listen to linkStream for warm start
  - Navigate using Navigator/Router on link received

### iOS Deep Link Configuration

- [ ] [T065] Configure iOS URL scheme (file: nova/ios/Runner/Info.plist)
  - Add URL scheme: `nova`
  - Add URL identifier: `com.galileimoro.nova`
  - Handle universal links (optional for future)

### Android Deep Link Configuration

- [ ] [T066] Configure Android intent filter (file: nova/android/app/src/main/AndroidManifest.xml)
  - Add intent filter for `nova://` scheme
  - Set android:autoVerify="true"
  - Handle deep link intents in MainActivity

### Event Detail Screen Deep Link Handling

- [ ] [T067] Update EventDetailScreen to handle event ID parameter (file: nova/lib/features/events/presentation/screens/event_detail_screen.dart)
  - Accept eventId as constructor parameter
  - Fetch event by ID via provider
  - Handle not found: show "Evento non disponibile" with "Torna al Feed" button
  - Handle pending event (non-creator): show "Evento in attesa di moderazione"
  - Handle rejected event (non-creator): show "Evento non disponibile"

### Web Fallback Page

- [ ] [T068] Create static HTML fallback page (file: supabase/storage/web-fallback/event.html)
  - Extract event ID from URL query param (?id=...)
  - Fetch event data via Supabase REST API (public endpoint)
  - Display: event image, title, description (3 lines)
  - Show buttons: "Scarica NOVA per iOS" → App Store, "Scarica NOVA per Android" → Play Store
  - Handle loading state and errors (event not found)

- [ ] [T069] Upload web fallback page to Supabase Storage (command)
  - Upload event.html to bucket: web-fallback
  - Set bucket public read access
  - Test URL: https://{project}.supabase.co/storage/v1/object/public/web-fallback/event.html?id={event_id}

### Tests

- [ ] [T070] Unit tests for DeepLinkHandler (file: nova/test/core/utils/deep_link_handler_test.dart)
  - Test parsing `nova://events/123`
  - Test extracting event ID
  - Test handling malformed URLs

- [ ] [T071] [P] Integration test for deep link flow (file: nova/integration_test/deep_link_test.dart)
  - Simulate deep link tap
  - Verify EventDetailScreen opens with correct event ID
  - Verify navigation works from cold start and warm start

---

## Phase 7: User Story 5 - Student Adds Co-Organizers to Event (P2)

**Purpose**: Co-organizer management, search functionality, collaborative editing with notifications

**Dependencies**: Phase 6 must complete first

**Acceptance Criteria**: FR-027 through FR-035

### User Search Widget

- [ ] [T072] Create UserSearchWidget (file: nova/lib/features/events/presentation/widgets/co_organizer_search.dart)
  - TextField for search query (name or class)
  - Debounced search (500ms)
  - Query Supabase users table: `full_name.ilike.%{query}% OR class.ilike.%{query}%`
  - Display results as selectable list items
  - Max 3 selections enforced
  - Show selected users as chips with remove button

### Co-Organizer Management in Event Form

- [ ] [T073] Add co-organizers field to EventFormState (file: nova/lib/features/events/presentation/providers/event_creation_provider.dart)
  - Field: `List<User> coOrganizers`
  - Methods: `addCoOrganizer(User user)`, `removeCoOrganizer(String userId)`
  - Validation: max 3 co-organizers

- [ ] [T074] Update EventForm to include co-organizer section (file: nova/lib/features/events/presentation/widgets/event_form.dart)
  - Section header: "Co-Organizzatori (Opzionale - Max 3)"
  - Button "Aggiungi Co-Organizer" → opens UserSearchWidget modal
  - Display selected co-organizers as chips with remove X button
  - Save co_organizers array when creating event

### Edit Event Screen

- [ ] [T075] Create EditEventScreen (file: nova/lib/features/events/presentation/screens/edit_event_screen.dart)
  - Pre-populate form with existing event data
  - Allow editing: title, description, event_date, location, image, co_organizers
  - Only accessible by creator or co-organizers (check RLS)
  - Disable status field (non-editable by students)
  - Submit button: "Salva Modifiche"
  - If event was approved, show warning: "Le modifiche richiederanno nuova moderazione"

### Update Event Logic

- [ ] [T076] Implement updateEvent in EventRepository (file: nova/lib/features/events/data/repositories/event_repository.dart)
  - Call Supabase PATCH endpoint
  - Handle RLS policy (only creator/co-organizers can update)
  - Trigger database function for event_modified notification
  - If event.status='approved', trigger status change to 'pending' (handled by DB trigger)

### Database Trigger for Event Modification

- [ ] [T077] Verify trigger_notify_event_modification (file: supabase/migrations/005_create_events_tables.sql)
  - Already created in migration
  - Test: modify event as co-organizer, verify creator + other co-organizers receive notification
  - Notification: "[Modifier Name] ha modificato l'evento '[Event Title]'"

### Database Trigger for Co-Organizer Addition

- [ ] [T078] Verify trigger_notify_co_organizer_addition (file: supabase/migrations/005_create_events_tables.sql)
  - Already created in migration
  - Test: add co-organizer, verify they receive notification
  - Notification: "[Creator Name] ti ha aggiunto come co-organizer dell'evento '[Event Title]'"

### Co-Organizer Removal

- [ ] [T079] Implement removeCoOrganizer action in EventRepository (file: nova/lib/features/events/data/repositories/event_repository.dart)
  - Update co_organizers array (remove user ID)
  - Call PATCH endpoint
  - Only creator can remove co-organizers
  - Send notification to removed user (handled by new trigger or client-side)

- [ ] [T080] Create database trigger for co-organizer removal (file: supabase/migrations/006_add_coorganizer_removal_trigger.sql)
  - New migration file
  - Trigger: notify_co_organizer_removal
  - Detect removed user IDs (compare OLD.co_organizers vs NEW.co_organizers)
  - Insert notification: "[Creator] ti ha rimosso come co-organizer dell'evento '[Title]'"

### RLS Policy Update for Co-Organizer Editing

- [ ] [T081] Verify RLS policy "Creators and co-organizers can update events" (file: supabase/migrations/005_create_events_tables.sql)
  - Already created in migration
  - Policy allows: `creator_id = auth.uid() OR auth.uid() = ANY(co_organizers)`
  - Test: co-organizer can edit event, non-co-organizer cannot

### Status Reversion on Edit

- [ ] [T082] Create database trigger for status reversion (file: supabase/migrations/007_add_status_reversion_trigger.sql)
  - New migration file
  - Trigger: revert_status_on_content_change
  - If event.status='approved' AND (title/description/event_date/location/image_url changed)
  - Then: set status='pending', moderated_by=null, moderated_at=null
  - Notify creator: "Le tue modifiche richiedono nuova moderazione"

### "Eventi Organizzati" Section in Profile

- [ ] [T083] Update MyEventsScreen to show "Eventi Organizzati" tab (file: nova/lib/features/events/presentation/screens/my_events_screen.dart)
  - Add TabBar with 2 tabs: "Creati da Me" | "Co-Organizzati"
  - "Creati da Me": filter `creator_id = auth.uid()`
  - "Co-Organizzati": filter `auth.uid() = ANY(co_organizers)`
  - Both tabs show EventStatusBadge and edit button

### Tests

- [ ] [T084] Unit tests for co-organizer logic (file: nova/test/features/events/data/repositories/event_repository_test.dart)
  - Test addCoOrganizer enforces max 3
  - Test removeCoOrganizer removes correctly
  - Test RLS policy allows co-organizer to edit

- [ ] [T085] [P] Integration test for co-organizer workflow (file: nova/integration_test/coorganizer_workflow_test.dart)
  - User A creates event
  - User A adds User B as co-organizer
  - Verify User B receives notification
  - User B edits event
  - Verify User A receives modification notification
  - Verify event status reverts to pending if was approved

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final polish, performance optimization, error handling, accessibility, documentation

**Dependencies**: Phase 7 must complete first

### Error Handling

- [ ] [T086] [P] Create ErrorWidget for repository failures (file: nova/lib/shared/widgets/error_widget.dart)
  - Display user-friendly error messages
  - Retry button for network errors
  - Use NovaColors for error states

- [ ] [T087] [P] Add global error boundary in main.dart (file: nova/lib/main.dart)
  - Catch and log unhandled exceptions
  - Show fallback UI on critical errors
  - Report errors to monitoring service (future)

### Loading States

- [ ] [T088] [P] Create SkeletonLoader for event cards (file: nova/lib/shared/widgets/skeleton_loader.dart)
  - Shimmer effect for loading states
  - Match EventCard layout
  - Use NovaColors.shimmer

### Performance Optimization

- [ ] [T089] Add image caching for event images (file: nova/lib/features/events/presentation/widgets/event_card.dart)
  - Use CachedNetworkImage package
  - Cache images locally after first load
  - Show placeholder during load

- [ ] [T090] [P] Implement pagination for event feed (file: nova/lib/features/events/presentation/providers/events_provider.dart)
  - Fetch 20 events at a time
  - Load more on scroll (infinite scroll)
  - Cache loaded pages

- [ ] [T091] [P] Add Supabase Realtime subscription for live updates (file: nova/lib/features/events/presentation/providers/events_provider.dart)
  - Subscribe to events table changes
  - Update feed in real-time when new events approved
  - Update moderation queue when events added/removed

### Accessibility

- [ ] [T092] [P] Add semantic labels to all interactive widgets (file: multiple)
  - Semantics() wrapper for images, buttons, cards
  - Test with screen reader (TalkBack/VoiceOver)
  - Ensure minimum touch target size (48x48dp)

- [ ] [T093] [P] Verify color contrast ratios (file: nova/lib/core/theme/nova_colors.dart)
  - Test all text/background combinations with WCAG 2.1 AA tool
  - Fix any contrast violations
  - Document contrast ratios in comments

### Edge Case Handling

- [ ] [T094] Handle offline mode gracefully (file: multiple)
  - Show "Nessuna connessione" banner when offline
  - Queue mutations (create/update event) for retry when online
  - Use cached data for feed

- [ ] [T095] [P] Handle deleted/missing events in detail screen (file: nova/lib/features/events/presentation/screens/event_detail_screen.dart)
  - Show "Evento non disponibile" if event not found
  - Handle RLS policy errors (event pending, user not authorized)

### Documentation

- [ ] [T096] [P] Add code documentation comments (file: multiple)
  - Document all public classes and methods
  - Add examples for complex utilities (ImageCompressor, DeepLinkHandler)
  - Follow Dart documentation style guide

- [ ] [T097] [P] Create README for events feature (file: nova/lib/features/events/README.md)
  - Feature overview
  - Architecture diagram (data/domain/presentation layers)
  - Key flows (create event, moderation, notifications)
  - Testing guide

### Final Testing

- [ ] [T098] Run full test suite (command)
  - `flutter test --coverage`
  - Verify all unit tests pass
  - Verify coverage >70% for critical paths

- [ ] [T099] [P] Run integration tests (command)
  - `flutter test integration_test/`
  - Test all 5 user stories end-to-end
  - Verify on iOS and Android devices

- [ ] [T100] Manual QA testing checklist (manual)
  - Test all acceptance scenarios from spec.md
  - Test edge cases documented in spec
  - Test on low-end devices (performance)
  - Test on slow network (3G)
  - Test offline mode

### Performance Profiling

- [ ] [T101] Profile EventCreationScreen performance (command)
  - Use Flutter DevTools performance tab
  - Verify 60fps during image compression
  - Verify <3s upload time on 4G

- [ ] [T102] [P] Profile ModerationQueueScreen performance (command)
  - Test with 50+ pending events
  - Verify smooth scrolling (60fps)
  - Verify no memory leaks on long sessions

### Final Code Review

- [ ] [T103] Code review checklist verification (manual)
  - No hardcoded values (all from NovaColors, NovaSpacing, etc.)
  - All RLS policies tested and working
  - All database triggers tested
  - All notification channels working
  - Deep links working on iOS and Android
  - Privacy: EXIF metadata removed from images
  - Performance: All budgets met (SC-001 through SC-010)

---

## Dependency Graph

**Sequential Dependencies**:

```
Phase 1 (Setup) → Phase 2 (Foundational)
                        ↓
                  Phase 3 (US1: Event Creation)
                        ↓
                  Phase 4 (US2: Status Tracking)
                        ↓
                  Phase 5 (US3: Moderation)
                        ↓
                  Phase 6 (US4: Sharing)
                        ↓
                  Phase 7 (US5: Co-Organizers)
                        ↓
                  Phase 8 (Polish)
```

**Parallelizable Tasks** (marked with [P]):
- Within each phase, all [P] tasks can run concurrently
- Example: In Phase 1, T001, T002, T004, T005, T007, T009, T010 can all run in parallel

**Critical Path** (longest dependency chain):
1. Setup (Phase 1) → Foundational entities/repositories (Phase 2)
2. → Event creation form (Phase 3, ~8 tasks)
3. → Status tracking + notifications (Phase 4, ~8 tasks)
4. → Moderation queue (Phase 5, ~12 tasks)
5. → Deep linking (Phase 6, ~11 tasks)
6. → Co-organizers (Phase 7, ~14 tasks)
7. → Polish (Phase 8, ~18 tasks)

**Estimated Total**: 103 tasks, ~71 parallelizable

---

## Parallel Execution Examples

### Phase 1 Parallel Set
```bash
# Run concurrently:
- T001: Add packages to pubspec.yaml
- T002: Add dev dependencies
- T004: Configure Firebase iOS
- T005: Configure Firebase Android
- T009: Create feature directories
- T010: Create core directories

# Then sequentially:
- T003: flutter pub get (depends on T001, T002)
- T006: Initialize Firebase (depends on T003, T004, T005)
- T007: Create Supabase Storage bucket (independent)
- T008: Run database migration (independent)
```

### Phase 2 Parallel Set
```bash
# Entities (fully parallel):
- T011: Event entity
- T012: EventStatus enum
- T013: AppNotification entity
- T014: NotificationChannel enum

# Data models (fully parallel):
- T015: EventModel
- T016: NotificationModel

# Utilities and services (fully parallel):
- T017: ImageCompressor
- T018: DeepLinkHandler
- T019: NotificationService
- T020: ShareService
- T023: EventRepository interface
- T024: NotificationRepository interface
- T026: EventLocalDataSource
- T027: NotificationRemoteDataSource

# Sequential dependencies:
- T021: EventDraft (depends on T011 for Event reference)
- T022: Initialize Hive (depends on T021)
- T025: EventRemoteDataSource (depends on T015)
- T028: EventRepository impl (depends on T023, T025, T026)
- T029: NotificationRepository impl (depends on T024, T027)
- T030: Supabase provider (depends on T028, T029)
- T031: Repository providers (depends on T030)
```

### Phase 8 Parallel Set (Polish)
```bash
# Fully parallelizable:
- T086: ErrorWidget
- T087: Global error boundary
- T088: SkeletonLoader
- T089: Image caching
- T090: Pagination
- T091: Realtime subscriptions
- T092: Semantic labels
- T093: Contrast verification
- T095: Edge case handling
- T096: Code documentation
- T097: Feature README
- T099: Integration tests
- T102: Performance profiling

# Sequential (at end):
- T094: Offline mode (depends on all features complete)
- T098: Full test suite (depends on all features)
- T100: Manual QA (depends on T098, T099)
- T101: Performance profiling (depends on T100)
- T103: Final code review (depends on all tasks)
```

---

## Task Completion Checklist

After each task is completed, verify:

- [ ] Code follows design system (no hardcoded colors/spacing/typography)
- [ ] Code uses Riverpod for state management (no direct repository instantiation)
- [ ] RLS policies tested (if database-related)
- [ ] Unit tests written and passing (if logic-heavy)
- [ ] Widget tests written (if UI component)
- [ ] Performance budget respected (if performance-critical)
- [ ] Accessibility labels added (if interactive widget)
- [ ] Documentation comments added
- [ ] No sensitive data logged
- [ ] Linting passes (`dart analyze`)

---

## Notes

- **Firebase Setup**: Requires Firebase project creation via Firebase Console before T004/T005. Generate and download config files manually.

- **Supabase Migration**: Migration 005 creates events and notifications tables with all RLS policies and triggers. Migrations 006 and 007 are new (co-organizer removal trigger, status reversion trigger).

- **Edge Function Deployment**: T044 and T060 require Supabase CLI for Edge Function deployment. Deploy via `supabase functions deploy send-event-notification`.

- **Image Compression Performance**: T038 and T101 should verify compression completes in <1 second for 5MB images on mid-range devices.

- **Deep Link Testing**: T071 requires physical devices or simulators to test deep link handling (cannot test in Flutter web).

- **Notification Testing**: T047, T048 require Firebase Test Lab or physical devices with FCM enabled to verify delivery rates.

- **Constitution Compliance**: All tasks must align with the 7 core principles. No hardcoded values (Principle 6), performance budgets respected (Principle 4), privacy maintained (Principle 2).

---

**Status**: Ready for implementation via `/speckit.implement`
**Total Tasks**: 103
**Estimated Duration**: 3-4 weeks (1 developer, full-time)
**Next Step**: Run `/speckit.implement` to execute all tasks in dependency order
