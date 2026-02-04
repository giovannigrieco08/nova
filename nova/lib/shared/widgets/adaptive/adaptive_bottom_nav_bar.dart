import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';

/// Bottom navigation bar item configuration
class BottomNavItem {
  /// Item label
  final String label;

  /// iOS: CupertinoIcons icon
  final IconData? cupertinoIcon;

  /// Android: Material icon
  final IconData? androidIcon;

  const BottomNavItem({
    required this.label,
    this.cupertinoIcon,
    this.androidIcon,
  });
}

/// Platform-adaptive bottom navigation bar.
///
/// - iOS: [CupertinoTabBar] with blur background
/// - Android: [NavigationBar] Material 3
///
/// Example:
/// ```dart
/// AdaptiveBottomNavBar(
///   currentIndex: _index,
///   onTap: (index) => setState(() => _index = index),
///   items: [
///     BottomNavItem(
///       label: 'Home',
///       cupertinoIcon: CupertinoIcons.house_fill,  // iOS
///       androidIcon: Icons.home,                    // Android
///     ),
///     // ... more items
///   ],
///   centerWidget: FloatingActionButton(...),  // Optional FAB
/// )
/// ```
class AdaptiveBottomNavBar extends StatelessWidget {
  /// Currently selected index
  final int currentIndex;

  /// Navigation items
  final List<BottomNavItem> items;

  /// Tap callback
  final ValueChanged<int> onTap;

  /// Optional center widget (e.g., Camera FAB for BeReal-style)
  final Widget? centerWidget;

  const AdaptiveBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.centerWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isIOS) {
      // iOS: CupertinoTabBar with glassmorphic background
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Blur background
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(NovaRadius.l),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: NovaColors.background(context).withValues(alpha: 0.8),
                  border: Border(
                    top: BorderSide(
                      color: NovaColors.border(context).withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: CupertinoTabBar(
                  currentIndex: currentIndex,
                  items: items.map((item) {
                    return BottomNavigationBarItem(
                      icon: Icon(item.cupertinoIcon ?? item.androidIcon),
                      label: item.label,
                    );
                  }).toList(),
                  onTap: onTap,
                  backgroundColor: Colors.transparent,
                  border: const Border(),
                ),
              ),
            ),
          ),

          // Center FAB (if provided)
          if (centerWidget != null)
            Positioned(
              top: -20,
              child: centerWidget!,
            ),
        ],
      );
    }

    // Android: Material 3 NavigationBar
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (centerWidget != null)
          Padding(
            padding: const EdgeInsets.only(bottom: NovaSpacing.xs),
            child: centerWidget,
          ),
        NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          backgroundColor: NovaColors.background(context),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          destinations: items.map((item) {
            return NavigationDestination(
              icon: Icon(item.androidIcon),
              label: item.label,
            );
          }).toList(),
        ),
      ],
    );
  }
}
