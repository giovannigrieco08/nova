# Deep Linking Specification: Magic Link Authentication

**Feature**: Passwordless Magic Link Authentication for Nova
**Version**: 1.0
**Date**: 2025-10-30
**Status**: Implementation Ready

---

## Overview

This document specifies the deep linking configuration for Nova's magic link authentication system. Deep links enable seamless authentication flow by automatically opening the Nova app when users click magic links in their email, bypassing manual URL copy-paste. The system uses **Android App Links** (verified HTTPS links) and **iOS Universal Links** (verified HTTPS links) for native app opening, with fallback to a web landing page for users without the app installed.

---

## URL Format

### Magic Link URL Structure

**Primary URL** (HTTPS with domain verification):
```
https://nova.galileimoro.edu.it/auth/confirm?token_hash={TOKEN_HASH}&type=email
```

**Components**:
- **Protocol**: `https` (required for App Links and Universal Links)
- **Domain**: `nova.galileimoro.edu.it` (must match domain in assetlinks.json and AASA file)
- **Path**: `/auth/confirm` (authentication confirmation endpoint)
- **Query Parameters**:
  - `token_hash`: Hashed magic link token from Supabase Auth (64-character hex string)
  - `type`: Token type, always `email` or `magiclink` for magic link authentication

**Example**:
```
https://nova.galileimoro.edu.it/auth/confirm?token_hash=a1b2c3d4e5f6789012345678901234567890abcdefabcdefabcdefabcdefabcdef&type=email
```

### Custom URL Scheme (Fallback)

**Alternative URL** (for testing or legacy support):
```
nova://auth/verify?token_hash={TOKEN_HASH}&type=email
```

**Note**: Custom URL schemes (`nova://`) are less secure than HTTPS deep links and should only be used for local testing or as a fallback. Production should use HTTPS App Links/Universal Links exclusively.

---

## Android App Links Configuration

### Requirements

- Android 6.0 (API 21) or higher
- Domain ownership verification via `assetlinks.json` file
- HTTPS hosting of verification file at `https://nova.galileimoro.edu.it/.well-known/assetlinks.json`

### AndroidManifest.xml Configuration

**File**: `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="it.edu.galileimoro.nova">

    <application
        android:label="Nova"
        android:icon="@mipmap/ic_launcher">

        <activity
            android:name=".MainActivity"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize"
            android:exported="true">

            <!-- Standard launcher intent -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>

            <!-- App Links intent filter (verified HTTPS links) -->
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />

                <!-- HTTPS scheme for verified App Links -->
                <data
                    android:scheme="https"
                    android:host="nova.galileimoro.edu.it"
                    android:pathPrefix="/auth" />
            </intent-filter>

            <!-- Custom URL scheme fallback (for testing) -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />

                <!-- Custom scheme -->
                <data
                    android:scheme="nova"
                    android:host="auth" />
            </intent-filter>

        </activity>

    </application>
</manifest>
```

**Key Attributes**:
- `android:autoVerify="true"`: Enables automatic verification of App Links with assetlinks.json
- `android:scheme="https"`: Uses secure HTTPS protocol
- `android:host="nova.galileimoro.edu.it"`: Must match domain in assetlinks.json
- `android:pathPrefix="/auth"`: Matches `/auth/confirm` and other `/auth/*` paths

### assetlinks.json File

**Hosting Location**: `https://nova.galileimoro.edu.it/.well-known/assetlinks.json`

**File Content**:
```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "it.edu.galileimoro.nova",
      "sha256_cert_fingerprints": [
        "14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5"
      ]
    }
  }
]
```

**Field Explanations**:

| Field | Description | Example Value |
|-------|-------------|---------------|
| `relation` | Permission type (always `delegate_permission/common.handle_all_urls`) | `["delegate_permission/common.handle_all_urls"]` |
| `namespace` | Target type (always `android_app` for Android) | `android_app` |
| `package_name` | Android app package ID (must match build.gradle) | `it.edu.galileimoro.nova` |
| `sha256_cert_fingerprints` | Array of SHA256 certificate fingerprints (signing key) | `["14:6D:E9:83:C5:73..."]` |

### Generating SHA256 Certificate Fingerprint

