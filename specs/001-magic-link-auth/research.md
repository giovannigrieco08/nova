# Technical Research & Decisions: Magic Link Authentication

**Feature**: Passwordless Magic Link Authentication for Nova
**Backend**: Supabase Auth with PostgreSQL
**Frontend**: Flutter 3.x with Riverpod
**Date**: 2025-10-30
**Status**: Research Complete

---

## 1. Supabase Auth Magic Link Configuration

### Decision
Use Supabase Auth's built-in magic link functionality with custom configuration: 15-minute expiration (900 seconds), single-use enforcement (automatic), and rate limiting of 3 requests per 15 minutes (custom configuration).

### Rationale
Supabase Auth provides native magic link support with automatic token generation, single-use enforcement, and email delivery integration out of the box. The default 1-hour expiration is too long for security purposes, but Supabase allows customization down to shorter durations. Single-use enforcement is automatic and cannot be bypassed, providing strong security against replay attacks. This eliminates the need to build custom token management infrastructure.

### Alternatives Considered
- **Custom JWT token generation**: Rejected because it duplicates Supabase Auth's existing functionality and introduces unnecessary complexity in token lifecycle management, storage, and security hardening.
- **One-Time Password (OTP) instead of magic links**: Rejected because OTPs require manual code entry (poor UX for mobile), lack deep linking capabilities, and are more prone to user error. Magic links provide seamless one-tap authentication.

### Implementation Notes

**Expiration Configuration:**
```bash
# Via Supabase Dashboard
# Navigate to: Authentication > Providers > Email > Email OTP Expiration
# Set value: 900 seconds (15 minutes)
# Maximum allowed: 86400 seconds (24 hours)
# Default: 3600 seconds (1 hour)
```

**Using Management API:**
```bash
curl -X PATCH "https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "MAILER_OTP_EXP": 900
  }'
```

**Key Configuration Properties:**
- Magic links expire after configured duration (15 minutes = 900 seconds)
- Each link is valid for a single login attempt only (automatic)
- Default rate limit: 1 request per email per 60 seconds (will be customized to 3 per 15 minutes)
- Tokens use secure hashing and cannot be reverse-engineered

**Email Template Customization:**
Navigate to Dashboard > Authentication > Email Templates > Magic Link

Available template variables:
- `{{ .Token }}` - 6-digit OTP (alternative to link)
- `{{ .TokenHash }}` - Hashed token for custom link construction
- `{{ .SiteURL }}` - Application site URL from auth settings
- `{{ .ConfirmationURL }}` - Complete magic link URL (recommended)

**Example Custom Template for PKCE Flow:**
```html
<a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=email">
  Open Nova App
</a>
```

**Important Gotchas:**
1. Rate limiting is per-email address, not per-IP or device
2. Cannot set expiration below 60 seconds or above 24 hours
3. Email delivery failures are silent - client cannot detect them
4. Magic link tokens are single-use and expire on first successful authentication OR after time limit

