import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../domain/entities/event.dart';
import '../providers/events_feed_provider.dart';
import 'event_creation_screen.dart';

/// Shows a participants bottom sheet (currently just empty state).
void showDetailParticipantsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: NovaColors.backgroundLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NovaColors.handleBar,
              borderRadius: NovaRadius.circularXxs,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Partecipanti',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NovaColors.textPrimaryLight,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 64, color: NovaColors.handleBar),
                  const SizedBox(height: 16),
                  Text(
                    'Nessun partecipante ancora',
                    style: TextStyle(
                        fontSize: 16, color: NovaColors.grayDark),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sii il primo a partecipare!',
                    style: TextStyle(
                        fontSize: 14, color: NovaColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shows platform-adaptive menu sheet with edit / delete / report.
void showDetailMenuSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Event event,
  required bool isOwner,
  required bool canEdit,
  required VoidCallback onDelete,
  required VoidCallback onReport,
  required void Function(Event?) onEdited,
}) {
  if (Platform.isIOS) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          if (canEdit)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _navigateToEditEvent(context, ref, event, onEdited);
              },
              child: const Text('Modifica evento'),
            ),
          if (isOwner)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                onDelete();
              },
              child: const Text('Elimina evento'),
            ),
          if (!isOwner)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                onReport();
              },
              child: const Text('Segnala'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annulla'),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifica evento'),
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToEditEvent(context, ref, event, onEdited);
                },
              ),
            if (isOwner)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: NovaColors.error(context)),
                title: Text('Elimina evento',
                    style: TextStyle(color: NovaColors.error(context))),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
              ),
            if (!isOwner)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Segnala'),
                onTap: () {
                  Navigator.pop(ctx);
                  onReport();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows confirm-delete dialog. Returns the deleted event's ID if confirmed.
Future<bool> confirmDeleteEvent({
  required BuildContext context,
  required WidgetRef ref,
  required Event event,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Elimina evento'),
      content: const Text(
          'Sei sicuro di voler eliminare questo evento? Questa azione non può essere annullata.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style:
              TextButton.styleFrom(foregroundColor: NovaColors.error(context)),
          child: const Text('Elimina'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      await ref.read(eventsRepositoryProvider).deleteEvent(event.id);
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: ${e.toString()}')),
        );
      }
      return false;
    }
  }
  return false;
}

// -----------------------------------------------------------------------------
// Private helpers
// -----------------------------------------------------------------------------

void _navigateToEditEvent(
  BuildContext context,
  WidgetRef ref,
  Event event,
  void Function(Event?) onEdited,
) async {
  final result = await Navigator.push<Event>(
    context,
    NovaPageRoute.swipeBack(
      page: EventCreationScreen(eventToEdit: event),
    ),
  );
  onEdited(result);
}