**Debug Keystore** (for development):
```bash
# macOS/Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Windows
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**Release Keystore** (for production):
```bash
keytool -list -v -keystore /path/to/release-keystore.jks -alias your-key-alias
```

**Extract SHA256 fingerprint** from output:
```
Certificate fingerprints:
  SHA1: AB:CD:EF:12:34:56...
  SHA256: 14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5
```

**Important**: You must include fingerprints for **both debug and release** keystores in the assetlinks.json file if you want App Links to work in both environments.

### Deployment Steps

1. **Generate SHA256 fingerprint** for debug and release keystores
2. **Create assetlinks.json** file with your package name and fingerprints
3. **Host the file** at `https://nova.galileimoro.edu.it/.well-known/assetlinks.json`
4. **Verify hosting**:
   ```bash
   curl https://nova.galileimoro.edu.it/.well-known/assetlinks.json
   ```
5. **Set correct MIME type**: `Content-Type: application/json`
6. **Ensure HTTPS**: File must be served over HTTPS (not HTTP)
7. **No redirects**: Direct file access required (301/302 redirects not allowed)

### Testing Android App Links

**Method 1: ADB Command** (Recommended)
```bash
# Test magic link deep link
adb shell am start -W -a android.intent.action.VIEW \
  -d "https://nova.galileimoro.edu.it/auth/confirm?token_hash=TEST123&type=email" \
  it.edu.galileimoro.nova

# Expected: Nova app opens automatically (no browser disambiguation dialog)
```

**Method 2: Android Debug Bridge Link Tester**
```bash
adb shell dumpsys package domain-preferred-apps
```

**Expected Output**:
```
Package: it.edu.galileimoro.nova
Domains: nova.galileimoro.edu.it
Status: always : 200000002
```

