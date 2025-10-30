---
description: "Task list for magic link authentication implementation"
---

# Tasks: Magic Link Authentication

**Input**: Design documents from `/specs/001-magic-link-auth/`
**Prerequisites**: plan.md (required), spec.md (required), data-model.md, contracts/, research.md, quickstart.md

**Tests**: Integration and widget tests are included based on specification requirements.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Flutter project**: `nova/lib/` for source code
- **Database**: `supabase/migrations/` for database schema
- **Platform-specific**: `nova/android/` and `nova/ios/` for deep linking
- **Landing page**: `landing/` for web fallback page
- **Scripts**: `scripts/` for verification and deployment scripts

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and environment configuration

- [ ] T001 Create Flutter project structure in nova/ directory with feature-first architecture
- [ ] T002 Initialize Flutter project with pubspec.yaml dependencies: supabase_flutter 2.8.0+, flutter_riverpod 2.6.1+, app_links 6.3.2+, flutter_dotenv 5.1.0
- [ ] T003 [P] Configure Flutter linting with analysis_options.yaml following constitution design system rules
- [ ] T004 [P] Setup environment configuration with .env file for Supabase credentials (SUPABASE_URL, SUPABASE_ANON_KEY)
- [ ] T005 [P] Create lib/core/config/ directory with supabase_config.dart for Supabase.initialize() with PKCE flow
- [ ] T006 [P] Create lib/core/constants/ directory with app_constants.dart for magic link URLs and timeout values
- [ ] T007 [P] Verify .gitignore includes .env, build/, .dart_tool/, .flutter-plugins
- [ ] T008 Run flutter pub get and verify no dependency conflicts

**Checkpoint**: Flutter project initialized with dependencies, environment configured, linting ready

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Database Schema Deployment

- [ ] T009 Create supabase/migrations/ directory for database migration files
- [ ] T010 Deploy database schema from contracts/database.sql to Supabase project via SQL Editor or CLI
- [ ] T011 Verify tables created: public.auth_events, public.magic_link_attempts with correct columns and types
- [ ] T012 Verify functions created: hash_email, check_magic_link_rate_limit, hook_restrict_signup_by_email_domain, log_auth_event, cleanup_old_auth_events
- [ ] T013 Verify trigger created: trigger_log_auth_events on auth.users table
- [ ] T014 Verify RLS policies enabled on auth_events (service_role insert, users read own) and magic_link_attempts (service_role only)
- [ ] T015 Test hash_email function with SQL query: SELECT public.hash_email('test@galileimoro.edu.it'); verify consistent SHA256 output
- [ ] T016 Test check_magic_link_rate_limit function with 4 sequential attempts, verify 4th fails with rate limit error
- [ ] T017 Configure Auth Hook "Before User Created" in Supabase Dashboard → Authentication → Hooks with hook_restrict_signup_by_email_domain function
- [ ] T018 Test email domain validation: attempt signup with @gmail.com, verify rejection with "not authorized" error

### Supabase Client & Core Services

- [ ] T019 Implement Supabase initialization in lib/core/config/supabase_config.dart with authOptions: AuthFlowType.pkce, autoRefreshToken: true, persistSession: true
- [ ] T020 Call SupabaseConfig.initialize() in main.dart before runApp, wrap in WidgetsFlutterBinding.ensureInitialized()
- [ ] T021 [P] Create lib/core/services/deep_link_service.dart with appLinks.uriLinkStream listener and getInitialAppLink() for cold start
- [ ] T022 [P] Create lib/core/utils/email_validator.dart with validateEmail(String email) using regex ^[a-zA-Z0-9._%+-]+@galileimoro\.edu\.it$
- [ ] T023 [P] Create lib/core/models/auth_state.dart with sealed class AuthState (authenticated, unauthenticated, loading, error)
- [ ] T024 Create lib/features/auth/data/repositories/auth_repository.dart with methods: sendMagicLink, verifyMagicLink, signOut, getCurrentUser, streamAuthState
- [ ] T025 Implement auth_repository.dart using Supabase.instance.client.auth methods (signInWithOtp, verifyOtp, signOut, onAuthStateChange)

**Checkpoint**: Foundation ready - database deployed, Supabase client configured, core services created, user story implementation can now begin in parallel

---

## Phase 3: Deep Linking Infrastructure

**Purpose**: Configure Android App Links and iOS Universal Links for magic link handling

### Android App Links Configuration

