import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/animations/page_transitions.dart';
import '../../../../../core/theme/nova_colors.dart';
import '../../../../../shared/widgets/nova_toast.dart';
import '../../../../auth/presentation/providers/auth_notifier.dart';
import '../../../../safety/presentation/screens/blocked_users_screen.dart';
import '../../../domain/entities/profile.dart';
import '../../providers/gdpr_export_provider.dart' show accountDeletionProvider;
import '../../providers/profile_provider.dart';
import 'settings_tile_builders.dart';

/// Section 2: Privacy (GDPR controls).
class SettingsPrivacySection extends ConsumerWidget {
  final Profile profile;

  const SettingsPrivacySection({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionCard(
      child: Column(
        children: [
          SettingsSwitchTile(
            icon: Icons.visibility_rounded,
            title: 'Profilo visibile',
            subtitle: 'Consenti agli altri di vedere il tuo profilo',
            value: profile.profileVisible,
            onChanged: (value) =>
                _toggleProfileVisibility(context, ref, value),
          ),
          const SettingsDivider(),
          SettingsActionTile(
            icon: Icons.block_rounded,
            title: 'Utenti bloccati',
            subtitle: 'Gestisci gli utenti che hai bloccato',
            onTap: () => Navigator.push(
              context,
              NovaPageRoute.swipeBack(page: const BlockedUsersScreen()),
            ),
          ),
          const SettingsDivider(),
          SettingsActionTile(
            icon: Icons.delete_forever_rounded,
            title: 'Elimina account',
            subtitle: '30 giorni per annullare',
            onTap: () => _showDeleteAccountDialog(context, ref),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  void _toggleProfileVisibility(
      BuildContext context, WidgetRef ref, bool value) async {
    try {
      final updateProfile = ref.read(updateProfileUseCaseProvider);
      await updateProfile(profile.userId, {'profile_visible': value});
      ref.invalidate(currentProfileProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(value ? 'Profilo ora visibile' : 'Profilo ora nascosto'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        NovaToast.showError(
            context, 'Errore nell\'aggiornare la privacy: ${e.toString()}');
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
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
                _softDeleteAccount(context, ref);
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
                _softDeleteAccount(context, ref);
              },
              style: TextButton.styleFrom(
                  foregroundColor: NovaColors.error(context)),
              child: const Text('Conferma eliminazione'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _softDeleteAccount(BuildContext context, WidgetRef ref) async {
    debugPrint(
        '[DeleteAccount] Starting soft delete for user: ${profile.userId}');

    try {
      final deleteNotifier = ref.read(accountDeletionProvider.notifier);
      await deleteNotifier.softDeleteAccount(profile.userId);

      final deleteState = ref.read(accountDeletionProvider);
      debugPrint(
          '[DeleteAccount] State: isDeleted=${deleteState.isDeleted}, error=${deleteState.errorMessage}');

      if (deleteState.isDeleted) {
        if (context.mounted) {
          NovaToast.showInfo(
              context, 'Account eliminato. Hai 30 giorni per annullare.');
        }
        await Future.delayed(const Duration(seconds: 2));
        if (context.mounted) {
          await ref.read(authNotifierProvider.notifier).signOut();
        }
      } else if (deleteState.errorMessage != null) {
        if (context.mounted) {
          NovaToast.showError(context, deleteState.errorMessage!);
        }
      } else {
        if (context.mounted) {
          NovaToast.showError(
              context, 'Errore durante l\'eliminazione. Riprova.');
        }
      }
    } catch (e, stack) {
      debugPrint('[DeleteAccount] Exception caught: $e');
      debugPrint('[DeleteAccount] Stack trace: $stack');
      if (context.mounted) {
        NovaToast.showError(context, 'Errore nell\'eliminare l\'account.');
      }
    }
  }
}
