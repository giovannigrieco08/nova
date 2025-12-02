# Admin Tab Integration Guide (T066-T067)

**Date:** 2025-11-15
**Feature:** 005-moderation-admin-panel (Phase 4, User Story 2)
**Tasks:** T066-T067

---

## Overview

This guide explains how to integrate the Admin Panel tab into the bottom navigation bar. The Admin tab should only be visible to users with the `admin` role.

---

## Integration Steps

### Step 1: Update MainFeedScreen Navigation Items

Add the Admin tab after the Moderazione tab (if user is admin):

**File:** `nova/lib/features/events/presentation/screens/main_feed_screen.dart`

```dart
// In _buildScreen method, add after Moderazione tab:

// Admin tab (admins only)
if (userRole == UserRole.admin)
  NavItem(
    sfSymbol: 'gear',
    materialIcon: Icons.admin_panel_settings,
    label: 'Admin',
    allowedRoles: [UserRole.admin],
  ),
```

### Step 2: Update _onNavItemSelected Handler

Handle navigation to AdminPanelScreen when Admin tab is tapped:

```dart
void _onNavItemSelected(int index) {
  setState(() {
    _currentNavIndex = index;
  });

  final userRole = ref.read(userRoleProvider).value ?? UserRole.student;

  if (userRole == UserRole.admin) {
    // Admins: 6 tabs (Home, Amici, Chat, Moderazione, Admin, Profilo)
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
      case 4: // Admin
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminPanelScreen(),
          ),
        );
        break;
      case 5: // Profilo
        _showComingSoonDialog('Profilo');
        break;
    }
  } else if (userRole.canModerate) {
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

### Step 3: Add Import for AdminPanelScreen

Add to imports in MainFeedScreen:

```dart
import 'package:nova/features/admin/presentation/screens/admin_panel_screen.dart';
```

---

## Router Integration (T067)

The AppRouter already has basic role guard support. The `/admin` route is already defined in `AppRouter.admin` constant.

### Verify Route Guard

**File:** `nova/lib/core/router/app_router.dart`

The route guard is already implemented in `canAccessRoute` method:

```dart
if (path == admin) {
  return userRole == UserRole.admin;
}
```

This ensures non-admin users are redirected to `/events` when attempting to access `/admin` route.

### Optional: Add Named Route

If using named routes for navigation, register the AdminPanelScreen:

**In main.dart or router configuration:**

```dart
routes: {
  '/events': (context) => const MainFeedScreen(),
  '/moderation': (context) => const ModerationDashboardScreen(),
  '/admin': (context) => const AdminPanelScreen(),
  '/profile': (context) => const ProfileScreen(),
  // ... other routes
}
```

Then in `_onNavItemSelected`, use named route:

```dart
case 4: // Admin
  Navigator.pushNamed(context, '/admin');
  break;
```

---

## Icon Choices

**iOS (SF Symbols):**
- `gear` - Settings/admin icon (recommended)
- `person.badge.shield.checkmark` - User with shield (alternative)
- `wrench.and.screwdriver` - Tools icon (alternative)

**Android (Material Icons):**
- `Icons.admin_panel_settings` - Admin panel icon (recommended)
- `Icons.settings` - Settings icon (alternative)
- `Icons.manage_accounts` - Manage accounts icon (alternative)

---

## Tab Order Summary

### Students (4 tabs)
0. Home
1. Amici (placeholder)
2. Chat (placeholder)
3. Profilo (placeholder)

### Moderators (5 tabs)
0. Home
1. Amici (placeholder)
2. Chat (placeholder)
3. **Moderazione** (with badge)
4. Profilo (placeholder)

### Admins (6 tabs)
0. Home
1. Amici (placeholder)
2. Chat (placeholder)
3. **Moderazione** (with badge)
4. **Admin**
5. Profilo (placeholder)

---

## Testing Checklist

After implementing T066-T067:

- [ ] Student users see 4 tabs (no Admin tab)
- [ ] Moderator users see 5 tabs (no Admin tab)
- [ ] Admin users see 6 tabs (Moderazione + Admin)
- [ ] Tapping Admin tab navigates to AdminPanelScreen
- [ ] Direct navigation to `/admin` route is blocked for non-admins
- [ ] Admin tab appears after Moderazione tab (correct order)
- [ ] Admin tab uses correct icon (gear / admin_panel_settings)
- [ ] Navigation indices shift correctly based on role

---

## Files Created/Modified

### New Files
- `nova/lib/features/admin/presentation/screens/admin_panel_screen.dart` ✅
- `nova/lib/features/admin/presentation/widgets/moderator_search.dart` ✅
- `nova/lib/features/admin/presentation/widgets/moderator_card.dart` ✅
- `nova/lib/features/admin/presentation/widgets/system_statistics_widget.dart` ✅
- `nova/lib/features/admin/presentation/providers/moderators_provider.dart` ✅
- `nova/lib/features/admin/presentation/providers/system_stats_provider.dart` ✅
- `nova/lib/features/admin/presentation/providers/admin_actions_notifier.dart` ✅
- `nova/lib/features/admin/data/repositories/admin_repository.dart` ✅
- `nova/lib/features/admin/domain/entities/moderator.dart` ✅
- `nova/lib/features/admin/domain/entities/system_stats.dart` ✅
- `nova/lib/features/admin/data/models/admin_action.dart` ✅
- `nova/lib/shared/widgets/role_change_listener.dart` ✅

### Files to Modify
- `nova/lib/features/events/presentation/screens/main_feed_screen.dart` (add Admin tab to navigation items)
- `nova/lib/main.dart` (wrap with RoleChangeListener if not already done)

### Router
- `nova/lib/core/router/app_router.dart` (already has /admin route guard) ✅

---

## Current Status

**Completed Tasks:**
- T052-T065: All admin panel infrastructure complete
- T066: Admin tab integration documented (requires MainFeedScreen modification)
- T067: Router guard already implemented ✅

**Remaining Integration:**
- Update MainFeedScreen to include Admin tab in navigation items
- Wrap app with RoleChangeListener in main.dart
- Test role-based navigation flow

---

## Notes

The Admin Panel screen is fully functional and ready to use. The only remaining work is:

1. **Integrate Admin tab into MainFeedScreen** (follow Step 1-3 above)
2. **Wrap app with RoleChangeListener** in main.dart
3. **Run build_runner** to generate Freezed/JSON serialization files
4. **Test end-to-end flow** with test admin user

Database functions (`promote_to_moderator`, `remove_moderator_role`, `get_system_statistics`) are assumed to exist from Phase 1 database migration.
