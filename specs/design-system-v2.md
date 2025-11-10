# Nova Design System v2.0 (Native-First)

**Version:** 2.0.0
**Last Updated:** 2025-11-10
**Project:** Nova - School Events Platform for Liceo Galilei Moro
**Replaces:** design-system.md v1.0 (archived due to custom library conflicts)

---

## 1. Introduction

### What Changed in v2.0

**v1.0 Approach (DEPRECATED):**
- Custom liquid glass via `liquid_glass_renderer` (DEV package, unstable)
- Custom typography via `google_fonts` (Inter font, +2MB APK size)
- Custom color palette (NovaColors)
- Custom animations and transitions

**v2.0 Approach (CURRENT):**
- **Native iOS**: Cupertino widgets (`cupertino_native` package) + SF Pro font
- **Native Android**: Material Design 3 widgets + Roboto font
- **Native glass effect**: `BackdropFilter` (built-in Flutter, GPU-accelerated)
- **Native colors**: `CupertinoColors` (iOS) + Material `ColorScheme` (Android)
- **Universal spacing**: `NovaSpacing` constants (works across both platforms)

### Why We Switched to Native-First

| Problem (v1.0) | Solution (v2.0) |
|----------------|-----------------|
| `liquid_glass_renderer` is DEV package (0.1.1-dev.10) - unstable, breaking changes risk | `BackdropFilter` built into Flutter - stable, battle-tested, GPU-accelerated |
| Custom Inter font via `google_fonts` adds 2MB+ to APK size | SF Pro (iOS) and Roboto (Android) are system fonts - 0MB added |
| Custom color palette requires manual dark mode logic | `CupertinoColors` and Material `ColorScheme` have automatic dark mode support |
| Custom animations less performant | Native Cupertino/Material transitions are GPU-optimized |
| Maintenance burden of keeping custom design system in sync | Native widgets automatically get platform updates (iOS 18, Material 4, etc.) |

### Design Philosophy v2.0

**1. Platform-Native Feel**
- iOS users get iOS-native experience (Cupertino widgets, SF Pro font, iOS transitions)
- Android users get Material Design 3 (Material widgets, Roboto font, Material motion)
- No "looks the same on both platforms" compromise - embrace platform conventions

**2. Performance First**
- Native widgets are GPU-accelerated by default
- System fonts load instantly (no network fetch, no APK bloat)
- Native transitions are 60fps out of the box

**3. Maintainability**
- Fewer dependencies to maintain (removed `liquid_glass_renderer`, `google_fonts`)
- Platform updates handled by Flutter SDK (iOS 18 features come for free)
- Smaller design system document (800 lines vs 3585 lines)

**4. Teenager-Focused (Unchanged)**
- Ages 14-19 are our users - modern aesthetic
- Fast load times (<1 second feed refresh)
- Intuitive first use (no tutorial needed)

### Constitution Principles This Design System Supports

- **STUDENTS_FIRST:** Native platform feel is familiar and respected
- **SIMPLICITY_FIRST:** Use platform defaults, don't reinvent the wheel
- **PERFORMANCE_FIRST:** Native widgets hit 60fps without custom tuning
- **DESIGN_SYSTEM_STRICT:** Universal spacing enforced, but defer to native for color/typography

---

## 2. Platform Strategy

Nova uses **platform-adaptive UI** - iOS gets Cupertino, Android gets Material Design.

### Platform Detection Pattern

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Widget buildPlatformButton({
  required String label,
  required VoidCallback onPressed,
}) {
  return Platform.isIOS
      ? CupertinoButton.filled(
          onPressed: onPressed,
          child: Text(label),
        )
      : ElevatedButton(
          onPressed: onPressed,
          child: Text(label),
        );
}
```

### Platform-Specific App Wrapper

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class NovaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Platform.isIOS
        ? CupertinoApp(
            title: 'Nova',
            theme: CupertinoThemeData(
              primaryColor: CupertinoColors.systemPurple,
              brightness: Brightness.light,
            ),
            home: MainFeedScreen(),
          )
        : MaterialApp(
            title: 'Nova',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            home: MainFeedScreen(),
          );
  }
}
```