- [ ] T026 [P] Update nova/android/app/src/main/AndroidManifest.xml with intent-filter for https://nova.galileimoro.edu.it/auth/confirm with android:autoVerify="true"
- [ ] T027 [P] Generate SHA256 certificate fingerprint for debug keystore: keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
- [ ] T028 [P] Generate SHA256 certificate fingerprint for release keystore (or document TODO for production)
- [ ] T029 Create assetlinks.json file with package name it.edu.galileimoro.nova and SHA256 fingerprints
- [ ] T030 Document assetlinks.json hosting requirement: must be hosted at https://nova.galileimoro.edu.it/.well-known/assetlinks.json (HTTPS, no redirects)

### iOS Universal Links Configuration

- [ ] T031 [P] Update nova/ios/Runner/Info.plist with FlutterDeepLinkingEnabled = true
- [ ] T032 [P] Find Apple Team ID from Apple Developer account or Xcode: open nova/ios/Runner.xcworkspace, check Signing & Capabilities
- [ ] T033 Configure Associated Domains in Xcode: open Runner.xcworkspace, add capability "Associated Domains" with applinks:nova.galileimoro.edu.it
- [ ] T034 Create apple-app-site-association (AASA) file with appID: TEAM_ID.it.edu.galileimoro.nova and path /auth/confirm
- [ ] T035 Document AASA hosting requirement: must be hosted at https://nova.galileimoro.edu.it/.well-known/apple-app-site-association (HTTPS, no redirects, no .json extension)

### Deep Link Service Implementation

- [ ] T036 Implement DeepLinkService.initialize() in lib/core/services/deep_link_service.dart to setup appLinks.uriLinkStream subscription
- [ ] T037 Implement DeepLinkService.handleDeepLink(Uri uri) to parse token_hash and type query parameters
- [ ] T038 Implement DeepLinkService cold start handling with getInitialAppLink() called in main.dart after Supabase.initialize()
- [ ] T039 Add deep link validation: check uri.host == 'nova.galileimoro.edu.it' and uri.path == '/auth/confirm'
- [ ] T040 Add error handling for missing or invalid query parameters (token_hash, type)
- [ ] T041 Test Android deep link with ADB: adb shell am start -W -a android.intent.action.VIEW -d "https://nova.galileimoro.edu.it/auth/confirm?token_hash=TEST123&type=email"
- [ ] T042 Test iOS deep link with Simulator: xcrun simctl openurl booted "https://nova.galileimoro.edu.it/auth/confirm?token_hash=TEST123&type=email"

### Landing Page for App-Not-Installed Fallback

- [ ] T043 [P] Create landing/index.html with "Download Nova" heading and platform detection JavaScript
- [ ] T044 [P] Add download buttons in landing/index.html: "Download on App Store" and "Get it on Google Play" with proper styling
- [ ] T045 [P] Implement JavaScript platform detection: navigator.userAgent checks for iOS/Android to show appropriate button
- [ ] T046 [P] Add fallback message in landing/index.html: "If you have Nova installed, please open the app manually"
- [ ] T047 Document landing page hosting requirement: deploy to Vercel/Netlify at https://nova.galileimoro.edu.it or subdomain

**Checkpoint**: Deep linking configured for Android and iOS, landing page ready, assetlinks.json and AASA documented for deployment

---

## Phase 4: Core Auth State Management

**Purpose**: Riverpod state management for authentication flow

- [ ] T048 [P] Create lib/features/auth/presentation/providers/auth_notifier.dart with AsyncNotifierProvider<AuthNotifier, AuthState>
- [ ] T049 Implement AuthNotifier class extending AsyncNotifier<AuthState> with methods: sendMagicLink(email), verifyMagicLink(tokenHash), signOut, checkSession
- [ ] T050 Implement AuthNotifier.build() to return initial state by checking current session with auth_repository.getCurrentUser()
- [ ] T051 Implement AuthNotifier.sendMagicLink(String email) to call auth_repository.sendMagicLink, update state to loading → success/error
- [ ] T052 Implement AuthNotifier.verifyMagicLink(String tokenHash) to call auth_repository.verifyMagicLink, update state to authenticated on success
- [ ] T053 Implement AuthNotifier.signOut() to call auth_repository.signOut, update state to unauthenticated
- [ ] T054 Implement AuthNotifier.checkSession() to call auth_repository.getCurrentUser, return authenticated if session valid (within 30 days)
- [ ] T055 [P] Create lib/features/auth/presentation/providers/auth_state_provider.dart with StreamProvider for auth state changes using auth_repository.streamAuthState()
- [ ] T056 Add error handling in AuthNotifier for network errors, invalid tokens, rate limiting (map to user-friendly error messages)

