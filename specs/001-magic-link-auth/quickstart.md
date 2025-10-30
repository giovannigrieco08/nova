# Developer Setup Guide: Magic Link Authentication

**Feature**: Passwordless Magic Link Authentication for Nova
**Version**: 1.0
**Date**: 2025-10-30
**Estimated Setup Time**: 2-3 hours

---

## Overview

This guide walks you through setting up Nova's magic link authentication system from scratch. You'll configure Supabase Auth, deploy database schema, set up deep linking for iOS and Android, and test the complete authentication flow locally. By the end of this guide, you'll have a working magic link authentication system ready for development and testing.

---

## Prerequisites

### Required Tools & Accounts

- [ ] **Flutter SDK 3.27+** with Dart 3.x
  - Install: [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
  - Verify: `flutter doctor -v`

- [ ] **Supabase Account** (free tier sufficient for development)
  - Sign up: [supabase.com](https://supabase.com)
  - Create new project (note: project creation takes 2-5 minutes)

- [ ] **IDE with Flutter Support**
  - VS Code with Flutter extension, or
  - Android Studio with Flutter plugin, or
  - IntelliJ IDEA with Flutter plugin

- [ ] **Android Development Setup** (for Android testing)
  - Android Studio installed
  - Android SDK installed (API 21+)
  - Android emulator or physical device

- [ ] **iOS Development Setup** (for iOS testing, macOS only)
  - Xcode 15+ installed
  - iOS Simulator or physical device
  - Apple Developer account (free tier sufficient for testing)

- [ ] **Supabase CLI** (optional but recommended)
  - Install: `npm install -g supabase`
  - Verify: `supabase --version`

- [ ] **Git** (for version control)
  - Install: [git-scm.com](https://git-scm.com)
  - Verify: `git --version`

### Knowledge Requirements

- Basic Flutter/Dart development experience
- Familiarity with command-line tools
- Understanding of asynchronous programming (Future, async/await)
- Basic knowledge of PostgreSQL (helpful but not required)

---

## Step 1: Supabase Project Setup

### 1.1 Create Supabase Project

1. **Go to** [supabase.com/dashboard](https://supabase.com/dashboard)
2. **Click** "New Project"
3. **Fill in project details**:
   - **Organization**: Select or create organization
   - **Project Name**: `nova-dev` (or your preferred name)
   - **Database Password**: Generate strong password (save it securely!)
   - **Region**: Choose closest to your location (e.g., `Europe West (Frankfurt)`)
   - **Pricing Plan**: Free tier (sufficient for development)
4. **Click** "Create new project"
5. **Wait** 2-5 minutes for project provisioning

### 1.2 Get Project Credentials

Once your project is ready:

1. **Navigate to** Settings → API
2. **Copy the following values** (you'll need them later):
   - **Project URL**: `https://your-project-ref.supabase.co`
   - **API Key (anon, public)**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
   - **Project Reference ID**: `your-project-ref` (from URL)

3. **Navigate to** Settings → Database
4. **Copy**:
   - **Connection String (URI)**: Used for Supabase CLI

### 1.3 Configure Authentication Settings

1. **Navigate to** Authentication → Providers
2. **Enable Email Provider**:
   - Toggle "Email" to ON
   - **Confirm Email**: Toggle OFF (magic links verify email automatically)
   - **Secure Email Change**: Toggle ON (recommended)

3. **Navigate to** Authentication → Email Templates
4. **Select** "Magic Link" template
5. **Customize email template** (optional):
   ```html
   <h2>Welcome to Nova!</h2>
   <p>Click the link below to sign in to your Nova account:</p>
   <p><a href="{{ .ConfirmationURL }}">Sign in to Nova</a></p>
   <p>This link expires in 15 minutes.</p>
   <p>If you didn't request this email, you can safely ignore it.</p>
   ```

6. **Save changes**

---

## Step 2: Magic Link Configuration

### 2.1 Set Magic Link Expiration (15 Minutes)

**Option A: Via Management API** (Recommended)

1. **Get Management API Token**:
   - Navigate to Settings → API
   - Find "Service Role Key" (keep this secret!)

2. **Run curl command** (replace placeholders):
   ```bash
   curl -X PATCH "https://api.supabase.com/v1/projects/YOUR_PROJECT_REF/config/auth" \
     -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "MAILER_OTP_EXP": 900
     }'
   ```

   **Expected response**: `{"MAILER_OTP_EXP": 900}`

**Option B: Via Supabase CLI** (Alternative)

```bash
supabase projects api-settings --project-ref YOUR_PROJECT_REF update \
  --mailer-otp-exp 900
```

### 2.2 Set Refresh Token Expiration (30 Days)

**Via Management API**:
```bash
curl -X PATCH "https://api.supabase.com/v1/projects/YOUR_PROJECT_REF/config/auth" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "REFRESH_TOKEN_EXPIRY": "2592000s"
  }'
```

**Verification**: Refresh token expiration is now 30 days (2,592,000 seconds)

### 2.3 Configure Rate Limiting (Optional)

**Note**: Supabase has built-in rate limiting (1 request per 60 seconds by default). Custom rate limiting will be enforced via PostgreSQL functions (deployed in Step 3).

---

## Step 3: Deploy Database Schema

### 3.1 Connect to Database

**Option A: Supabase SQL Editor** (Easiest)

1. **Navigate to** SQL Editor in Supabase Dashboard
2. **Click** "New Query"
3. **Copy** entire contents of `contracts/database.sql`
4. **Paste** into SQL Editor
5. **Click** "Run" (bottom right)
6. **Verify** no errors (check logs at bottom)

**Option B: Supabase CLI** (Advanced)

```bash
# Login to Supabase
supabase login

# Link project
supabase link --project-ref YOUR_PROJECT_REF

# Run migration
supabase db push --file specs/001-magic-link-auth/contracts/database.sql
```

**Option C: psql Command Line** (For Database Experts)

```bash
# Connect to database
psql "postgresql://postgres:[YOUR_PASSWORD]@db.your-project-ref.supabase.co:5432/postgres"

# Run migration
\i specs/001-magic-link-auth/contracts/database.sql
```

### 3.2 Verify Schema Deployment

**Run verification queries** in SQL Editor:

```sql
-- Check tables created
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('auth_events', 'magic_link_attempts');
-- Expected: 2 rows

-- Check functions created
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('hash_email', 'check_magic_link_rate_limit', 'hook_restrict_signup_by_email_domain', 'log_auth_event', 'cleanup_old_auth_events');
-- Expected: 5 rows

-- Check trigger created
SELECT trigger_name
FROM information_schema.triggers
WHERE event_object_table = 'users'
  AND trigger_name = 'trigger_log_auth_events';
-- Expected: 1 row

-- Check RLS enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('auth_events', 'magic_link_attempts');
-- Expected: Both tables with rowsecurity = true
```

**Expected output**: All queries should return expected number of rows. If any query returns 0 rows, re-run the schema deployment.

---

## Step 4: Configure Auth Hooks

### 4.1 Deploy Email Domain Validation Hook

1. **Navigate to** Authentication → Hooks in Supabase Dashboard
2. **Find** "Before User Created" hook
3. **Enable** the hook (toggle ON)
4. **Hook Type**: Select "Postgres Function"
5. **Schema**: `public`
6. **Function**: `hook_restrict_signup_by_email_domain`
7. **Save** configuration

### 4.2 Test Email Domain Validation

**Test 1: Valid Email** (should succeed)
```bash
curl -X POST "https://YOUR_PROJECT_REF.supabase.co/auth/v1/otp" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@galileimoro.edu.it"
  }'
```

**Expected response**: `{"success": true}` (or empty response with 200 status)

**Test 2: Invalid Email** (should fail)
```bash
curl -X POST "https://YOUR_PROJECT_REF.supabase.co/auth/v1/otp" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@gmail.com"
  }'
```

**Expected response**: `{"error": "Email address cannot be used as it is not authorized"}` (with 403 status)

---

## Step 5: Flutter Project Setup

### 5.1 Add Dependencies

**Edit** `pubspec.yaml` and add the following dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Supabase client
  supabase_flutter: ^2.8.0

  # State management
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

  # Deep linking
  app_links: ^6.3.2

  # Secure storage (included with supabase_flutter)
  # flutter_secure_storage: ^9.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter

  # Code generation
  build_runner: ^2.4.13
  riverpod_generator: ^2.6.2
```

**Run**:
```bash
flutter pub get
```

### 5.2 Initialize Supabase

**Create** `lib/core/config/supabase_config.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_PROJECT_URL', // Replace with your URL for development
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_ANON_KEY', // Replace with your key for development
  );

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce, // Use PKCE flow for mobile
        autoRefreshToken: true,
        persistSession: true,
      ),
    );
  }
}
```

**Update** `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Nova - Magic Link Auth Setup'),
        ),
      ),
    );
  }
}
```

**Run app** to verify Supabase initialization:
```bash
flutter run
```

**Expected**: App launches without errors. Check console for Supabase initialization logs.

---

## Step 6: Deep Linking Configuration

### 6.1 Android Configuration

#### 6.1.1 Update AndroidManifest.xml

**File**: `android/app/src/main/AndroidManifest.xml`

**Add** deep link intent filters inside `<activity>` tag:

```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    android:exported="true">

    <!-- Existing launcher intent -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>

    <!-- ADD THIS: App Links intent filter -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />

        <data
            android:scheme="https"
            android:host="nova.galileimoro.edu.it"
            android:pathPrefix="/auth" />
    </intent-filter>

    <!-- ADD THIS: Custom URL scheme fallback (for testing) -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />

        <data
            android:scheme="nova"
            android:host="auth" />
    </intent-filter>

