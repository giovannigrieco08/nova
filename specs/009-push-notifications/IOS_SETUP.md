# iOS Push Notification Setup

**Feature**: 009-push-notifications
**Date**: 2025-11-30

## Prerequisites

- Apple Developer Account (Team account, not personal)
- Access to Firebase Console
- Xcode installed on macOS

## Step 1: Generate APNs Authentication Key

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
2. Click **+** to create new key
3. Enter name: "Nova Push Notifications"
4. Check **Apple Push Notifications service (APNs)**
5. Click **Continue** then **Register**
6. **Download** the .p8 file (SAVE THIS FILE - you can only download once!)
7. Note the **Key ID** (10 character string)
8. Note your **Team ID** (visible in Membership section)

## Step 2: Upload APNs Key to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Project Settings** (gear icon)
4. Click **Cloud Messaging** tab
5. Under **Apple app configuration**, click **Upload**
6. Upload the .p8 file you downloaded
7. Enter your **Key ID** and **Team ID**
8. Click **Upload**

## Step 3: Verify iOS Project Configuration

### Info.plist Configuration

The following entries should be in `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

### GoogleService-Info.plist

Verify `ios/Runner/GoogleService-Info.plist` exists and contains:
- Your bundle ID
- API key
- Project ID

### Xcode Capabilities

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Push Notifications**
6. Add **Background Modes** and check:
   - **Background fetch**
   - **Remote notifications**

## Step 4: Test Push Notifications

Push notifications cannot be tested on iOS Simulator. You must use a physical device.

1. Build and run on physical iOS device
2. Grant notification permission when prompted
3. Trigger a notification (e.g., have another user comment on your event)
4. Verify push notification appears

## Troubleshooting

### No push received

1. Check FCM token is saved in `fcm_tokens` table
2. Verify APNs key is correctly uploaded to Firebase
3. Check Edge Function logs in Supabase Dashboard
4. Ensure device has internet connection

### "NotRegistered" error

Token is invalid. App should auto-refresh, but try:
1. Uninstall and reinstall app
2. New token will be registered on login

### Badge not updating

1. Verify badge permission was granted
2. Check `badge` count in FCM payload

## References

- [Firebase iOS Push Setup](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [Apple Push Notification Service](https://developer.apple.com/documentation/usernotifications)
