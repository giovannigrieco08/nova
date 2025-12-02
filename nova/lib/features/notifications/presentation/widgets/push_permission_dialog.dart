// =====================================================================
// Push Permission Dialog - Push Notifications Feature (009)
// =====================================================================
// Purpose: Pre-permission explanation dialog before requesting notification permission
// Shows: Why notifications are useful, what types of notifications user will receive
// =====================================================================

import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';

/// Pre-permission explanation dialog
///
/// Shows before requesting notification permission to explain
/// why notifications are useful and what the user will receive.
///
/// **Usage**:
/// ```dart
/// final result = await showPushPermissionDialog(context);
/// if (result == PushPermissionDialogResult.allow) {
///   // Request actual permission
/// }
/// ```
enum PushPermissionDialogResult {
  /// User tapped "Attiva notifiche"
  allow,

  /// User tapped "Non ora"
  later,

  /// Dialog was dismissed without selection
  dismissed,
}

/// Show pre-permission explanation dialog
///
/// Returns the user's choice.
Future<PushPermissionDialogResult> showPushPermissionDialog(
  BuildContext context,
) async {
  if (Platform.isIOS) {
    return _showCupertinoDialog(context);
  } else {
    return _showMaterialDialog(context);
  }
}

/// iOS-style Cupertino dialog
Future<PushPermissionDialogResult> _showCupertinoDialog(
  BuildContext context,
) async {
  final result = await showCupertinoDialog<PushPermissionDialogResult>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const _CupertinoPermissionDialog(),
  );
  return result ?? PushPermissionDialogResult.dismissed;
}

/// Android-style Material dialog
Future<PushPermissionDialogResult> _showMaterialDialog(
  BuildContext context,
) async {
  final result = await showDialog<PushPermissionDialogResult>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const _MaterialPermissionDialog(),
  );
  return result ?? PushPermissionDialogResult.dismissed;
}

/// Cupertino-style permission dialog
class _CupertinoPermissionDialog extends StatelessWidget {
  const _CupertinoPermissionDialog();

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('Resta sempre aggiornato'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Attiva le notifiche per non perdere nessun evento!',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildBenefitsList(context, isCupertino: true),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: false,
          onPressed: () =>
              Navigator.of(context).pop(PushPermissionDialogResult.later),
          child: const Text('Non ora'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () =>
              Navigator.of(context).pop(PushPermissionDialogResult.allow),
          child: const Text('Attiva notifiche'),
        ),
      ],
    );
  }
}

/// Material-style permission dialog
class _MaterialPermissionDialog extends StatelessWidget {
  const _MaterialPermissionDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NovaRadius.large),
      ),
      backgroundColor: NovaColors.background(context),
      title: Row(
        children: [
          Icon(
            Icons.notifications_active,
            color: NovaColors.primary(context),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Resta sempre aggiornato',
              style: NovaTextStyles.h3.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attiva le notifiche per non perdere nessun evento!',
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 20),
          _buildBenefitsList(context, isCupertino: false),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(PushPermissionDialogResult.later),
          child: Text(
            'Non ora',
            style: TextStyle(
              color: NovaColors.textSecondary(context),
            ),
          ),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(PushPermissionDialogResult.allow),
          style: FilledButton.styleFrom(
            backgroundColor: NovaColors.primary(context),
          ),
          child: const Text('Attiva notifiche'),
        ),
      ],
    );
  }
}

/// Build list of notification benefits
Widget _buildBenefitsList(BuildContext context, {required bool isCupertino}) {
  final benefits = [
    ('Nuovi commenti', 'Quando qualcuno commenta i tuoi eventi'),
    ('Risposte', 'Quando qualcuno risponde ai tuoi commenti'),
    ('Moderazione', 'Quando i tuoi eventi vengono approvati'),
    ('Partecipazioni', 'Quando qualcuno partecipa ai tuoi eventi'),
  ];

  if (isCupertino) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: benefits.map((b) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                CupertinoIcons.checkmark_circle_fill,
                size: 18,
                color: CupertinoColors.activeGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  b.$1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: benefits.map((b) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle,
              size: 20,
              color: NovaColors.success(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.$1,
                    style: NovaTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: NovaColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );
}