</activity>
```

#### 6.1.2 Generate SHA256 Certificate Fingerprint

**For Debug Keystore**:
```bash
# macOS/Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA256

# Windows
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | findstr SHA256
```

**Copy the SHA256 fingerprint** (format: `14:6D:E9:83:C5:73:06:50:...`)

#### 6.1.3 Create assetlinks.json

**File**: `.well-known/assetlinks.json` (in your web hosting root)

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "it.edu.galileimoro.nova",
      "sha256_cert_fingerprints": [
        "PASTE_YOUR_SHA256_FINGERPRINT_HERE"
      ]
    }
  }
]
```

**Deploy** this file to `https://nova.galileimoro.edu.it/.well-known/assetlinks.json`

**Verify hosting**:
```bash
curl -I https://nova.galileimoro.edu.it/.well-known/assetlinks.json
# Expected: Content-Type: application/json (status 200)
```

### 6.2 iOS Configuration

#### 6.2.1 Update Info.plist

**File**: `ios/Runner/Info.plist`

**Add** inside `<dict>` tag:

```xml
<key>FlutterDeepLinkingEnabled</key>
<true/>
```

#### 6.2.2 Configure Associated Domains in Xcode

1. **Open** `ios/Runner.xcworkspace` in Xcode
2. **Select** Runner target → Signing & Capabilities tab
3. **Click** "+ Capability" → "Associated Domains"
4. **Add** domain: `applinks:nova.galileimoro.edu.it`

