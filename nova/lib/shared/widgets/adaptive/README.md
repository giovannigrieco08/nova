# Nova Adaptive Widgets

Platform-adaptive widgets that automatically render native iOS (Cupertino) or Android (Material 3) components.

## Overview

This directory contains widgets that provide a unified API while rendering platform-appropriate native components:

- **iOS**: Uses Cupertino widgets and `cupertino_native` for UIKit-native components
- **Android**: Uses Material 3 widgets

## Available Widgets

### Navigation

#### AdaptiveScaffold
```dart
AdaptiveScaffold(
  appBar: AdaptiveAppBar(title: Text('Home')),
  body: MyContent(),
  bottomNavigationBar: AdaptiveBottomNavBar(...),
)
```
- **iOS**: `CupertinoPageScaffold`
- **Android**: `Scaffold`

#### AdaptiveAppBar
```dart
// Standard app bar
AdaptiveAppBar(
  title: Text('Events'),
  actions: [IconButton(...)],
)

// iOS Large Title (requires CustomScrollView)
CustomScrollView(
  slivers: [
    SliverToBoxAdapter(
      child: AdaptiveAppBar(
        title: Text('Events'),
        large: true,  // iOS large title
      ),
    ),
    SliverList(...),
  ],
)
```
- **iOS**: `CupertinoNavigationBar` or `CupertinoSliverNavigationBar` (large title)
- **Android**: `AppBar`

#### AdaptiveBottomNavBar
```dart
AdaptiveBottomNavBar(
  currentIndex: _index,
  onTap: (index) => setState(() => _index = index),
  items: [
    BottomNavItem(
      label: 'Home',
      iconSystemName: 'house.fill',  // iOS SF Symbol
      androidIcon: Icons.home,         // Android Material
    ),
  ],
  centerWidget: FloatingActionButton(...),  // Optional
)
```
- **iOS**: `CNTabBar` (native UIKit) with blur background
- **Android**: `NavigationBar` Material 3

### Content

#### AdaptiveCard
```dart
AdaptiveCard(
  child: Column(...),
  padding: EdgeInsets.all(16),
)
```
- **iOS**: `GlassContainer` with glassmorphism
- **Android**: `Material` surface with elevation

#### AdaptiveButton
```dart
AdaptiveButton(
  type: AdaptiveButtonType.primary,
  onPressed: () => print('Pressed'),
  child: Text('Save'),
)
```
- **iOS**: `CupertinoButton`
- **Android**: `FilledButton` / `OutlinedButton` / `TextButton` (Material 3)

**Button Types:**
- `primary`: Filled button
- `secondary`: Outlined button
- `destructive`: Red/warning button
- `text`: Text-only button

#### AdaptiveTextField
```dart
AdaptiveTextField(
  label: 'Email',
  placeholder: 'Enter your email',
  controller: _emailController,
  keyboardType: TextInputType.emailAddress,
)
```
- **iOS**: `CupertinoTextField` with label above
- **Android**: `TextField` Material with filled decoration

### Form Controls

#### AdaptiveSwitch
```dart
AdaptiveSwitch(
  value: _enabled,
  onChanged: (value) => setState(() => _enabled = value),
)
```
- **iOS**: `CNSwitch` (native UIKit)
- **Android**: `Switch` Material

#### AdaptiveSlider
```dart
AdaptiveSlider(
  value: _volume,
  min: 0,
  max: 100,
  onChanged: (value) => setState(() => _volume = value),
)
```
- **iOS**: `CNSlider` (native UIKit)
- **Android**: `Slider` Material

#### AdaptiveSegmentedControl
```dart
AdaptiveSegmentedControl<String>(
  groupValue: _selected,
  onValueChanged: (value) => setState(() => _selected = value),
  children: {
    'option1': 'Option 1',
    'option2': 'Option 2',
  },
)
```
- **iOS**: `CNSegmentedControl` (native UIKit)
- **Android**: `SegmentedButton` Material 3

### Feedback

#### AdaptiveLoadingIndicator
```dart
AdaptiveLoadingIndicator()
```
- **iOS**: `CupertinoActivityIndicator`
- **Android**: `CircularProgressIndicator`