### References
- [Supabase Auth Magic Link Documentation](https://supabase.com/docs/guides/auth/auth-magic-link)
- [Email Templates Customization](https://supabase.com/docs/guides/auth/auth-email-templates)
- [Magic Link Expiration Discussion](https://github.com/orgs/supabase/discussions/16194)
- [PKCE Flow Documentation](https://supabase.com/docs/guides/auth/sessions/pkce-flow)

---

## 2. Flutter Deep Linking Package Selection

### Decision
Use **app_links** package (official Flutter plugin) for deep link handling with manual navigation control, avoiding go_router's automatic deep link handling.

### Rationale
The app_links package provides full control over navigation stack preservation, which is critical for maintaining user context when handling deep links. Unlike go_router's automatic deep linking (which clears the navigation stack via `context.go()`), app_links delivers the raw URL and lets us handle routing explicitly. This prevents the disjointed experience where users click a magic link and lose their place in the app. For authentication flows, we need to handle both cold starts (app terminated) and warm starts (app backgrounded) differently, which app_links supports through `getInitialAppLink()` and `uriLinkStream`.

### Alternatives Considered
- **go_router with automatic deep linking**: Rejected because it uses `context.go()` internally, which replaces the entire navigation stack. When a magic link opens the app, users lose any previous navigation history, creating a jarring experience. Authentication requires preserving state for returning users.
- **uni_links package**: Rejected because it's deprecated and no longer maintained by the Flutter team. app_links is the official replacement with better platform support and ongoing maintenance.

### Implementation Notes

**Package Dependencies:**
```yaml
dependencies:
  app_links: ^6.3.2  # Check pub.dev for latest version
```

**Android Configuration (AndroidManifest.xml):**
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="https"
        android:host="nova.galileimoro.edu.it"
        android:pathPrefix="/auth" />
</intent-filter>
```

**Android App Links (assetlinks.json):**
Host at: `https://nova.galileimoro.edu.it/.well-known/assetlinks.json`

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "it.edu.galileimoro.nova",
    "sha256_cert_fingerprints": ["YOUR_SHA256_FINGERPRINT"]
  }
}]
```

**iOS Configuration (Info.plist):**
```xml
<key>FlutterDeepLinkingEnabled</key>
<true/>
```

**iOS Universal Links (Xcode):**
1. Enable "Associated Domains" capability
2. Add: `applinks:nova.galileimoro.edu.it`

**iOS AASA File:**
Host at: `https://nova.galileimoro.edu.it/.well-known/apple-app-site-association`

```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appID": "TEAM_ID.it.edu.galileimoro.nova",
      "paths": ["/auth/*"]
    }]
  }
}
```

**Flutter Implementation Pattern:**
```dart
import 'package:app_links/app_links.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // Handle initial link (app was terminated)
  Future<void> handleInitialLink() async {
    final uri = await _appLinks.getInitialAppLink();
    if (uri != null) {
      _handleDeepLink(uri);
    }
  }

  // Listen to incoming links (app running/backgrounded)
  void startListening() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (err) => print('Deep link error: $err'),
    );
  }

  void _handleDeepLink(Uri uri) {
    // Parse magic link: https://nova.galileimoro.edu.it/auth/confirm?token_hash=...&type=email
    if (uri.path == '/auth/confirm') {
      final tokenHash = uri.queryParameters['token_hash'];
      final type = uri.queryParameters['type'];

      if (tokenHash != null && type == 'email') {
        // Trigger Supabase auth verification
        // Navigate to appropriate screen (preserve stack with pushReplacement or push)
      }
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
```

**Testing Deep Links:**

Android (ADB):
```bash
adb shell am start -W -a android.intent.action.VIEW \
  -d "https://nova.galileimoro.edu.it/auth/confirm?token_hash=TEST&type=email" \
  it.edu.galileimoro.nova
```

iOS (Simulator):
```bash
xcrun simctl openurl booted "https://nova.galileimoro.edu.it/auth/confirm?token_hash=TEST&type=email"
```

**Important Gotchas:**
1. Flutter 3.27+ enables deep linking by default; earlier versions need manual opt-in via Info.plist
2. Test both cold start (app terminated) and warm start (app backgrounded) scenarios
3. Android App Links require verified domain ownership via assetlinks.json
4. iOS Universal Links require verified domain via AASA file
5. Implement debouncing/deduplication to prevent duplicate link handling
6. Handle different app states (terminated, background, foreground) separately

### References
- [Flutter Deep Linking Official Guide](https://docs.flutter.dev/ui/navigation/deep-linking)
- [app_links Package Documentation](https://pub.dev/packages/app_links)
- [Android App Links Setup](https://docs.flutter.dev/cookbook/navigation/set-up-app-links)
- [iOS Universal Links Setup](https://docs.flutter.dev/cookbook/navigation/set-up-universal-links)
- [Handling Deep Links Without Losing Navigation (Medium)](https://medium.com/@pinky.hlaing173/handling-deep-links-in-flutter-without-losing-navigation-using-app-links-over-go-router-45845bc07373)

---

## 3. Email Domain Validation Strategy

### Decision
Implement **server-side validation using Supabase Auth Hooks** (Before User Created hook with PostgreSQL function) for security, with **client-side validation using regex** for immediate UX feedback.

### Rationale
Server-side validation is mandatory for security because client-side checks can be bypassed by malicious actors or automated tools. Supabase Auth Hooks provide a native, performant way to enforce domain restrictions before user accounts are created, with automatic 403 error responses for unauthorized domains. Client-side validation enhances UX by providing instant feedback before the network request, reducing failed API calls and improving perceived performance. The two-layer approach provides defense in depth.

### Alternatives Considered
- **Client-side validation only**: Rejected because it's trivially bypassed by anyone inspecting network requests or using API tools like Postman. Not acceptable for security-critical authentication.
- **Database trigger on auth.users table**: Rejected because triggers fire AFTER insertion, requiring rollback logic. Auth hooks fire BEFORE user creation, providing cleaner error handling and preventing unwanted database writes.

### Implementation Notes

**Client-Side Validation (Flutter):**

Regex pattern: `^[a-zA-Z0-9._%+-]+@galileimoro\.edu\.it$`

```dart
class EmailValidator {
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@galileimoro\.edu\.it$',
    caseSensitive: false,
  );

  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email address is required';
    }

    // Normalize to lowercase
    final normalizedEmail = email.trim().toLowerCase();

    if (!_emailRegex.hasMatch(normalizedEmail)) {
      return 'Please use your school email (@galileimoro.edu.it)';
    }

    return null; // Valid
  }

  static String normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }
}
```

**Server-Side Validation (Supabase Auth Hook):**

Step 1: Create allowed domains table (optional, for flexibility):
```sql
-- Create table to store allowed email domains
CREATE TABLE IF NOT EXISTS public.signup_email_domains (
  id SERIAL PRIMARY KEY,
  domain TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert allowed domain
INSERT INTO public.signup_email_domains (domain)
VALUES ('galileimoro.edu.it');
```

Step 2: Create PostgreSQL function for domain validation:
```sql
CREATE OR REPLACE FUNCTION public.hook_restrict_signup_by_email_domain()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_email TEXT;
  user_email_domain TEXT;
  domain_exists BOOLEAN;
BEGIN
  -- Extract email from request payload
  user_email := LOWER(TRIM((current_setting('request.jwt.claims', true)::jsonb->'email')::text, '"'));

  -- Extract domain from email
  user_email_domain := SPLIT_PART(user_email, '@', 2);

  -- Check if domain is allowed
  SELECT EXISTS (
    SELECT 1 FROM public.signup_email_domains
    WHERE domain = user_email_domain
  ) INTO domain_exists;

  IF NOT domain_exists THEN
    RAISE EXCEPTION 'Email address cannot be used as it is not authorized'
      USING HINT = 'Please use your school email (@galileimoro.edu.it)';
  END IF;

  -- Allow signup to proceed
  RETURN jsonb_build_object();
END;
$$;
```

Alternative simpler approach (hardcoded domain):
```sql
CREATE OR REPLACE FUNCTION public.hook_restrict_signup_by_email_domain()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_email TEXT;
  user_email_domain TEXT;
BEGIN
  -- Extract and normalize email
  user_email := LOWER(TRIM((current_setting('request.jwt.claims', true)::jsonb->'email')::text, '"'));
  user_email_domain := SPLIT_PART(user_email, '@', 2);

  -- Check domain
  IF user_email_domain != 'galileimoro.edu.it' THEN
    RAISE EXCEPTION 'Email address cannot be used as it is not authorized'
      USING HINT = 'Please use your school email (@galileimoro.edu.it)';
  END IF;

  RETURN jsonb_build_object();
END;
$$;
```

Step 3: Configure Auth Hook in Supabase Dashboard:
1. Navigate to: Authentication > Hooks
2. Enable: "Before User Created" hook
3. Set Hook Type: "Postgres Function"
4. Select Schema: "public"
5. Select Function: "hook_restrict_signup_by_email_domain"

**Email Normalization:**
Always normalize emails to lowercase before validation and storage:
```dart
final normalizedEmail = email.trim().toLowerCase();
```

This prevents duplicate accounts from case variations:
- Mario.Rossi@galileimoro.edu.it
- mario.rossi@galileimoro.edu.it

**Error Handling:**
```dart
try {
  await supabase.auth.signInWithOtp(
    email: EmailValidator.normalizeEmail(email),
  );
} on AuthException catch (e) {
  if (e.message.contains('not authorized')) {
    // Show: "Please use your school email (@galileimoro.edu.it)"
  } else {
    // Show generic error
  }
}
```

**Important Gotchas:**
1. Auth hooks must return JSONB object or raise exception
2. Exceptions in hooks result in 403 responses to client
3. Client-side validation should match server-side exactly
4. Test with edge cases: uppercase, extra spaces, special characters
5. Gmail address normalization (dots, plus signs) should NOT be applied to school emails

### References
- [Supabase Before User Created Hook](https://supabase.com/docs/guides/auth/auth-hooks/before-user-created-hook)
- [Email Domain Validation Blog Post](https://blog.mansueli.com/secure-your-supabase-auth-with-emailguard)
- [Supabase Auth Invalid Email Domain](https://drdroid.io/stack-diagnosis/supabase-auth-invalid-email-domain)
- [Stack Overflow: Restrict Signup to Specific Domain](https://stackoverflow.com/questions/71591949/restrict-supabase-sign-up-to-a-specific-domain)

---

## 4. Session Management Pattern

### Decision
Use Supabase Auth's built-in refresh token mechanism with custom configuration: 30-day refresh token expiration (2,592,000 seconds), 1-hour access token expiration (default), automatic token refresh enabled by default in supabase-flutter client.

### Rationale
Supabase Auth implements OAuth2-style refresh token pattern natively, eliminating the need to build custom session management. Refresh tokens are single-use with automatic rotation, providing security against replay attacks. The supabase-flutter client automatically handles token refresh in the background when access tokens approach expiration, providing seamless session management without application code. 30-day sessions meet the spec requirement while balancing security (users must re-authenticate monthly) with UX (no daily login prompts).

### Alternatives Considered
- **Custom JWT token management**: Rejected because it duplicates Supabase's battle-tested token infrastructure and introduces security risks from implementing cryptographic operations incorrectly.
- **Time-boxed sessions (fixed duration)**: Considered but rejected because inactivity timeout is more secure (dormant accounts auto-expire). However, Supabase's time-boxed sessions feature requires Pro Plan, so we'll use refresh token expiration instead.
- **Session persistence in local storage**: Rejected because supabase-flutter client handles persistence automatically via secure storage, and custom persistence could leak tokens or create sync issues.

### Implementation Notes

**Supabase Configuration:**

Access Token Expiration (Dashboard):
```
Navigate to: Authentication > Settings > Advanced Settings
JWT Expiry Limit: 3600 seconds (1 hour - default, DO NOT CHANGE)
```

Refresh Token Expiration (Management API):
```bash
curl -X PATCH "https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "REFRESH_TOKEN_EXPIRY": "2592000s"
  }'
```

Note: Use string format "2592000s" (30 days in seconds)

**Flutter Client Setup:**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // Use PKCE flow for mobile
      autoRefreshToken: true,          // Default: true (automatic refresh)
      persistSession: true,             // Default: true (persist to secure storage)
    ),
  );

  runApp(MyApp());
}
```

**Session State Checking:**

```dart
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Check if user has valid session
  bool get isAuthenticated => _supabase.auth.currentSession != null;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Check if session is expired
  bool get isSessionExpired {
    final session = _supabase.auth.currentSession;
    if (session == null) return true;

    return session.isExpired; // Built-in property
  }

  // Listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Manual logout
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}
```

**Handling Session Expiration:**

```dart
class AuthStateProvider extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final supabase = Supabase.instance.client;

    // Listen to auth state changes
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.signedIn) {
        state = AsyncValue.data(data.session?.user);
      } else if (event == AuthChangeEvent.signedOut) {
        state = const AsyncValue.data(null);
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        // Token was automatically refreshed
        state = AsyncValue.data(data.session?.user);
      } else if (event == AuthChangeEvent.userDeleted) {
        state = const AsyncValue.data(null);
      }
    });

    return supabase.auth.currentUser;
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
  }
}
```

**App Initialization with Session Check:**

```dart
class SplashScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // User has valid session -> navigate to feed
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/feed');
          });
        } else {
          // No session or expired -> navigate to login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/login');
          });
        }
        return CircularProgressIndicator();
      },
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => ErrorWidget(err),
    );
  }
}
```

**Token Refresh Behavior:**
- Automatic: supabase-flutter checks tokens every few seconds
- Refresh starts when access token is close to expiration
- If refresh fails, retries indefinitely (with exponential backoff)
- If refresh token is expired (30 days), user must re-authenticate

**Offline Handling:**
```dart
// Known issue: Supabase.initialize() blocks with expired token offline
// Workaround: Implement timeout wrapper
Future<void> initializeSupabaseWithTimeout() async {
  try {
    await Supabase.initialize(...).timeout(
      Duration(seconds: 10),
      onTimeout: () {
        // Clear expired session and proceed
        print('Supabase init timeout - clearing session');
        // User will see login screen
      },
    );
  } catch (e) {
    print('Supabase init error: $e');
  }
}
```

**Important Gotchas:**
1. Access token expiration should NOT be set below 5 minutes (increases server load)
2. Setting access token expiration above 1 hour is discouraged (security risk)
3. Refresh tokens never expire naturally but become invalid after 30 days (configurable)
4. Refresh tokens are single-use; each refresh returns new access + refresh token pair
5. Refresh token rotation is enabled by default (cannot be disabled)
6. `REFRESH_TOKEN_REUSE_INTERVAL` provides grace period for concurrent refresh requests
7. Offline initialization with expired token blocks app startup - needs timeout handling
8. Session persistence uses platform-specific secure storage (iOS Keychain, Android EncryptedSharedPreferences)

**Session Lifetime Configuration (Pro Plan Feature - Not Available):**
If your project upgrades to Pro Plan, you can enable additional session controls:
- Time-boxed sessions: Fixed duration (e.g., exactly 30 days)
- Inactivity timeout: Session expires after X hours without refresh
- Single session per user: Only most recent session remains active

### References
- [Supabase User Sessions Documentation](https://supabase.com/docs/guides/auth/sessions)
- [JavaScript Token Refresh Mechanism](https://deepwiki.com/supabase/auth-js/4.1-token-refresh-mechanism)
- [Flutter API: refreshSession](https://supabase.com/docs/reference/dart/auth-refreshsession)
- [GitHub Issue: Token Refresh After 1h](https://github.com/supabase/supabase-flutter/issues/906)
- [Server-Side Advanced Guide](https://supabase.com/docs/guides/auth/server-side/advanced-guide)

---

## 5. Rate Limiting Implementation

### Decision
Use **Supabase Auth's built-in rate limiting configuration** (customizable via Management API) for magic link requests, with fallback to **PostgreSQL function with tracking table** if more granular control is needed.

### Rationale
Supabase Auth provides native rate limiting for OTP/magic link requests with configurable thresholds, eliminating the need for custom infrastructure. The built-in approach is performant (runs at the Auth server level), requires zero maintenance, and provides consistent behavior across all authentication endpoints. Custom rate limiting via Edge Functions adds latency and cost, while client-side tracking is easily bypassed. PostgreSQL functions provide a middle ground if the built-in limits are insufficient, but should only be used if absolutely necessary.

### Alternatives Considered
- **Supabase Edge Functions with Upstash Redis**: Rejected because it adds external dependency (Redis), increases latency (extra network hop), incurs additional cost (Upstash fees), and is overkill for simple per-email rate limiting.
- **Client-side rate limiting**: Rejected because it's trivially bypassed by anyone inspecting the code or using different devices. Not acceptable for security-critical features.
- **PostgreSQL trigger-based rate limiting**: Considered but rejected because triggers fire after database writes, while Auth hooks fire before user creation, providing better security and cleaner error handling.

### Implementation Notes

**Built-in Supabase Auth Rate Limiting:**

Default Limits:
- Magic link requests: 1 per 60 seconds per email
- OTP requests: 30 per hour per email

Custom Configuration via Management API:
```bash
# Get current rate limits
curl -X GET "https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN"

