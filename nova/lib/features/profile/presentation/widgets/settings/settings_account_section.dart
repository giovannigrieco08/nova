import 'package:flutter/material.dart';
import '../../../domain/entities/profile.dart';
import 'settings_tile_builders.dart';

/// Section 1: Account (read-only info).
class SettingsAccountSection extends StatelessWidget {
  final Profile profile;

  const SettingsAccountSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        '${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}';

    return SettingsSectionCard(
      child: Column(
        children: [
          SettingsReadOnlyTile(
            icon: Icons.email_rounded,
            title: 'Email',
            value: profile.email,
          ),
          const SettingsDivider(),
          SettingsReadOnlyTile(
            icon: Icons.alternate_email_rounded,
            title: 'Username',
            value: '@${profile.username}',
          ),
          const SettingsDivider(),
          SettingsReadOnlyTile(
            icon: Icons.calendar_today_rounded,
            title: 'Membro dal',
            value: formattedDate,
          ),
        ],
      ),
    );
  }
}
