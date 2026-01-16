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

/// Nova custom bottom navigation bar with BeReal-style liquid glass design.
///
/// Features:
/// - Edge-to-edge liquid glass effect on iOS
/// - Strong blur with translucent dark background
/// - Pill-shaped selection indicator behind selected icon
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

  /// iOS: BeReal-style liquid glass bottom nav (edge-to-edge)
  Widget _buildIOSBottomNav(BuildContext context) {
    final isDark = NovaColors.isDark(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: 80, // Taller for better touch targets
          decoration: BoxDecoration(
            // Darker translucent background for liquid glass effect
            color: isDark
                ? Colors.black.withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.75),
            // Subtle top border for definition
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _buildNavItems(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Android: Material bottom nav with similar styling to iOS
  Widget _buildAndroidBottomNav(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        border: Border(
          top: BorderSide(
            color: NovaColors.border(context).withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _buildNavItems(context),
          ),
        ),
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

  /// Build a regular navigation item with BeReal-style pill selection indicator
  Widget _buildNavItem(
    BuildContext context,
    int index,
    NavItem item,
  ) {
    final isSelected = currentIndex == index;
    final isDark = NovaColors.isDark(context);
    final showBadge = item.badgeCount != null && item.badgeCount! > 0;

    // Colors for selected/unselected states
    final Color iconColor;
    if (isSelected) {
      // Selected: use contrasting color based on background
      iconColor = isDark ? Colors.white : Colors.black;
    } else {
      // Unselected: muted gray
      iconColor = isDark
          ? Colors.white.withValues(alpha: 0.5)
          : Colors.black.withValues(alpha: 0.5);
    }

    // Determine the icon widget to display
    Widget iconWidget;
    if (item.customIcon != null) {
      // Custom icon (e.g., profile avatar)
      iconWidget = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: isDark ? Colors.white : Colors.black,
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
        color: iconColor,
      );
    } else {
      // Fallback placeholder
      iconWidget = Icon(Icons.circle, size: 26, color: iconColor);
    }

    // Wrap icon with pill-shaped selection indicator
    Widget navContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // BeReal-style: pill background only on selected item
        color: isSelected
            ? (isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.08))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(NovaRadius.full),
      ),
      child: iconWidget,
    );

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              navContent,
              // Badge indicator
              if (showBadge)
                Positioned(
                  right: 4,
                  top: 0,
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
                          fontWeight: FontWeight.w600,
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