### iOS (Cupertino) Component Reference

**Navigation:**
- `CupertinoNavigationBar` - iOS-style app bar with back button
- `CupertinoTabBar` - Bottom tab navigation (Instagram-style)
- `CupertinoPageScaffold` - Page wrapper with safe area

**Buttons:**
- `CupertinoButton` - Standard iOS button
- `CupertinoButton.filled` - Primary action button
- `CupertinoContextMenuAction` - Context menu items (long-press)

**Inputs:**
- `CupertinoTextField` - iOS-style text input
- `CupertinoSwitch` - iOS toggle switch
- `CupertinoPicker` - iOS wheel picker

**Dialogs:**
- `CupertinoAlertDialog` - iOS action sheet
- `CupertinoActionSheet` - Bottom sheet with actions
- `showCupertinoModalPopup` - Full-screen modal

**Lists:**
- `CupertinoListSection` - iOS Settings-style grouped lists
- `CupertinoListTile` - List item with iOS styling

### Android (Material) Component Reference

**Navigation:**
- `AppBar` - Material top app bar
- `BottomNavigationBar` - Bottom navigation
- `Scaffold` - Page wrapper with drawer, snackbar support

**Buttons:**
- `ElevatedButton` - Primary action button (filled)
- `TextButton` - Secondary action button (flat)
- `IconButton` - Icon-only button
- `FloatingActionButton` - FAB for primary action

**Inputs:**
- `TextField` - Material text input
- `Switch` - Material toggle
- `DropdownButton` - Material dropdown picker

**Dialogs:**
- `AlertDialog` - Material dialog
- `showModalBottomSheet` - Bottom sheet
- `showDialog` - Generic modal dialog

**Lists:**
- `ListTile` - Standard list item
- `Card` - Material card for grouped content

### When to Use Platform-Specific vs Universal Widgets

**Always Platform-Specific:**
- Navigation bars (CupertinoNavigationBar vs AppBar)
- Buttons (CupertinoButton vs ElevatedButton)
- Dialogs and modals (CupertinoAlertDialog vs AlertDialog)
- Bottom navigation (CupertinoTabBar vs BottomNavigationBar)

**Universal (Use Anywhere):**
- `Container`, `Column`, `Row`, `Stack`, `Positioned`
- `Text` (uses platform default font automatically)
- `Image`, `Icon` (use SF Symbols on iOS, Material Icons on Android)
- `ListView`, `GridView`, `CustomScrollView`
- `GestureDetector`, `InkWell` (Material ripple on Android only)

---

## 3. Universal Spacing System

**These constants work across BOTH iOS and Android.** Use them everywhere to maintain consistency.

### NovaSpacing Constants

```dart
/// Universal spacing constants for Nova
/// Use these on both iOS (Cupertino) and Android (Material)
class NovaSpacing {
  // Base unit: 4px (standard mobile grid)

  // Micro spacing
  static const double xxs = 2.0;   // 2px - Hairline gaps
  static const double xs = 4.0;    // 4px - Minimal spacing
  static const double sm = 8.0;    // 8px - Compact spacing

  // Standard spacing
  static const double md = 12.0;   // 12px - Default spacing
  static const double lg = 16.0;   // 16px - Comfortable spacing
  static const double xl = 20.0;   // 20px - Generous spacing

  // Large spacing
  static const double xxl = 24.0;  // 24px - Section spacing
  static const double xxxl = 32.0; // 32px - Major sections
  static const double huge = 48.0; // 48px - Hero spacing

  // Screen edges
  static const double screenHorizontal = 16.0;  // Left/right screen padding
  static const double screenVertical = 20.0;    // Top/bottom screen padding

  // Component-specific
  static const double cardPadding = 16.0;       // Padding inside cards
  static const double listItemVertical = 12.0;  // Vertical padding in list items
  static const double buttonHorizontal = 24.0;  // Horizontal padding in buttons
}
```