**Checkpoint**: Auth state management ready with Riverpod providers, all authentication methods implemented

---

## Phase 5: User Story 1 - First-Time Student Login (Priority: P1) 🎯 MVP

**Goal**: Student downloads Nova, enters @galileimoro.edu.it email, receives magic link, clicks link, authenticates to main feed

**Independent Test**:
1. Open Nova app (no existing session)
2. Enter valid school email (e.g., student@galileimoro.edu.it)
3. Tap "Send Magic Link"
4. Check email inbox for magic link
5. Click magic link
6. App opens and shows main feed screen (authenticated)

### UI Implementation

- [ ] T057 [P] [US1] Create lib/features/auth/presentation/screens/login_screen.dart with Scaffold, AppBar title "Welcome to Nova"
- [ ] T058 [P] [US1] Add NovaGlassCard widget in login_screen.dart center with padding from NovaSpacing.lg
- [ ] T059 [P] [US1] Add TextFormField in login_screen.dart for email input with hint "@galileimoro.edu.it", keyboardType: TextInputType.emailAddress
- [ ] T060 [P] [US1] Add "Send Magic Link" ElevatedButton in login_screen.dart with NovaColors.primaryBlue background
- [ ] T061 [P] [US1] Add explanatory Text widget above email field: "Sign in with your school email. No password needed!"
- [ ] T062 [P] [US1] Apply NovaTypography.h3 to "Welcome to Nova" title and NovaTypography.body to explanatory text
- [ ] T063 [US1] Add Form widget with GlobalKey<FormState> in login_screen.dart wrapping TextFormField for validation

### Email Validation

- [ ] T064 [US1] Implement TextFormField validator in login_screen.dart calling EmailValidator.validateEmail, return error "Please use your school email (@galileimoro.edu.it)" if invalid
- [ ] T065 [US1] Normalize email to lowercase before sending: email.trim().toLowerCase()
- [ ] T066 [US1] Add validator check for empty email: return "Email is required" if email.isEmpty

### Magic Link Request Flow

- [ ] T067 [US1] Implement onPressed for "Send Magic Link" button: validate form, call ref.read(authNotifierProvider.notifier).sendMagicLink(email)
- [ ] T068 [US1] Add loading state UI in login_screen.dart: show CircularProgressIndicator when AuthState is loading
- [ ] T069 [US1] Add success message in login_screen.dart: SnackBar with "Check your email for a magic link" when sendMagicLink succeeds
- [ ] T070 [US1] Add error handling in login_screen.dart: SnackBar with error message when sendMagicLink fails (rate limit, network error, invalid domain)
- [ ] T071 [US1] Disable "Send Magic Link" button while loading to prevent duplicate requests

### Deep Link Verification Flow

- [ ] T072 [US1] Implement deep link handling in DeepLinkService: when uri received, extract token_hash and call ref.read(authNotifierProvider.notifier).verifyMagicLink(tokenHash)
- [ ] T073 [US1] Add loading overlay in app during token verification: show fullscreen CircularProgressIndicator with "Signing you in..."
- [ ] T074 [US1] Add navigation logic in main.dart: listen to authStateProvider, navigate to MainFeedScreen when authenticated
- [ ] T075 [US1] Add error handling for expired magic link: show AlertDialog "This magic link has expired. Please request a new one" with "OK" button to dismiss
- [ ] T076 [US1] Add error handling for already used magic link: show AlertDialog "This magic link has already been used. Please request a new one if needed"
- [ ] T077 [US1] Add error handling for invalid token: show AlertDialog "Invalid magic link. Please try again or request a new one"

### Main Feed Screen (Placeholder for Authentication Success)

- [ ] T078 [P] [US1] Create lib/features/events/presentation/screens/main_feed_screen.dart with Scaffold, AppBar title "Nova Events"
- [ ] T079 [P] [US1] Add placeholder content in main_feed_screen.dart: Center widget with Text "Welcome to Nova! Event feed coming soon..." using NovaTypography.body
- [ ] T080 [US1] Update main.dart MaterialApp to route authenticated users to MainFeedScreen, unauthenticated to LoginScreen

### Edge Case Handling

