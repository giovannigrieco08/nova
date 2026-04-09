import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/nova_colors.dart';
import '../../../../../shared/widgets/nova_toast.dart';
import '../../../../auth/presentation/providers/auth_notifier.dart';
import '../../../../auth/presentation/screens/login_screen.dart';
import 'settings_tile_builders.dart';

/// Section 8: Logout.
class SettingsLogoutSection extends ConsumerWidget {
  const SettingsLogoutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionCard(
      child: SettingsActionTile(
        icon: Icons.logout_rounded,
        title: 'Esci',
        subtitle: 'Disconnetti il tuo account',
        onTap: () => _showLogoutConfirmation(context, ref),
        isDestructive: true,
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
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
                _performLogout(context, ref);
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
                _performLogout(context, ref);
              },
              style: TextButton.styleFrom(
                  foregroundColor: NovaColors.error(context)),
              child: const Text('Esci'),
            ),
          ],
        ),
      );
    }
  }

  void _performLogout(BuildContext context, WidgetRef ref) async {
    try {
      final success = await ref.read(authNotifierProvider.notifier).signOut();
      if (success && context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        NovaToast.showError(
            context, 'Errore durante il logout: ${e.toString()}');
      }
    }
  }
}