### Usage Examples

```dart
// ✅ CORRECT - Use NovaSpacing constants
Container(
  padding: EdgeInsets.all(NovaSpacing.md),
  margin: EdgeInsets.symmetric(
    horizontal: NovaSpacing.screenHorizontal,
    vertical: NovaSpacing.sm,
  ),
  child: Column(
    spacing: NovaSpacing.lg,  // Flutter 3.16+ Column/Row spacing parameter
    children: [
      Text('Event Title'),
      Text('Event details'),
    ],
  ),
)

// ❌ FORBIDDEN - Hardcoded spacing values
Container(
  padding: EdgeInsets.all(12),  // NO - use NovaSpacing.md
  margin: EdgeInsets.symmetric(
    horizontal: 16,  // NO - use NovaSpacing.screenHorizontal
    vertical: 8,     // NO - use NovaSpacing.sm
  ),
  child: Text('Event Title'),
)
```

### Spacing Decision Tree

**When to use which spacing:**

- **xxs (2px):** Border thickness, hairline separators
- **xs (4px):** Icon-to-text gaps, chip inner padding
- **sm (8px):** Compact lists, inline elements
- **md (12px):** Default - when unsure, use this
- **lg (16px):** Comfortable reading, card padding
- **xl (20px):** Generous breathing room
- **xxl (24px):** Between sections within same screen
- **xxxl (32px):** Between major screen sections
- **huge (48px):** Hero spacing (e.g., onboarding screens)

---

## 4. Border Radius (Platform Conventions)

### Platform-Specific Radius Guidelines

**iOS (Cupertino):**
- Small: 8px (buttons, chips)
- Medium: 10px (cards, inputs)
- Large: 16px (modals, sheets)
- X-Large: 28px (iOS 18 large widgets)

**Android (Material Design 3):**
- Extra Small: 4px (small chips)
- Small: 8px (buttons)
- Medium: 12px (cards)
- Large: 16px (FAB, large cards)
- Extra Large: 28px (bottom sheets)

### Universal Radius Constants (Optional)

If you need universal radius values that look good on both platforms:

```dart
class NovaRadius {
  static const double small = 8.0;   // Buttons, chips
  static const double medium = 12.0; // Cards, inputs
  static const double large = 16.0;  // Modals, sheets
  static const double xlarge = 24.0; // Hero elements
  static const double circle = 999.0; // Circular (e.g., avatars)
}
```

### Usage Example

```dart
// Platform-adaptive radius
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(
      Platform.isIOS ? 10.0 : 12.0,  // iOS uses 10px, Android uses 12px
    ),
  ),
  child: Text('Event Card'),
)

// Universal radius (simpler, good enough for most cases)
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(NovaRadius.medium),
  ),
  child: Text('Event Card'),
)
```

---

## 5. Typography (Native Fonts)

### Font Defaults (Automatic)

**iOS:** SF Pro (system font) - Flutter uses automatically
**Android:** Roboto (system font) - Flutter uses automatically

**No need to specify font family** - `Text` widget uses platform default automatically.

### Text Styles (Platform-Specific)

**iOS (Cupertino):**

```dart
import 'package:flutter/cupertino.dart';

// Use CupertinoTheme text styles
Text(
  'Event Title',
  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
)

// Available styles:
// - navLargeTitleTextStyle (34pt, bold)
// - navTitleTextStyle (17pt, semibold)
// - textStyle (17pt, regular)
// - actionTextStyle (17pt, regular, blue)
// - tabLabelTextStyle (10pt, regular)
// - dateTimePickerTextStyle (21pt, regular)
```

**Android (Material):**

