import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_icons.dart';

/// Nova custom bottom navigation bar with pill-shaped glassmorphic design.
///
/// Features:
/// - Pill-shaped container with rounded corners
/// - Glassmorphism on iOS (blur + semi-transparent)
/// - Material elevation on Android (subtle shadow)
/// - 5 items: Home, Friends, + button (center, large), Chat, Profile
/// - Plus button emphasized: larger, circular, white
/// - Optional badge support for Profile tab (for moderators with pending events)
///
/// Example:
/// ```dart
/// NovaBottomNavBar(
///   currentIndex: _selectedIndex,
///   onTap: (index) => setState(() => _selectedIndex = index),
///   onCameraTap: () => _openCamera(),
///   profileBadgeCount: 3, // Show badge with count
/// )
/// ```
class NovaBottomNavBar extends StatelessWidget {
  /// Currently selected item index (0-3, camera is not selectable)
  final int currentIndex;

  /// Callback when a nav item is tapped (receives index 0-3)
  /// Index mapping: 0=Home, 1=Friends, 2=Chat, 3=Profile
  final ValueChanged<int> onTap;

  /// Callback when camera button is tapped
  final VoidCallback onCameraTap;

  /// Optional badge count for Profile tab (for moderators with pending events)
  /// If > 0, shows red badge with count. If null or 0, no badge shown.
  final int? profileBadgeCount;

  const NovaBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCameraTap,
    this.profileBadgeCount,
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
      height: 80,
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
              children: [
                _buildNavItem(context, 0, 'house.fill', Icons.home, 'Home'),
                _buildNavItem(context, 1, 'person.2.fill', Icons.people, 'Amici'),
                _buildPlusButton(context),
                _buildNavItem(context, 2, 'message.fill', Icons.chat_bubble, 'Chat'),
                _buildNavItem(context, 3, 'person.circle.fill', Icons.person, 'Profilo', badgeCount: profileBadgeCount),
              ],
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
      height: 80,
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
        children: [
          _buildNavItem(context, 0, 'house.fill', Icons.home, 'Home'),
          _buildNavItem(context, 1, 'person.2.fill', Icons.people, 'Amici'),
          _buildPlusButton(context),
          _buildNavItem(context, 2, 'message.fill', Icons.chat_bubble, 'Chat'),
          _buildNavItem(context, 3, 'person.circle.fill', Icons.person, 'Profilo', badgeCount: profileBadgeCount),
        ],
      ),
    );
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: NovaSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  NovaIcons.adaptive(
                    context,
                    sfSymbol: sfSymbol,
                    materialIcon: materialIcon,
                    size: 24,
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
                          color: const Color(0xFFD32F2F), // Material Red 700
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
              const SizedBox(height: 4),
              Text(
                label,
                style: NovaTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
      width: 66,
      height: 66,
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
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