#### AdaptiveDialog
```dart
AdaptiveDialog.show(
  context: context,
  title: 'Delete Event',
  content: 'Are you sure?',
  actions: [
    AdaptiveDialogAction(
      text: 'Cancel',
      onPressed: () {},
    ),
    AdaptiveDialogAction(
      text: 'Delete',
      isDestructiveAction: true,
      onPressed: () => _deleteEvent(),
    ),
  ],
)
```
- **iOS**: `CupertinoAlertDialog`
- **Android**: `AlertDialog` Material

#### AdaptiveActionSheet
```dart
AdaptiveActionSheet.show(
  context: context,
  title: 'Choose Action',
  actions: [...],
  cancelAction: AdaptiveDialogAction(
    text: 'Cancel',
    onPressed: () {},
  ),
)
```
- **iOS**: `CupertinoActionSheet`
- **Android**: `AlertDialog` (fallback)

#### AdaptiveBottomSheet
```dart
AdaptiveBottomSheet.show(
  context: context,
  title: 'Options',
  child: ListView(...),
)
```
- **iOS**: `CupertinoModalPopup`
- **Android**: `showModalBottomSheet` with `DraggableScrollableSheet`

## Icons - NovaIcons

Use `NovaIcons` for platform-adaptive icons:

```dart
// Returns Widget (not IconData)
NovaIcons.home(context)
NovaIcons.camera(context, size: 32, color: Colors.white)
NovaIcons.notifications(context)
```

**iOS**: Native SF Symbols via `CNIcon` from cupertino_native
**Android**: Material Icons

### Available Icons

- Navigation: `home`, `events`, `camera`, `chat`, `profile`
- Actions: `notifications`, `heart`, `search`, `settings`, `share`
- Navigation: `chevronRight`, `chevronLeft`, `close`, `add`, `check`
- Content: `location`, `calendar`, `more`, `photo`, `person`
- Status: `info`, `warning`, `error`, `success`

## Design Consistency

All adaptive widgets maintain visual consistency:

- **Same color palette**: `NovaColors` used on both platforms
- **Same spacing**: `NovaSpacing` constants
- **Same typography**: `NovaTypography` (Inter font) on both platforms
- **Same border radius**: `NovaRadius`
- **Platform-appropriate feedback**: Haptic (iOS) vs Ripple (Android)

## Migration Guide

### From Custom Widgets

| Old Widget | New Widget |
|------------|------------|
| `NovaAppBar` | `AdaptiveAppBar` |
| `NovaBottomNavBar` | `AdaptiveBottomNavBar` |
| `GlassContainer` | `AdaptiveCard` |
| Custom buttons | `AdaptiveButton` |
| `TextField` | `AdaptiveTextField` |
| `CircularProgressIndicator` | `AdaptiveLoadingIndicator` |
| `showDialog` | `AdaptiveDialog.show` |
| Hardcoded `Icons.*` | `NovaIcons.*` |

### Example Migration

**Before:**
```dart
Scaffold(
  appBar: NovaAppBar(title: 'Events'),
  body: ListView(
    children: [
      GlassContainer(
        child: EventCard(),
      ),
    ],
  ),
  bottomNavigationBar: NovaBottomNavBar(),
)
```

**After:**
```dart
AdaptiveScaffold(
  appBar: AdaptiveAppBar(
    title: Text('Events'),
    large: true,  // iOS large title
  ),
  body: CustomScrollView(
    slivers: [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => AdaptiveCard(
            child: EventCard(),
          ),
        ),
      ),
    ],
  ),
  bottomNavigationBar: AdaptiveBottomNavBar(...),
)
```

## Platform Detection

Use `context.isIOS` / `context.isAndroid` for custom platform logic:

```dart
if (context.isIOS) {
  // iOS-specific code
} else {
  // Android-specific code
}

// Or adaptive value helper
final padding = context.adaptive(
  EdgeInsets.all(8),   // iOS
  EdgeInsets.all(16),  // Android
);
```

## Dependencies

- **cupertino_native**: Native UIKit components (iOS only, requires Xcode 26 beta)
- **Flutter built-in**: All Material and Cupertino widgets

## Notes

- Adaptive widgets automatically detect platform at runtime
- No need to manually check platform in feature code
- Maintains single codebase with native feel on each platform
- iOS glassmorphism vs Android elevation creates appropriate depth on each platform