#### 6.2.3 Find Your Apple Team ID

**Method 1**: Xcode
- Runner target → General tab → Team dropdown
- Team ID shown in parentheses (e.g., "John Doe (A1B2C3D4E5)")

**Method 2**: Apple Developer Portal
- Go to [developer.apple.com](https://developer.apple.com)
- Sign in → Membership → Team ID displayed at top

#### 6.2.4 Create AASA File

**File**: `.well-known/apple-app-site-association` (in your web hosting root)

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": [
          "YOUR_TEAM_ID.it.edu.galileimoro.nova"
        ],
        "components": [
          {
            "/": "/auth/*",
            "comment": "Matches all paths under /auth/"
          }
        ]
      }
    ]
  }
}
```

**Replace** `YOUR_TEAM_ID` with your actual Team ID (e.g., `A1B2C3D4E5`)

**Deploy** this file to `https://nova.galileimoro.edu.it/.well-known/apple-app-site-association`

**Verify hosting**:
```bash
curl -I https://nova.galileimoro.edu.it/.well-known/apple-app-site-association
# Expected: Content-Type: application/json (status 200)
```

---

## Step 7: Implement Deep Link Service

### 7.1 Create Deep Link Service

**File**: `lib/shared/services/deep_link_service.dart`

```dart
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> initialize() async {
    // Handle initial link (cold start)
    await _handleInitialLink();

    // Listen to incoming links (warm start)
    _startListening();
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialAppLink();
      if (uri != null) {
        await _handleDeepLink(uri);
      }
    } catch (e) {
      print('Error handling initial link: $e');
    }
  }

  void _startListening() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (err) => print('Deep link error: $err'),
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    print('Deep link received: $uri');

    if (uri.path == '/auth/confirm' || uri.path == '/auth/verify') {
      final tokenHash = uri.queryParameters['token_hash'];
      final type = uri.queryParameters['type'];

      if (tokenHash != null && type == 'email') {
        try {
          await Supabase.instance.client.auth.verifyOTP(
            tokenHash: tokenHash,
            type: OtpType.magiclink,
          );
          print('Magic link verified successfully');
        } on AuthException catch (e) {
          print('Magic link verification failed: ${e.message}');
        }
      }
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
```

