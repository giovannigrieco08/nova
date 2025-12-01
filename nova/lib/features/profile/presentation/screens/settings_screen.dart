// Screen: SettingsScreen
// Feature: 006-user-profile (User Story 3 - T061)
// Purpose: App settings with Account, Privacy, Notifiche, Info, Moderazione sections

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import '../../domain/entities/profile.dart';
import '../providers/profile_provider.dart';
import '../providers/gdpr_export_provider.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../shared/widgets/adaptive/adaptive_scaffold.dart';
import '../../../../shared/widgets/adaptive/adaptive_switch.dart';
import '../../../../shared/widgets/adaptive/adaptive_loading_indicator.dart';
import '../../../notifications/presentation/screens/notification_preferences_screen.dart';
import '../../../notifications/presentation/providers/push_permission_provider.dart';
import '../../../notifications/domain/entities/notification_permission_state.dart';
// Tutoring feature imports (T049-T052)
import '../../../tutoring/presentation/providers/tutor_providers.dart';
import '../../../tutoring/presentation/screens/become_tutor_screen.dart';
import '../../../tutoring/presentation/screens/edit_tutor_screen.dart';

/// Settings screen with GDPR compliance
///
/// **Sections**:
/// 1. **Account** (read-only): Email, username, data iscrizione
/// 2. **Privacy**: Toggle "Profilo visibile", "Scarica i tuoi dati", "Elimina account"
/// 3. **Notifiche**: Toggles for eventi, chat, moderazione (if moderator)
/// 4. **Info**: App version, privacy policy link, terms of service
/// 5. **Moderazione** (only if role=moderator): Link to dashboard, stats
///
/// **GDPR Compliance**:
/// - Right to Access: "Scarica i tuoi dati" exports JSON <10s (FR-049)
/// - Right to Erasure: "Elimina account" soft-deletes with 30-day grace period
/// - Right to Rectification: Edit profile data via EditProfileScreen
///
/// **Design**:
/// - Platform-adaptive: CupertinoListSection (iOS) / ListTile (Android)
/// - Sections separated with headers
/// - Danger actions (delete account) in red
///
/// **Usage**:
/// ```dart
/// // Navigate from ProfileScreen settings icon (⚙️)
/// Navigator.push(
///   context,
///   Platform.isIOS
///     ? CupertinoPageRoute(builder: (_) => SettingsScreen())
///     : MaterialPageRoute(builder: (_) => SettingsScreen()),
/// )
/// ```
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      data: (profile) => _buildSettingsView(profile),
      loading: () => _buildLoadingView(),
      error: (error, stack) => _buildErrorView(error),
    );
  }

  /// Build settings view with all sections
  Widget _buildSettingsView(Profile profile) {
    return AdaptiveScaffold(
      appBar: _buildAppBar(),
      body: ListView(
        children: [
          SizedBox(height: NovaSpacing.small),

          // Section 1: Account (read-only)
          _buildSectionHeader('Account'),
          _buildAccountSection(profile),

          SizedBox(height: NovaSpacing.large),

          // Section 2: Privacy (GDPR controls)
          _buildSectionHeader('Privacy'),
          _buildPrivacySection(profile),

          SizedBox(height: NovaSpacing.large),

          // Section 3: Notifiche
          _buildSectionHeader('Notifiche'),
          _buildNotificationsSection(profile),

          SizedBox(height: NovaSpacing.large),

          // Section 4: Tutor (T049-T052)
          _buildSectionHeader('Ripetizioni'),
          _buildTutorSection(profile),

          // Section 5: Moderazione (only if moderator)
          if (profile.isModerator) ...[
            SizedBox(height: NovaSpacing.large),
            _buildSectionHeader('Moderazione'),
            _buildModerationSection(profile),
          ],

          SizedBox(height: NovaSpacing.large),

          // Section 5: Info
          _buildSectionHeader('Info'),
          _buildInfoSection(),

          SizedBox(height: NovaSpacing.xxlarge),
        ],
      ),
    );
  }

  /// Build app bar
  PreferredSizeWidget _buildAppBar() {
    if (Platform.isIOS) {
      return const CupertinoNavigationBar(
        middle: Text('Impostazioni'),
        previousPageTitle: 'Profilo',
      );
    } else {
      return AppBar(
        title: Text(
          'Impostazioni',
          style: NovaTypography.headingMedium,
        ),
      );
    }
  }

  /// Build section header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        NovaSpacing.large,
        NovaSpacing.small,
        NovaSpacing.large,
        NovaSpacing.xsmall,
      ),
      child: Text(
        title.toUpperCase(),
        style: NovaTypography.bodySmall.copyWith(
          color: NovaColors.textTertiary(context),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Section 1: Account (read-only info)
  Widget _buildAccountSection(Profile profile) {
    final formattedDate = profile.createdAt.day.toString() +
        '/' +
        profile.createdAt.month.toString() +
        '/' +
        profile.createdAt.year.toString();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
      decoration: BoxDecoration(
        color: NovaColors.backgroundSecondary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildReadOnlyTile(
            icon: Icons.email_rounded,
            title: 'Email',
            value: profile.email,
          ),
          _buildDivider(),
          _buildReadOnlyTile(
            icon: Icons.alternate_email_rounded,
            title: 'Username',
            value: '@${profile.username}',
          ),
          _buildDivider(),
          _buildReadOnlyTile(
            icon: Icons.calendar_today_rounded,
            title: 'Membro dal',
            value: formattedDate,
          ),
        ],
      ),
    );
  }

  /// Section 2: Privacy (GDPR controls)
  Widget _buildPrivacySection(Profile profile) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
      decoration: BoxDecoration(
        color: NovaColors.backgroundSecondary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Toggle: Profilo visibile
          _buildSwitchTile(
            icon: Icons.visibility_rounded,
            title: 'Profilo visibile',
            subtitle: 'Consenti agli altri di vedere il tuo profilo',
            value: profile.profileVisible,
            onChanged: (value) => _toggleProfileVisibility(profile, value),
          ),
          _buildDivider(),

          // Button: Scarica i tuoi dati (GDPR Article 15)
          _buildActionTile(
            icon: Icons.download_rounded,
            title: 'Scarica i tuoi dati',
            subtitle: 'Esporta tutti i tuoi dati in formato JSON',
            onTap: () => _exportUserData(profile),
          ),
          _buildDivider(),

          // Button: Elimina account (GDPR Article 17) - RED
          _buildActionTile(
            icon: Icons.delete_forever_rounded,
            title: 'Elimina account',
            subtitle: '30 giorni per annullare',
            onTap: () => _showDeleteAccountDialog(profile),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  /// Section 3: Notifiche - Navigate to dedicated preferences screen
  Widget _buildNotificationsSection(Profile profile) {
    final permissionState = ref.watch(pushPermissionProvider);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
      decoration: BoxDecoration(
        color: NovaColors.backgroundSecondary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Show "Enable notifications" warning if permission denied
          if (permissionState.status == NotificationPermissionState.denied)
            _buildEnableNotificationsTile(),

          _buildActionTile(
            icon: Icons.notifications_outlined,
            title: 'Preferenze notifiche',
            subtitle: 'Gestisci le notifiche per eventi, commenti e altro',
            onTap: () {
              Navigator.push(
                context,
                Platform.isIOS
                    ? CupertinoPageRoute(
                        builder: (context) => const NotificationPreferencesScreen(),
                      )
                    : MaterialPageRoute(
                        builder: (context) => const NotificationPreferencesScreen(),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Build "Enable notifications" tile for denied users
  Widget _buildEnableNotificationsTile() {
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
                      SizedBox(height: 2),
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

  /// Section 4: Tutor (T049-T052)
  Widget _buildTutorSection(Profile profile) {
    final tutorAsync = ref.watch(currentTutorProfileProvider);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
      decoration: BoxDecoration(
        color: NovaColors.backgroundSecondary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: tutorAsync.when(
        data: (tutorProfile) {
          if (tutorProfile == null) {
            // Not a tutor - show "Diventa Tutor" (T051)
            return _buildActionTile(
              icon: Platform.isIOS ? CupertinoIcons.book : Icons.school_rounded,
              title: 'Diventa Tutor',
              subtitle: 'Offri ripetizioni ai tuoi compagni',
              onTap: _navigateToBecomeTutor,
            );
          } else {
            // Is a tutor - show "Gestisci Profilo" (T050)
            return Column(
              children: [
                _buildActionTile(
                  icon: Platform.isIOS ? CupertinoIcons.pencil : Icons.edit_rounded,
                  title: 'Gestisci Profilo Tutor',
                  subtitle: tutorProfile.isActive
                      ? '${tutorProfile.subjects.length} materie • ${tutorProfile.priceDisplay}'
                      : 'Profilo disattivato',
                  onTap: () => _navigateToEditTutor(tutorProfile),
                ),
                if (!tutorProfile.isActive) ...[
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.visibility_rounded,
                    title: 'Riattiva Profilo',
                    subtitle: 'Torna visibile agli altri studenti',
                    onTap: () => _reactivateTutorProfile(),
                  ),
                ],
              ],
            );
          }
        },
        loading: () => Padding(
          padding: EdgeInsets.all(NovaSpacing.medium),
          child: const Center(child: AdaptiveLoadingIndicator()),
        ),
        error: (_, __) => _buildActionTile(
          icon: Platform.isIOS ? CupertinoIcons.book : Icons.school_rounded,
          title: 'Diventa Tutor',
          subtitle: 'Offri ripetizioni ai tuoi compagni',
          onTap: _navigateToBecomeTutor,
        ),
      ),
    );
  }

  /// Navigate to BecomeTutorScreen (T051)
  void _navigateToBecomeTutor() {
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(builder: (_) => const BecomeTutorScreen())
          : MaterialPageRoute(builder: (_) => const BecomeTutorScreen()),
    );
  }

  /// Navigate to EditTutorScreen (T050)
  void _navigateToEditTutor(tutorProfile) {
    Navigator.push(
      context,
      Platform.isIOS
          ? CupertinoPageRoute(builder: (_) => EditTutorScreen(profile: tutorProfile))
          : MaterialPageRoute(builder: (_) => EditTutorScreen(profile: tutorProfile)),
    );
  }

  /// Reactivate tutor profile (T052)
  void _reactivateTutorProfile() async {
    final notifier = ref.read(toggleTutorActiveProvider.notifier);
    final result = await notifier.reactivate();

    if (result != null && mounted) {
      _showToast('Profilo tutor riattivato!');
    }
  }

  /// Section 5: Moderazione (only if moderator)
  Widget _buildModerationSection(Profile profile) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
      decoration: BoxDecoration(
        color: NovaColors.backgroundSecondary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.dashboard_rounded,
            title: 'Dashboard Moderazione',
            subtitle: 'Gestisci coda moderazione',
            onTap: _navigateToModerationDashboard,
          ),
          _buildDivider(),
          _buildReadOnlyTile(
            icon: Icons.check_circle_rounded,
            title: 'Review effettuate',
            value: '42', // TODO(T086): Fetch from get_moderator_stats()
          ),
          _buildDivider(),
          _buildReadOnlyTile(
            icon: Icons.percent_rounded,
            title: 'Tasso approval',
            value: '87%', // TODO(T086): Fetch from get_moderator_stats()
          ),
        ],
      ),
    );
  }

  /// Section 5: Info
  Widget _buildInfoSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
      decoration: BoxDecoration(
        color: NovaColors.backgroundSecondary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildReadOnlyTile(
            icon: Icons.info_rounded,
            title: 'Versione',
            value: '1.0.0', // TODO: Get from pubspec.yaml or package_info_plus
          ),
          _buildDivider(),
          _buildActionTile(
            icon: Icons.policy_rounded,
            title: 'Privacy Policy',
            subtitle: 'Leggi la nostra informativa privacy',
            onTap: _openPrivacyPolicy,
          ),
          _buildDivider(),
          _buildActionTile(
            icon: Icons.gavel_rounded,
            title: 'Termini di Servizio',
            subtitle: 'Leggi i termini di utilizzo',
            onTap: _openTermsOfService,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TILE BUILDERS
  // =========================================================================

  /// Build read-only info tile
  Widget _buildReadOnlyTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: NovaColors.textSecondary(context)),
      title: Text(title, style: NovaTypography.bodyMedium),
      trailing: Text(
        value,
        style: NovaTypography.bodySmall.copyWith(
          color: NovaColors.textSecondary(context),
        ),
      ),
      enabled: false, // Read-only
    );
  }

  /// Build switch toggle tile
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: NovaColors.textPrimary(context)),
      title: Text(title, style: NovaTypography.bodyMedium),
      subtitle: Text(
        subtitle,
        style: NovaTypography.bodySmall.copyWith(
          color: NovaColors.textSecondary(context),
        ),
      ),
      trailing: AdaptiveSwitch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  /// Build action tile (tappable)
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final titleColor = isDestructive ? NovaColors.error(context) : NovaColors.textPrimary(context);

    return ListTile(
      leading: Icon(icon, color: titleColor),
      title: Text(
        title,
        style: NovaTypography.bodyMedium.copyWith(color: titleColor),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: NovaTypography.bodySmall.copyWith(
                color: isDestructive
                    ? NovaColors.error(context).withOpacity(0.7)
                    : NovaColors.textSecondary(context),
              ),
            )
          : null,
      trailing: Icon(
        Platform.isIOS
            ? CupertinoIcons.chevron_right
            : Icons.chevron_right_rounded,
        color: NovaColors.textTertiary(context),
      ),
      onTap: onTap,
    );
  }

  /// Build divider
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: NovaSpacing.large,
      color: NovaColors.divider(context),
    );
  }

  // =========================================================================
  // INTERACTION HANDLERS
  // =========================================================================

  /// Toggle profile visibility (T064)
  void _toggleProfileVisibility(Profile profile, bool value) async {
    try {
      final updateProfile = ref.read(updateProfileUseCaseProvider);
      await updateProfile(profile.userId, {'profile_visible': value});

      // Invalidate profile to refresh UI
      ref.invalidate(currentProfileProvider);

      if (mounted) {
        _showToast(value ? 'Profilo ora visibile' : 'Profilo ora nascosto');
      }
    } catch (e) {
      if (mounted) {
        _showError('Errore nell\'aggiornare la privacy: ${e.toString()}');
      }
    }
  }

  /// Export user data (T065)
  void _exportUserData(Profile profile) async {
    try {
      final exportNotifier = ref.read(gdprExportProvider.notifier);

      // Show loading dialog
      _showLoadingDialog('Generazione dati in corso...');

      // Trigger export
      await exportNotifier.exportUserData(profile.userId);

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Check export state
      final exportState = ref.read(gdprExportProvider);

      if (exportState.isSuccess) {
        // Show download URL in dialog
        _showDownloadDialog(exportState.metadata!.downloadUrl);
      } else if (exportState.isError) {
        _showError(exportState.errorMessage!);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showError('Errore nell\'esportare i dati: ${e.toString()}');
      }
    }
  }

  /// Show delete account dialog (T066)
  void _showDeleteAccountDialog(Profile profile) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Eliminare account?'),
          content: const Text(
            'Il tuo account sarà eliminato dopo 30 giorni. Puoi annullare entro 30 giorni.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _softDeleteAccount(profile);
              },
              child: const Text('Conferma eliminazione'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminare account?'),
          content: const Text(
            'Il tuo account sarà eliminato dopo 30 giorni. Puoi annullare entro 30 giorni.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _softDeleteAccount(profile);
              },
              style: TextButton.styleFrom(foregroundColor: NovaColors.error(context)),
              child: const Text('Conferma eliminazione'),
            ),
          ],
        ),
      );
    }
  }

  /// Soft delete account (T067)
  void _softDeleteAccount(Profile profile) async {
    try {
      final deleteNotifier = ref.read(accountDeletionProvider.notifier);
      await deleteNotifier.softDeleteAccount(profile.userId);

      final deleteState = ref.read(accountDeletionProvider);

      if (deleteState.isDeleted) {
        // Show confirmation banner
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Account eliminato. Hai 30 giorni per annullare.'),
              backgroundColor: NovaColors.error(context),
              duration: const Duration(seconds: 5),
            ),
          );
        }

        // TODO(T068): Logout user or show reactivation option
      } else if (deleteState.errorMessage != null) {
        _showError(deleteState.errorMessage!);
      }
    } catch (e) {
      if (mounted) {
        _showError('Errore nell\'eliminare l\'account: ${e.toString()}');
      }
    }
  }

  /// Navigate to moderation dashboard
  void _navigateToModerationDashboard() {
    // TODO(US5-Moderation): Navigate to ModerationQueueScreen
    _showToast('Dashboard Moderazione coming soon');
  }

  /// Open privacy policy
  void _openPrivacyPolicy() {
    // TODO: Open browser with URL nova.galileimoro.edu.it/privacy
    _showToast('Privacy Policy: nova.galileimoro.edu.it/privacy');
  }

  /// Open terms of service
  void _openTermsOfService() {
    // TODO: Open browser with URL nova.galileimoro.edu.it/terms
    _showToast('Terms: nova.galileimoro.edu.it/terms');
  }

  // =========================================================================
  // DIALOGS & NOTIFICATIONS
  // =========================================================================

  /// Show loading dialog
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const AdaptiveLoadingIndicator(),
            SizedBox(width: NovaSpacing.medium),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  /// Show download dialog with URL
  void _showDownloadDialog(String downloadUrl) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Dati pronti!'),
          content: Text(
            'I tuoi dati sono pronti per il download. Il link scade tra 24h.\n\n$downloadUrl',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dati pronti!'),
          content: Text(
            'I tuoi dati sono pronti per il download. Il link scade tra 24h.\n\n$downloadUrl',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Show toast message
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: NovaColors.error(context),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Build loading view
  Widget _buildLoadingView() {
    return AdaptiveScaffold(
      appBar: _buildAppBar(),
      body: const Center(
        child: AdaptiveLoadingIndicator(),
      ),
    );
  }

  /// Build error view
  Widget _buildErrorView(Object error) {
    return AdaptiveScaffold(
      appBar: _buildAppBar(),
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
