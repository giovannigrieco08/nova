// Screen: NotificationPreferencesScreen
// Feature: 004-event-creation-moderation (US2 - Status Tracking)
// Purpose: Notification channel preferences (opt-in/opt-out)
//
// Channels:
// - "Eventi Propri" (event_approved, event_rejected)
// - "Co-Organizer Updates" (added_as_coorganizer, event_modified)
// - "Moderazione" (new_pending_event) - only visible if moderator
//
// Preferences saved to SharedPreferences

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../providers/repository_providers.dart';

/// Notification preferences screen
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  // Preferences state
  bool _ownEventsEnabled = true;
  bool _coOrganizerEnabled = true;
  bool _moderationEnabled = true; // Only shown if moderator
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  /// Load preferences from SharedPreferences
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ownEventsEnabled = prefs.getBool('notif_own_events') ?? true;
      _coOrganizerEnabled = prefs.getBool('notif_coorganizer') ?? true;
      _moderationEnabled = prefs.getBool('notif_moderation') ?? true;
      _isLoading = false;
    });
  }

  /// Save preference
  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final isModeratorAsync = ref.watch(isModeratorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifiche'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NovaColors.backgroundPrimary(context),
        foregroundColor: NovaColors.textPrimary(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(NovaSpacing.large),
              children: [
                // Header text
                Text(
                  'Gestisci le tue notifiche push',
                  style: NovaTypography.bodyMedium.copyWith(
                    color: NovaColors.textSecondary(context),
                  ),
                ),
                SizedBox(height: NovaSpacing.large),

                // Own Events notifications
                _buildSwitchTile(
                  context,
                  title: 'Eventi Propri',
                  subtitle:
                      'Notifiche quando i tuoi eventi vengono approvati o rifiutati',
                  value: _ownEventsEnabled,
                  onChanged: (value) {
                    setState(() => _ownEventsEnabled = value);
                    _savePreference('notif_own_events', value);
                  },
                ),

                SizedBox(height: NovaSpacing.medium),

                // Co-Organizer notifications
                _buildSwitchTile(
                  context,
                  title: 'Aggiornamenti Co-Organizer',
                  subtitle:
                      'Notifiche quando vieni aggiunto come co-organizer o un evento viene modificato',
                  value: _coOrganizerEnabled,
                  onChanged: (value) {
                    setState(() => _coOrganizerEnabled = value);
                    _savePreference('notif_coorganizer', value);
                  },
                ),

                // Moderation notifications (only if moderator)
                isModeratorAsync.when(
                  data: (isModerator) {
                    if (!isModerator) return const SizedBox();
                    return Column(
                      children: [
                        SizedBox(height: NovaSpacing.medium),
                        _buildSwitchTile(
                          context,
                          title: 'Moderazione',
                          subtitle:
                              'Notifiche quando nuovi eventi richiedono moderazione',
                          value: _moderationEnabled,
                          onChanged: (value) {
                            setState(() => _moderationEnabled = value);
                            _savePreference('notif_moderation', value);
                          },
                          icon: Icons.admin_panel_settings_outlined,
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),

                SizedBox(height: NovaSpacing.xlarge),

                // Info box
                Container(
                  padding: EdgeInsets.all(NovaSpacing.medium),
                  decoration: BoxDecoration(
                    color: NovaColors.primary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(NovaRadius.medium),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: NovaColors.primary(context),
                      ),
                      SizedBox(width: NovaSpacing.small),
                      Expanded(
                        child: Text(
                          'Puoi modificare le impostazioni di notifica in qualsiasi momento. '
                          'Le notifiche importanti (es: evento rifiutato) verranno sempre inviate.',
                          style: NovaTypography.bodySmall.copyWith(
                            color: NovaColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// Build switch tile
  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    IconData? icon,
  }) {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.medium),
      decoration: BoxDecoration(
        border: Border.all(color: NovaColors.border(context)),
        borderRadius: BorderRadius.circular(NovaRadius.medium),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 24,
              color: NovaColors.primary(context),
            ),
            SizedBox(width: NovaSpacing.medium),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: NovaTypography.labelMedium,
                ),
                SizedBox(height: NovaSpacing.xsmall),
                Text(
                  subtitle,
                  style: NovaTypography.bodySmall.copyWith(
                    color: NovaColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: NovaColors.primary(context),
          ),
        ],
      ),
    );
  }
}