```dart
import 'package:flutter/material.dart';

// Use Material Theme text styles
Text(
  'Event Title',
  style: Theme.of(context).textTheme.headlineMedium,
)

// Material 3 text styles:
// - displayLarge (57pt)
// - headlineLarge (32pt)
// - headlineMedium (28pt)
// - titleLarge (22pt)
// - bodyLarge (16pt)
// - bodyMedium (14pt)
// - labelLarge (14pt, buttons)
```

### When to Use Custom Text Styles

**Only customize when:**
1. Platform default doesn't have exact size needed
2. Need specific color for semantic meaning (e.g., error red)
3. Need specific weight for emphasis

```dart
// ✅ CORRECT - Custom style when needed
Text(
  'Error message',
  style: TextStyle(
    fontSize: 14,
    color: CupertinoColors.systemRed,  // iOS
    // or: Theme.of(context).colorScheme.error,  // Android
    fontWeight: FontWeight.w500,
  ),
)

// ❌ AVOID - Overriding font family (breaks native feel)
Text(
  'Event Title',
  style: TextStyle(
    fontFamily: 'Inter',  // NO - breaks SF Pro on iOS, Roboto on Android
    fontSize: 18,
  ),
)
```

---

## 6. Colors (Native Palettes)

### iOS Colors (CupertinoColors)

```dart
import 'package:flutter/cupertino.dart';

// Primary colors
CupertinoColors.systemPurple  // Nova primary color
CupertinoColors.systemBlue
CupertinoColors.systemGreen

// Semantic colors
CupertinoColors.systemRed      // Errors, destructive actions
CupertinoColors.systemGreen    // Success
CupertinoColors.systemOrange   // Warnings
CupertinoColors.systemBlue     // Info, links

// Text colors (auto-adapt to dark mode)
CupertinoColors.label          // Primary text
CupertinoColors.secondaryLabel // Secondary text
CupertinoColors.tertiaryLabel  // Tertiary text

// Background colors (auto-adapt to dark mode)
CupertinoColors.systemBackground      // Main background
CupertinoColors.secondarySystemBackground  // Elevated surfaces
CupertinoColors.tertiarySystemBackground   // Further elevated

// Separators
CupertinoColors.separator       // Lines, borders
CupertinoColors.opaqueSeparator // Opaque variant
```

### Android Colors (Material ColorScheme)

```dart
import 'package:flutter/material.dart';

// Access via Theme
Theme.of(context).colorScheme.primary       // Primary color (purple)
Theme.of(context).colorScheme.secondary     // Accent color
Theme.of(context).colorScheme.tertiary      // Third accent

// Semantic colors
Theme.of(context).colorScheme.error         // Error states
Theme.of(context).colorScheme.onPrimary     // Text on primary color
Theme.of(context).colorScheme.onBackground  // Text on background

// Surface colors
Theme.of(context).colorScheme.surface       // Cards, sheets
Theme.of(context).colorScheme.background    // Main background

// Auto dark mode support
Theme.of(context).colorScheme.brightness    // Brightness.light or .dark
```

### Usage Example (Platform-Adaptive)

```dart
Color getPrimaryColor(BuildContext context) {
  return Platform.isIOS
      ? CupertinoColors.systemPurple
      : Theme.of(context).colorScheme.primary;
}

Widget build(BuildContext context) {
  return Container(
    color: getPrimaryColor(context),
    child: Text('Event Title'),
  );
}
```

### Dark Mode (Automatic)

Both `CupertinoColors` and Material `ColorScheme` automatically adapt to system dark mode:

```dart
// iOS - automatic dark mode
CupertinoColors.systemBackground  // White in light mode, black in dark mode
CupertinoColors.label             // Black in light mode, white in dark mode

// Android - automatic dark mode
Theme.of(context).colorScheme.background  // Adapts based on brightness
Theme.of(context).colorScheme.onBackground  // Adapts for contrast
```

---

## 7. Glass Effect (Native BackdropFilter)

### Replacing liquid_glass_renderer

