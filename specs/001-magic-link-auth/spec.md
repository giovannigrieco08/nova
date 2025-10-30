# Feature Specification: Magic Link Authentication

**Feature Branch**: `001-magic-link-auth`
**Created**: 2025-10-30
**Status**: Draft
**Input**: User description: "Passwordless magic link authentication for Nova students with @galileimoro.edu.it email domain validation, 30-day sessions, Supabase Auth backend, including first login, returning user, session expired, and manual logout flows"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - First-Time Student Login (Priority: P1)

A student downloads the Nova app for the first time, opens it, enters their school email address (@galileimoro.edu.it), receives a magic link in their email inbox, clicks the link, and is automatically authenticated into the app showing the main event feed screen.

**Why this priority**: This is the foundational authentication flow - without it, no student can access the app. It's the absolute minimum viable functionality that delivers value (access to Nova).

**Independent Test**: Can be fully tested by installing the app on a fresh device, entering a valid @galileimoro.edu.it email, clicking the received magic link, and verifying the user lands on the feed screen with an active session. Delivers immediate value: student can now see school events.

**Acceptance Scenarios**:

1. **Given** the student opens Nova for the first time, **When** they see the login screen, **Then** they see an email input field with a hint showing "@galileimoro.edu.it", a "Send Magic Link" button, and explanatory text about passwordless login
2. **Given** the student enters a valid @galileimoro.edu.it email, **When** they tap "Send Magic Link", **Then** they see a confirmation message "Check your email for a magic link" within 2 seconds
3. **Given** the student receives the magic link email, **When** they click the link within 15 minutes, **Then** the Nova app opens automatically and they are authenticated to the main feed screen
4. **Given** the student successfully authenticates, **When** they check their session, **Then** they have a 30-day active session and won't need to re-authenticate until it expires
5. **Given** the student enters an email without the @galileimoro.edu.it domain, **When** they tap "Send Magic Link", **Then** they see an error message "Please use your school email (@galileimoro.edu.it)"

---

### User Story 2 - Returning Student Auto-Login (Priority: P2)

A student who previously authenticated opens the Nova app again within the 30-day session period and is automatically logged in without any authentication prompts, landing directly on the main feed screen.

**Why this priority**: This is the most frequent user interaction - returning users should have a seamless experience. Critical for daily engagement but depends on P1 being completed first.

**Independent Test**: Can be tested by authenticating a user via P1, closing the app, reopening it within 30 days, and verifying the user bypasses the login screen and lands directly on the feed. Delivers value: frictionless daily access to events.

**Acceptance Scenarios**:

1. **Given** a student has an active session (authenticated within the last 30 days), **When** they open the Nova app, **Then** they bypass the login screen and land directly on the main feed within 1 second
2. **Given** a student has an active session, **When** they use the app multiple times per day, **Then** they never see the login screen until their 30-day session expires
3. **Given** a student authenticated 29 days ago, **When** they open the app, **Then** they are still automatically logged in (session still valid)

---

### User Story 3 - Session Expired Re-Authentication (Priority: P2)

A student whose 30-day session has expired opens the Nova app and sees the login screen, re-enters their email address, receives a new magic link, clicks it, and is re-authenticated back into the app.

**Why this priority**: Essential for long-term user retention - students must be able to regain access after session expiration. Same priority as P2 because it's part of the seamless experience loop.

**Independent Test**: Can be tested by authenticating a user, manually expiring their session (or waiting 30 days), reopening the app, verifying the login screen appears, and completing the magic link flow again. Delivers value: students can always regain access.

**Acceptance Scenarios**:

1. **Given** a student's 30-day session has expired, **When** they open the Nova app, **Then** they see the login screen (same as first-time users)
2. **Given** the student is on the login screen after session expiration, **When** they re-enter their email and request a magic link, **Then** they receive a new magic link and can authenticate again
3. **Given** the student was previously authenticated (stored email), **When** they see the login screen, **Then** they must manually re-enter their email address (no pre-filled email for security)

---

### User Story 4 - Manual Logout (Priority: P3)

