import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../safety/data/models/report.dart';
import '../../../safety/presentation/widgets/report_sheet.dart';
import '../providers/events_feed_provider.dart';
import 'event_card_models.dart';
import 'help_requests_picker_sheet.dart';
import 'invite_users_sheet.dart';
import 'offer_help_sheet.dart';

// =============================================================================
// Participants sheet
// =============================================================================

/// Shows a draggable bottom sheet listing event participants with search.
void showParticipantsSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String eventId,
  required String eventTitle,
  required VoidCallback onInvite,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.m)),
    ),
    builder: (sheetContext) {
      String searchQuery = '';
      return StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              _buildHandleBar(),
              // Search bar + Invite button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cerca',
                          hintStyle: const TextStyle(
                            fontSize: 16,
                            color: NovaColors.grayDark,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 20,
                            color: NovaColors.grayDark,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 36,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: NovaRadius.circularXs,
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: NovaColors.grayLight,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                        onChanged: (query) {
                          setSheetState(() {
                            searchQuery = query.toLowerCase();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onInvite,
                      child: const Icon(
                        Icons.person_add_outlined,
                        size: 24,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _ParticipantsList(
                  ref: ref,
                  eventId: eventId,
                  searchQuery: searchQuery,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ParticipantsList extends StatelessWidget {
  final WidgetRef ref;
  final String eventId;
  final String searchQuery;
  final ScrollController scrollController;

  const _ParticipantsList({
    required this.ref,
    required this.eventId,
    required this.searchQuery,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(eventsRepositoryProvider).getParticipants(eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.error_outline, size: 64, color: NovaColors.handleBar),
                SizedBox(height: 16),
                Text(
                  'Errore nel caricamento',
                  style: TextStyle(fontSize: 16, color: NovaColors.grayDark),
                ),
              ],
            ),
          );
        }

        var participants = snapshot.data ?? [];

        if (searchQuery.isNotEmpty) {
          participants = participants.where((p) {
            final name = (p['full_name'] as String? ?? '').toLowerCase();
            final className = (p['class'] as String? ?? '').toLowerCase();
            return name.contains(searchQuery) ||
                className.contains(searchQuery);
          }).toList();
        }

        if (participants.isEmpty) {
          final isSearching = searchQuery.isNotEmpty;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSearching ? Icons.search_off : Icons.people_outline,
                  size: 64,
                  color: NovaColors.handleBar,
                ),
                const SizedBox(height: 16),
                Text(
                  isSearching
                      ? 'Nessun risultato'
                      : 'Nessun partecipante ancora',
                  style: const TextStyle(
                      fontSize: 16, color: NovaColors.grayDark),
                ),
                const SizedBox(height: 8),
                Text(
                  isSearching
                      ? 'Prova con un altro nome'
                      : 'Sii il primo a partecipare!',
                  style: const TextStyle(
                      fontSize: 14, color: NovaColors.textTertiaryLight),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          itemCount: participants.length,
          itemBuilder: (context, index) {
            final participant = participants[index];
            final name = participant['full_name'] as String? ?? '';
            final className = participant['class'] as String? ?? '';
            final avatarUrl = participant['avatar_url'] as String?;

            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor:
                    NovaColors.brandViolet.withValues(alpha: 0.2),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: NovaColors.brandViolet,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              subtitle: className.isNotEmpty
                  ? Text(
                      className,
                      style: const TextStyle(
                          fontSize: 14, color: NovaColors.grayDark),
                    )
                  : null,
              onTap: () => Navigator.pop(context),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// Organizers sheet
// =============================================================================

/// Shows a bottom sheet listing all organizers (main + collaborators).
void showOrganizersSheet({
  required BuildContext context,
  required String mainOrganizerName,
  required String mainOrganizerClass,
  required List<EventCollaborator> collaborators,
}) {
  final allOrganizers = [
    EventCollaborator(name: mainOrganizerName, className: mainOrganizerClass),
    ...collaborators,
  ];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.m)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandleBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Organizzatori',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: NovaColors.placeholder,
                    borderRadius: NovaRadius.circularS,
                  ),
                  child: Text(
                    '${allOrganizers.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: NovaColors.grayDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...allOrganizers.asMap().entries.map((entry) {
            final index = entry.key;
            final organizer = entry.value;
            final isMain = index == 0;

            return ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [NovaColors.gradientStart, NovaColors.gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    _getInitials(organizer.name),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      organizer.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMain) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: NovaColors.brandViolet.withValues(alpha: 0.1),
                        borderRadius: NovaRadius.circularXxs,
                      ),
                      child: Text(
                        'Creatore',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: NovaColors.brandViolet,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                organizer.className.isNotEmpty
                    ? organizer.className
                    : 'Studente',
                style: const TextStyle(
                  fontSize: 14,
                  color: NovaColors.grayDark,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to profile
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

// =============================================================================
// Menu sheet (report)
// =============================================================================

/// Shows platform-adaptive action sheet with report option.
void showEventMenuSheet({
  required BuildContext context,
  required String eventId,
}) {
  if (Platform.isIOS) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _showReportSheet(context, eventId);
            },
            child: const Text('Segnala'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.flag_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Segnala',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              subtitle: Text(
                'Segnala contenuto inappropriato',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showReportSheet(context, eventId);
              },
            ),
          ],
        ),
      ),
    );
  }
}

void _showReportSheet(BuildContext context, String eventId) {
  ReportCategorySheet.show(
    context,
    contentType: ReportableContentType.event,
    contentId: eventId,
  );
}

// =============================================================================
// Invite sheet
// =============================================================================

/// Opens the invite users sheet for an event.
void showInviteSheet({
  required BuildContext context,
  required String eventId,
  required String eventTitle,
}) {
  Navigator.pop(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.m)),
    ),
    builder: (context) => InviteUsersSheet(
      eventId: eventId,
      eventTitle: eventTitle,
    ),
  );
}

// =============================================================================
// Help offer sheets
// =============================================================================

/// Handle "Offri aiuto" button tap.
/// If 1 request → open OfferHelpSheet directly.
/// If multiple → open HelpRequestsPickerSheet to choose.
void handleOfferHelp({
  required BuildContext context,
  required String eventId,
  required List<HelpRequestInfo> openRequests,
}) {
  if (openRequests.length == 1) {
    _showOfferHelpSheet(context, eventId, openRequests.first);
  } else {
    _showHelpRequestsPickerSheet(context, eventId, openRequests);
  }
}

void _showOfferHelpSheet(
    BuildContext context, String eventId, HelpRequestInfo request) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.m)),
    ),
    builder: (context) => OfferHelpSheet(
      requestId: request.id,
      requestDescription: request.description,
      eventId: eventId,
    ),
  );

  if (context.mounted && result != null && result != 'success') {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(result), backgroundColor: Colors.red),
    );
  }
}

void _showHelpRequestsPickerSheet(
    BuildContext context, String eventId, List<HelpRequestInfo> requests) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.m)),
    ),
    builder: (context) => HelpRequestsPickerSheet(
      requests: requests,
      onRequestSelected: (request) {
        Navigator.pop(context);
        _showOfferHelpSheet(context, eventId, request);
      },
    ),
  );
}

// =============================================================================
// Shared helpers
// =============================================================================

Widget _buildHandleBar() {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: NovaColors.handleBar,
      borderRadius: NovaRadius.circularXxs,
    ),
  );
}

String _getInitials(String name) {
  final parts = name.trim().split(' ');
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
