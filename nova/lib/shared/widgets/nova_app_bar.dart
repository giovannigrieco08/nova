// Widget: NovaAppBar
// Purpose: Custom app bar with Nova logo and notifications icon (BeReal-inspired)

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_shadows.dart';

/// Custom AppBar with Nova logo on left and notifications icon on right
///
/// Features:
/// - Nova logo SVG on the left
/// - Notifications bell icon on the right
/// - Clean white background with subtle shadow
/// - Fixed height of 60px
/// - Tappable notification icon with badge support
class NovaAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Callback when notifications icon is tapped
  final VoidCallback? onNotificationsTap;

  /// Whether to show notification badge (red dot)
  final bool showNotificationBadge;

  const NovaAppBar({
    super.key,
    this.onNotificationsTap,
    this.showNotificationBadge = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        boxShadow: NovaShadows.small,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.l,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Nova Logo (left side)
              SvgPicture.asset(
                'assets/logos/nova_logo.svg',
                height: 32,
                width: 32,
                colorFilter: ColorFilter.mode(
                  NovaColors.primary(context),
                  BlendMode.srcIn,
                ),
              ),

              // Notifications Icon (right side)
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: NovaColors.textPrimary(context),
                      size: 28,
                    ),
                    onPressed: onNotificationsTap,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Notifiche',
                  ),

                  // Notification badge (red dot)
                  if (showNotificationBadge)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: NovaColors.error(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: NovaColors.surface(context),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