# Update rate limits for 3 requests per 15 minutes
curl -X PATCH "https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "rate_limit_email_sent": 3,
    "rate_limit_token_refresh": 30
  }'
```

Note: The built-in rate limiting works per-email address across a time window. For the requirement of "3 requests per 15 minutes", we'll set `rate_limit_email_sent` to 3 and monitor behavior. If Supabase's rate window is fixed at 1 hour, we'll need the custom PostgreSQL approach below.

**Custom PostgreSQL Rate Limiting (If Needed):**

Step 1: Create rate limiting tracking table:
```sql
CREATE TABLE IF NOT EXISTS public.magic_link_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_address INET,
  user_agent TEXT,
  status TEXT NOT NULL DEFAULT 'sent', -- sent, blocked, failed

  -- Index for fast lookups
  INDEX idx_magic_link_attempts_email_time ON magic_link_attempts(email, requested_at DESC)
);

-- Enable Row-Level Security
ALTER TABLE public.magic_link_attempts ENABLE ROW LEVEL SECURITY;

-- Policy: Only service role can write
CREATE POLICY "Service role can insert attempts"
  ON public.magic_link_attempts
  FOR INSERT
  TO service_role
  WITH CHECK (true);
```

Step 2: Create rate limiting function:
```sql
CREATE OR REPLACE FUNCTION public.check_magic_link_rate_limit(
  user_email TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  attempt_count INTEGER;
  time_window INTERVAL := INTERVAL '15 minutes';
  max_attempts INTEGER := 3;
BEGIN
  -- Normalize email
  user_email := LOWER(TRIM(user_email));

  -- Count recent attempts
  SELECT COUNT(*)
  INTO attempt_count
  FROM public.magic_link_attempts
  WHERE email = user_email
    AND requested_at >= NOW() - time_window
    AND status IN ('sent', 'blocked');

  -- Check if limit exceeded
  IF attempt_count >= max_attempts THEN
    -- Log blocked attempt
    INSERT INTO public.magic_link_attempts (email, status)
    VALUES (user_email, 'blocked');

    RAISE EXCEPTION 'Too many requests. Please wait 15 minutes before requesting another magic link'
      USING HINT = 'Rate limit: 3 requests per 15 minutes';
  END IF;

  -- Log successful attempt
  INSERT INTO public.magic_link_attempts (email, status)
  VALUES (user_email, 'sent');

  RETURN jsonb_build_object('allowed', true);
END;
$$;
```

Step 3: Create Before Sign In hook (if using custom approach):
```sql
CREATE OR REPLACE FUNCTION public.hook_check_rate_limit_before_signin()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_email TEXT;
BEGIN
  -- Extract email from request
  user_email := LOWER(TRIM((current_setting('request.jwt.claims', true)::jsonb->'email')::text, '"'));

  -- Check rate limit
  PERFORM public.check_magic_link_rate_limit(user_email);

  RETURN jsonb_build_object();
END;
$$;
```

Configure hook in Dashboard:
1. Navigate to: Authentication > Hooks
2. Enable: "Before Sign In" hook (not "Before User Created" - that's for signups only)
3. Set Hook Type: "Postgres Function"
4. Select Function: "hook_check_rate_limit_before_signin"

**Client-Side Error Handling:**

```dart
class MagicLinkService {
  Future<void> sendMagicLink(String email) async {
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: EmailValidator.normalizeEmail(email),
      );

      // Success: Show "Check your email" message
    } on AuthException catch (e) {
      if (e.message.contains('Too many requests')) {
        // Show: "Too many requests. Please wait 15 minutes."
        // Optionally: Calculate and show countdown timer
        throw RateLimitException(
          message: 'Too many requests. Please wait 15 minutes.',
          retryAfter: Duration(minutes: 15),
        );
      } else if (e.message.contains('Email rate limit exceeded')) {
        // Supabase built-in rate limit hit
        throw RateLimitException(
          message: 'Too many requests. Please try again in a few minutes.',
          retryAfter: Duration(minutes: 1),
        );
      } else {
        // Generic error
        throw AuthenticationException(e.message);
      }
    }
  }
}
```

**Countdown Timer UI:**
```dart
class RateLimitError extends StatefulWidget {
  final Duration retryAfter;