A student who is currently authenticated navigates to the app's Settings screen, taps the "Logout" button, confirms the logout action in a confirmation dialog, and is immediately logged out and returned to the login screen.

**Why this priority**: Nice-to-have for security-conscious students sharing devices, but not critical for core functionality. Most students will simply use the app until session expiration.

**Independent Test**: Can be tested by authenticating a user, navigating to Settings, tapping Logout, confirming, and verifying the user is returned to the login screen with no active session. Delivers value: students can secure their account on shared devices.

**Acceptance Scenarios**:

1. **Given** a student is authenticated and on the Settings screen, **When** they tap the "Logout" button, **Then** they see a confirmation dialog "Are you sure you want to logout?"
2. **Given** the student sees the logout confirmation dialog, **When** they tap "Confirm", **Then** their session is terminated and they are redirected to the login screen
3. **Given** the student taps "Confirm" on logout, **When** they try to access any authenticated screen, **Then** they are prevented and must re-authenticate
4. **Given** the student sees the logout confirmation dialog, **When** they tap "Cancel", **Then** the dialog closes and they remain logged in on the Settings screen

---

### Edge Cases

- **What happens when a student clicks an expired magic link (>15 minutes old)?** The link shows an error message "This magic link has expired. Please request a new one" and redirects to the login screen.

- **What happens when a student clicks a magic link that was already used once?** The link shows an error message "This magic link has already been used. Please request a new one if needed" (prevents replay attacks).

- **What happens when a student requests multiple magic links in quick succession?** After 3 requests within 15 minutes, the system shows "Too many requests. Please wait 15 minutes before requesting another magic link" (rate limiting).

- **What happens when a student's email inbox is full or email delivery fails?** The system shows "Magic link sent! Check your email (including spam folder)" - the app cannot detect delivery failures, so the student must troubleshoot email issues or retry.

- **What happens when a student clicks a magic link from a different device than they requested it from?** The magic link works on any device - it authenticates the user on whatever device clicks the link, creating a new session on that device.

- **What happens when a student has active sessions on multiple devices and logs out on one device?** Logout only terminates the session on the current device - other devices remain authenticated (sessions are device-specific).

- **What happens when a student enters a valid email format but wrong domain (e.g., @gmail.com)?** The system shows an error message immediately (before sending): "Please use your school email (@galileimoro.edu.it)".

- **What happens when a student tries to access the app with no internet connection?** If they have an active session, cached content may load; if they need to authenticate, they see "No internet connection. Please connect to Wi-Fi or mobile data."

- **What happens when a student enters an email address with uppercase letters (e.g., Mario.Rossi@galileimoro.edu.it)?** The system normalizes the email to lowercase before validation and storage (mario.rossi@galileimoro.edu.it).

- **What happens when the Supabase Auth service is temporarily down during magic link send?** The system shows an error message "Unable to send magic link. Please try again in a few moments" after a 10-second timeout.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST validate email addresses against the exact domain @galileimoro.edu.it (case-insensitive) using regex pattern `^[a-zA-Z0-9._%+-]+@galileimoro\.edu\.it$` and reject any emails not matching this pattern with a clear error message before attempting to send a magic link

- **FR-002**: System MUST generate magic links that expire exactly 15 minutes after creation, prevent reuse after a single successful authentication, and display appropriate error messages for expired or already-used links

- **FR-003**: System MUST deliver magic link emails with p95 latency under 2 seconds from the moment the user taps "Send Magic Link" to when the confirmation message appears (email delivery time excluded)

- **FR-004**: System MUST implement deep linking so that clicking a magic link on a mobile device automatically opens the Nova app (if installed) rather than opening in a web browser, using URL schemes like `nova://auth/verify`

- **FR-005**: System MUST establish 30-day session tokens (refresh tokens) upon successful magic link authentication that allow users to remain logged in without re-authenticating until the 30-day period elapses

- **FR-006**: System MUST automatically log out users whose 30-day session has expired, showing them the login screen on their next app launch with a message "Your session has expired. Please log in again"

