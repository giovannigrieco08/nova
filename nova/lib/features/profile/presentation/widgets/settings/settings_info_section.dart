import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../../core/animations/page_transitions.dart';
import '../../../../../core/theme/nova_colors.dart';
import '../../../../../core/theme/nova_spacing.dart';
import '../../../../safety/presentation/screens/tos_acceptance_screen.dart';
import 'settings_tile_builders.dart';

/// Provider for package info (kept local to this section).
final _packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// Section 6: Info (version, privacy policy, ToS, licenses).
class SettingsInfoSection extends ConsumerWidget {
  const SettingsInfoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfoAsync = ref.watch(_packageInfoProvider);
    final versionString = packageInfoAsync.when(
      data: (info) => '${info.version} (${info.buildNumber})',
      loading: () => '...',
      error: (_, __) => '1.0.0',
    );

    return SettingsSectionCard(
      child: Column(
        children: [
          SettingsReadOnlyTile(
            icon: Icons.info_rounded,
            title: 'Versione',
            value: versionString,
          ),
          const SettingsDivider(),
          SettingsActionTile(
            icon: Icons.policy_rounded,
            title: 'Privacy Policy',
            subtitle: 'Leggi la nostra informativa privacy',
            onTap: () => _openPrivacyPolicy(context),
          ),
          const SettingsDivider(),
          SettingsActionTile(
            icon: Icons.gavel_rounded,
            title: 'Termini di Servizio',
            subtitle: 'Leggi i termini di utilizzo',
            onTap: () => Navigator.push(
              context,
              NovaPageRoute.swipeBack(page: const TosAcceptanceScreen()),
            ),
          ),
          const SettingsDivider(),
          SettingsActionTile(
            icon: Icons.code_rounded,
            title: 'Licenze Open Source',
            subtitle: 'Librerie utilizzate',
            onTap: () => _openLicenses(context),
          ),
        ],
      ),
    );
  }

  void _openPrivacyPolicy(BuildContext context) {
    const content = '''
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
''';

    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Privacy Policy'),
          content: const SingleChildScrollView(
            child: Text(content, style: TextStyle(fontSize: 13)),
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
          title: const Text('Privacy Policy'),
          content: const SingleChildScrollView(child: Text(content)),
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

  void _openLicenses(BuildContext context) {
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
      applicationLegalese:
          '© 2024 Liceo Galilei Moro\nTutti i diritti riservati.',
    );
  }
}