  @override
  State<RateLimitError> createState() => _RateLimitErrorState();
}

class _RateLimitErrorState extends State<RateLimitError> {
  late DateTime _retryAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _retryAt = DateTime.now().add(widget.retryAfter);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (DateTime.now().isAfter(_retryAt)) {
        _timer?.cancel();
        setState(() {});
      } else {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _retryAt.difference(DateTime.now());

    if (remaining.isNegative) {
      return Text('You can now try again');
    }

    return Text(
      'Too many requests. Please wait ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
```

**Production Monitoring:**
```sql
-- Query to monitor rate limiting effectiveness
SELECT
  DATE_TRUNC('hour', requested_at) as hour,
  COUNT(*) as total_attempts,
  COUNT(*) FILTER (WHERE status = 'blocked') as blocked_attempts,
  COUNT(*) FILTER (WHERE status = 'sent') as successful_attempts
FROM public.magic_link_attempts
WHERE requested_at >= NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour DESC;

-- Identify users hitting rate limits frequently
SELECT
  email,
  COUNT(*) as total_attempts,
  COUNT(*) FILTER (WHERE status = 'blocked') as blocked_count,
  MAX(requested_at) as last_attempt
FROM public.magic_link_attempts
WHERE requested_at >= NOW() - INTERVAL '7 days'
GROUP BY email
HAVING COUNT(*) FILTER (WHERE status = 'blocked') > 3
ORDER BY blocked_count DESC;
```

**Important Gotchas:**
1. Built-in rate limiting is per-email, not per-IP or device
2. Rate limits reset on a sliding window, not fixed intervals
3. Custom PostgreSQL rate limiting requires careful transaction handling to avoid race conditions
4. CAPTCHA should be added if abuse persists beyond rate limiting
5. Monitor rate limit blocks to detect potential attacks
6. Consider adding IP-based rate limiting if email-based limits are insufficient

### References
- [Supabase Auth Rate Limits](https://supabase.com/docs/guides/auth/rate-limits)
- [Rate Limiting Edge Functions](https://supabase.com/docs/guides/functions/examples/rate-limiting)
- [Rate Limiting with PostgreSQL and pgheaderkit](https://blog.mansueli.com/rate-limiting-supabase-requests-with-postgresql-and-pgheaderkit)
- [GitHub Discussion: Rate Limiting](https://github.com/orgs/supabase/discussions/4349)

---

## 6. Authentication Event Logging Architecture

### Decision
Use **PostgreSQL trigger-based audit logging with custom audit table** for authentication events (logins, failures, logouts, session expirations), combined with **Supabase's built-in Auth Audit Logs** for compliance monitoring.

### Rationale
PostgreSQL triggers provide reliable, automatic audit trails without requiring application-level code. Triggers fire on database events (INSERT, UPDATE, DELETE on auth.users), capturing all authentication state changes regardless of how they occur. This approach is more maintainable than application-level logging, which requires updating every authentication code path. Supabase's built-in Auth Audit Logs provide additional visibility but are stored in platform logs (not queryable SQL), so custom tables are needed for application-level audit queries, metrics, and GDPR compliance.

### Alternatives Considered
- **Application-level logging**: Rejected because it's fragile (easy to miss code paths), requires maintenance when authentication flows change, and doesn't capture system-level events (token expiration, automatic session refresh).
- **PGAudit extension**: Rejected because it logs to Postgres log files (not database tables), making it difficult to query, analyze, and retain logs for GDPR compliance. PGAudit is better for infrastructure-level auditing, not application metrics.
- **Supabase Auth Hooks for logging**: Considered but rejected because hooks only fire on specific events (signup, signin) and don't capture logouts, session expirations, or token refreshes.

### Implementation Notes

**Custom Audit Table:**

```sql
-- Create auth events audit table
CREATE TABLE IF NOT EXISTS public.auth_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  email_hash TEXT NOT NULL, -- SHA256 hash for privacy
  event_type TEXT NOT NULL, -- signin, signup, signout, session_expired, token_refreshed, failed_signin
  event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Device/context metadata
  ip_address INET,
  user_agent TEXT,
  device_info JSONB, -- { platform: 'iOS', version: '16.0', app_version: '1.0.0' }

  -- Event-specific data
  metadata JSONB, -- { reason: 'manual', provider: 'email', ... }

  -- Index for efficient queries
  INDEX idx_auth_events_user_time ON auth_events(user_id, event_timestamp DESC),
  INDEX idx_auth_events_type_time ON auth_events(event_type, event_timestamp DESC),
  INDEX idx_auth_events_email_hash ON auth_events(email_hash)
);

-- Enable Row-Level Security
ALTER TABLE public.auth_events ENABLE ROW LEVEL SECURITY;

-- Policy: Service role can insert
CREATE POLICY "Service role can insert events"
  ON public.auth_events
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Policy: Users can read their own events
CREATE POLICY "Users can read own events"
  ON public.auth_events
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Policy: Admins can read all events (create admin role if needed)
-- CREATE POLICY "Admins can read all events"
--   ON public.auth_events
--   FOR SELECT
--   TO admin_role
--   USING (true);
```

**Helper Function for Hashing Emails:**

```sql
CREATE OR REPLACE FUNCTION public.hash_email(email TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN encode(digest(LOWER(TRIM(email)), 'sha256'), 'hex');
END;
$$;
```

**Trigger Function for Auth Events:**

```sql
CREATE OR REPLACE FUNCTION public.log_auth_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Log successful signup
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.auth_events (
      user_id,
      email_hash,
      event_type,
      metadata
    )
    VALUES (
      NEW.id,
      public.hash_email(NEW.email),
      'signup',
      jsonb_build_object(
        'provider', COALESCE(NEW.raw_app_meta_data->>'provider', 'email'),
        'email_confirmed', NEW.email_confirmed_at IS NOT NULL
      )
    );
  END IF;

  -- Log email confirmation (magic link click)
  IF TG_OP = 'UPDATE' AND OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL THEN
    INSERT INTO public.auth_events (
      user_id,
      email_hash,
      event_type,
      metadata
    )
    VALUES (
      NEW.id,
      public.hash_email(NEW.email),
      'signin',
      jsonb_build_object('method', 'magic_link')
    );
  END IF;

  -- Log last sign in update (session refresh)
  IF TG_OP = 'UPDATE' AND NEW.last_sign_in_at > OLD.last_sign_in_at THEN
    INSERT INTO public.auth_events (
      user_id,
      email_hash,
      event_type,
      metadata
    )
    VALUES (
      NEW.id,
      public.hash_email(NEW.email),
      'signin',
      jsonb_build_object('method', 'session_refresh')
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Attach trigger to auth.users table
CREATE TRIGGER trigger_log_auth_events
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.log_auth_event();
```

**Application-Level Logout Logging:**

Triggers can't capture signout events (no database change), so log from application:

```dart
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> logout() async {
    final user = _supabase.auth.currentUser;

    if (user != null) {
      // Log signout event before clearing session
      await _logAuthEvent(
        userId: user.id,
        email: user.email!,
        eventType: 'signout',
        metadata: {'reason': 'manual'},
      );
    }

    await _supabase.auth.signOut();
  }

  Future<void> _logAuthEvent({
    required String userId,
    required String email,
    required String eventType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _supabase.from('auth_events').insert({
        'user_id': userId,
        'email_hash': _hashEmail(email),
        'event_type': eventType,
        'metadata': metadata,
        // Note: IP address and user agent can be captured via Edge Function if needed
      });
    } catch (e) {
      print('Failed to log auth event: $e');
      // Don't throw - logging failure shouldn't break auth flow
    }
  }

  String _hashEmail(String email) {
    // Use crypto package for SHA256
    final bytes = utf8.encode(email.toLowerCase().trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
```

**Failed Authentication Logging (Via Auth Hook):**

```sql
CREATE OR REPLACE FUNCTION public.hook_log_failed_signin()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_email TEXT;
BEGIN
  -- Extract email from request
  user_email := LOWER(TRIM((current_setting('request.jwt.claims', true)::jsonb->'email')::text, '"'));

  -- This hook won't actually block signin, just log the attempt
  -- If you want to log failed attempts, you need to check auth.users
  -- and see if the email exists but email_confirmed_at is NULL

  RETURN jsonb_build_object();
END;
$$;
```

Note: Failed authentication logging is challenging because Supabase doesn't expose a "failed signin" hook. Failed attempts should be logged client-side or via custom Edge Function.

**Client-Side Failed Attempt Logging:**

```dart
Future<void> sendMagicLink(String email) async {
  try {
    await _supabase.auth.signInWithOtp(email: email);
  } on AuthException catch (e) {
    // Log failed attempt
    await _logAuthEvent(
      userId: 'unknown', // No user ID for failed attempts
      email: email,
      eventType: 'failed_signin',
      metadata: {
        'reason': e.message,
        'error_code': e.statusCode,
      },
    );
    rethrow;
  }
}
```

**Session Expiration Logging:**

Track when users are forced to re-authenticate due to expired sessions:

```dart
class AuthStateProvider extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final supabase = Supabase.instance.client;

    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final user = data.session?.user;

      if (event == AuthChangeEvent.signedOut && user != null) {
        // Check if signout was due to session expiration
        final session = data.session;
        if (session == null || session.isExpired) {
          _logAuthEvent(
            userId: user.id,
            email: user.email!,
            eventType: 'session_expired',
            metadata: {'reason': 'token_expired'},
          );
        }
      }
    });

    return supabase.auth.currentUser;
  }
}
```

**Analytics Queries:**

```sql
-- Authentication success rate (last 24 hours)
SELECT
  COUNT(*) FILTER (WHERE event_type IN ('signin', 'signup')) as successful_auths,
  COUNT(*) FILTER (WHERE event_type = 'failed_signin') as failed_auths,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE event_type IN ('signin', 'signup')) /
    NULLIF(COUNT(*), 0),
    2
  ) as success_rate_percent
