import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/theme/nova_colors.dart';
import '../../../../../core/theme/nova_spacing.dart';
import '../../../../../core/theme/nova_radius.dart';
import '../../../../../core/theme/nova_typography.dart';
import 'settings_tile_builders.dart';

/// Section 7: Supporto (report, FAQ, contact).
class SettingsSupportSection extends StatelessWidget {
  const SettingsSupportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      child: Column(
        children: [
          SettingsActionTile(
            icon: Icons.bug_report_rounded,
            title: 'Segnala un problema',
            subtitle: 'Aiutaci a migliorare Nova',
            onTap: () => _reportProblem(context),
          ),
          const SettingsDivider(),
          SettingsActionTile(
            icon: Icons.help_outline_rounded,
            title: 'FAQ',
            subtitle: 'Domande frequenti',
            onTap: () => _showFAQSheet(context),
          ),
          const SettingsDivider(),
          SettingsActionTile(
            icon: Icons.mail_outline_rounded,
            title: 'Contattaci',
            subtitle: 'Scrivici per qualsiasi domanda',
            onTap: () => _contactUs(context),
          ),
        ],
      ),
    );
  }

  void _reportProblem(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@galileimoro.edu.it',
      queryParameters: {
        'subject': '[Nova] Segnalazione problema',
        'body':
            'Descrivi il problema:\n\n\n---\nVersione app: 1.0.0\nDispositivo: ${Platform.isIOS ? 'iOS' : 'Android'}',
      },
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire l\'app email')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: ${e.toString()}')),
        );
      }
    }
  }

  void _contactUs(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@galileimoro.edu.it',
      queryParameters: {'subject': '[Nova] Contatto'},
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire l\'app email')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: ${e.toString()}')),
        );
      }
    }
  }

  void _showFAQSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NovaColors.background(context),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(NovaRadius.l)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: NovaSpacing.small),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NovaColors.handleBar,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(NovaSpacing.medium),
              child: Text('Domande Frequenti',
                  style: NovaTypography.headingMedium),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding:
                    EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
                children: const [
                  _FAQItem(
                    question: 'Come creo un evento?',
                    answer:
                        'Tocca il pulsante + nella schermata Home, compila i dettagli dell\'evento e invialo per l\'approvazione. Un moderatore verificherà il contenuto prima della pubblicazione.',
                  ),
                  _FAQItem(
                    question:
                        'Quanto tempo ci vuole per approvare un evento?',
                    answer:
                        'Gli eventi vengono generalmente approvati entro 24 ore. Riceverai una notifica quando il tuo evento sarà pubblicato.',
                  ),
                  _FAQItem(
                    question: 'Come cancello il mio account?',
                    answer:
                        'Vai su Impostazioni > Privacy > Elimina account. Hai 30 giorni per annullare la cancellazione.',
                  ),
                  _FAQItem(
                    question: 'I messaggi della chat vengono salvati?',
                    answer:
                        'No, i messaggi della chat vengono automaticamente eliminati dopo 24 ore per proteggere la tua privacy.',
                  ),
                  _FAQItem(
                    question: 'Come segnalo un contenuto inappropriato?',
                    answer:
                        'Tocca i tre puntini (...) su un evento o commento e seleziona "Segnala". Un moderatore esaminerà la segnalazione.',
                  ),
                  _FAQItem(
                    question: 'Come divento tutor?',
                    answer:
                        'Vai su Impostazioni > Ripetizioni > Diventa Tutor. Compila il tuo profilo con le materie che offri e il tuo prezzo.',
                  ),
                  _FAQItem(
                    question: 'Chi può vedere il mio profilo?',
                    answer:
                        'Solo gli altri studenti del Liceo Galilei Moro possono vedere il tuo profilo. Puoi renderlo privato dalle Impostazioni.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FAQItem({required this.question, required this.answer});

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
        style: NovaTypography.bodyMedium
            .copyWith(fontWeight: FontWeight.w600),
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