- **FR-007**: System MUST provide a manual logout option accessible from the Settings screen that terminates the current session and returns the user to the login screen after confirmation

- **FR-008**: System MUST automatically create a new user account on first successful magic link authentication for any email matching @galileimoro.edu.it domain (no pre-registration or approval required)

- **FR-009**: System MUST bypass the login screen for users with active sessions (authenticated within the last 30 days) and navigate directly to the main feed screen on app launch

### Non-Functional Requirements

- **NFR-001**: Login flow MUST be optimized for 14-19 year old students with a modern, Instagram-inspired UI aesthetic using the Nova design system (NovaColors, NovaSpacing, NovaTypography, NovaGlassCard)

- **NFR-002**: Login screen MUST meet WCAG 2.1 Level AA accessibility standards with sufficient color contrast (4.5:1 for body text, 3:1 for large text) and support screen readers

- **NFR-003**: All authentication UI components MUST use exclusively the Nova design system constants - zero hardcoded colors, spacing, typography, or radius values are permitted

- **NFR-004**: Authentication flow MUST work offline-first for already-authenticated users (cached session validation) with graceful degradation showing "No internet connection" messages for unauthenticated users

- **NFR-005**: Magic link email template MUST be mobile-responsive, branded with Nova identity, and render correctly across email clients (Gmail, Outlook, Apple Mail) with a clear, prominent "Open Nova" button

### Security Requirements

- **SEC-001**: System MUST enforce single-use magic links by marking tokens as "consumed" in the database after first successful authentication and reject any subsequent attempts to use the same token

- **SEC-002**: System MUST transmit all authentication-related data (magic link generation, session token exchange, user profile fetching) exclusively over HTTPS connections with TLS 1.2 or higher

- **SEC-003**: System MUST set the `email_verified` flag to `true` in the user profile upon successful magic link authentication (clicking the link proves email ownership)

- **SEC-004**: System MUST NOT store, hash, or process passwords in any form - the entire authentication architecture is passwordless (no password fields, no password reset flows)

- **SEC-005**: System MUST implement Supabase Row-Level Security (RLS) policies ensuring each authenticated user can only access their own data (user profile, event RSVPs, comments)

- **SEC-006**: System MUST rate-limit magic link requests to maximum 3 requests per email address per 15-minute sliding window, displaying "Too many requests" error and countdown timer for blocked users

### Privacy Requirements

- **PRIV-001**: System MUST collect only the minimum data required during authentication: email address during magic link request, and basic profile metadata (user ID, email, email_verified, created_at, last_login_at) upon successful authentication

- **PRIV-002**: System MUST comply with GDPR Right to Erasure (Article 17) by providing a mechanism for users to permanently delete their account and all associated data through the Settings screen

- **PRIV-003**: System MUST NOT integrate any third-party tracking, analytics, or advertising services during the authentication flow (zero cookies or scripts from Google Analytics, Facebook Pixel, etc.)

- **PRIV-004**: System MUST NOT share, sell, or transmit user email addresses or authentication data to any external services beyond the Supabase Auth backend (which is the designated authentication provider)

### Key Entities *(mandatory)*

- **User**: Represents a student authenticated via magic link. Key attributes include: unique identifier (UUID), email address (must match @galileimoro.edu.it), email verification status (set to true upon magic link auth), account creation timestamp, and last login timestamp. Each user has a one-to-one relationship with their authentication session.

- **Session**: Represents an active authentication session for a user on a specific device. Key attributes include: foreign key to User (many-to-one relationship), refresh token (JWT format), session expiration timestamp (30 days from creation), device information (optional metadata for multi-device tracking), and session creation timestamp.

- **MagicLinkAttempt**: Represents an email-based magic link request for audit and rate-limiting purposes. Key attributes include: email address (not necessarily linked to a User if first-time), request timestamp, email sent timestamp, link expiration timestamp (15 minutes from creation), link usage timestamp (null until clicked), and status (pending, sent, expired, consumed, failed).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-P001**: Users receive authentication email within 2 seconds (p95 latency) from tapping "Send Magic Link" button to seeing confirmation message on screen