FROM public.auth_events
WHERE event_timestamp >= NOW() - INTERVAL '24 hours';

-- Daily active users (last 7 days)
SELECT
  DATE(event_timestamp) as date,
  COUNT(DISTINCT user_id) as daily_active_users
FROM public.auth_events
WHERE event_type IN ('signin', 'signup')
  AND event_timestamp >= NOW() - INTERVAL '7 days'
GROUP BY DATE(event_timestamp)
ORDER BY date DESC;

-- Average session duration
WITH session_starts AS (
  SELECT user_id, event_timestamp as start_time
  FROM public.auth_events
  WHERE event_type IN ('signin', 'signup')
),
session_ends AS (
  SELECT user_id, event_timestamp as end_time
  FROM public.auth_events
  WHERE event_type IN ('signout', 'session_expired')
)
SELECT
  AVG(end_time - start_time) as avg_session_duration
FROM session_starts
JOIN session_ends USING (user_id)
WHERE end_time > start_time;

-- Users hitting rate limits
SELECT
  email_hash,
  COUNT(*) as blocked_attempts,
  MAX(event_timestamp) as last_attempt
FROM public.auth_events
WHERE event_type = 'failed_signin'
  AND metadata->>'reason' LIKE '%rate limit%'
  AND event_timestamp >= NOW() - INTERVAL '7 days'