### 7.2 Initialize Deep Link Service in main()

**Update** `lib/main.dart`:

```dart
import 'shared/services/deep_link_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize deep link service
  final deepLinkService = DeepLinkService();
  await deepLinkService.initialize();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
```

---

## Step 8: Environment Variables (Secure Credentials)

### 8.1 Create .env File (Development)

**Create** `.env` file in project root:

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Add** `.env` to `.gitignore`:

```gitignore
# Supabase credentials
.env
```

### 8.2 Load Environment Variables (Optional)

**Add** `flutter_dotenv` package:

```yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

**Update** `lib/core/config/supabase_config.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;

  static Future<void> initialize() async {
    await dotenv.load(); // Load .env file
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
        persistSession: true,
      ),
    );
  }
}
```

**Add** `.env` to `pubspec.yaml` assets:

```yaml
flutter:
  assets:
    - .env
```

---

## Step 9: Testing Magic Links Locally

### 9.1 Test with Custom URL Scheme (Quick Test)

**Android**:
```bash
# Send deep link to running app/emulator
adb shell am start -W -a android.intent.action.VIEW \
  -d "nova://auth/verify?token_hash=TEST123&type=email"
```

**iOS Simulator**:
```bash
xcrun simctl openurl booted "nova://auth/verify?token_hash=TEST123&type=email"
```

**Expected**: App should receive deep link and log it in console.

### 9.2 Test Full Magic Link Flow

**Step 1: Request Magic Link via Flutter**

**Create** test button in your app:

```dart
ElevatedButton(
  onPressed: () async {
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: 'your-test-email@galileimoro.edu.it',
      );
      print('Magic link sent! Check your email.');
    } on AuthException catch (e) {
      print('Error: ${e.message}');
    }
  },
  child: const Text('Send Magic Link'),
)
```

**Step 2: Check Email**

- Open email inbox for `your-test-email@galileimoro.edu.it`
- Find "Magic Link" email from Supabase
- Note: Email may take 5-30 seconds to arrive

**Step 3: Extract Token from Email**

- Right-click magic link in email → "Copy Link Address"
- Paste URL (format: `https://nova.galileimoro.edu.it/auth/confirm?token_hash=...&type=email`)
- Extract `token_hash` value

**Step 4: Test Deep Link with Real Token**

**Android**:
```bash
adb shell am start -W -a android.intent.action.VIEW \
  -d "nova://auth/verify?token_hash=PASTE_REAL_TOKEN_HERE&type=email"
```

**iOS Simulator**:
```bash
xcrun simctl openurl booted "nova://auth/verify?token_hash=PASTE_REAL_TOKEN_HERE&type=email"
```

**Expected**: App authenticates user and logs "Magic link verified successfully".

### 9.3 Test with ngrok (HTTPS Testing)

**Rationale**: App Links and Universal Links require HTTPS. Use ngrok to expose your local web server for testing.

**Install ngrok**:
```bash
npm install -g ngrok
```

**Start ngrok tunnel**:
```bash
ngrok http 3000
```

**Expected output**:
```
Forwarding  https://abc123.ngrok.io -> http://localhost:3000
```

**Update email template** in Supabase to use ngrok URL:
```html
<a href="{{ .ConfirmationURL }}">Sign in to Nova</a>
```

**Note**: This is for testing only. Production should use your actual domain (`nova.galileimoro.edu.it`).

---

## Step 10: Running Tests

### 10.1 Unit Tests

**Create** `test/features/auth/email_validator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/auth/domain/validators/email_validator.dart';

void main() {
  group('EmailValidator', () {
    test('validates correct @galileimoro.edu.it email', () {
      expect(EmailValidator.validateEmail('test@galileimoro.edu.it'), isNull);
    });

    test('rejects invalid domain', () {
      expect(
        EmailValidator.validateEmail('test@gmail.com'),
        contains('school email'),
      );
    });

    test('normalizes email to lowercase', () {
      expect(
        EmailValidator.normalizeEmail('Test@GALILEIMORO.EDU.IT'),
        equals('test@galileimoro.edu.it'),
      );
    });
  });
}
```

**Run tests**:
```bash
flutter test
```

### 10.2 Integration Tests

