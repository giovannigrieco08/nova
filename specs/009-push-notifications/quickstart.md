# Quickstart Guide: Push Notifications

**Feature**: 009-push-notifications
**Date**: 2025-11-30

## Prerequisites

Before implementing push notifications:

1. **Firebase Project** - Already configured (firebase_core present in pubspec.yaml)
2. **FCM Setup** - Firebase Messaging already added
3. **In-App Notifications** - 008-realtime-notifications must be complete
4. **iOS Developer Account** - Required for APNs certificates

## Quick Integration Scenarios

### Scenario 1: User Receives Push with App Closed

**Test Steps:**
1. Login as User A on Device 1
2. Login as User B on Device 2
3. User B creates an event
4. User B's event is approved by moderator
5. Close Nova app completely on User B's device (force quit)
6. User A comments on User B's event
7. User B should receive push notification within 5 seconds

**Expected Result:**
- Push notification appears in system tray
- Title: "Mario ha commentato sul tuo evento"
- Body: First 100 chars of comment
- Tapping navigates to event detail with comments visible

### Scenario 2: Deep Link from Terminated State

**Test Steps:**
1. Force quit Nova app
2. Receive push notification
3. Tap notification

**Expected Result:**
- App cold starts
- Navigates directly to target (event/comment)
- Notification marked as read in database

### Scenario 3: Foreground Banner

**Test Steps:**
1. Open Nova app to Events feed
2. From another device, trigger notification (like, comment)

**Expected Result:**
- Banner appears at top of screen
- Shows notification content
- Tapping navigates to target
- Swiping dismisses banner

### Scenario 4: Permission Request (iOS)

**Test Steps:**
1. Install Nova on fresh iOS device
2. Login for first time

**Expected Result:**
- Pre-permission dialog explains value
- If user taps "Enable", iOS permission sheet appears
- If granted, FCM token registered

### Scenario 5: Respect User Preferences

**Test Steps:**
1. Go to Settings → Notifications
2. Disable "Nuovi commenti"
3. Have another user comment on your event

**Expected Result:**
- In-app notification is NOT created (existing behavior)
- Push notification is NOT sent (since no notification created)

### Scenario 6: Multi-Device

**Test Steps:**
1. Login on Phone A
2. Login on Tablet B (same account)
3. Trigger notification from third device

**Expected Result:**
- Both Phone A and Tablet B receive push
- FCM handles deduplication (no duplicates)

## Code Snippets

### Initialize FCM in main.dart

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

// Top-level function for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Handle background message (update badge, etc.)
  print('Background message: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Set up background handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: NovaApp()));
}
```

### Request Permission (iOS)

```dart
Future<void> requestNotificationPermission() async {
  final messaging = FirebaseMessaging.instance;

  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission');
    await registerFcmToken();
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('User granted provisional permission');
    await registerFcmToken();
  } else {
    print('User denied permission');
  }
}
```

### Register FCM Token

```dart
Future<void> registerFcmToken() async {
  final messaging = FirebaseMessaging.instance;
  final token = await messaging.getToken();

  if (token != null) {
    await supabase.from('fcm_tokens').upsert({
      'user_id': supabase.auth.currentUser!.id,
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'device_name': await getDeviceName(),
    }, onConflict: 'token');
  }

  // Listen for token refresh
  messaging.onTokenRefresh.listen((newToken) async {
    await supabase.from('fcm_tokens').upsert({
      'user_id': supabase.auth.currentUser!.id,
      'token': newToken,
      'platform': Platform.isIOS ? 'ios' : 'android',
    }, onConflict: 'token');
  });
}
```

### Handle Foreground Messages

```dart
void setupForegroundHandler() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // Show in-app banner
    showTopBanner(
      title: message.notification?.title ?? 'Nova',
      body: message.notification?.body ?? '',
      onTap: () => navigateToTarget(message.data),
    );
  });
}
```

### Handle Message Taps (Background/Terminated)

```dart
void setupMessageOpenedHandler() {
  // Background state - tap opens app
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    navigateToTarget(message.data);
  });
}

Future<void> checkInitialMessage() async {
  // Terminated state - app opened via notification
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    navigateToTarget(initialMessage.data);
  }
}

void navigateToTarget(Map<String, dynamic> data) {
  final targetType = data['target_type'] as String?;
  final targetId = data['target_id'] as String?;

  if (targetType == 'event' && targetId != null) {
    navigatorKey.currentState?.pushNamed('/events/$targetId');
  } else if (targetType == 'comment' && targetId != null) {
    final eventId = data['event_id'] as String?;
    if (eventId != null) {
      navigatorKey.currentState?.pushNamed('/events/$eventId?commentId=$targetId');
    }
  }
}
```

### Delete Token on Logout

```dart
Future<void> logout() async {
  // Delete FCM token before signing out
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    await supabase
        .from('fcm_tokens')
        .delete()
        .eq('token', token);
  }

  // Sign out
  await supabase.auth.signOut();
}
```

## Edge Function Deployment

### Create Function

```bash
supabase functions new send-push-notification
```

### Set Secrets

```bash
supabase secrets set FCM_SERVER_KEY=<your-server-key>
```

### Deploy

```bash
supabase functions deploy send-push-notification
```

### Configure Webhook

In Supabase Dashboard:
1. Go to Database → Webhooks
2. Create new webhook
3. Table: `notifications`
4. Events: `INSERT`
5. URL: `https://<ref>.supabase.co/functions/v1/send-push-notification`
6. Headers: `Authorization: Bearer <service_role_key>`

## iOS Setup Checklist

- [ ] Enable Push Notifications capability in Xcode
- [ ] Add `GoogleService-Info.plist` to Runner target
- [ ] Enable Background Modes: Remote notifications
- [ ] Generate APNs Key in Apple Developer Portal
- [ ] Upload APNs Key to Firebase Console
- [ ] Test on physical device (simulator doesn't support push)

## Android Setup Checklist

- [ ] Add `google-services.json` to `android/app/`
- [ ] Verify `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` in manifest
- [ ] Create notification channel for Android 8+
- [ ] Test on Android 13+ device for permission flow

## Troubleshooting

### No push received
1. Check FCM token exists in `fcm_tokens` table
2. Check webhook is configured correctly
3. Check Edge Function logs in Supabase Dashboard
4. Verify FCM_SERVER_KEY is set correctly

### Push received but no navigation
1. Check `target_type` and `target_id` in FCM data payload
2. Verify `onMessageOpenedApp` handler is set up
3. Check `getInitialMessage()` is called on app start

### iOS permission not showing
1. Cannot test on simulator - use physical device
2. Check Info.plist has required entries
3. Try deleting app and reinstalling

### Badge not updating
1. Check `flutter_app_badger` is installed
2. iOS: Ensure badge permission granted
3. Android: Check device supports app badger