- [ ] T081 [US1] Add network error handling: show SnackBar "No internet connection. Please connect to Wi-Fi or mobile data" when network unavailable
- [ ] T082 [US1] Add rate limit error handling: show SnackBar "Too many requests. Please wait 15 minutes before trying again" when 429 error received
- [ ] T083 [US1] Add email delivery confirmation: always show "Magic link sent! Check your email (including spam folder)" even if delivery status unknown (Supabase doesn't expose delivery confirmation)

### Widget Tests

- [ ] T084 [P] [US1] Create nova/test/features/auth/presentation/screens/login_screen_test.dart with widget test for login screen rendering
- [ ] T085 [P] [US1] Add widget test in login_screen_test.dart: verify email TextFormField shows hint "@galileimoro.edu.it"
- [ ] T086 [P] [US1] Add widget test in login_screen_test.dart: verify "Send Magic Link" button is present and enabled
- [ ] T087 [P] [US1] Add widget test in login_screen_test.dart: enter invalid email (@gmail.com), tap button, verify error message shows
- [ ] T088 [P] [US1] Add widget test in login_screen_test.dart: enter valid email (@galileimoro.edu.it), tap button, verify loading indicator shows

### Integration Tests

- [ ] T089 [US1] Create nova/test_driver/integration/magic_link_flow_test.dart for end-to-end magic link authentication flow
- [ ] T090 [US1] Add integration test in magic_link_flow_test.dart: launch app, enter email, tap button, verify success message
- [ ] T091 [US1] Add integration test in magic_link_flow_test.dart: simulate deep link received with valid token, verify navigation to MainFeedScreen
- [ ] T092 [US1] Add integration test in magic_link_flow_test.dart: simulate deep link with expired token, verify error dialog shows

**Checkpoint**: User Story 1 fully functional - student can request magic link, click link, authenticate to main feed. Test independently before proceeding.

---

## Phase 6: User Story 2 - Returning Student Auto-Login (Priority: P2)

**Goal**: Student with active session (<30 days) opens Nova and automatically lands on main feed without login prompts

**Independent Test**:
1. Complete User Story 1 (authenticate student)
2. Close Nova app completely
3. Reopen Nova app within 30 days
4. Verify app bypasses login screen and shows main feed directly within 1 second

### Session Check on App Launch

- [ ] T093 [US2] Implement session check in main.dart build(): call ref.watch(authNotifierProvider) to get current auth state before building MaterialApp
- [ ] T094 [US2] Add initial route logic in main.dart: if authState.authenticated, set initialRoute to '/feed', else set to '/login'
- [ ] T095 [US2] Implement checkSession() in AuthNotifier to verify session validity (check expires_at timestamp is >now)
- [ ] T096 [US2] Add loading splash screen in main.dart while checking session: show fullscreen NovaLogo with CircularProgressIndicator

### Auto-Navigation Logic

- [ ] T097 [US2] Update main.dart to listen to authStateProvider stream: when state changes to authenticated, navigate to '/feed' if on login screen
- [ ] T098 [US2] Add session persistence verification: close and reopen app 5 times, verify no login prompt each time
- [ ] T099 [US2] Verify token refresh happens automatically: check Supabase logs for token refresh events when access token nears 1-hour expiration

### Background Token Refresh

- [ ] T100 [US2] Verify Supabase client autoRefreshToken: true is set in supabase_config.dart (should be from T019)
- [ ] T101 [US2] Add token refresh listener in auth_repository.dart: log token refresh events for debugging
- [ ] T102 [US2] Test token refresh: authenticate user, wait 50 minutes, verify access token refreshes automatically without user interaction

### Integration Tests

- [ ] T103 [P] [US2] Create nova/test_driver/integration/returning_user_test.dart for returning user auto-login flow
- [ ] T104 [US2] Add integration test in returning_user_test.dart: authenticate user, close app, reopen app, verify lands on MainFeedScreen
- [ ] T105 [US2] Add integration test in returning_user_test.dart: authenticate user, simulate 29 days passing, reopen app, verify still authenticated

**Checkpoint**: User Story 2 fully functional - returning student bypasses login screen, sessions persist across app restarts, tokens refresh automatically

---

## Phase 7: User Story 3 - Session Expired Re-Authentication (Priority: P2)

**Goal**: Student whose 30-day session expired sees login screen, re-enters email, receives new magic link, re-authenticates

**Independent Test**:
1. Authenticate student (User Story 1)
2. Manually expire session: update expires_at in Supabase Dashboard to past date OR wait 30 days
3. Reopen Nova app
4. Verify login screen shows (session expired)
5. Re-enter email, request magic link, click link, verify re-authentication succeeds

### Session Expiration Detection

- [ ] T106 [US3] Implement session expiration check in AuthNotifier.checkSession(): if expires_at < DateTime.now(), return unauthenticated state
- [ ] T107 [US3] Add session expiration during app usage: listen to authStateProvider, if state changes to unauthenticated while on MainFeedScreen, navigate to LoginScreen
- [ ] T108 [US3] Show graceful logout message when session expires during usage: SnackBar "Your session has expired. Please log in again"

### Re-Authentication Flow

- [ ] T109 [US3] Verify login screen does NOT pre-fill email address after session expiration (security requirement)
- [ ] T110 [US3] Verify re-authentication uses same flow as User Story 1 (no code duplication, reuse existing login_screen.dart)
- [ ] T111 [US3] Add auth event logging: verify auth_events table logs "session_expired" event with user_id and timestamp

### Integration Tests

- [ ] T112 [P] [US3] Create nova/test_driver/integration/session_expiration_test.dart for session expiration and re-authentication flow
- [ ] T113 [US3] Add integration test in session_expiration_test.dart: authenticate user, manually expire session, reopen app, verify login screen shows
- [ ] T114 [US3] Add integration test in session_expiration_test.dart: after session expiration, re-authenticate, verify succeeds and lands on MainFeedScreen

**Checkpoint**: User Story 3 fully functional - expired sessions detected, users redirected to login, re-authentication works seamlessly

---

## Phase 8: User Story 4 - Manual Logout (Priority: P3)

**Goal**: Authenticated student navigates to Settings, taps "Logout" button, confirms logout, returns to login screen

**Independent Test**:
1. Authenticate student (User Story 1)
2. Navigate to Settings screen
3. Tap "Logout" button
4. Verify confirmation dialog shows: "Are you sure you want to logout?"
5. Tap "Confirm"
6. Verify session terminated and login screen shows

### Settings Screen UI

- [ ] T115 [P] [US4] Create lib/features/settings/presentation/screens/settings_screen.dart with Scaffold, AppBar title "Settings"
- [ ] T116 [P] [US4] Add "Logout" button in settings_screen.dart: ElevatedButton with red background (NovaColors.error)
- [ ] T117 [P] [US4] Add navigation to SettingsScreen from MainFeedScreen: add IconButton(Icons.settings) in AppBar, navigate to '/settings' onPressed
- [ ] T118 [P] [US4] Add placeholder settings items in settings_screen.dart: ListView with "Account", "Notifications", "About" tiles (non-functional)

### Logout Confirmation Dialog

- [ ] T119 [US4] Implement onPressed for "Logout" button: show AlertDialog with title "Are you sure you want to logout?" and two actions: "Cancel" and "Confirm"
- [ ] T120 [US4] Implement "Cancel" button in confirmation dialog: Navigator.pop(context) to close dialog without logging out
- [ ] T121 [US4] Implement "Confirm" button in confirmation dialog: call ref.read(authNotifierProvider.notifier).signOut(), then Navigator.pop(context)

### Session Termination

- [ ] T122 [US4] Verify AuthNotifier.signOut() calls auth_repository.signOut() which calls Supabase.instance.client.auth.signOut()
- [ ] T123 [US4] Add navigation after logout: listen to authStateProvider, when state becomes unauthenticated, navigate to LoginScreen (remove all routes)
- [ ] T124 [US4] Verify logout only affects current device: authenticate on 2 devices, logout on device 1, verify device 2 remains authenticated
- [ ] T125 [US4] Add auth event logging: verify auth_events table logs "signout" event with user_id and timestamp

### Widget Tests

- [ ] T126 [P] [US4] Create nova/test/features/settings/presentation/screens/settings_screen_test.dart with widget test for settings screen rendering
- [ ] T127 [P] [US4] Add widget test in settings_screen_test.dart: verify "Logout" button is present
- [ ] T128 [P] [US4] Add widget test in settings_screen_test.dart: tap "Logout" button, verify confirmation dialog shows

### Integration Tests

- [ ] T129 [US4] Create nova/test_driver/integration/logout_test.dart for manual logout flow
- [ ] T130 [US4] Add integration test in logout_test.dart: authenticate user, navigate to settings, tap logout, tap confirm, verify login screen shows
- [ ] T131 [US4] Add integration test in logout_test.dart: after logout, verify accessing MainFeedScreen redirects to LoginScreen

**Checkpoint**: User Story 4 fully functional - authenticated users can manually logout, sessions terminate correctly, multi-device sessions remain independent

---

## Phase 9: Testing & Validation

**Purpose**: Comprehensive testing across all user stories and system components

### Database Function Tests

- [ ] T132 [P] Create scripts/test_database_functions.sql with test queries for all PostgreSQL functions
- [ ] T133 [P] Add test in test_database_functions.sql: SELECT public.hash_email('test@galileimoro.edu.it'), verify returns consistent SHA256 hash
- [ ] T134 [P] Add test in test_database_functions.sql: INSERT 4 magic link attempts within 15 minutes, call check_magic_link_rate_limit, verify 4th fails
- [ ] T135 [P] Add test in test_database_functions.sql: INSERT auth event, verify trigger_log_auth_events populates auth_events table
- [ ] T136 [P] Add test in test_database_functions.sql: call cleanup_old_auth_events after inserting 91-day-old event, verify old event deleted

### Performance Validation

- [ ] T137 [P] Create scripts/performance_tests.dart with Flutter performance tests
- [ ] T138 Add performance test in performance_tests.dart: measure magic link request latency (button tap to success message), assert p95 < 2 seconds
- [ ] T139 Add performance test in performance_tests.dart: measure session check latency (app launch to main feed), assert p95 < 1 second for returning users
- [ ] T140 Add performance test in performance_tests.dart: measure deep link handling latency (link click to authentication), assert < 500ms

### Rate Limiting Verification

- [ ] T141 Create scripts/test_rate_limiting.sh with curl commands to test rate limiting
- [ ] T142 Add test in test_rate_limiting.sh: send 3 magic link requests to same email within 15 minutes, verify all succeed
- [ ] T143 Add test in test_rate_limiting.sh: send 4th request immediately after 3rd, verify 429 error "Too many requests"
- [ ] T144 Add test in test_rate_limiting.sh: wait 15 minutes after 3rd request, send 4th request, verify succeeds (sliding window expired)

### Deep Linking Platform Tests

- [ ] T145 Test Android App Links on physical device: install Nova APK, click magic link in Gmail app, verify Nova opens automatically (not browser)
- [ ] T146 Test iOS Universal Links on physical device: install Nova IPA, click magic link in Mail app, verify Nova opens automatically
- [ ] T147 Test Android fallback: uninstall Nova, click magic link, verify web landing page opens with "Download Nova" button
- [ ] T148 Test iOS fallback: uninstall Nova, click magic link, verify web landing page opens with App Store button

### End-to-End User Story Tests

- [ ] T149 Run complete User Story 1 test: fresh install, email entry, magic link, authentication, verify success
- [ ] T150 Run complete User Story 2 test: authenticate, close app, reopen 5 times, verify no login prompts
- [ ] T151 Run complete User Story 3 test: authenticate, expire session, reopen app, re-authenticate, verify success
- [ ] T152 Run complete User Story 4 test: authenticate, navigate to settings, logout, verify login screen

### Security Validation

- [ ] T153 Verify email domain validation: attempt signup with @gmail.com, @yahoo.com, @test.com, verify all rejected
- [ ] T154 Verify magic link single-use: click same magic link twice, verify second click shows "already used" error
- [ ] T155 Verify magic link expiration: wait 16 minutes after requesting magic link, click link, verify "expired" error
- [ ] T156 Verify session security: inspect auth_events table, verify email_hash (not plain email) is stored
- [ ] T157 Verify RLS policies: attempt to query auth_events table as non-authenticated user, verify access denied

**Checkpoint**: All tests passing, performance goals met, security validation complete

---

## Phase 10: Polish & Documentation

**Purpose**: Cross-cutting improvements and production readiness

### Error Message Refinement

- [ ] T158 [P] Review all error messages across LoginScreen, MainFeedScreen, SettingsScreen for clarity and constitution tone compliance
- [ ] T159 [P] Add contextual help text for rate limiting error: "You can request a new magic link in X minutes" (calculate remaining time)
- [ ] T160 [P] Standardize error message styling: use NovaColors.error for error text, NovaTypography.body for message content

### Loading States Optimization

- [ ] T161 [P] Add skeleton loading UI in MainFeedScreen for initial load (replace "coming soon" placeholder)
- [ ] T162 [P] Add smooth transitions between LoginScreen and MainFeedScreen using Hero widgets for Nova logo
- [ ] T163 [P] Optimize CircularProgressIndicator colors to match NovaColors.primaryBlue

### Analytics & Monitoring

- [ ] T164 [P] Create lib/core/services/analytics_service.dart with methods: logAuthEvent, logNavigationEvent, logErrorEvent
- [ ] T165 [P] Integrate analytics_service.dart calls in AuthNotifier: log sendMagicLink, verifyMagicLink, signOut events
- [ ] T166 [P] Add performance monitoring: log magic link request latency, session check latency, deep link handling time
- [ ] T167 [P] Document analytics implementation: note that auth_events table in PostgreSQL serves as analytics database

### Developer Documentation

- [ ] T168 Update README.md with "Authentication" section explaining magic link flow, session duration, rate limits
- [ ] T169 Create docs/AUTHENTICATION.md with deep linking setup instructions (Android App Links, iOS Universal Links)
- [ ] T170 Create docs/TESTING.md with instructions for running widget tests, integration tests, database tests
- [ ] T171 Update quickstart.md with deployment checklist: assetlinks.json hosting, AASA file hosting, landing page deployment

### Production Deployment Preparation

- [ ] T172 Document assetlinks.json deployment: must be hosted at https://nova.galileimoro.edu.it/.well-known/assetlinks.json before Play Store release
- [ ] T173 Document AASA file deployment: must be hosted at https://nova.galileimoro.edu.it/.well-known/apple-app-site-association before App Store release
- [ ] T174 Generate release keystore for Android: keytool -genkey -v -keystore nova-release.keystore -alias nova -keyalg RSA -keysize 2048 -validity 10000
- [ ] T175 Update assetlinks.json with release keystore SHA256 fingerprint (replace debug fingerprint from T027)
- [ ] T176 Configure App Store Connect: add Apple Team ID to AASA file, configure bundle ID it.edu.galileimoro.nova
- [ ] T177 Run flutter build apk --release and flutter build ios --release, verify builds succeed without errors

### Final Validation

- [ ] T178 Run flutter analyze, verify zero issues (linting, formatting, unused imports)
- [ ] T179 Run all widget tests: flutter test, verify 100% pass rate
- [ ] T180 Run all integration tests: flutter drive --target=test_driver/integration/magic_link_flow_test.dart, verify pass
- [ ] T181 Run scripts/verify_supabase_config.sh, verify all checks pass (MAILER_OTP_EXP=900, email provider enabled)
- [ ] T182 Perform security audit: verify .env not committed, check for hardcoded credentials, verify HTTPS-only connections
- [ ] T183 Validate quickstart.md: follow all steps from scratch in clean environment, verify complete setup works

**Checkpoint**: Production-ready - all polish complete, documentation updated, deployment preparation done, final validation passing

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **Deep Linking (Phase 3)**: Depends on Setup completion - can run in parallel with Foundational (Phase 2)
- **Core Auth (Phase 4)**: Depends on Foundational (Phase 2) - BLOCKS all user story UI implementation
- **User Stories (Phase 5-8)**: All depend on Foundational (Phase 2) and Core Auth (Phase 4) completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (US1 → US2 → US3 → US4)
- **Testing (Phase 9)**: Depends on all desired user stories being complete
- **Polish (Phase 10)**: Depends on Testing (Phase 9) - final step before production

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) and Core Auth (Phase 4) - No dependencies on other stories ✅ MVP
- **User Story 2 (P2)**: Depends on User Story 1 (must have authentication before returning user) - Should still be independently testable
- **User Story 3 (P2)**: Depends on User Story 1 (session expiration implies previous authentication) - Reuses US1 components
- **User Story 4 (P3)**: Depends on User Story 1 and User Story 2 (must be authenticated to logout) - Adds new Settings screen