**Create** `integration_test/auth_flow_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nova/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Complete magic link auth flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Test login screen renders
    expect(find.text('Welcome to Nova'), findsOneWidget);

    // Test email input
    await tester.enterText(find.byType(TextField), 'test@galileimoro.edu.it');
    await tester.tap(find.text('Send Magic Link'));
    await tester.pumpAndSettle();

    // Test success message
    expect(find.text('Check your email'), findsOneWidget);
  });
}
```

**Run integration tests**:
```bash
flutter test integration_test/auth_flow_test.dart
```

---

## Step 11: Troubleshooting

### Common Issues

#### Issue 1: Supabase initialization fails

**Error**: `Supabase has not been initialized`

**Solution**:
- Verify `SupabaseConfig.initialize()` is called in `main()` before `runApp()`
- Check SUPABASE_URL and SUPABASE_ANON_KEY are correct
- Ensure `WidgetsFlutterBinding.ensureInitialized()` is called first

#### Issue 2: Email not delivered

**Error**: No magic link email received

**Solution**:
- Check Supabase email logs: Authentication → Logs
- Verify email provider is enabled: Authentication → Providers → Email
- Check spam folder in email inbox
- Try different email address
- Wait 30-60 seconds (email delivery can be slow)

#### Issue 3: Deep link not working (Android)

**Error**: Link opens in browser instead of app

**Solution**:
- Verify `assetlinks.json` is hosted at correct URL with HTTPS
- Check SHA256 fingerprint matches your keystore
- Ensure `android:autoVerify="true"` in AndroidManifest.xml
- Clear app verification cache:
  ```bash
  adb shell pm clear com.android.vending
  adb uninstall it.edu.galileimoro.nova
  flutter run
  ```

#### Issue 4: Deep link not working (iOS)

**Error**: Link opens in Safari instead of app

**Solution**:
- Verify AASA file is hosted at correct URL with HTTPS
- Check Team ID and Bundle ID are correct in AASA file
- Ensure Associated Domains configured in Xcode
- Test on physical device (Simulator may not support Universal Links fully)
- Validate AASA file: [Apple AASA Validator](https://search.developer.apple.com/appsearch-validation-tool/)

#### Issue 5: Session not persisting

**Error**: User logged out after app restart

**Solution**:
- Verify `persistSession: true` in FlutterAuthClientOptions
- Check secure storage permissions:
  - iOS: Keychain access enabled
  - Android: EncryptedSharedPreferences working
- Test on physical device (emulator storage may be cleared on restart)

#### Issue 6: Rate limiting not enforced

**Error**: Can request unlimited magic links

**Solution**:
- Verify `check_magic_link_rate_limit()` function is deployed
- Check rate limiting hook is configured (if using hook-based approach)
- Verify `magic_link_attempts` table exists and has data
- Test with query:
  ```sql
  SELECT * FROM public.magic_link_attempts
  WHERE email = 'test@galileimoro.edu.it'
  ORDER BY requested_at DESC;
  ```

---

## Next Steps

Congratulations! You now have a working magic link authentication system. Here's what to do next:

1. **Implement UI Components**:
   - Create login screen with email input
   - Add loading states and error handling
   - Design magic link sent confirmation screen

2. **Build Authentication State Management**:
   - Create Riverpod AsyncNotifier provider
   - Implement auth state gate for routing
   - Add logout functionality

3. **Deploy Landing Page**:
   - Create static landing page for app-not-installed scenario
   - Deploy to Vercel or Netlify
   - Test fallback flow

4. **Add Analytics**:
   - Track authentication success/failure rates
   - Monitor deep link open rates
   - Log rate limiting events

5. **Prepare for Production**:
   - Replace debug credentials with environment variables
   - Update SHA256 fingerprint to release keystore
   - Configure production domain (`nova.galileimoro.edu.it`)
   - Set up monitoring and alerting

---

## Resources

### Documentation
- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Flutter Deep Linking Guide](https://docs.flutter.dev/ui/navigation/deep-linking)
- [Riverpod Documentation](https://riverpod.dev)

### Tools
- [Supabase Dashboard](https://supabase.com/dashboard)
- [Android App Links Tester](https://developers.google.com/digital-asset-links/tools/generator)
- [Apple AASA Validator](https://search.developer.apple.com/appsearch-validation-tool/)

### Support
- [Supabase Discord](https://discord.supabase.com)
- [Flutter Discord](https://discord.gg/flutter)
- [Nova Development Team](mailto:dev@galileimoro.edu.it)

---

**Document Version**: 1.0
**Last Updated**: 2025-10-30
**Estimated Setup Time**: 2-3 hours
**Status**: Production Ready