**v1.0 (DEPRECATED):**
```dart
// OLD - used liquid_glass_renderer package (DEV version, unstable)
GlassContainer(
  child: Text('Event Card'),
)
```

**v2.0 (CURRENT):**
```dart
// NEW - use BackdropFilter (built into Flutter)
ClipRRect(
  borderRadius: BorderRadius.circular(NovaRadius.medium),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(
      decoration: BoxDecoration(
        color: Platform.isIOS
            ? CupertinoColors.systemBackground.withOpacity(0.7)
            : Theme.of(context).colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(NovaRadius.medium),
        border: Border.all(
          color: Platform.isIOS
              ? CupertinoColors.separator
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      padding: EdgeInsets.all(NovaSpacing.lg),
      child: Text('Event Card'),
    ),
  ),
)
```

### Reusable GlassContainer Widget (v2.0)

```dart
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';

/// Native glass effect using BackdropFilter
/// Works on both iOS and Android with platform-specific styling
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blurStrength;

  const GlassContainer({
    Key? key,
    required this.child,
    this.borderRadius = 12.0,
    this.padding,
    this.blurStrength = 10.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurStrength, sigmaY: blurStrength),
        child: Container(
          decoration: BoxDecoration(
            color: Platform.isIOS
                ? CupertinoColors.systemBackground
                    .resolveFrom(context)
                    .withOpacity(0.7)
                : Theme.of(context).colorScheme.surface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Platform.isIOS
                  ? CupertinoColors.separator.resolveFrom(context)
                  : Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          padding: padding ?? EdgeInsets.all(NovaSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}
```

### Usage Example

```dart
// Event card with glass effect
GlassContainer(
  borderRadius: NovaRadius.medium,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Event Title', style: Theme.of(context).textTheme.titleLarge),
      SizedBox(height: NovaSpacing.sm),
      Text('Event description...'),
    ],
  ),
)
```

### Performance Notes

- `BackdropFilter` is GPU-accelerated on both iOS and Android
- Use sparingly (max 3-5 per screen) - blurring is computationally expensive
- Disable on low-end devices if frame rate drops below 60fps
- Always use `ClipRRect` to avoid overflow artifacts

---

## 8. Accessibility (WCAG 2.1 AA Compliance)

### Minimum Requirements

**Contrast Ratios:**
- Normal text (16px+): **4.5:1** contrast ratio
- Large text (24px+): **3:1** contrast ratio
- UI components (buttons, icons): **3:1** contrast ratio

**Touch Targets:**
- Minimum size: **44x44 dp** (iOS), **48x48 dp** (Android)
- Use `CupertinoButton` (iOS) or `ElevatedButton` (Android) - both enforce minimum sizes

**Semantic Labels:**
- All interactive elements must have labels for screen readers
- Use `Semantics` widget when icons lack text labels

### Contrast Verification

Use native color systems - they're WCAG-compliant by default:

**iOS (CupertinoColors):**
```dart
// ✅ Verified WCAG AA compliant
CupertinoColors.label on CupertinoColors.systemBackground  // 14:1 contrast
CupertinoColors.secondaryLabel on CupertinoColors.systemBackground  // 4.5:1 contrast
```

**Android (Material ColorScheme):**
```dart
// ✅ Material 3 ColorScheme ensures WCAG AA compliance automatically
Theme.of(context).colorScheme.onBackground  // Auto-calculated for contrast
Theme.of(context).colorScheme.onPrimary     // Auto-calculated for contrast
```

### Semantic Labels Example

```dart
// ✅ CORRECT - Icon button with semantic label
Semantics(
  label: 'Like event',
  child: IconButton(
    icon: Icon(Icons.favorite_border),
    onPressed: () => likeEvent(),
  ),
)

// ❌ INCORRECT - No screen reader support
IconButton(
  icon: Icon(Icons.favorite_border),
  onPressed: () => likeEvent(),
)
```

### Dark Mode (Automatic)

Both platforms handle dark mode contrast automatically:

```dart
// iOS - uses system brightness setting
CupertinoColors.label  // Black (light mode) → White (dark mode)

// Android - uses ThemeData brightness
Theme.of(context).colorScheme.onBackground  // Adapts automatically
```

---

## 9. Common Patterns

### Event Card (Platform-Adaptive)

```dart
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EventCard extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onTap;

  const EventCard({
    Key? key,
    required this.title,
    required this.description,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS
        ? _buildCupertinoCard(context)
        : _buildMaterialCard(context);
  }

  Widget _buildCupertinoCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: 10.0,  // iOS convention
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
            ),
            SizedBox(height: NovaSpacing.sm),
            Text(
              description,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    color: CupertinoColors.secondaryLabel,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),  // Material convention
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: EdgeInsets.all(NovaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: NovaSpacing.sm),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Bottom Navigation (Platform-Adaptive)

```dart
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    EventsFeedScreen(),
    BachecheScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS ? _buildCupertinoScaffold() : _buildMaterialScaffold();
  }

  Widget _buildCupertinoScaffold() {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            label: 'Eventi',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_list),
            label: 'Bacheche',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            label: 'Profilo',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) => _screens[index],
        );
      },
    );
  }

  Widget _buildMaterialScaffold() {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.event),
            label: 'Eventi',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Bacheche',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profilo',
          ),
        ],
      ),
    );
  }
}
```

### Loading Indicators (Platform-Adaptive)

```dart
Widget buildLoadingIndicator() {
  return Center(
    child: Platform.isIOS
        ? CupertinoActivityIndicator(radius: 14.0)
        : CircularProgressIndicator(),
  );
}
```

---

## 10. Migration Guide (v1 → v2)

### Step 1: Remove Deprecated Dependencies

**pubspec.yaml changes:**

```yaml
# REMOVE these lines:
# liquid_glass_renderer: 0.1.1-dev.10  # ❌ Remove
# google_fonts: ^6.1.0                  # ❌ Remove

# KEEP these lines:
cupertino_native: ^0.1.0  # ✅ Keep for iOS native widgets
# flutter/material is built-in, no need to add
```

### Step 2: Replace Custom Widgets with Native

**GlassContainer (from liquid_glass_renderer):**

```dart
// OLD (v1.0):
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

GlassContainer(
  child: Text('Event'),
)

// NEW (v2.0):
import 'dart:ui';  // For ImageFilter
import 'package:flutter/cupertino.dart';

ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground
            .resolveFrom(context)
            .withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('Event'),
    ),
  ),
)
```

### Step 3: Replace Custom Typography

**Text styles:**

```dart
// OLD (v1.0):
Text(
  'Event Title',
  style: NovaTypography.headingMedium,  // Custom Inter font
)

// NEW (v2.0):
Text(
  'Event Title',
  style: Platform.isIOS
      ? CupertinoTheme.of(context).textTheme.navTitleTextStyle  // SF Pro
      : Theme.of(context).textTheme.titleLarge,  // Roboto
)
```

### Step 4: Replace Custom Colors

```dart
// OLD (v1.0):
Container(
  color: NovaColors.primaryLight,  // Custom purple
)

// NEW (v2.0):
Container(
  color: Platform.isIOS
      ? CupertinoColors.systemPurple
      : Theme.of(context).colorScheme.primary,
)
```

### Step 5: Keep Universal Spacing

```dart
// ✅ NovaSpacing constants still work in v2.0
Container(
  padding: EdgeInsets.all(NovaSpacing.lg),  // Still valid
  margin: EdgeInsets.symmetric(
    horizontal: NovaSpacing.screenHorizontal,
  ),
)
```

---

## 11. Common Mistakes

### ❌ Mistake #1: Hardcoding Platform Detection

```dart
// ❌ BAD - Hardcoding platform check everywhere
if (Platform.isIOS) {
  return CupertinoButton(child: Text('Submit'), onPressed: () {});
} else {
  return ElevatedButton(child: Text('Submit'), onPressed: () {});
}