**Method 3: Online Verification Tool**
- [Google App Links Assistant](https://developers.google.com/digital-asset-links/tools/generator)
- [Statement List Generator & Tester](https://developers.google.com/digital-asset-links/v1/create-statement)

### Troubleshooting

**Issue**: App Links not working (browser opens instead of app)

**Solutions**:
1. **Verify assetlinks.json hosting**:
   ```bash
   curl -I https://nova.galileimoro.edu.it/.well-known/assetlinks.json
   # Should return: Content-Type: application/json (not text/html)
   ```

2. **Check certificate fingerprint** matches your keystore:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore | grep SHA256
   ```

3. **Clear Android app verification cache**:
   ```bash
   adb shell pm clear com.android.vending
   adb shell pm clear com.google.android.gms
   adb uninstall it.edu.galileimoro.nova
   adb install app-debug.apk
   ```

4. **Check Android version**: App Links require Android 6.0+ (API 23+)

5. **Verify intent filter** has `android:autoVerify="true"` attribute

---

## iOS Universal Links Configuration

### Requirements

- iOS 9.0 or higher
- Domain ownership verification via AASA (Apple App Site Association) file
- HTTPS hosting of AASA file at `https://nova.galileimoro.edu.it/.well-known/apple-app-site-association`

### Info.plist Configuration

**File**: `ios/Runner/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Existing keys... -->

    <!-- Enable Flutter Deep Linking -->
    <key>FlutterDeepLinkingEnabled</key>
    <true/>

    <!-- Note: Associated Domains are configured in Xcode, not Info.plist -->
</dict>
</plist>
```

**Note**: Flutter 3.27+ enables deep linking by default. The `FlutterDeepLinkingEnabled` key is optional but explicit.

### Xcode Associated Domains Configuration

**Steps**:

1. **Open Xcode project**: `ios/Runner.xcworkspace`
2. **Select Runner target** → Signing & Capabilities tab
3. **Add capability**: Click "+ Capability" → "Associated Domains"
4. **Add domain**: Click "+" under Associated Domains
5. **Enter domain**: `applinks:nova.galileimoro.edu.it`

**Format**: `applinks:{domain}` (no `https://` or `www.`)

**Example**:
```
applinks:nova.galileimoro.edu.it
```

**Result in Runner.entitlements**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:nova.galileimoro.edu.it</string>
    </array>
</dict>
</plist>
```

### AASA File (Apple App Site Association)

**Hosting Location**: `https://nova.galileimoro.edu.it/.well-known/apple-app-site-association`

**File Content** (Modern Format - iOS 13+):
```json
{
  "applinks": {
    "details": [
      {
        "appIDs": [
          "TEAM_ID.it.edu.galileimoro.nova"
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

**File Content** (Legacy Format - iOS 9-12 Support):
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.it.edu.galileimoro.nova",
        "paths": [
          "/auth/*"
        ]
      }
    ]
  }
}
```

**Field Explanations**:

| Field | Description | Example Value |
|-------|-------------|---------------|
| `appIDs` or `appID` | Array (modern) or string (legacy) of app identifiers | `["TEAM_ID.it.edu.galileimoro.nova"]` |
| `TEAM_ID` | Apple Developer Team ID (found in Apple Developer Portal) | `A1B2C3D4E5` |
| `Bundle Identifier` | iOS app bundle ID (must match Xcode project) | `it.edu.galileimoro.nova` |
| `components` | Modern path matching (iOS 13+) with pattern support | `[{"/": "/auth/*"}]` |
| `paths` | Legacy path matching (iOS 9-12) with wildcard support | `["/auth/*"]` |

### Finding Your Apple Team ID

**Method 1: Apple Developer Portal**
1. Go to [developer.apple.com](https://developer.apple.com)
2. Sign in with your Apple Developer account
3. Navigate to "Membership" in the sidebar
4. Team ID is displayed at the top (e.g., `A1B2C3D4E5`)

**Method 2: Xcode**
1. Open Xcode project: `ios/Runner.xcworkspace`
2. Select Runner target → General tab
3. Team ID is shown in the "Team" dropdown (e.g., "John Doe (A1B2C3D4E5)")

**Method 3: Command Line**
```bash
# Get Team ID from provisioning profile
security find-identity -v -p codesigning | grep "Apple Development"
```

### Deployment Steps

1. **Find your Team ID** from Apple Developer Portal or Xcode
2. **Create AASA file** with your Team ID and bundle identifier
3. **Host the file** at `https://nova.galileimoro.edu.it/.well-known/apple-app-site-association`
4. **Verify hosting**:
   ```bash
   curl https://nova.galileimoro.edu.it/.well-known/apple-app-site-association
   ```
5. **Set correct MIME type**: `Content-Type: application/json` or `application/pkcs7-mime`
6. **No file extension**: File name must be exactly `apple-app-site-association` (no `.json`)
7. **Ensure HTTPS**: File must be served over HTTPS (not HTTP)
8. **No redirects**: Direct file access required (301/302 redirects not allowed)

### Testing iOS Universal Links

**Method 1: iOS Simulator** (Recommended for Development)
```bash
# Launch simulator
open -a Simulator

# Send deep link to simulator
xcrun simctl openurl booted "https://nova.galileimoro.edu.it/auth/confirm?token_hash=TEST123&type=email"

# Expected: Nova app opens automatically (not Safari)
```

**Method 2: Physical Device** (Required for Production Testing)
1. **Send magic link email** to test email account
2. **Open email on iPhone** (Mail app, Gmail app, etc.)
3. **Tap magic link** in email
4. **Expected behavior**: Nova app opens directly (no Safari intermediate page)

**Method 3: Notes App Test**
1. Open Notes app on iPhone
2. Type or paste: `https://nova.galileimoro.edu.it/auth/confirm?token_hash=TEST123&type=email`
3. Tap the link
4. Expected: Nova app opens automatically

**Method 4: Safari Address Bar Test**
1. Open Safari on iPhone
2. Type URL in address bar (not search bar)
3. Press "Go"
4. Expected: Nova app opens automatically

**Note**: Universal Links do NOT work when:
- Typing URL in Safari search bar (use address bar instead)
- Clicking link from same domain in Safari (opens in Safari)
- Programmatically opening link with `window.open()` in web app

### Troubleshooting

**Issue**: Universal Links not working (Safari opens instead of app)

**Solutions**:
1. **Verify AASA hosting**:
   ```bash
   curl -I https://nova.galileimoro.edu.it/.well-known/apple-app-site-association
   # Should return: Content-Type: application/json (or application/pkcs7-mime)
   ```

2. **Validate AASA file format**:
   - Use [Apple's AASA Validator](https://search.developer.apple.com/appsearch-validation-tool/)
   - Enter domain: `nova.galileimoro.edu.it`
   - Verify no errors reported

3. **Check Team ID and Bundle ID** match Xcode project:
   ```bash
   # Compare with Xcode: Runner target → General → Bundle Identifier
   ```

4. **Clear iOS Universal Link cache**:
   ```bash
   # Uninstall and reinstall app
   # iOS caches AASA file for up to 24 hours
   ```

5. **Test on physical device** (Simulator may not fully support Universal Links)

6. **Verify Associated Domains entitlement** in Xcode:
   - Runner target → Signing & Capabilities → Associated Domains
   - Should show: `applinks:nova.galileimoro.edu.it`

7. **Check iOS version**: Universal Links require iOS 9.0+

---

## Deep Link Handling Logic

### Flutter Implementation (app_links Package)

**File**: `lib/shared/services/deep_link_service.dart`

```dart
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// Initialize deep link handling
  Future<void> initialize() async {
    // Handle initial link (app was terminated - cold start)
    await _handleInitialLink();

    // Listen to incoming links (app running or backgrounded - warm start)
    _startListening();
  }

  /// Handle initial link when app was terminated
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

  /// Listen to incoming links when app is running
  void _startListening() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (err) => print('Deep link error: $err'),
    );
  }

  /// Process deep link and authenticate user
  Future<void> _handleDeepLink(Uri uri) async {
    print('Deep link received: $uri');

    // Parse magic link URL
    // Expected format: https://nova.galileimoro.edu.it/auth/confirm?token_hash=...&type=email
    if (uri.path == '/auth/confirm') {
      final tokenHash = uri.queryParameters['token_hash'];
      final type = uri.queryParameters['type'];

      if (tokenHash != null && type == 'email') {
        try {
          // Verify magic link token with Supabase
          await Supabase.instance.client.auth.verifyOTP(
            tokenHash: tokenHash,
            type: OtpType.magiclink,
          );

          // Success: User is now authenticated
          // Auth state will update automatically via Supabase listener
          print('Magic link verified successfully');

          // Navigate to main feed (optional - handled by AuthGate)
          // navigatorKey.currentState?.pushReplacementNamed('/feed');
        } on AuthException catch (e) {
          // Failed verification (expired, used, or invalid token)
          print('Magic link verification failed: ${e.message}');

          // Show error to user
          _showErrorDialog(e.message);
        }
      } else {
        print('Invalid magic link format (missing token_hash or type)');
      }
    } else {
      print('Unknown deep link path: ${uri.path}');
    }
  }

  /// Show error dialog to user
  void _showErrorDialog(String message) {
    // TODO: Implement error dialog based on your UI framework
    // Example: Show SnackBar, AlertDialog, or custom error screen
  }

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
  }
}
```

### Cold Start vs Warm Start Handling

**Cold Start** (App Terminated):
1. User clicks magic link in email
2. Operating system launches Nova app
3. Flutter initializes, runs `main()`
4. `DeepLinkService.initialize()` calls `getInitialAppLink()`
5. Returns magic link URI
6. Verifies token and authenticates user
7. Navigates to Feed screen

**Pseudocode**:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(...);

  // Initialize deep link service
  final deepLinkService = DeepLinkService();
  await deepLinkService.initialize();

  runApp(MyApp());
}
```

**Warm Start** (App Backgrounded or Running):
1. User clicks magic link in email
2. Operating system brings Nova app to foreground
3. `uriLinkStream` emits new URI event
4. `_handleDeepLink()` called with magic link URI
5. Verifies token and authenticates user
6. Navigates to Feed screen (preserving navigation stack)

**Pseudocode**:
```dart
// In DeepLinkService._startListening()
_appLinks.uriLinkStream.listen((uri) {
  // Handle link while app is running
  _handleDeepLink(uri);
});
```

### Navigation Considerations

**Preserve Navigation Stack** (Warm Start):
```dart
// Don't use context.go() - it replaces entire stack
// Use pushReplacement or push instead

Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (context) => FeedScreen()),
);
```

**Replace Navigation Stack** (Cold Start):
```dart
// Cold start: No existing navigation stack, safe to use go()
context.go('/feed');
```

**Edge Case: User Already Authenticated**:
```dart
Future<void> _handleDeepLink(Uri uri) async {
  // Check if user already authenticated
  if (Supabase.instance.client.auth.currentUser != null) {
    print('User already authenticated, ignoring magic link');
    return; // Don't re-verify token
  }

  // Proceed with magic link verification...
}
```

---

## Fallback: App Not Installed

### Web Landing Page

When a user clicks a magic link without the Nova app installed, the link should open a web landing page with platform-specific download buttons.

**Hosting**: Vercel/Netlify static hosting at `https://nova-landing.vercel.app`

**Redirect Logic**:
1. Magic link URL opens in browser (app not installed)
2. Browser loads landing page
3. JavaScript detects platform (iOS/Android/Desktop)
4. Shows appropriate "Download Nova" button
5. Links to App Store (iOS) or Google Play (Android)

**Platform Detection**:
```javascript
function detectPlatform() {
  const userAgent = navigator.userAgent || navigator.vendor || window.opera;

  // iOS detection
  if (/iPad|iPhone|iPod/.test(userAgent) && !window.MSStream) {
    return {
      platform: 'ios',
      storeUrl: 'https://apps.apple.com/app/nova/YOUR_APP_ID',
      storeName: 'App Store'
    };
  }

  // Android detection
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
    storeName: null
  };
}
```

**Auto-Redirect Attempt** (Optional):
```javascript
// Try to open app deep link
const urlParams = new URLSearchParams(window.location.search);
const tokenHash = urlParams.get('token_hash');
const type = urlParams.get('type');

if (tokenHash && type) {
  // Attempt to open app with custom scheme
  window.location.href = `nova://auth/verify?token_hash=${tokenHash}&type=${type}`;

  // If app doesn't open in 2 seconds, show download page
  setTimeout(() => {
    document.querySelector('.landing-page').style.display = 'block';
  }, 2000);
}
```

### User Experience Flow

**Scenario 1: App Installed**
1. User clicks magic link in email
2. Operating system detects App Link/Universal Link
3. Nova app opens automatically (no browser)
4. App verifies token and authenticates user
5. User lands on Feed screen

**Scenario 2: App Not Installed**
1. User clicks magic link in email
2. Link opens in browser (no app to handle it)
3. Landing page displays "Download Nova" button
4. User taps button → redirected to App Store/Google Play
5. User installs app
6. User must request new magic link (original link expired after 15 minutes)

**Note**: Magic links cannot be "saved" for post-install use because they expire after 15 minutes. Users must always request a fresh magic link after installing the app.

---

## Testing Procedures

### Android Testing Checklist

- [ ] **Install app** on physical Android device (API 21+)
- [ ] **Verify AndroidManifest.xml** has correct intent filter with `autoVerify="true"`
- [ ] **Host assetlinks.json** at `https://nova.galileimoro.edu.it/.well-known/assetlinks.json`
- [ ] **Verify HTTPS hosting** with correct Content-Type header
- [ ] **Test with ADB command**:
  ```bash
  adb shell am start -W -a android.intent.action.VIEW \
    -d "https://nova.galileimoro.edu.it/auth/confirm?token_hash=TEST&type=email" \
    it.edu.galileimoro.nova
  ```
