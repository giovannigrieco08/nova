import 'package:flutter/material.dart';
import '../../../../../core/animations/page_transitions.dart';
import '../../../../events/presentation/screens/moderation_queue_screen.dart';
import 'settings_tile_builders.dart';

/// Section 5: Moderazione (only if moderator).
class SettingsModerationSection extends StatelessWidget {
  const SettingsModerationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      child: Column(
        children: [
          SettingsActionTile(
            icon: Icons.dashboard_rounded,
            title: 'Dashboard Moderazione',
            subtitle: 'Gestisci coda moderazione',
            onTap: () => Navigator.push(
              context,
              NovaPageRoute.swipeBack(page: const ModerationQueueScreen()),
            ),
          ),
          const SettingsDivider(),
          const SettingsReadOnlyTile(
            icon: Icons.check_circle_rounded,
            title: 'Review effettuate',
            value: '42', // TODO(T086): Fetch from get_moderator_stats()
          ),
          const SettingsDivider(),
          const SettingsReadOnlyTile(
            icon: Icons.percent_rounded,
            title: 'Tasso approval',
            value: '87%', // TODO(T086): Fetch from get_moderator_stats()
          ),
        ],
      ),
    );
  }
}