// ✅ GOOD - Create helper function
Widget buildPlatformButton(BuildContext context, String label, VoidCallback onPressed) {
  return Platform.isIOS
      ? CupertinoButton.filled(child: Text(label), onPressed: onPressed)
      : ElevatedButton(child: Text(label), onPressed: onPressed);
}
```

### ❌ Mistake #2: Mixing Platform Styles

```dart
// ❌ BAD - CupertinoButton with Material color
CupertinoButton(
  color: Theme.of(context).colorScheme.primary,  // Material color on Cupertino widget
  child: Text('Submit'),
  onPressed: () {},
)

// ✅ GOOD - Use matching color system
CupertinoButton(
  color: CupertinoColors.systemPurple,  // Cupertino color
  child: Text('Submit'),
  onPressed: () {},
)
```

### ❌ Mistake #3: Overriding Font Family

```dart
// ❌ BAD - Breaks native platform feel
Text(
  'Event Title',
  style: TextStyle(
    fontFamily: 'Inter',  // Overrides SF Pro (iOS) / Roboto (Android)
  ),
)

// ✅ GOOD - Use platform default
Text(
  'Event Title',
  style: Platform.isIOS
      ? CupertinoTheme.of(context).textTheme.navTitleTextStyle
      : Theme.of(context).textTheme.titleLarge,
)
```

### ❌ Mistake #4: Too Many BackdropFilters

```dart
// ❌ BAD - 10 glass containers on one screen (performance killer)
Column(
  children: List.generate(10, (i) => GlassContainer(child: Text('Item $i'))),
)

// ✅ GOOD - Use glass effect sparingly (max 3-5 per screen)
Column(
  children: [
    GlassContainer(child: Text('Featured Event')),  // Hero glass effect
    Card(child: Text('Regular Event 1')),  // Regular cards for list items
    Card(child: Text('Regular Event 2')),
    Card(child: Text('Regular Event 3')),
  ],
)
```

---

## 12. Assets Reference

### Icons

**iOS:** Use `CupertinoIcons` (built into Flutter)
**Android:** Use `Icons` (Material Icons, built into Flutter)

```dart
Icon(
  Platform.isIOS ? CupertinoIcons.heart : Icons.favorite,
  color: Platform.isIOS
      ? CupertinoColors.systemRed
      : Theme.of(context).colorScheme.error,
)
```

### Images

**Asset structure (unchanged):**

```
assets/
├── logos/
│   └── nova_logo.svg
└── images/
    ├── onboarding_1.png
    └── placeholder_event.png
```

**pubspec.yaml:**

```yaml
flutter:
  assets:
    - assets/logos/
    - assets/images/
```

---

## 13. Performance Checklist

- [ ] **Using native widgets** (Cupertino on iOS, Material on Android)
- [ ] **No custom font loading** (SF Pro/Roboto are system fonts)
- [ ] **Max 3-5 BackdropFilters per screen** (blurring is expensive)
- [ ] **No hardcoded colors/spacing** (use NovaSpacing, CupertinoColors, Material ColorScheme)
- [ ] **No unnecessary rebuilds** (use `const` constructors where possible)
- [ ] **Images optimized** (WebP format, max 200KB per image)
- [ ] **Lazy loading lists** (use `ListView.builder`, not `ListView` with all children)

---

## 14. Related Documentation

- **[Constitution v1.1.0](.specify/memory/constitution.md)** - Core principles and constraints
- **[Flutter Cupertino Documentation](https://docs.flutter.dev/ui/widgets/cupertino)** - iOS native widgets
- **[Flutter Material Documentation](https://docs.flutter.dev/ui/widgets/material)** - Android native widgets
- **[WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)** - Accessibility standards

---

**Last Updated:** 2025-11-10
**Version:** 2.0.0
**Replaces:** design-system.md v1.0 (archived to specs/archive/design-system-v1-archived.md)
