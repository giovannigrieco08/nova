// Screen: SettingsScreen
// Feature: 006-user-profile (User Story 3 - T061)
// Purpose: App settings with Account, Privacy, Notifiche, Info, Moderazione sections

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import '../../../../core/animations/page_transitions.dart';
import '../../domain/entities/profile.dart';
import '../providers/profile_provider.dart';
import '../providers/gdpr_export_provider.dart' show accountDeletionProvider;
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../shared/widgets/adaptive/adaptive_switch.dart';
import '../../../../shared/widgets/adaptive/adaptive_loading_indicator.dart';
import '../../../notifications/presentation/screens/notification_preferences_screen.dart';
import '../../../notifications/presentation/providers/push_permission_provider.dart';
import '../../../notifications/domain/entities/notification_permission_state.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../auth/presentation/screens/login_screen.dart';
// Tutoring feature imports (T049-T052)
import '../../../tutoring/presentation/providers/tutor_providers.dart';
import '../../../tutoring/presentation/screens/become_tutor_screen.dart';
import '../../../tutoring/presentation/screens/edit_tutor_screen.dart';
// Moderation feature import
import '../../../events/presentation/screens/moderation_queue_screen.dart';

/// Provider for app package info (version, build number)
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

/// Settings screen with GDPR compliance
///
/// **Sections**:
/// 1. **Account** (read-only): Email, username, data iscrizione
/// 2. **Privacy**: Toggle "Profilo visibile", "Elimina account"
/// 3. **Notifiche**: Toggles for eventi, chat, moderazione (if moderator)
/// 4. **Ripetizioni**: Tutor settings
/// 5. **Moderazione** (only if role=moderator): Link to dashboard, stats
/// 6. **Info**: App version, privacy policy, terms, open source licenses
/// 7. **Supporto**: Report problem, FAQ, contact
/// 8. **Esci**: Logout button
///
/// **GDPR Compliance**:
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
    // Use Scaffold directly instead of AdaptiveScaffold because this screen
    // uses Material widgets (ListTile) which render better with Material scaffold
    return Scaffold(
      backgroundColor: NovaColors.background(context),
      appBar: AppBar(
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
      ),
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

          // Section 6: Info
          _buildSectionHeader('Info'),
          _buildInfoSection(),

          SizedBox(height: NovaSpacing.large),

          // Section 7: Supporto
          _buildSectionHeader('Supporto'),
          _buildSupportSection(),

          SizedBox(height: NovaSpacing.large),

          // Section 8: Esci
          _buildLogoutSection(),

          SizedBox(height: NovaSpacing.xxlarge),
        ],
      ),
    );
  }

  /// Build Material app bar (used consistently across platform for this screen)
  PreferredSizeWidget _buildMaterialAppBar() {
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
    final formattedDate = '${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
      decoration: BoxDecoration(
        color: NovaColors.backgroundSecondary(context),
        borderRadius: NovaRadius.circularM,
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
        borderRadius: NovaRadius.circularM,
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
        borderRadius: NovaRadius.circularM,
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
                NovaPageRoute.swipeBack(page: const NotificationPreferencesScreen()),
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
                    borderRadius: NovaRadius.circularXs,
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
        borderRadius: NovaRadius.circularM,
      ),
      child: tutorAsync.when(
        data: (tutorProfile) {
          if (tutorProfile == null) {
            // Not a tutor - show "Diventa Tutor" (T051)
            return _buildActionTile(
              icon: Icons.school_rounded,
              title: 'Diventa Tutor',
              subtitle: 'Offri ripetizioni ai tuoi compagni',
              onTap: _navigateToBecomeTutor,
            );
          } else {
            // Is a tutor - show "Gestisci Profilo" (T050)
            return Column(
              children: [
                _buildActionTile(
                  icon: Icons.edit_rounded,
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
          icon: Icons.school_rounded,
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
      NovaPageRoute.swipeBack(page: const BecomeTutorScreen()),
    );
  }

  /// Navigate to EditTutorScreen (T050)
  void _navigateToEditTutor(tutorProfile) {
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(page: EditTutorScreen(profile: tutorProfile)),
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
        borderRadius: NovaRadius.circularM,
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

  /// Section: Info
  Widget _buildInfoSection() {
    final packageInfoAsync = ref.watch(packageInfoProvider);
    final versionString = packageInfoAsync.when(
      data: (info) => '${info.version} (${info.buildNumber})',
      loading: () => '...',
      error: (_, __) => '1.0.0',
    );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
      decoration: BoxDecoration(
        color: NovaColors.backgroundSecondary(context),
        borderRadius: NovaRadius.circularM,
      ),
      child: Column(
        children: [
          _buildReadOnlyTile(
            icon: Icons.info_rounded,
            title: 'Versione',
            value: versionString,
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
          _buildDivider(),
          _buildActionTile(
            icon: Icons.code_rounded,
            title: 'Licenze Open Source',
            subtitle: 'Librerie utilizzate',
            onTap: _openLicenses,
          ),
        ],
      ),
    );
  }

  /// Section: Supporto
  Widget _buildSupportSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
      decoration: BoxDecoration(
        color: NovaColors.backgroundSecondary(context),
        borderRadius: NovaRadius.circularM,
      ),
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.bug_report_rounded,
            title: 'Segnala un problema',
            subtitle: 'Aiutaci a migliorare Nova',
            onTap: _reportProblem,
          ),
          _buildDivider(),
          _buildActionTile(
            icon: Icons.help_outline_rounded,
            title: 'FAQ',
            subtitle: 'Domande frequenti',
            onTap: _openFAQ,
          ),
          _buildDivider(),
          _buildActionTile(
            icon: Icons.mail_outline_rounded,
            title: 'Contattaci',
            subtitle: 'Scrivici per qualsiasi domanda',
            onTap: _contactUs,
          ),
        ],
      ),
    );
  }

  /// Section: Logout
  Widget _buildLogoutSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
      decoration: BoxDecoration(
        color: NovaColors.backgroundSecondary(context),
        borderRadius: NovaRadius.circularM,
      ),
      child: _buildActionTile(
        icon: Icons.logout_rounded,
        title: 'Esci',
        subtitle: 'Disconnetti il tuo account',
        onTap: _showLogoutConfirmation,
        isDestructive: true,
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
      title: Text(
        title,
        style: NovaTypography.bodyMedium.copyWith(
          color: NovaColors.textPrimary(context),
        ),
      ),
      trailing: Text(
        value,
        style: NovaTypography.bodySmall.copyWith(
          color: NovaColors.textSecondary(context),
        ),
      ),
      // No onTap = non-interactive, but visually normal
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
                    ? NovaColors.error(context).withValues(alpha: 0.7)
                    : NovaColors.textSecondary(context),
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
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

        // Logout user after account deletion
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          await ref.read(authNotifierProvider.notifier).signOut();
        }
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
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(page: const ModerationQueueScreen()),
    );
  }

  /// Open privacy policy
  void _openPrivacyPolicy() {
    _showLegalDialog(
      title: 'Privacy Policy',
      content: '''
Nova rispetta la tua privacy e si impegna a proteggere i tuoi dati personali.

DATI RACCOLTI
• Email scolastica (@galileimoro.edu.it)
• Nome e cognome
• Classe frequentata
• Handle Instagram (opzionale)

UTILIZZO DEI DATI
I tuoi dati sono utilizzati esclusivamente per:
• Autenticazione e accesso all'app
• Visualizzazione del profilo agli altri studenti
• Comunicazioni relative agli eventi scolastici

I TUOI DIRITTI (GDPR)
• Diritto di accesso ai tuoi dati
• Diritto alla rettifica
• Diritto alla cancellazione
• Diritto alla portabilità

CONSERVAZIONE
• I messaggi della chat vengono eliminati dopo 24 ore
• L'account può essere eliminato in qualsiasi momento

Per domande sulla privacy: support@galileimoro.edu.it
''',
    );
  }

  /// Open terms of service
  void _openTermsOfService() {
    _showLegalDialog(
      title: 'Termini di Servizio',
      content: '''
Utilizzando Nova, accetti i seguenti termini di servizio.

ACCESSO ALL'APP
• Nova è riservata agli studenti del Liceo Galilei Moro
• L'accesso avviene tramite email scolastica (@galileimoro.edu.it)
• È vietato condividere le credenziali di accesso

COMPORTAMENTO
• Rispetta gli altri utenti
• Non pubblicare contenuti offensivi, illegali o inappropriati
• Non fare spam o molestie
• Segnala contenuti problematici ai moderatori

CONTENUTI
• Sei responsabile dei contenuti che pubblichi
• I moderatori possono rimuovere contenuti inappropriati
• Gli eventi devono essere approvati prima della pubblicazione

ACCOUNT
• Puoi eliminare il tuo account in qualsiasi momento
• La cancellazione diventa effettiva dopo 30 giorni
• I tuoi dati verranno rimossi in modo permanente

MODIFICHE
I termini possono essere aggiornati. Continuerai a usare l'app solo se accetti i nuovi termini.

Ultimo aggiornamento: Dicembre 2024
''',
    );
  }

  /// Open licenses page (built-in Flutter)
  void _openLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'Nova',
      applicationVersion: '1.0.0',
      applicationIcon: Padding(
        padding: EdgeInsets.all(NovaSpacing.medium),
        child: Icon(
          Icons.school_rounded,
          size: 48,
          color: NovaColors.brandViolet,
        ),
      ),
      applicationLegalese: '© 2024 Liceo Galilei Moro\nTutti i diritti riservati.',
    );
  }

  /// Report a problem via email
  void _reportProblem() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@galileimoro.edu.it',
      queryParameters: {
        'subject': '[Nova] Segnalazione problema',
        'body': 'Descrivi il problema:\n\n\n---\nVersione app: 1.0.0\nDispositivo: ${Platform.isIOS ? 'iOS' : 'Android'}',
      },
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showToast('Impossibile aprire l\'app email');
      }
    } catch (e) {
      _showToast('Errore: ${e.toString()}');
    }
  }

  /// Open FAQ
  void _openFAQ() {
    _showFAQDialog();
  }

  /// Show FAQ dialog with expandable questions
  void _showFAQDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NovaColors.background(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.l)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.symmetric(vertical: NovaSpacing.small),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NovaColors.handleBar,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: EdgeInsets.all(NovaSpacing.medium),
              child: Text(
                'Domande Frequenti',
                style: NovaTypography.headingMedium,
              ),
            ),
            // FAQ list
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
                children: const [
                  _FAQItem(
                    question: 'Come creo un evento?',
                    answer: 'Tocca il pulsante + nella schermata Home, compila i dettagli dell\'evento e invialo per l\'approvazione. Un moderatore verificherà il contenuto prima della pubblicazione.',
                  ),
                  _FAQItem(
                    question: 'Quanto tempo ci vuole per approvare un evento?',
                    answer: 'Gli eventi vengono generalmente approvati entro 24 ore. Riceverai una notifica quando il tuo evento sarà pubblicato.',
                  ),
                  _FAQItem(
                    question: 'Come cancello il mio account?',
                    answer: 'Vai su Impostazioni > Privacy > Elimina account. Hai 30 giorni per annullare la cancellazione.',
                  ),
                  _FAQItem(
                    question: 'I messaggi della chat vengono salvati?',
                    answer: 'No, i messaggi della chat vengono automaticamente eliminati dopo 24 ore per proteggere la tua privacy.',
                  ),
                  _FAQItem(
                    question: 'Come segnalo un contenuto inappropriato?',
                    answer: 'Tocca i tre puntini (...) su un evento o commento e seleziona "Segnala". Un moderatore esaminerà la segnalazione.',
                  ),
                  _FAQItem(
                    question: 'Come divento tutor?',
                    answer: 'Vai su Impostazioni > Ripetizioni > Diventa Tutor. Compila il tuo profilo con le materie che offri e il tuo prezzo.',
                  ),
                  _FAQItem(
                    question: 'Chi può vedere il mio profilo?',
                    answer: 'Solo gli altri studenti del Liceo Galilei Moro possono vedere il tuo profilo. Puoi renderlo privato dalle Impostazioni.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Contact us via email
  void _contactUs() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@galileimoro.edu.it',
      queryParameters: {
        'subject': '[Nova] Contatto',
      },
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showToast('Impossibile aprire l\'app email');
      }
    } catch (e) {
      _showToast('Errore: ${e.toString()}');
    }
  }

  /// Show logout confirmation dialog
  void _showLogoutConfirmation() {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Esci'),
          content: const Text('Sei sicuro di voler uscire da Nova?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _performLogout();
              },
              child: const Text('Esci'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Esci'),
          content: const Text('Sei sicuro di voler uscire da Nova?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _performLogout();
              },
              style: TextButton.styleFrom(foregroundColor: NovaColors.error(context)),
              child: const Text('Esci'),
            ),
          ],
        ),
      );
    }
  }

  /// Perform logout
  void _performLogout() async {
    try {
      final success = await ref.read(authNotifierProvider.notifier).signOut();
      if (success && mounted) {
        // Navigate to LoginScreen and clear navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Errore durante il logout: ${e.toString()}');
      }
    }
  }

  // =========================================================================
  // DIALOGS & NOTIFICATIONS
  // =========================================================================

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

  /// Show legal document dialog (Privacy Policy, Terms of Service)
  void _showLegalDialog({required String title, required String content}) {
    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(content, style: const TextStyle(fontSize: 13)),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      );
    }
  }

  /// Build loading view
  Widget _buildLoadingView() {
    return Scaffold(
      backgroundColor: NovaColors.background(context),
      appBar: _buildMaterialAppBar(),
      body: const Center(
        child: AdaptiveLoadingIndicator(),
      ),
    );
  }

  /// Build error view
  Widget _buildErrorView(Object error) {
    return Scaffold(
      backgroundColor: NovaColors.background(context),
      appBar: _buildMaterialAppBar(),
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

/// FAQ Item widget with expandable answer
class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.small,
        vertical: NovaSpacing.xsmall,
      ),
      childrenPadding: EdgeInsets.only(
        left: NovaSpacing.medium,
        right: NovaSpacing.medium,
        bottom: NovaSpacing.medium,
      ),
      title: Text(
        question,
        style: NovaTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        Text(
          answer,
          style: NovaTypography.bodySmall.copyWith(
            color: NovaColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