- [ ] **Verify app opens automatically** (no browser disambiguation)
- [ ] **Test cold start**: Uninstall app, click magic link, app doesn't open (expected)
- [ ] **Test warm start**: Open app, background it, click magic link, app comes to foreground

### iOS Testing Checklist

- [ ] **Install app** on physical iOS device (iOS 9.0+) or Simulator
- [ ] **Verify Info.plist** has `FlutterDeepLinkingEnabled` set to `true`
- [ ] **Configure Associated Domains** in Xcode with `applinks:nova.galileimoro.edu.it`
- [ ] **Host AASA file** at `https://nova.galileimoro.edu.it/.well-known/apple-app-site-association`
- [ ] **Verify HTTPS hosting** with correct Content-Type header and no redirects
- [ ] **Test with Simulator**:
  ```bash
  xcrun simctl openurl booted "https://nova.galileimoro.edu.it/auth/confirm?token_hash=TEST&type=email"
  ```
- [ ] **Verify app opens automatically** (not Safari)
- [ ] **Test on physical device** (required for production validation)
- [ ] **Test in Notes app**: Paste link, tap it, verify app opens
- [ ] **Test in Safari address bar**: Type URL, press Go, verify app opens

### Edge Cases to Test

- [ ] **Expired magic link** (>15 minutes old): Should show error message
- [ ] **Used magic link** (clicked twice): Second click should show "already used" error
- [ ] **Invalid token hash**: Should show "invalid link" error
- [ ] **Missing query parameters**: Should handle gracefully (no crash)
- [ ] **User already authenticated**: Should not re-verify token (idempotent)
- [ ] **Network offline**: Should show "no internet connection" error
- [ ] **App not installed**: Should open landing page in browser
- [ ] **Deep link from same domain in Safari (iOS)**: May open in Safari (expected iOS behavior)