GROUP BY email_hash
HAVING COUNT(*) > 5
ORDER BY blocked_attempts DESC;
```

**GDPR Compliance - Log Retention:**

```sql
-- Automatically delete logs older than 90 days
CREATE OR REPLACE FUNCTION public.cleanup_old_auth_events()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.auth_events
  WHERE event_timestamp < NOW() - INTERVAL '90 days';
END;
$$;

-- Schedule via pg_cron (if available) or run manually
-- SELECT cron.schedule('cleanup-auth-events', '0 2 * * *', 'SELECT public.cleanup_old_auth_events()');
```

**Important Gotchas:**
1. Triggers can't capture signout events (no database change) - must log from application
2. Failed authentication attempts are hard to capture server-side - use client-side logging
3. Hash emails for privacy, but hashing prevents exact email lookups (trade-off)
4. Avoid logging sensitive data (magic link tokens, session tokens, passwords)
5. Implement log retention policy for GDPR compliance (90 days recommended)
6. Use service_role for logging to bypass RLS policies
7. Don't throw errors in logging code - auth flow should succeed even if logging fails

### References
- [Supabase Auth Audit Logs](https://supabase.com/docs/guides/auth/audit-logs)
- [PostgreSQL Auditing in 150 lines of SQL](https://supabase.com/blog/postgres-audit)
- [PGAudit Extension](https://supabase.com/docs/guides/database/extensions/pgaudit)
- [Simple Audit Trail for Supabase (Medium)](https://medium.com/@harish.siri/simpe-audit-trail-for-supabase-database-efefcce622ff)
- [5mins of Postgres: Auditing with Triggers vs pgAudit](https://pganalyze.com/blog/5mins-postgres-auditing-pgaudit-supabase-supa-audit)

---

## 7. Web Landing Page Hosting for App-Not-Installed Scenario

### Decision
Use **Supabase Edge Functions with static HTML bundling** to serve a lightweight landing page with platform detection and app store links, deployed at `/auth/fallback` route. If custom domain is unavailable, use **Vercel/Netlify static hosting** with redirect from Supabase.

### Rationale
Supabase Edge Functions now support static file bundling (CLI 2.7.0+), allowing us to serve HTML landing pages directly from the backend without external hosting. This keeps infrastructure consolidated and reduces moving parts. Edge Functions can serve HTML when a custom domain is configured, providing fast global CDN delivery. If custom domain is not available (HTML returns as text/plain), we fall back to dedicated static hosting (Vercel/Netlify) which is free, fast, and requires minimal setup. This approach avoids using Supabase Storage for HTML serving, which is not designed for website hosting.

### Alternatives Considered
- **Supabase Storage for static hosting**: Rejected because Supabase explicitly doesn't recommend this approach. Storage overrides HTML content-type to text/plain (unless custom domain is configured), and the platform lacks features for proper website hosting (no redirects, no custom domains on free tier).
- **Custom server (Express, Flask, etc.)**: Rejected as massive overkill for serving a single static page. Adds deployment complexity, costs, and maintenance burden.
- **Flutter Web build**: Rejected because Flutter's web output is heavy (large JS bundle) for a simple landing page, and lacks SEO optimization. Landing page should be lightweight HTML/CSS/JS.

### Implementation Notes

**Option 1: Supabase Edge Function (Requires Custom Domain)**

Step 1: Create Edge Function with bundled HTML:

```bash
# Create Edge Function
supabase functions new auth-fallback

# Project structure
supabase/functions/
└── auth-fallback/
    ├── index.ts
    └── static/
        ├── index.html
        ├── styles.css
        └── logo.png
```

`supabase/functions/auth-fallback/index.ts`:
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  const url = new URL(req.url);

  // Serve static files
  if (url.pathname === "/" || url.pathname === "/index.html") {
    const html = await Deno.readTextFile("./static/index.html");
    return new Response(html, {
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  }

  if (url.pathname === "/styles.css") {
    const css = await Deno.readTextFile("./static/styles.css");
    return new Response(css, {
      headers: { "Content-Type": "text/css" },
    });
  }

  if (url.pathname === "/logo.png") {
    const image = await Deno.readFile("./static/logo.png");
    return new Response(image, {
      headers: { "Content-Type": "image/png" },
    });
  }

  return new Response("Not Found", { status: 404 });
});
```

`supabase/functions/auth-fallback/static/index.html`:
```html
<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Nova - Download App</title>
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <div class="container">
    <img src="/logo.png" alt="Nova Logo" class="logo">
    <h1>Benvenuto su Nova!</h1>
    <p>Per accedere agli eventi del Liceo Galilei Moro, scarica l'app Nova.</p>

    <div class="download-buttons">
      <a href="#" id="download-btn" class="btn btn-primary">
        <span id="btn-text">Scarica Nova</span>
      </a>
    </div>

    <p class="help-text">
      Dopo aver installato l'app, richiedi un nuovo magic link per accedere.
    </p>
  </div>

  <script>
    // Platform detection
    function detectPlatform() {
      const userAgent = navigator.userAgent || navigator.vendor || window.opera;

      // iOS detection
      if (/iPad|iPhone|iPod/.test(userAgent) && !window.MSStream) {
        return 'ios';
      }

      // Android detection
      if (/android/i.test(userAgent)) {
        return 'android';
      }

      return 'unknown';
    }

    // Set download link based on platform
    const platform = detectPlatform();
    const downloadBtn = document.getElementById('download-btn');
    const btnText = document.getElementById('btn-text');

    if (platform === 'ios') {
      downloadBtn.href = 'https://apps.apple.com/app/nova/YOUR_APP_ID';
      btnText.textContent = 'Scarica su App Store';
    } else if (platform === 'android') {
      downloadBtn.href = 'https://play.google.com/store/apps/details?id=it.edu.galileimoro.nova';
      btnText.textContent = 'Scarica su Google Play';
    } else {
      // Desktop or unknown - show both
      downloadBtn.style.display = 'none';
      document.querySelector('.download-buttons').innerHTML = `
        <a href="https://apps.apple.com/app/nova/YOUR_APP_ID" class="btn btn-secondary">
          App Store
        </a>
        <a href="https://play.google.com/store/apps/details?id=it.edu.galileimoro.nova" class="btn btn-secondary">
          Google Play
        </a>
      `;
    }
  </script>
</body>
</html>
```

`supabase/functions/auth-fallback/static/styles.css`:
```css
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.container {
  background: white;
  border-radius: 24px;
  padding: 48px 32px;
  max-width: 480px;
  text-align: center;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
}

.logo {
  width: 120px;
  height: 120px;
  margin-bottom: 24px;
}

h1 {
  font-size: 32px;
  color: #1a202c;
  margin-bottom: 16px;
}

p {
  font-size: 18px;
  color: #4a5568;
  line-height: 1.6;
  margin-bottom: 32px;
}

.download-buttons {
  display: flex;
  flex-direction: column;
  gap: 16px;
  margin-bottom: 24px;
}

.btn {
  display: inline-block;
  padding: 16px 32px;
  border-radius: 12px;
  font-size: 18px;
  font-weight: 600;
  text-decoration: none;
  transition: transform 0.2s, box-shadow 0.2s;
}

.btn-primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}

.btn-secondary {
  background: #f7fafc;
  color: #667eea;
  border: 2px solid #667eea;
}

.btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.2);
}

.help-text {
  font-size: 14px;
  color: #718096;
}

@media (max-width: 480px) {
  .container {
    padding: 32px 24px;
  }

  h1 {
    font-size: 24px;
  }

  p {
    font-size: 16px;
  }
}
```

