import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tos_provider.dart';

/// Screen for displaying and accepting Terms of Service
class TosAcceptanceScreen extends ConsumerStatefulWidget {
  const TosAcceptanceScreen({
    super.key,
    this.onAccepted,
    this.showBackButton = true,
  });

  final VoidCallback? onAccepted;
  final bool showBackButton;

  /// Route name for navigation
  static const String routeName = '/tos-acceptance';

  @override
  ConsumerState<TosAcceptanceScreen> createState() =>
      _TosAcceptanceScreenState();
}

class _TosAcceptanceScreenState extends ConsumerState<TosAcceptanceScreen> {
  final _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      if (!_hasScrolledToBottom) {
        setState(() => _hasScrolledToBottom = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tosState = ref.watch(tosNotifierProvider);
    final version = ref.watch(currentTosVersionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Termini di Servizio'),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        automaticallyImplyLeading: widget.showBackButton,
      ),
      body: Column(
        children: [
          // Version info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Versione $version',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          // ToS content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    context,
                    title: 'Accettazione dei Termini',
                    content:
                        'Utilizzando Nova, accetti di essere vincolato da questi Termini di Servizio. Se non accetti questi termini, non puoi utilizzare l\'app.',
                  ),
                  _buildSection(
                    context,
                    title: 'Idoneità',
                    content:
                        'Nova è destinato agli studenti delle scuole superiori italiane (14-19 anni). Per utilizzare Nova devi essere uno studente iscritto a una scuola superiore italiana, avere un indirizzo email scolastico valido e utilizzare il tuo nome reale.',
                  ),
                  _buildSection(
                    context,
                    title: 'Condotta dell\'Utente',
                    content:
                        'Ti impegni a rispettare gli altri utenti, condividere contenuti appropriati per l\'ambiente scolastico e segnalare contenuti inappropriati quando li incontri.',
                  ),
                  _buildHighlightedSection(
                    context,
                    title: '⚠️ Tolleranza Zero per Contenuti Offensivi',
                    content: '''
Nova adotta una politica di TOLLERANZA ZERO per:

• Bullismo e cyberbullismo
• Contenuti discriminatori
• Linguaggio d'odio
• Molestie sessuali
• Minacce di violenza
• Contenuti illegali

Le violazioni comportano:
1ª violazione: Avvertimento formale
2ª violazione: Sospensione temporanea (7 giorni)
3ª violazione: Ban permanente

Per violazioni gravi, Nova procederà direttamente al ban permanente.''',
                  ),
                  _buildSection(
                    context,
                    title: 'Segnalazioni e Moderazione',
                    content:
                        'Puoi segnalare qualsiasi contenuto inappropriato tramite il pulsante "Segnala". Le segnalazioni vengono esaminate entro 24 ore. L\'identità di chi segnala rimane anonima.',
                  ),
                  _buildSection(
                    context,
                    title: 'Blocco Utenti',
                    content:
                        'Puoi bloccare qualsiasi utente in qualsiasi momento. Gli utenti bloccati non possono vedere i tuoi contenuti o contattarti. Il blocco è privato: l\'utente bloccato non viene notificato.',
                  ),
                  _buildSection(
                    context,
                    title: 'Privacy',
                    content:
                        'Non vendiamo i tuoi dati a terze parti. Puoi richiedere l\'esportazione o la cancellazione dei tuoi dati in qualsiasi momento.',
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Scorri fino in fondo per accettare i termini.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 100), // Extra space at bottom
                ],
              ),
            ),
          ),

          // Accept button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  if (tosState.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        tosState.error!,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _hasScrolledToBottom && !_isAccepting
                          ? _acceptTos
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isAccepting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _hasScrolledToBottom
                                  ? 'Ho letto e accetto i Termini di Servizio'
                                  : 'Scorri per leggere i termini',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptTos() async {
    setState(() => _isAccepting = true);

    final success = await ref.read(tosNotifierProvider.notifier).acceptTos();

    setState(() => _isAccepting = false);

    if (success && mounted) {
      widget.onAccepted?.call();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Termini di Servizio accettati'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

/// Show ToS acceptance dialog if needed
///
/// Returns true if ToS was accepted or already accepted
/// Returns false if user dismissed without accepting
Future<bool> showTosAcceptanceIfNeeded(
    BuildContext context, WidgetRef ref) async {
  final needsAcceptance = await ref.read(needsTosAcceptanceProvider.future);

  if (!needsAcceptance) {
    return true; // Already accepted
  }

  if (!context.mounted) return false;

  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (context) => const TosAcceptanceScreen(
        showBackButton: true,
      ),
      fullscreenDialog: true,
    ),
  );

  return result ?? false;
}