---

## Security Considerations

### HTTPS Requirement

**Rationale**: App Links and Universal Links require HTTPS for domain verification. This prevents man-in-the-middle attacks and ensures magic link tokens are transmitted securely.

**Enforcement**:
- assetlinks.json and AASA files must be served over HTTPS
- Magic link URLs must use `https://` scheme (not `http://`)
- TLS 1.2 or higher required

### Token Security

**Magic link tokens are sensitive credentials**:
- 15-minute expiration limits exposure window
- Single-use enforcement prevents replay attacks
- Tokens transmitted only over HTTPS (never HTTP or URL encoding in logs)

**Best Practices**:
- Never log full magic link URLs (redact token_hash in logs)
- Don't cache magic link URLs in browser history
- Clear magic link from email after use (optional)

### Domain Verification

**Purpose**: Prevents malicious apps from intercepting magic links intended for Nova app.

**Mechanism**:
- **Android**: assetlinks.json proves domain ownership via certificate fingerprint
- **iOS**: AASA file proves domain ownership via Apple Team ID

**Verification Process**:
1. User installs app
2. Operating system fetches assetlinks.json or AASA file from `https://nova.galileimoro.edu.it/.well-known/`
3. OS validates app signature matches certificate in verification file
4. If valid: App Links/Universal Links enabled
5. If invalid: Links open in browser (fallback)