Deploy Edge Function:
```bash
supabase functions deploy auth-fallback --no-verify-jwt
```

Access URL: `https://your-project-ref.supabase.co/functions/v1/auth-fallback`

**Important**: This only works with custom domain. Without custom domain, HTML will be served as text/plain.

**Option 2: Vercel/Netlify Static Hosting (Recommended for Simplicity)**

Step 1: Create standalone project:

```
landing-page/
├── index.html  (same as above)
├── styles.css  (same as above)
├── logo.png
└── vercel.json (or netlify.toml)
```

`vercel.json`:
```json
{
  "redirects": [
    {
      "source": "/",
      "destination": "/index.html",
      "permanent": false
    }
  ]
}
```

Deploy:
```bash
# Vercel
npm install -g vercel
vercel deploy

# Netlify
npm install -g netlify-cli
netlify deploy
```

Step 2: Configure magic link redirect in Supabase:

In Email Template, use landing page URL for fallback:
```html
<!-- Supabase Email Template -->
<a href="nova://auth/verify?token={{ .TokenHash }}&type=email">
  Open Nova App
</a>

<!-- Fallback link for web -->
<p>
  <a href="https://nova-landing.vercel.app?redirect=nova://auth/verify?token={{ .TokenHash }}&type=email">
    Click here if the app doesn't open
  </a>
</p>
```

Landing page with auto-redirect:
```javascript
// In landing page
const urlParams = new URLSearchParams(window.location.search);
const redirectUrl = urlParams.get('redirect');

if (redirectUrl) {
  // Try to open app
  window.location.href = redirectUrl;

  // If app doesn't open in 2 seconds, show download page
  setTimeout(() => {
    document.querySelector('.container').style.display = 'block';
  }, 2000);
}
```

**Platform Detection Logic:**

```javascript
function detectPlatform() {
  const userAgent = navigator.userAgent || navigator.vendor || window.opera;

  // iOS
  if (/iPad|iPhone|iPod/.test(userAgent) && !window.MSStream) {
    return {
      platform: 'ios',
      storeUrl: 'https://apps.apple.com/app/nova/YOUR_APP_ID',
      storeName: 'App Store'
    };
  }

  // Android
  if (/android/i.test(userAgent)) {
    return {
      platform: 'android',
      storeUrl: 'https://play.google.com/store/apps/details?id=it.edu.galileimoro.nova',
      storeName: 'Google Play'
    };
  }

  // Desktop/Unknown
  return {
    platform: 'unknown',
    storeUrl: null,
    storeName: 'App Store'
  };
}
```

**Important Gotchas:**
1. Supabase Edge Functions can only serve HTML with custom domain configured
2. Without custom domain, use dedicated static hosting (Vercel/Netlify)
3. Platform detection can be spoofed - always show both store links as fallback
4. Magic links expire (15 min) - landing page should explain this
5. Deep link fallback doesn't work perfectly on all browsers - test thoroughly
6. Consider analytics (Plausible, Simple Analytics) to track landing page conversion

**Recommended Approach:**
Use Vercel/Netlify for simplicity unless custom domain is already configured. Static hosting is free, fast, and requires zero maintenance.

### References
- [Supabase Edge Functions Static Files Support](https://github.com/orgs/supabase/discussions/32815)
- [Render HTML in Edge Functions Discussion](https://github.com/orgs/supabase/discussions/31238)
- [Supabase Storage Static Site Hosting Discussion](https://github.com/orgs/supabase/discussions/991)
- [Hono Framework for Supabase Edge Functions](https://hono.dev/docs/getting-started/supabase-functions)

---

## 8. Riverpod Authentication State Management Pattern

### Decision
Use **AsyncNotifier** (Riverpod 2.0+) for authentication state management with **flutter_secure_storage** for session token persistence. Leverage Supabase Flutter client's built-in persistence and use AsyncNotifier to expose authentication state reactively to the UI.

### Rationale
AsyncNotifier is the modern, recommended approach for managing asynchronous state in Riverpod 2.0+ (current version is 3.0 as of 2025). It replaces the legacy StateNotifier pattern with a more ergonomic API specifically designed for async operations like authentication. The supabase-flutter client already handles session persistence via platform-specific secure storage (iOS Keychain, Android EncryptedSharedPreferences), so we don't need to manually persist tokens. AsyncNotifier provides built-in loading/data/error states via AsyncValue, simplifying UI logic. Using keepAlive: true ensures authentication state persists even when no widgets are actively listening.

### Alternatives Considered
- **StateNotifier**: Rejected because it's now considered legacy in Riverpod 2.0+. StateNotifierProvider is moved to a legacy import path, and the Riverpod team recommends migrating to AsyncNotifier.
- **FutureProvider**: Rejected because it's designed for one-time async operations, not mutable state. Authentication requires mutable state (login, logout, session refresh) which FutureProvider doesn't support.
- **Notifier (synchronous)**: Rejected because authentication operations are inherently asynchronous (network requests, token validation). AsyncNotifier is purpose-built for this use case.

### Implementation Notes

**Package Dependencies:**

```yaml
dependencies:
  flutter_riverpod: ^2.6.1  # Check pub.dev for latest
  riverpod_annotation: ^2.6.1
  supabase_flutter: ^2.8.0
  flutter_secure_storage: ^9.2.2

dev_dependencies:
  build_runner: ^2.4.13
  riverpod_generator: ^2.6.2
```

**Auth State Provider (AsyncNotifier Pattern):**

`lib/features/auth/providers/auth_provider.dart`:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true) // Keep state alive even when no listeners
class AuthState extends _$AuthState {
  @override
  Future<User?> build() async {
    final supabase = Supabase.instance.client;

    // Listen to auth state changes
    final subscription = supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final user = data.session?.user;

      switch (event) {
        case AuthChangeEvent.signedIn:
          state = AsyncValue.data(user);
          break;
        case AuthChangeEvent.signedOut:
          state = const AsyncValue.data(null);
          break;
        case AuthChangeEvent.tokenRefreshed:
          state = AsyncValue.data(user);
          break;
        case AuthChangeEvent.userDeleted:
          state = const AsyncValue.data(null);
          break;
        case AuthChangeEvent.passwordRecovery:
          // Not applicable for magic link auth
          break;
        case AuthChangeEvent.userUpdated:
          state = AsyncValue.data(user);
          break;
        default:
          break;
      }
    });

    // Clean up subscription when provider is disposed
    ref.onDispose(() {
      subscription.cancel();
    });

    // Return initial auth state
    return supabase.auth.currentUser;
  }

  // Login with magic link
  Future<void> sendMagicLink(String email) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email.trim().toLowerCase(),
      );

      // Magic link sent - user is still null until they click link
      return null;
    });
  }

  // Logout
  Future<void> logout() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await Supabase.instance.client.auth.signOut();
      return null;
    });
  }

  // Check if user is authenticated
  bool get isAuthenticated {
    return state.valueOrNull != null;
  }
}
```

**Generate Code:**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Auth Service (Optional - for separation of concerns):**

`lib/features/auth/services/auth_service.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Send magic link
  Future<void> sendMagicLink(String email) async {
    await _supabase.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
    );
  }

  // Verify magic link (called from deep link handler)
  Future<AuthResponse> verifyMagicLink(String tokenHash) async {
    return await _supabase.auth.verifyOTP(
      tokenHash: tokenHash,
      type: OtpType.magiclink,
    );
  }

  // Logout
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Check if session is valid
  bool get hasValidSession {
    final session = _supabase.auth.currentSession;
    return session != null && !session.isExpired;
  }

  // Stream of auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}

