// Screen: SettingsScreen
// Feature: Profile settings
// Purpose: Settings hub with sections for account, privacy, notifications,
//          tutoring, moderation, info, support, and logout.

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../shared/widgets/adaptive/adaptive_loading_indicator.dart';
import '../../domain/entities/profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/settings/settings_tile_builders.dart';
import '../widgets/settings/settings_account_section.dart';
import '../widgets/settings/settings_privacy_section.dart';
import '../widgets/settings/settings_notifications_section.dart';
import '../widgets/settings/settings_tutor_section.dart';
import '../widgets/settings/settings_moderation_section.dart';
import '../widgets/settings/settings_info_section.dart';
import '../widgets/settings/settings_support_section.dart';
import '../widgets/settings/settings_logout_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      data: (profile) => _buildSettingsView(context, profile),
      loading: () => _buildLoadingView(context),
      error: (error, stack) => _buildErrorView(context, error),
    );
  }

  Widget _buildSettingsView(BuildContext context, Profile profile) {
    return Scaffold(
      backgroundColor: NovaColors.background(context),
      appBar: _buildAppBar(context),
      body: ListView(
        children: [
          SizedBox(height: NovaSpacing.small),

          const SettingsSectionHeader(title: 'Account'),
          SettingsAccountSection(profile: profile),

          SizedBox(height: NovaSpacing.large),

          const SettingsSectionHeader(title: 'Privacy'),
          SettingsPrivacySection(profile: profile),

          SizedBox(height: NovaSpacing.large),

          const SettingsSectionHeader(title: 'Notifiche'),
          const SettingsNotificationsSection(),

          SizedBox(height: NovaSpacing.large),

          const SettingsSectionHeader(title: 'Ripetizioni'),
          const SettingsTutorSection(),

          if (profile.isModerator) ...[
            SizedBox(height: NovaSpacing.large),
            const SettingsSectionHeader(title: 'Moderazione'),
            const SettingsModerationSection(),
          ],

          SizedBox(height: NovaSpacing.large),

          const SettingsSectionHeader(title: 'Info'),
          const SettingsInfoSection(),

          SizedBox(height: NovaSpacing.large),

          const SettingsSectionHeader(title: 'Supporto'),
          const SettingsSupportSection(),

          SizedBox(height: NovaSpacing.large),

          const SettingsLogoutSection(),

          SizedBox(height: NovaSpacing.xxlarge),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: Icon(
          Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back,
          color: NovaColors.textPrimary(context),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Impostazioni',
        style: NovaTypography.headingMedium.copyWith(
          color: NovaColors.textPrimary(context),
        ),
      ),
      backgroundColor: NovaColors.background(context),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    );
  }

  Widget _buildLoadingView(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background(context),
      appBar: _buildAppBar(context),
      body: const Center(child: AdaptiveLoadingIndicator()),
    );
  }

  Widget _buildErrorView(BuildContext context, Object error) {
    return Scaffold(
      backgroundColor: NovaColors.background(context),
      appBar: _buildAppBar(context),
      body: Center(
        child: Text(
          'Errore nel caricare le impostazioni: ${error.toString()}',
          style: NovaTypography.bodyMedium.copyWith(
            color: NovaColors.error(context),
          ),
        ),
      ),
    );
  }
}
