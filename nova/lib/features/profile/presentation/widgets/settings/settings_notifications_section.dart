import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/animations/page_transitions.dart';
import '../../../../../core/theme/nova_colors.dart';
import '../../../../../core/theme/nova_spacing.dart';
import '../../../../../core/theme/nova_typography.dart';
import '../../../../notifications/domain/entities/notification_permission_state.dart';
import '../../../../notifications/presentation/providers/push_permission_provider.dart';
import '../../../../notifications/presentation/screens/notification_preferences_screen.dart';
import 'settings_tile_builders.dart';

/// Section 3: Notifiche.
class SettingsNotificationsSection extends ConsumerWidget {
  const SettingsNotificationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionState = ref.watch(pushPermissionProvider);

    return SettingsSectionCard(
      child: Column(
        children: [
          if (permissionState.status == NotificationPermissionState.denied)
            _EnableNotificationsTile(),
          SettingsActionTile(
            icon: Icons.notifications_outlined,
            title: 'Preferenze notifiche',
            subtitle: 'Gestisci le notifiche per eventi, commenti e altro',
            onTap: () => Navigator.push(
              context,
              NovaPageRoute.swipeBack(
                  page: const NotificationPreferencesScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnableNotificationsTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        InkWell(
          onTap: () async {
            final notifier = ref.read(pushPermissionProvider.notifier);
            await notifier.openAppSettings();
          },
          child: Padding(
            padding: EdgeInsets.all(NovaSpacing.medium),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(NovaSpacing.small),
                  decoration: BoxDecoration(
                    color: NovaColors.warning(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.notifications_off_outlined,
                    color: NovaColors.warning(context),
                    size: 24,
                  ),
                ),
                SizedBox(width: NovaSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifiche disattivate',
                        style: NovaTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: NovaColors.warning(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tocca per abilitarle nelle impostazioni',
                        style: NovaTypography.caption.copyWith(
                          color: NovaColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  color: NovaColors.textTertiary(context),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: NovaColors.border(context),
          indent: NovaSpacing.medium,
          endIndent: NovaSpacing.medium,
        ),
      ],
    );
  }
}