// Provider for auth service
@riverpod
AuthService authService(AuthServiceRef ref) {
  return AuthService();
}
```

**UI Integration - Login Screen:**

`lib/features/auth/screens/login_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text;

    try {
      await ref.read(authStateProvider.notifier).sendMagicLink(email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Check your email for a magic link'),
          backgroundColor: Colors.green,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome to Nova',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'School Email',
                    hintText: 'nome.cognome@galileimoro.edu.it',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@galileimoro\.edu\.it$')
                        .hasMatch(value)) {
                      return 'Please use your school email (@galileimoro.edu.it)';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                authState.isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _sendMagicLink,
                        child: Text('Send Magic Link'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

**App Initialization with Auth Check:**

`lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
      persistSession: true,
    ),
  );

  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova',
      home: AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // User authenticated -> show main app
          return FeedScreen();
        } else {
          // Not authenticated -> show login
          return LoginScreen();
        }
      },
      loading: () => Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}
```

**Deep Link Handler Integration:**

`lib/features/auth/services/deep_link_service.dart`:
```dart
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final Ref _ref;

  DeepLinkService(this._ref);

  Future<void> initialize() async {
    // Handle initial link (app was terminated)
    final initialLink = await _appLinks.getInitialAppLink();
    if (initialLink != null) {
      await _handleDeepLink(initialLink);
    }

    // Listen to incoming links
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (err) => print('Deep link error: $err'),
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.path == '/auth/confirm') {
      final tokenHash = uri.queryParameters['token_hash'];
      final type = uri.queryParameters['type'];

      if (tokenHash != null && type == 'email') {
        try {
          // Verify magic link with Supabase
          await Supabase.instance.client.auth.verifyOTP(
            tokenHash: tokenHash,
            type: OtpType.magiclink,
          );

          // Auth state will update automatically via listener in AuthStateProvider
        } catch (e) {
          print('Magic link verification failed: $e');
          // Show error to user
        }
      }
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}

@riverpod
DeepLinkService deepLinkService(DeepLinkServiceRef ref) {
  final service = DeepLinkService(ref);
  service.initialize();
  ref.onDispose(service.dispose);
  return service;
}
```

**Session Persistence (Automatic):**

The supabase-flutter client automatically persists sessions using:
- iOS: Keychain (via flutter_secure_storage)
- Android: EncryptedSharedPreferences (via flutter_secure_storage)
- Web: localStorage (encrypted)

No manual implementation needed. Sessions persist across app restarts.

**Important Gotchas:**
1. Use `keepAlive: true` on auth provider to prevent state loss when no widgets listen
2. AsyncNotifier.guard() automatically catches errors and sets state to AsyncValue.error
3. Supabase client handles session persistence - don't manually save tokens
4. Auth state changes emit events - listen in AsyncNotifier.build() for reactive updates
5. Test offline scenarios - Supabase.initialize() can block with expired token
6. Don't store sensitive data (tokens) in regular state - use supabase client's secure storage

**Migration from StateNotifier (if applicable):**

Old (StateNotifier):
```dart
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final user = Supabase.instance.client.auth.currentUser;
    state = AsyncValue.data(user);
  }
}
```

New (AsyncNotifier):
```dart
@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  @override
  Future<User?> build() async {
    return Supabase.instance.client.auth.currentUser;
  }
}
```

### References
- [How to use AsyncNotifier with Riverpod Generator](https://codewithandrea.com/articles/flutter-riverpod-async-notifier/)
- [Migrating from StateNotifier to Notifier in Riverpod 2.0](https://q.agency/blog/migrating-from-statenotifier-to-notifier-in-riverpod-2-0-with-unit-tests/)
- [Flutter Riverpod 3.0 Released](https://medium.com/@lee645521797/flutter-riverpod-3-0-released-a-major-redesign-of-the-state-management-framework-f7e31f19b179)
- [Firebase Authentication with Riverpod 2025](https://medium.com/@pravin_palukuru/firebase-authentication-in-flutter-with-riverpod-2025-edition-1ca04a3e0f84)
- [Riverpod Official Documentation: From StateNotifier](https://riverpod.dev/docs/migration/from_state_notifier)
- [Master Riverpod's Local Storage](https://medium.com/@alaxhenry0121/stop-struggling-with-state-management-master-riverpods-local-storage-in-15-minutes-2862c66e5d2f)

---

## Summary of Key Decisions

| Area | Decision | Key Technology |
|------|----------|---------------|
| **Magic Link Config** | Built-in Supabase Auth with 15-min expiration | Supabase Auth |
| **Deep Linking** | app_links package with manual navigation control | app_links 6.3.2+ |
| **Email Validation** | Server-side Auth Hook + client-side regex | PostgreSQL Function |
| **Session Management** | 30-day refresh tokens with auto-refresh | Supabase Auth (OAuth2) |
| **Rate Limiting** | Built-in Supabase config (3 per 15min) | Supabase Management API |
| **Event Logging** | PostgreSQL triggers + custom audit table | PostgreSQL |
| **Landing Page** | Vercel/Netlify static hosting | HTML/CSS/JS |
| **State Management** | AsyncNotifier with built-in persistence | Riverpod 2.0+ |

---

## Next Steps

1. **Configure Supabase Project**:
   - Set magic link expiration to 900 seconds
   - Configure email domain restriction hook
   - Set refresh token expiration to 30 days
   - Customize email template

2. **Set Up Deep Linking**:
   - Configure Android App Links (assetlinks.json)
   - Configure iOS Universal Links (AASA file)
   - Implement app_links integration
   - Test deep link flows

3. **Implement Authentication UI**:
   - Create login screen with email validation
   - Set up Riverpod AsyncNotifier provider
   - Implement auth state gate
   - Add logout functionality

4. **Deploy Landing Page**:
   - Create static landing page with platform detection
   - Deploy to Vercel/Netlify
   - Test fallback flow

5. **Set Up Monitoring**:
   - Create auth events audit table
   - Implement PostgreSQL triggers
   - Set up analytics queries
   - Configure log retention

---

**Document Version**: 1.0
**Last Updated**: 2025-10-30
**Research Status**: Complete
**Ready for Implementation Planning**: Yes
