import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_icons.dart';

/// Navigation item configuration
class NavItem {
  final String sfSymbol;
  final IconData materialIcon;
  final String label;
  final int? badgeCount;

  const NavItem({
    required this.sfSymbol,
    required this.materialIcon,
    required this.label,
    this.badgeCount,
  });
}

/// Nova custom bottom navigation bar with pill-shaped glassmorphic design.
///
/// Features:
/// - Pill-shaped container with rounded corners
/// - Glassmorphism on iOS (blur + semi-transparent)
/// - Material elevation on Android (subtle shadow)
/// - Dynamic items based on role (students: 5 tabs, moderators: 6 tabs, admins: 7 tabs)
/// - Plus button emphasized: larger, circular, white
/// - Optional badge support for any tab
/// - Role-based tab visibility
///
/// Example:
/// ```dart
/// NovaBottomNavBar(
///   currentIndex: _selectedIndex,
///   items: [
///     NavItem(sfSymbol: 'house.fill', materialIcon: Icons.home, label: 'Home'),
///     NavItem(sfSymbol: 'person.2.fill', materialIcon: Icons.people, label: 'Friends'),
///     NavItem(sfSymbol: 'message.fill', materialIcon: Icons.chat_bubble, label: 'Chat'),
///     NavItem(sfSymbol: 'gavel', materialIcon: Icons.gavel, label: 'Moderation', badgeCount: 5),
///     NavItem(sfSymbol: 'person.circle.fill', materialIcon: Icons.person, label: 'Profile'),
///   ],
///   onTap: (index) => setState(() => _selectedIndex = index),
///   onCameraTap: () => _openCamera(),
/// )
/// ```
class NovaBottomNavBar extends StatelessWidget {
  /// Currently selected item index
  final int currentIndex;

  /// Navigation items to display (dynamically filtered by role)
  final List<NavItem> items;

  /// Callback when a nav item is tapped
  final ValueChanged<int> onTap;

  /// Callback when camera button is tapped (center + button)
  final VoidCallback onCameraTap;

  const NovaBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isIOS) {
      return _buildIOSBottomNav(context);
    }
    return _buildAndroidBottomNav(context);
  }

  /// iOS: Glassmorphic pill-shaped bottom nav
  Widget _buildIOSBottomNav(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        left: NovaSpacing.m,
        right: NovaSpacing.m,
        bottom: NovaSpacing.xxs, // 2px invece di 12px (alzato di 10px)
      ),
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NovaRadius.full),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NovaRadius.full),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: NovaColors.surface(context).withOpacity(0.8),
              borderRadius: BorderRadius.circular(NovaRadius.full),
              border: Border.all(
                color: NovaColors.border(context).withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _buildNavItems(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Android: Material pill-shaped bottom nav (similar to iOS but with elevation)
  Widget _buildAndroidBottomNav(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        left: NovaSpacing.m,
        right: NovaSpacing.m,
        bottom: NovaSpacing.xxs, // 2px invece di 12px (alzato di 10px)
      ),
      height: 60,
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        borderRadius: BorderRadius.circular(NovaRadius.full),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _buildNavItems(context),
      ),
    );
  }

  /// Build all navigation items with camera button in the middle
  List<Widget> _buildNavItems(BuildContext context) {
    final widgets = <Widget>[];

    // Calculate middle index (where camera button should be)
    final middleIndex = items.length ~/ 2;

    for (int i = 0; i < items.length; i++) {
      // Add camera button in the middle
      if (i == middleIndex) {
        widgets.add(_buildPlusButton(context));
      }

      final item = items[i];
      widgets.add(_buildNavItem(
        context,
        i,
        item.sfSymbol,
        item.materialIcon,
        item.label,
        badgeCount: item.badgeCount,
      ));
    }

    return widgets;
  }

  /// Build a regular navigation item (Home, Friends, Chat, Profile)
  Widget _buildNavItem(
    BuildContext context,
    int index,
    String sfSymbol,
    IconData materialIcon,
    String label, {
    int? badgeCount,
  }) {
    final isSelected = currentIndex == index;
    final color = isSelected
        ? NovaColors.primary(context)
        : NovaColors.textSecondary(context);
    final showBadge = badgeCount != null && badgeCount > 0;

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
              // Badge indicator
              if (showBadge)
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: NovaColors.errorLight, // Badge notification red
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        badgeCount! > 99 ? '99+' : badgeCount.toString(),
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

  /// Build the center plus button (large, circular, emphasized)
  Widget _buildPlusButton(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: NovaSpacing.xs),
      decoration: BoxDecoration(
        color: NovaColors.primary(context),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onCameraTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              context.isIOS ? CupertinoIcons.plus : Icons.add,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