### Within Each User Story

- Tests (if included) should be written and FAIL before implementation (TDD approach)
- UI components before business logic integration
- Core implementation before edge case handling
- Widget tests before integration tests
- Story complete and independently validated before moving to next priority

### Parallel Opportunities

- **Phase 1 (Setup)**: T002, T003, T004, T005, T006, T007 can all run in parallel (different files)
- **Phase 2 (Foundational)**: T021, T022, T023 can run in parallel (different files)
- **Phase 3 (Deep Linking)**: T026-T028 (Android), T031-T032 (iOS), T043-T046 (Landing) can all run in parallel
- **Phase 4 (Core Auth)**: T048 and T055 can run in parallel (different provider files)
- **Phase 5 (US1 UI)**: T057-T063 can run in parallel (UI components in same file, but can be done by multiple devs if split into separate widgets)
- **Phase 5 (US1 Tests)**: T084-T088 (widget tests) can all run in parallel
- **Phase 6 (US2)**: T103-T105 (integration tests) can run in parallel
- **Phase 7 (US3)**: T112-T114 (integration tests) can run in parallel
- **Phase 8 (US4 UI)**: T115-T118 can run in parallel (Settings screen components)
- **Phase 8 (US4 Tests)**: T126-T128 (widget tests) can run in parallel
- **Phase 9 (Testing)**: T132-T136 (database tests), T137-T140 (performance), T141-T144 (rate limiting) can all run in parallel
- **Phase 10 (Polish)**: T158-T160 (error messages), T161-T163 (loading states), T164-T167 (analytics) can all run in parallel