- **SC-P002**: Returning users with active sessions see the main feed screen within 1 second of opening the app (95% of cold starts, measured from app launch to feed render)

- **SC-UX001**: First-time users complete the entire authentication flow (email entry → magic link click → authenticated to feed) in under 2 minutes with >90% completion rate

- **SC-UX002**: User satisfaction with passwordless authentication experience averages >4.5/5 stars in post-authentication survey or app store reviews mentioning login

- **SC-SEC001**: Zero magic link reuse incidents (100% of already-used tokens are rejected with appropriate error messages)

- **SC-SEC002**: Email domain validation achieves 100% accuracy (zero false positives allowing non-@galileimoro.edu.it emails, zero false negatives rejecting valid school emails)

- **SC-BIZ001**: Zero support tickets or user complaints related to "password reset", "forgot password", or "password not working" (benefit of passwordless architecture)

- **SC-BIZ002**: Authentication error rate (failed magic link sends, expired links, rate limiting) affects <5% of total authentication attempts

- **SC-ADO001**: Median session duration (time between first login and session expiration or manual logout) exceeds 25 days (indicating users remain engaged with long-lived sessions)

- **SC-ADO002**: Daily active user (DAU) retention rate >70% after initial authentication (indicating successful session management and re-engagement)

## Assumptions

The following assumptions have been made in the absence of explicit clarification. If any assumption is incorrect, the specification may need revision.

1. **Supabase Auth Magic Link Behavior**: We assume Supabase Auth's built-in magic link functionality provides automatic token generation, expiration (configurable to 15 minutes), single-use enforcement, and email delivery integration. If Supabase does not support these features natively, custom implementation will be required.

2. **Session Management Pattern**: We assume the standard OAuth2-style refresh token pattern with 30-day expiration is supported by Supabase Auth (configurable via `REFRESH_TOKEN_EXPIRY` setting). If not, custom session management logic will be needed.

3. **Deep Linking Setup**: We assume the Flutter `uni_links` package (or similar) can be configured to handle `nova://auth/verify?token=...` URL schemes on both iOS and Android, and that the Nova app will be registered with the appropriate URL scheme in platform-specific configuration files (AndroidManifest.xml, Info.plist).

4. **Email Delivery Service**: We assume Supabase Auth integrates with a reliable transactional email service (e.g., SendGrid, AWS SES) configured by the Nova backend team, and that SMTP credentials/API keys are properly configured in the Supabase project settings.

5. **Multi-Device Strategy**: We assume that each device gets an independent 30-day session (device-specific sessions) rather than a single shared session across all devices. This means logging out on one device does NOT log out other devices.

6. **Email Normalization**: We assume all email addresses are normalized to lowercase before storage and validation (e.g., Mario.Rossi@galileimoro.edu.it → mario.rossi@galileimoro.edu.it) to prevent duplicate accounts due to case differences.

7. **Session Expiration Choice**: Per clarification Q1, we assume that when a student's session expires after 30 days, they must manually re-enter their email address on the login screen (no pre-filled email or automatic magic link send). This is recommended option B for better security.

8. **Rate Limiting Parameters**: Per clarification Q2, we assume the rate limit is set to 3 magic link requests per email per 15-minute sliding window (recommended option A). This balances user convenience with protection against abuse.

9. **Auto-Registration Policy**: Per clarification Q3, we assume any email matching @galileimoro.edu.it domain is automatically approved for account creation upon first magic link authentication (recommended option A). No pre-registration whitelist or manual approval is required.

## Constitution Check

This feature has been evaluated against Nova's 7 core principles:

- **✅ STUDENTS_FIRST**: Passwordless authentication eliminates the frustration of remembering complex passwords for 14-19 year olds, provides a familiar "magic link" UX pattern common in modern apps (Instagram, TikTok), and prioritizes speed (<2s magic link) over administrative complexity.

- **✅ PRIVACY_FOUNDATION**: Collects only email address during authentication (minimal data collection), implements GDPR Right to Erasure (account deletion), uses zero third-party tracking during login flow, and keeps email data within Supabase (designated auth provider, no external sharing).

