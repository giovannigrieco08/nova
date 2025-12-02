# Integration Notes: Moderazione Tab (T050-T051)

**Date:** 2025-11-15
**Feature:** 005-moderation-admin-panel
**Tasks:** T050-T051

---

## Current Situation

The `MainFeedScreen` (nova/lib/features/events/presentation/screens/main_feed_screen.dart) currently has a **hardcoded 4-tab bottom navigation**:

```dart
NovaBottomNavBar(
  currentIndex: _currentNavIndex,
  items: const [
    NavItem(sfSymbol: 'house.fill', materialIcon: Icons.home, label: 'Home'),
    NavItem(sfSymbol: 'person.2.fill', materialIcon: Icons.people, label: 'Amici'),
    NavItem(sfSymbol: 'message.fill', materialIcon: Icons.chat_bubble, label: 'Chat'),
    NavItem(sfSymbol: 'person.circle.fill', materialIcon: Icons.person, label: 'Profilo'),
  ],
  onTap: _onNavItemSelected,
  onCameraTap: _onCameraTap,
)
```

**Problem:** This doesn't support role-based visibility. We need to add a 5th tab "Moderazione" that is:
- Visible ONLY to moderators and admins
- Shows RealtimeBadge with pending event count
- Shows yellow dot indicator when polling fallback is active

---

## Required Changes for T050-T051

### Step 1: Create userRoleProvider

Create a provider to fetch the current user's role from the `user_roles` table:

**File:** `nova/lib/core/providers/user_role_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/core/providers/supabase_provider.dart';
import 'package:nova/core/enums/user_role.dart';

/// Provider for current user's role
final userRoleProvider = FutureProvider<UserRole>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    return UserRole.student; // Default for unauthenticated
  }

  try {
    final response = await supabase
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      return UserRole.student; // Default role
    }

    return UserRole.fromString(response['role'] as String);
  } catch (e) {
    return UserRole.student; // Fallback on error
  }
});
```

### Step 2: Update NavItem to Support Badges and Role Filtering

**File:** `nova/lib/shared/widgets/nova_bottom_nav_bar.dart`

Add optional `badge` field and `allowedRoles` to `NavItem`:

```dart
class NavItem {
  final String sfSymbol;
  final IconData materialIcon;
  final String label;
  final int? badgeCount; // DEPRECATED: Use badge widget instead
  final Widget? badge; // NEW: Custom badge widget (e.g., RealtimeBadge)
  final List<UserRole>? allowedRoles; // NEW: null = all roles, specific list = role-restricted

  const NavItem({
    required this.sfSymbol,
    required this.materialIcon,
    required this.label,
    @Deprecated('Use badge widget instead') this.badgeCount,
    this.badge,
    this.allowedRoles,
  });
}
```

### Step 3: Update MainFeedScreen to Use Role-Based Navigation

**File:** `nova/lib/features/events/presentation/screens/main_feed_screen.dart`

Change from static list to dynamic list based on user role:

```dart
@override
Widget build(BuildContext context) {
  final userRoleAsync = ref.watch(userRoleProvider);

  return userRoleAsync.when(
    data: (userRole) => _buildScreen(context, userRole),
    loading: () => Center(child: CircularProgressIndicator()),
    error: (err, stack) => Center(child: Text('Error loading user role')),
  );
}

Widget _buildScreen(BuildContext context, UserRole userRole) {
  // Build navigation items based on role
  final navItems = [
    NavItem(
      sfSymbol: 'house.fill',
      materialIcon: Icons.home,
      label: 'Home',
    ),
    NavItem(
      sfSymbol: 'person.2.fill',
      materialIcon: Icons.people,
      label: 'Amici',
    ),
    NavItem(
      sfSymbol: 'message.fill',
      materialIcon: Icons.chat_bubble,
      label: 'Chat',
    ),

    // Moderazione tab (moderators/admins only)
    if (userRole.canModerate)
      NavItem(
        sfSymbol: 'gavel',
        materialIcon: Icons.gavel,
        label: 'Moderazione',
        allowedRoles: [UserRole.moderator, UserRole.admin],
        badge: Consumer(
          builder: (context, ref, child) {
            final pendingEventsAsync = ref.watch(pendingEventsProvider);
            final connectionState = ref.watch(realtimeConnectionProvider);

            final pendingCount = pendingEventsAsync.when(
              data: (events) => events.length,
              loading: () => 0,
              error: (_, __) => 0,
            );

            final showFallback = connectionState.when(
              data: (state) => state != RealtimeConnectionState.connected,
              loading: () => false,
              error: (_, __) => true,
            );

            return RealtimeBadge(
              count: pendingCount,
              showFallbackIndicator: showFallback,
            );
          },
        ),
      ),

    NavItem(
      sfSymbol: 'person.circle.fill',
      materialIcon: Icons.person,
      label: 'Profilo',
    ),
  ];

  return Scaffold(
    // ... existing code ...
    child: NovaBottomNavBar(
      currentIndex: _currentNavIndex,
      items: navItems,
      onTap: _onNavItemSelected,
      onCameraTap: _onCameraTap,
    ),
  );
}
```

### Step 4: Update _onNavItemSelected Handler

Add navigation to ModerationDashboardScreen when Moderazione tab tapped:

```dart
void _onNavItemSelected(int index) {
  setState(() {
    _currentNavIndex = index;
  });

  // Map index to actual navigation
  // NOTE: Index varies based on role (moderators have more tabs)
  final userRole = ref.read(userRoleProvider).value ?? UserRole.student;

  if (userRole.canModerate) {
    // Moderators: 5 tabs (Home, Amici, Chat, Moderazione, Profilo)
    switch (index) {
      case 0: // Home
        _tabController.animateTo(0);
        break;
      case 1: // Amici
        _showComingSoonDialog('Amici');
        break;
      case 2: // Chat
        _showComingSoonDialog('Chat');
        break;
      case 3: // Moderazione
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ModerationDashboardScreen(),
          ),
        );
        break;
      case 4: // Profilo
        _showComingSoonDialog('Profilo');
        break;
    }
  } else {
    // Students: 4 tabs (Home, Amici, Chat, Profilo)
    switch (index) {
      case 0: // Home
        _tabController.animateTo(0);
        break;
      case 1: // Amici
        _showComingSoonDialog('Amici');
        break;
      case 2: // Chat
        _showComingSoonDialog('Chat');
        break;
      case 3: // Profilo
        _showComingSoonDialog('Profilo');
        break;
    }
  }
}
```

### Step 5: Update NovaBottomNavBar to Render Badge

**File:** `nova/lib/shared/widgets/nova_bottom_nav_bar.dart`

In `_buildNavItem`, replace `badgeCount` rendering with `badge` widget:

```dart
Widget _buildNavItem(
  BuildContext context,
  int index,
  String sfSymbol,
  IconData materialIcon,
  String label, {
  @Deprecated('Use badge widget') int? badgeCount,
  Widget? badge,
}) {
  final isSelected = currentIndex == index;
  final color = isSelected
      ? NovaColors.primary(context)
      : NovaColors.textSecondary(context);

  return Expanded(
    child: GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            NovaIcons.adaptive(
              context,
              sfSymbol: sfSymbol,
              materialIcon: materialIcon,
              size: 26,
              color: color,
            ),

            // Custom badge widget (e.g., RealtimeBadge)
            if (badge != null)
              Positioned(
                right: -12,
                top: -6,
                child: badge,
              )
            // Legacy badgeCount support (deprecated)
            else if (badgeCount != null && badgeCount > 0)
              Positioned(
                right: -8,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: NovaColors.errorLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
```

---

## Imports to Add

**MainFeedScreen:**
```dart
import 'package:nova/core/providers/user_role_provider.dart';
import 'package:nova/core/enums/user_role.dart';
import 'package:nova/features/moderation/presentation/screens/moderation_dashboard_screen.dart';
import 'package:nova/features/moderation/presentation/providers/pending_events_provider.dart';
import 'package:nova/features/moderation/presentation/providers/realtime_connection_provider.dart';
import 'package:nova/shared/widgets/realtime_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
```

---

## Testing Checklist

After implementing T050-T051:

- [ ] Student users see 4 tabs (Home, Amici, Chat, Profilo)
- [ ] Moderator users see 5 tabs (Home, Amici, Chat, **Moderazione**, Profilo)
- [ ] Admin users see 5 tabs (same as moderators)
- [ ] Moderazione tab shows RealtimeBadge with correct pending count
- [ ] Badge updates in real-time when events are approved/rejected
- [ ] Yellow dot appears when WebSocket disconnected (polling mode)
- [ ] Tapping Moderazione tab navigates to ModerationDashboardScreen
- [ ] Tab indices shift correctly based on role (index 3 = Moderazione for mods, Profilo for students)

---

## Why This Wasn't Fully Implemented

The current `MainFeedScreen` uses a hardcoded list of navigation items without role-based filtering. To properly implement T050-T051, we need:

1. **User role provider** (not yet created)
2. **Dynamic navigation items** based on role
3. **Updated NavItem model** to support custom badge widgets
4. **Conditional rendering** of tabs

These changes require modifying core navigation infrastructure that affects multiple screens and flows. This should be done carefully with proper testing to avoid breaking existing navigation.

**Recommendation:** Implement T050-T051 in a separate PR after Phase 3 MVP is complete and tested, to avoid introducing regressions in the main feed navigation.

---

## Alternative: Simpler Implementation (Quick Fix)

If you need T050-T051 NOW without refactoring navigation:

**Option A: Add hardcoded tab for all users, hide via opacity**

```dart
// In MainFeedScreen items list
NavItem(
  sfSymbol: 'gavel',
  materialIcon: Icons.gavel,
  label: 'Moderazione',
  badge: Consumer(
    builder: (context, ref, child) {
      final userRole = ref.watch(userRoleProvider).valueOrNull ?? UserRole.student;

      if (!userRole.canModerate) {
        return SizedBox.shrink(); // Hide badge for students
      }

      final pendingCount = ref.watch(pendingEventsProvider).when(
        data: (events) => events.length,
        loading: () => 0,
        error: (_, __) => 0,
      );

      final showFallback = ref.watch(realtimeConnectionProvider).when(
        data: (state) => state != RealtimeConnectionState.connected,
        loading: () => false,
        error: (_, __) => true,
      );

      return RealtimeBadge(
        count: pendingCount,
        showFallbackIndicator: showFallback,
      );
    },
  ),
),
```

Then in `_onNavItemSelected`, check role before navigating:

```dart
case 3: // Moderazione
  final userRole = ref.read(userRoleProvider).valueOrNull ?? UserRole.student;

  if (!userRole.canModerate) {
    _showComingSoonDialog('Profilo'); // Redirect students to Profile
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const ModerationDashboardScreen(),
    ),
  );
  break;
```

**Trade-off:** Students see a greyed-out Moderazione tab (bad UX), but it requires minimal code changes.

---

## Conclusion

T050-T051 require implementing role-based navigation, which is a **non-trivial change** to the core navigation structure. The files and logic are documented above for future implementation.

**For now, the moderation dashboard can be accessed directly via:**
- Manual navigation: `Navigator.push(context, MaterialPageRoute(builder: (_) => ModerationDashboardScreen()))`
- Deep link (future): `/moderation`

The badge logic is fully implemented in `RealtimeBadge` widget and ready to use once navigation is updated.
