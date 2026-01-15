import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_icons.dart';

/// Navigation item configuration
class NavItem {
  final String? sfSymbol;
  final IconData? materialIcon;
  final String label;
  final int? badgeCount;
  final Widget? customIcon; // For profile avatar

  const NavItem({
    this.sfSymbol,
    this.materialIcon,
    required this.label,
    this.badgeCount,
    this.customIcon,
  });
}

/// Nova custom bottom navigation bar with pill-shaped glassmorphic design.
///
/// Features:
/// - Pill-shaped container with rounded corners
/// - Glassmorphism on iOS (blur + semi-transparent)
/// - Material elevation on Android (subtle shadow)
/// - Dynamic items based on role (students: 5 tabs, moderators: 6 tabs, admins: 7 tabs)
/// - All icons have equal visual weight (no emphasized center button)
/// - Optional badge support for any tab
/// - Role-based tab visibility
///
/// Example:
/// ```dart
/// NovaBottomNavBar(
///   currentIndex: _selectedIndex,
///   items: [
///     NavItem(sfSymbol: 'house.fill', materialIcon: Icons.home, label: 'Home'),
///     NavItem(sfSymbol: 'magnifyingglass', materialIcon: Icons.search, label: 'Cerca'),
///     NavItem(sfSymbol: 'message.fill', materialIcon: Icons.chat_bubble, label: 'Chat'),
///     NavItem(sfSymbol: 'gavel', materialIcon: Icons.gavel, label: 'Moderation', badgeCount: 5),
///     NavItem(sfSymbol: 'person.circle.fill', materialIcon: Icons.person, label: 'Profile'),
///   ],
///   onTap: (index) => setState(() => _selectedIndex = index),
/// )
/// ```
class NovaBottomNavBar extends StatelessWidget {
  /// Currently selected item index
  final int currentIndex;

  /// Navigation items to display (dynamically filtered by role)
  final List<NavItem> items;

  /// Callback when a nav item is tapped
  final ValueChanged<int> onTap;

  const NovaBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
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
              color: NovaColors.surface(context).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(NovaRadius.full),
              border: Border.all(
                color: NovaColors.border(context).withValues(alpha: 0.2),
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
            color: Colors.black.withValues(alpha: 0.1),
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

  /// Build all navigation items (uniform visual weight)
  List<Widget> _buildNavItems(BuildContext context) {
    return items.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      return _buildNavItem(
        context,
        i,
        item,
      );
    }).toList();
  }

  /// Build a regular navigation item (Home, Friends, Chat, Profile)
  Widget _buildNavItem(
    BuildContext context,
    int index,
    NavItem item,
  ) {
    final isSelected = currentIndex == index;
    final color = isSelected
        ? NovaColors.primary(context)
        : NovaColors.textSecondary(context);
    final showBadge = item.badgeCount != null && item.badgeCount! > 0;

    // Determine the icon widget to display
    Widget iconWidget;
    if (item.customIcon != null) {
      // Custom icon (e.g., profile avatar)
      // Add selection border for Instagram-style feedback
      iconWidget = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: NovaColors.primary(context),
                  width: 2,
                )
              : null,
        ),
        child: ClipOval(
          child: item.customIcon!,
        ),
      );
    } else if (item.sfSymbol != null && item.materialIcon != null) {
      // Standard icon
      iconWidget = NovaIcons.adaptive(
        context,
        sfSymbol: item.sfSymbol!,
        materialIcon: item.materialIcon!,
        size: 26,
        color: color,
      );
    } else {
      // Fallback placeholder
      iconWidget = Icon(Icons.circle, size: 26, color: color);
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              iconWidget,
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
                      borderRadius: NovaRadius.circularXs,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        item.badgeCount! > 99 ? '99+' : item.badgeCount.toString(),
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

}