- **✅ SIMPLICITY_FIRST**: Passwordless architecture eliminates password reset flows, password complexity requirements, and password storage security concerns. Single-button authentication ("Send Magic Link") is simpler than traditional email/password forms. No separate signup flow (auto-account creation).

- **✅ PERFORMANCE_FIRST**: Explicit performance targets defined: <2s magic link delivery (p95), <1s returning user authentication (95% cold starts). 30-day sessions minimize repeated authentication overhead. Deep linking provides instant app opening (no manual copy-paste).

- **✅ SPEC_FIRST**: This comprehensive specification is being created BEFORE any implementation work begins, following SpecKit methodology (specify → clarify → plan → tasks → implement).

- **✅ DESIGN_SYSTEM_STRICT**: All authentication UI components will reference Nova design system constants: NovaColors (primary color, text colors, background), NovaSpacing (screen padding, button spacing), NovaTypography (input labels, button text), NovaGlassCard (login card with liquid glass effect), NovaRadius (input field corners). Zero hardcoded values permitted.

- **⚪ CONTENT_MODERATION**: Not applicable - authentication feature does not involve user-generated content requiring moderation.

**Constitution Compliance**: 100% (6/6 applicable principles)

## Out of Scope

The following items are explicitly excluded from this feature specification to maintain focus and manage complexity:

- **Social Login**: OAuth integration with Google, Apple, Facebook, or other social providers is not included. Only email-based magic link authentication is in scope.

- **Biometric Authentication**: Fingerprint, Face ID, or other biometric login methods are not included. Students must use magic link for initial authentication (though biometric unlock after initial auth could be considered in a future iteration).

- **Multi-Device Session Management UI**: No admin panel or Settings screen showing "Active Devices" with ability to remotely log out other devices. Each device has an independent session, and manual logout only affects the current device.

- **Password Recovery Flows**: Since this is passwordless authentication, there are no "forgot password", "reset password", or "change password" features.

- **Admin Approval for New Users**: Every student with a valid @galileimoro.edu.it email is automatically approved for account creation. No teacher/admin approval workflow is included.

- **Custom Email Templates with Branding**: While the magic link email must be branded with Nova identity, extensive customization of email templates (personalized greetings, dynamic content, A/B testing) is out of scope. Basic Supabase Auth email template with Nova logo and colors is sufficient.

- **Advanced Rate Limiting (per-IP, per-device)**: Rate limiting is implemented per-email address only (3 requests per 15 minutes). More sophisticated rate limiting by IP address, device fingerprinting, or CAPTCHA challenges is not included.

## Design References

All authentication UI components must follow the Nova Design System as specified in [specs/design-system.md](../design-system.md):

- **Colors**: Use `NovaColors.primaryLight` / `NovaColors.primaryDark` for the "Send Magic Link" button (purple #8B5CF6), `NovaColors.backgroundLight` / `NovaColors.backgroundDark` for screen background, `NovaColors.textPrimaryLight` / `NovaColors.textPrimaryDark` for input labels and body text

- **Typography**: Use `NovaTypography.h1` for screen title ("Welcome to Nova"), `NovaTypography.body` for input labels and instructions (15px Inter font), `NovaTypography.button` for button text (14px Inter Medium)

- **Spacing**: Use `NovaSpacing.l` (16px) for screen padding, `NovaSpacing.m` (12px) for spacing between elements (email input and button), `NovaSpacing.s` (8px) for smaller gaps

- **Glass Effect**: Use `NovaGlassCard` widget with `GlassLevel.subtle` for the login card container to achieve the Instagram-inspired liquid glass aesthetic

- **Border Radius**: Use `NovaRadius.circularS` (8px) for input field corners and button corners, `NovaRadius.circularM` (16px) for the login card container

- **Shadows**: Use `NovaShadows.small` for the login card elevation (subtle shadow for depth)

- **Icons**: Use `NovaIconSizes.m` (24px) for any icons in the authentication flow (e.g., email icon in input field prefix)
