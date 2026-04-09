import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../domain/entities/notification_channel.dart';
import '../providers/notification_providers.dart';
import '../../data/providers/notifications_data_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification preferences screen
///
/// Allows users to toggle individual notification channels on/off.
/// Features:
/// - 6 toggle switches for each channel
/// - Italian labels and descriptions
/// - Optimistic UI updates
/// - Real-time sync with Supabase
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(notificationPreferencesNotifierProvider);

    return Scaffold(
      backgroundColor: NovaColors.background(context),
      appBar: AppBar(
        title: Text(
          'Impostazioni Notifiche',
          style: NovaTextStyles.h2.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ),
        backgroundColor: NovaColors.surface(context),
        elevation: 0,
      ),
      body: preferencesAsync.when(
        data: (preferences) => _buildPreferencesList(context, ref, preferences),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(context, ref, error.toString()),
      ),
    );
  }

  Widget _buildPreferencesList(
    BuildContext context,
    WidgetRef ref,
    dynamic preferences,
  ) {
    return ListView(
      padding: EdgeInsets.symmetric(vertical: NovaSpacing.l),
      children: [
        // Global Push Toggle (T053)
        _buildGlobalPushToggle(context, ref),
        SizedBox(height: NovaSpacing.l),

        // Header section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: NovaSpacing.l),
          child: Text(
            'Scegli quali notifiche ricevere',
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
        ),
        SizedBox(height: NovaSpacing.l),

        // Notification toggles
        _buildToggleTile(
          context,
          ref,
          channel: NotificationChannel.eventModeration,
          value: preferences.eventiModeratiEnabled,
          columnName: 'eventi_moderati_enabled',
        ),
        _buildToggleTile(
          context,
          ref,
          channel: NotificationChannel.newComment,
          value: preferences.nuoviCommentiEnabled,
          columnName: 'nuovi_commenti_enabled',
        ),
        _buildToggleTile(
          context,
          ref,
          channel: NotificationChannel.commentReply,
          value: preferences.risposteCommentiEnabled,
          columnName: 'risposte_commenti_enabled',
        ),
        _buildToggleTile(
          context,
          ref,
          channel: NotificationChannel.eventLike,
          value: preferences.likeEventiEnabled,
          columnName: 'like_eventi_enabled',
        ),
        _buildToggleTile(
          context,
          ref,
          channel: NotificationChannel.eventParticipation,
          value: preferences.nuovePartecipazioniEnabled,
          columnName: 'nuove_partecipazioni_enabled',
        ),
        _buildToggleTile(
          context,
          ref,
          channel: NotificationChannel.coorganizerUpdate,
          value: preferences.coorganizerUpdatesEnabled,
          columnName: 'coorganizer_updates_enabled',
        ),

        SizedBox(height: NovaSpacing.xxl),

        // Info section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: NovaSpacing.l),
          child: Container(
            padding: EdgeInsets.all(NovaSpacing.m),
            decoration: BoxDecoration(
              color: NovaColors.info(context).withValues(alpha: 0.1),
              borderRadius: NovaRadius.circularM,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: NovaColors.info(context),
                  size: 20,
                ),
                SizedBox(width: NovaSpacing.s),
                Expanded(
                  child: Text(
                    'Le notifiche push arrivano anche quando l\'app è chiusa.',
                    style: NovaTextStyles.caption.copyWith(
                      color: NovaColors.info(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Global push notification toggle (T053)
  Widget _buildGlobalPushToggle(BuildContext context, WidgetRef ref) {
    // Use datasource from provider for push_enabled control
    final fcmDatasource = ref.read(fcmTokenRemoteDataSourceProvider);

    return FutureBuilder<bool>(
      future: fcmDatasource.getPushEnabled(),
      builder: (context, snapshot) {
        final pushEnabled = snapshot.data ?? true;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: NovaSpacing.l),
          decoration: BoxDecoration(
            color: NovaColors.primary(context).withValues(alpha: 0.1),
            borderRadius: NovaRadius.circularM,
            border: Border.all(
              color: NovaColors.primary(context).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: SwitchListTile(
            title: Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: NovaColors.primary(context),
                  size: 24,
                ),
                SizedBox(width: NovaSpacing.s),
                Text(
                  'Notifiche Push',
                  style: NovaTextStyles.bodyBold.copyWith(
                    color: NovaColors.textPrimary(context),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: EdgeInsets.only(top: NovaSpacing.xs, left: 32),
              child: Text(
                'Ricevi notifiche anche quando l\'app è chiusa',
                style: NovaTextStyles.caption.copyWith(
                  color: NovaColors.textSecondary(context),
                ),
              ),
            ),
            value: pushEnabled,
            onChanged: (value) async {
              await fcmDatasource.setPushEnabled(value);
              // Rebuild widget
              (context as Element).markNeedsBuild();
            },
            thumbColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? NovaColors.primary(context)
                    : null),
            contentPadding: EdgeInsets.symmetric(
              horizontal: NovaSpacing.m,
              vertical: NovaSpacing.xs,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: NovaRadius.circularM,
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggleTile(
    BuildContext context,
    WidgetRef ref, {
    required NotificationChannel channel,
    required bool value,
    required String columnName,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: NovaSpacing.l,
        vertical: NovaSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: NovaColors.card(context),
        borderRadius: NovaRadius.circularM,
        border: Border.all(
          color: NovaColors.border(context),
          width: 0.5,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          channel.label,
          style: NovaTextStyles.bodyBold.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: NovaSpacing.xs),
          child: Text(
            channel.description,
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
        ),
        value: value,
        onChanged: (newValue) => _togglePreference(ref, columnName, newValue),
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? NovaColors.primary(context)
                : null),
        contentPadding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.m,
          vertical: NovaSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: NovaRadius.circularM,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: NovaColors.error(context),
            ),
            SizedBox(height: NovaSpacing.l),
            Text(
              'Errore nel caricamento',
              style: NovaTextStyles.h3.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.s),
            Text(
              error,
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.l),
            ElevatedButton(
              onPressed: () => ref
                  .read(notificationPreferencesNotifierProvider.notifier)
                  .refresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.primary(context),
              ),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePreference(WidgetRef ref, String columnName, bool value) {
    ref
        .read(notificationPreferencesNotifierProvider.notifier)
        .togglePreference(columnName, value);
  }
}