---

## Parallel Example: User Story 1 - First-Time Login

```bash
# After Foundational phase complete, launch these tasks together:

# UI Components (can be built in parallel if split into separate widget files):
Task T057: "Create login_screen.dart scaffold"
Task T058: "Add NovaGlassCard widget"
Task T059: "Add email TextFormField"
Task T060: "Add Send Magic Link button"

# Widget Tests (completely independent):
Task T084: "Widget test for login screen rendering"
Task T085: "Widget test for email hint text"
Task T086: "Widget test for send button presence"
Task T087: "Widget test for invalid email validation"
Task T088: "Widget test for loading state"

# Then sequentially:
Task T067: "Implement send magic link button logic" (depends on UI complete)
Task T072: "Implement deep link handling" (depends on button logic)
Task T089-T092: "Integration tests" (depends on full implementation)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

**Goal**: Ship authentication as fast as possible

1. ✅ Complete **Phase 1: Setup** (T001-T008) - ~2-4 hours
2. ✅ Complete **Phase 2: Foundational** (T009-T025) - ~6-8 hours (CRITICAL - blocks everything)
3. ✅ Complete **Phase 3: Deep Linking** (T026-T047) - ~4-6 hours (can overlap with Phase 2)
4. ✅ Complete **Phase 4: Core Auth** (T048-T056) - ~3-4 hours
5. ✅ Complete **Phase 5: User Story 1** (T057-T092) - ~8-12 hours
6. **STOP and VALIDATE**: Test US1 independently (run T089-T092)
7. **Deploy MVP**: Ship authentication-only version, gather feedback

**Total MVP Time Estimate**: ~25-35 hours for 1 developer

### Incremental Delivery

**Goal**: Add value with each user story, maintain working product

1. ✅ **Foundation Ready** (Phases 1-4): Setup + Database + Deep Linking + Core Auth → ~15-20 hours
2. ✅ **MVP** (Phase 5 - US1): First-time login → Test independently → Deploy → ~8-12 hours
3. ✅ **Version 1.1** (Phase 6 - US2): Returning user auto-login → Test independently → Deploy → ~4-6 hours
4. ✅ **Version 1.2** (Phase 7 - US3): Session expiration handling → Test independently → Deploy → ~4-6 hours
5. ✅ **Version 1.3** (Phase 8 - US4): Manual logout → Test independently → Deploy → ~6-8 hours
6. ✅ **Version 1.4** (Phases 9-10): Testing + Polish → Deploy production-ready version → ~10-15 hours

**Each version adds value without breaking previous stories**

### Parallel Team Strategy

**Goal**: Maximize throughput with multiple developers

With 3 developers:

1. **All together**: Complete Phases 1-2 (Setup + Foundational) → ~1-2 days
2. **Once Foundational is done**:
   - **Developer A**: Phase 5 (User Story 1) → 2-3 days
   - **Developer B**: Phase 3 (Deep Linking Infrastructure) → 1-2 days, then Phase 6 (US2) → 1 day
   - **Developer C**: Phase 4 (Core Auth State) → 1 day, then Phase 7 (US3) → 1 day, then Phase 8 (US4) → 1 day
3. **All together**: Phase 9 (Testing & Validation) → 1-2 days
4. **All together**: Phase 10 (Polish & Documentation) → 1 day

**Total Parallel Time Estimate**: ~1 week (5-7 days) for 3 developers vs 2-3 weeks for 1 developer

---

## Notes

- **[P] tasks** = different files, no dependencies, safe to parallelize
- **[Story] label** = maps task to specific user story for traceability
- Each user story is independently completable and testable
- Widget tests and integration tests can be written in parallel with implementation (or before for TDD)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently before proceeding
- **MVP is User Story 1 only** - ship authentication first, iterate with US2-US4
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- **Constitution compliance**: All UI uses Nova design system (NovaColors, NovaTypography, NovaSpacing, NovaGlassCard)
- **Security critical**: Email domain validation enforced server-side (Auth Hook) AND client-side (regex)
- **Performance critical**: Magic link request <2s, returning user auth <1s, deep link handling <500ms
