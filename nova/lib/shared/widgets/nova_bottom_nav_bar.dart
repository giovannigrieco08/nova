import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Nova custom bottom navigation bar with BeReal-style floating liquid glass design.
///
/// Features:
/// - Floating oval/pill shape with rounded corners
/// - iOS liquid glass effect with strong blur
/// - Press/scale animation on tap (BeReal-style)
/// - High contrast for visibility
/// - Pill-shaped selection indicator behind selected icon
/// - Material elevation on Android (subtle shadow)
/// - Dynamic items based on role
/// - All icons have equal visual weight
/// - Optional badge support for any tab
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

  /// iOS: BeReal-style floating liquid glass bottom nav
  Widget _buildIOSBottomNav(BuildContext context) {
    final isDark = NovaColors.isDark(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      // Horizontal margins for floating effect + bottom safe area
      padding: EdgeInsets.only(
        left: NovaSpacing.m,
        right: NovaSpacing.m,
        bottom: bottomPadding + NovaSpacing.s,
      ),
      child: ClipRRect(
        // Fully rounded pill shape
        borderRadius: BorderRadius.circular(NovaRadius.full),
        child: BackdropFilter(
          // Strong blur for liquid glass effect
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              // Translucent background with good contrast
              color: isDark
                  ? Colors.black.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(NovaRadius.full),
              // Subtle border for definition (liquid glass style)
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.5,
              ),
              // Soft shadow for floating effect
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
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

  /// Android: Material floating bottom nav with similar styling
  Widget _buildAndroidBottomNav(BuildContext context) {
    final isDark = NovaColors.isDark(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: NovaSpacing.m,
        right: NovaSpacing.m,
        bottom: bottomPadding + NovaSpacing.s,
      ),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.grey[900]!.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(NovaRadius.full),
          border: Border.all(
            color: NovaColors.border(context).withValues(alpha: 0.2),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _buildNavItems(context),
        ),
      ),
    );
  }

  /// Build all navigation items (uniform visual weight)
  List<Widget> _buildNavItems(BuildContext context) {
    return items.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      return _NavItemWidget(
        index: i,
        item: item,
        isSelected: currentIndex == i,
        onTap: () => onTap(i),
      );
    }).toList();
  }
}

/// Individual navigation item widget with press animation
class _NavItemWidget extends StatefulWidget {
  final int index;
  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.index,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItemWidget> createState() => _NavItemWidgetState();
}

class _NavItemWidgetState extends State<_NavItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  void _handleTap() {
    // Haptic feedback on iOS
    if (PlatformUtils.isIOS) {
      HapticFeedback.lightImpact();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = NovaColors.isDark(context);
    final showBadge =
        widget.item.badgeCount != null && widget.item.badgeCount! > 0;

    // Colors for selected/unselected states - higher contrast
    final Color iconColor;
    if (widget.isSelected) {
      iconColor = isDark ? Colors.white : Colors.black;
    } else {
      iconColor = isDark
          ? Colors.white.withValues(alpha: 0.55)
          : Colors.black.withValues(alpha: 0.45);
    }

    // Build icon widget
    Widget iconWidget;
    if (widget.item.customIcon != null) {
      // Custom icon (e.g., profile avatar)
      iconWidget = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: widget.isSelected
              ? Border.all(
                  color: isDark ? Colors.white : Colors.black,
                  width: 2,
                )
              : null,
        ),
        child: ClipOval(
          child: widget.item.customIcon!,
        ),
      );
    } else if (widget.item.sfSymbol != null &&
        widget.item.materialIcon != null) {
      iconWidget = NovaIcons.adaptive(
        context,
        sfSymbol: widget.item.sfSymbol!,
        materialIcon: widget.item.materialIcon!,
        size: 26,
        color: iconColor,
      );
    } else {
      iconWidget = Icon(Icons.circle, size: 26, color: iconColor);
    }

    // Selection indicator with pill background
    Widget navContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        // Pill background on selected item
        color: widget.isSelected
            ? (isDark
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.10))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(NovaRadius.full),
      ),
      child: iconWidget,
    );

    return Expanded(
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                navContent,
                // Badge indicator
                if (showBadge)
                  Positioned(
                    right: 2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
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
                          widget.item.badgeCount! > 99
                              ? '99+'
                              : widget.item.badgeCount.toString(),
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
      ),
    );
  }
}