---

## Monitoring & Analytics

### Deep Link Success Metrics

**Recommended Tracking**:
- Deep link open rate (clicks that opened app vs browser)
- Authentication success rate from deep links
- Cold start vs warm start distribution
- Platform-specific open rates (iOS vs Android)
- Average time from link click to authentication

**Implementation**:
```dart
// Log deep link events to analytics
void _handleDeepLink(Uri uri) async {
  // Track deep link received
  analytics.logEvent('deep_link_received', parameters: {
    'platform': Platform.isIOS ? 'ios' : 'android',
    'path': uri.path,
    'app_state': _appLinks.getInitialAppLink() != null ? 'cold_start' : 'warm_start',
  });

  // Attempt authentication...

  // Track success or failure
  analytics.logEvent('deep_link_authentication', parameters: {
    'success': true,
  });
}
```

### Troubleshooting Deep Link Issues

**Debug Logging**:
```dart
// Enable verbose logging in DeepLinkService
void _handleDeepLink(Uri uri) async {
  print('=== Deep Link Debug ===');
  print('Full URI: $uri');
  print('Scheme: ${uri.scheme}');
  print('Host: ${uri.host}');
  print('Path: ${uri.path}');
  print('Query params: ${uri.queryParameters}');
  print('======================');

  // Continue processing...
}
```

**Common Issues**:
1. **Deep link opens browser instead of app**: Verify assetlinks.json or AASA file hosting
2. **Token verification fails**: Check token expiration and format
3. **App crashes on deep link**: Ensure proper null checking and error handling
4. **Deep link ignored**: Check intent filter or Associated Domains configuration

---

## References

### Android App Links
- [Android App Links Documentation](https://developer.android.com/training/app-links)
- [Flutter Android App Links Setup](https://docs.flutter.dev/cookbook/navigation/set-up-app-links)
- [Digital Asset Links Generator](https://developers.google.com/digital-asset-links/tools/generator)

### iOS Universal Links
- [Apple Universal Links Documentation](https://developer.apple.com/ios/universal-links/)
- [Flutter iOS Universal Links Setup](https://docs.flutter.dev/cookbook/navigation/set-up-universal-links)
- [Apple AASA Validator](https://search.developer.apple.com/appsearch-validation-tool/)

### Flutter app_links Package
- [app_links Package (pub.dev)](https://pub.dev/packages/app_links)
- [Flutter Deep Linking Guide](https://docs.flutter.dev/ui/navigation/deep-linking)

---

**Document Version**: 1.0
**Last Updated**: 2025-10-30
**Status**: Implementation Ready
**Dependencies**: research.md (technical decisions), data-model.md (entities)
**Next Steps**: Create quickstart.md with developer setup guide
